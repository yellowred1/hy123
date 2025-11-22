#!/bin/sh
set -e

# ======== 环境变量校验 ========
[ -z "$IN_PORT" ] && { echo "❌ IN_PORT 未设置"; exit 1; }
[ -z "$HOST"    ] && { echo "❌ HOST 未设置";    exit 1; }
[ -z "$PORT"    ] && { echo "❌ PORT 未设置";    exit 1; }


if [ -z "$PW" ]; then
    PW=$(hostname)
    echo "PW 环境变量未设置，使用hostname作为密码：$PW"
else
    echo "使用环境变量的密码: $PW"
fi

# ======== 生成配置文件 ========
cat > /app/config.yaml <<EOF
listen: :${IN_PORT}

auth:
  type: password
  password: $PW

tls:
  cert: /app/cert.pem
  key: /app/cert.key
EOF

# ======== 生成客户端链接 ========
LINK="hy2://${PW}@${HOST}:${PORT}?sni=www.bing.com&insecure=1&alpn=h3#my_hy2"

echo "=============================================="
echo "                🚀 Hysteria2 服务已启动"
echo "=============================================="
echo "🔗 客户端链接:"
echo "$LINK"
echo

# ======== 发送 POST 通知（安全版） ========
send_post_notification() {
    local url="$1"
    local msg="$2"

    # 构造两行内容：标题 + 换行 + 链接
    # 使用 \\n 实现在 JSON 中换行（最终为 \n）
    escaped_msg=$(printf '%s\\n%s' "🎉 新 Hysteria 链接生成：" "$msg" | \
                  sed 's/"/\\"/g; s/\\/\\\\/g')

    if command -v curl >/dev/null 2>&1; then
        if curl -fsS --connect-timeout 5 --max-time 10 \
            -X POST "$url" \
            -H "Content-Type: application/json" \
            -d "{\"content\":\"$escaped_msg\"}" \
            -o /dev/null; then
            echo "✅ 通知已发送 (POST JSON)"
            return 0
        fi
    fi

    if command -v wget >/dev/null 2>&1; then
        if wget -q --timeout=10 --method=POST \
            --header="Content-Type: application/json" \
            --post-data="{\"content\":\"$escaped_msg\"}" \
            -O /dev/null "$url" 2>/dev/null; then
            echo "✅ 通知已通过 wget 发送"
            return 0
        fi
    fi

    echo "⚠️ 通知发送失败或 curl/wget 未安装"
}

# ======== 主流程 ========
WEBHOOK_URL="${NOTIFY_WEBHOOK:-}"
NOTIFY_DISABLED="${NOTIFY_DISABLE:-0}"

# 如启用通知且有 webhook URL，则后台发送
if [ "$NOTIFY_DISABLED" != "1" ] && [ -n "$WEBHOOK_URL" ]; then
    echo "📩 发送 POST 通知至: $WEBHOOK_URL"
    send_post_notification "$WEBHOOK_URL" "$LINK" &
    sleep 0.1  # 确保子进程 fork 完成
else
    if [ "$NOTIFY_DISABLED" = "1" ]; then
        echo "🔕 通知已禁用"
    else
        echo "ℹ️ 未设置 NOTIFY_WEBHOOK，跳过通知"
    fi
fi

echo
echo "🚀 启动 Hysteria2 服务..."
exec /app/hysteria server -c /app/config.yaml
