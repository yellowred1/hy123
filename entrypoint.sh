#!/bin/sh
set -e

# ======== 环境变量校验 ========
[ -z "$IN_PORT" ] && { echo "❌ IN_PORT 未设置"; exit 1; }
[ -z "$HOST"    ] && { echo "❌ HOST 未设置";    exit 1; }
[ -z "$PORT"    ] && { echo "❌ PORT 未设置";    exit 1; }

HOST=$(curl -s cip.cc | grep -oE 'IP\s*:\s*[0-9.]+'

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

    # 安全转义 JSON 字符串：防止 "、\ 等破坏 JSON 结构
    # 使用 POSIX sh 兼容方式（busybox sh 友好）
    escaped_msg=$(printf '%s' "$msg" | sed 's/"/\\"/g; s/\\/\\\\/g')

    if command -v curl >/dev/null 2>&1; then
        # 标准 POST JSON 方式（推荐）
        if curl -fsS --connect-timeout 5 --max-time 10 \
            -X POST "$url" \
            -H "Content-Type: application/json" \
            -d "{\"content\":\"$escaped_msg\"}" \
            -o /dev/null; then
            echo "✅ 通知已发送 (POST JSON)"
        else
            echo "⚠️ 通知发送失败（请检查 webhook 地址是否支持 POST JSON）"
        fi
    elif command -v wget >/dev/null 2>&1; then
        # wget fallback（需支持 --post-data）
        if wget -q --timeout=10 --method=POST \
            --header="Content-Type: application/json" \
            --post-data="{\"content\":\"$escaped_msg\"}" \
            -O /dev/null "$url"; then
            echo "✅ 通知已通过 wget 发送"
        else
            echo "⚠️ wget POST 失败"
        fi
    else
        echo "ℹ️ 未安装 curl/wget，跳过通知"
    fi
}

# 从环境变量读取 webhook URL
WEBHOOK_URL="${NOTIFY_WEBHOOK:-}"

# 可选：禁用通知
[ "${NOTIFY_DISABLE:-0}" = "1" ] && { echo "🔕 通知已禁用"; echo; } && \
  echo "🚀 启动 Hysteria2 服务..." && exec /app/hysteria server -c /app/config.yaml

if [ -n "$WEBHOOK_URL" ]; then
    echo "📩 发送 POST 通知至: $WEBHOOK_URL"
    # 后台发送，避免阻塞

    # 构造带换行的通知内容
    NOTIFICATION_MSG="🎉 新 Hysteria 链接生成：
${RAW_LINK}

    
    send_post_notification "$WEBHOOK_URL" "$NOTIFICATION_MSG" &
    # 等 0.1 秒让子进程 fork 出去（避免 exec 前被 kill）
    sleep 0.1
else
    echo "ℹ️ 未设置 NOTIFY_WEBHOOK，跳过通知"
fi

echo
echo "🚀 启动 Hysteria2 服务..."
exec /app/hysteria server -c /app/config.yaml
