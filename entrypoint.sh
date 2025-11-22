#!/bin/sh
set -e

# ======== 环境变量校验 ========
[ -z "$IN_PORT" ] && { echo "❌ IN_PORT 未设置"; exit 1; }
[ -z "$HOST"    ] && { echo "❌ HOST 未设置";    exit 1; }
[ -z "$PORT"    ] && { echo "❌ PORT 未设置";    exit 1; }

if [ -z "$PW" ]; then
    PW=$(hostname)
    echo "🔑 PW 环境变量未设置，使用 hostname 作为密码: $PW"
else
    echo "🔑 使用环境变量密码: ${PW:0:3}***"
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
echo "🔗 客户端链接（推荐复制整行）:"
echo "$LINK"
echo

# ======== 发送 form-data 通知（推荐）========
send_post_notification() {
    local url="$1"
    local msg="$2"

    if command -v curl >/dev/null 2>&1; then
        # ✅ 核心：--data-urlencode 自动处理换行 & 特殊字符
        if curl -fsS --connect-timeout 5 --max-time 10 \
            -X POST "$url" \
            --data-urlencode "content=$msg" \
            -o /dev/null; then
            echo "✅ 通知已通过 curl 发送"
            return 0
        fi
    fi

    # wget fallback（部分系统无 curl）
    if command -v wget >/dev/null 2>&1; then
        # 注意：wget 不支持 --data-urlencode，需手动编码 \n → %0A
        encoded_msg=$(printf '%s' "$msg" | sed ':a;N;$!ba;s/\n/%0A/g')
        if wget -q --timeout=10 --post-data="content=$encoded_msg" -O /dev/null "$url"; then
            echo "✅ 通知已通过 wget 发送"
            return 0
        fi
    fi

    echo "⚠️ 通知失败：curl/wget 未安装或网络错误"
    return 1
}

# ======== 主流程 ========
WEBHOOK_URL="${NOTIFY_WEBHOOK:-}"
NOTIFY_DISABLED="${NOTIFY_DISABLE:-0}"

if [ "$NOTIFY_DISABLED" = "1" ]; then
    echo "🔕 通知已禁用 (NOTIFY_DISABLE=1)"
elif [ -n "$WEBHOOK_URL" ]; then
    echo "📩 发送通知至: $WEBHOOK_URL"

    # 构造带换行的通知内容（⚠️ 用 LINK，不是 RAW_LINK）
    NOTIFICATION_MSG="🎉 新 Hysteria 链接生成：
$LINK"

    # ✅ 后台发送，避免阻塞
    send_post_notification "$WEBHOOK_URL" "$NOTIFICATION_MSG" &
    sleep 0.1
else
    echo "ℹ️ 未设置 NOTIFY_WEBHOOK，跳过通知"
fi

echo
echo "🚀 启动 Hysteria2 服务..."
exec /app/hysteria server -c /app/config.yaml
