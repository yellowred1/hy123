#!/bin/sh
set -e

# ======== 实用函数定义（前置） ========
# 安全地转义 JSON 字符串（兼容 POSIX sh，避免依赖 jq/sed 有歧义行为）
escape_json() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/ /\\u0020/g'
}

# 通知发送统一入口
send_notification() {
    local webhook_url="$1"
    local title="$2"
    local content="$3"

    [ -z "$webhook_url" ] && return 0

    local escaped_title escaped_content
    escaped_title=$(escape_json "$title")
    escaped_content=$(escape_json "$content")

    local json_payload
    # 支持通用 webhook：Discord / 飞书 / 企业微信 / 自定义 JSON 接收端
    # 按 content 字段发送（最通用）
    json_payload="{\"content\":\"${escaped_title}\\n${escaped_content}\"}"

    if command -v curl >/dev/null 2>&1; then
        if curl -fsS --connect-timeout 5 --max-time 10 \
            -X POST "$webhook_url" \
            -H "Content-Type: application/json" \
            -d "$json_payload" >/dev/null; then
            echo "✅ 通知已发送"
            return 0
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q --timeout=10 --method=POST \
            --header="Content-Type: application/json" \
            --post-data="$json_payload" \
            -O /dev/null "$webhook_url" 2>/dev/null; then
            echo "✅ 通知已通过 wget 发送"
            return 0
        fi
    fi
    echo "⚠️ 通知发送失败或工具不可用"
    return 1
}

# ======== 环境变量校验 ========
# 必填项：claw 的端口
[ -z "${IN_PORT}" ] && { echo "❌ IN_PORT 未设置"; exit 1; }
# 必填项：claw给的host和端口
[ -z "${HOST}"   ] && { echo "❌ HOST 未设置";   exit 1; }
[ -z "${PORT}"   ] && { echo "❌ PORT 未设置";   exit 1; }

# 密码处理：若未设 PW，则用 hostname（但需限制长度/特殊字符？）
if [ -z "${PW}" ]; then
    PW="$(hostname)"
    echo "ℹ️ PW 未设置，使用 hostname 作为密码：$(echo "$PW")" 
    echo "   （实际值：$PW）"
else
    echo "ℹ️ 使用环境变量 PW"
fi

# 校验密码是否含非法字符（Hysteria2 password 不支持 ? # @ 等 URL 关键字符！）
case "$PW" in
    *[\?\#\@\&\=]*)
        echo "❌ PW 含非法 URL 字符（?, #, @, &, =），会导致客户端链接解析失败！"
        echo "   请改用纯字母数字密码，例如：PW=MySecure123"
        exit 1
        ;;
esac

# ======== 生成配置文件 ========
cat > /app/config.yaml <<EOF
listen: :${IN_PORT}

auth:
  type: password
  password: ${PW}

tls:
  cert: /app/cert.pem
  key: /app/cert.key
EOF

# ======== 构造客户端链接 ========
# 注意：hy2:// 协议中 password 不可含特殊字符！已提前校验
LINK="hy2://${PW}@${HOST}:${PORT}?sni=www.bing.com&insecure=1&alpn=h3#my_hy2"

echo "=============================================="
echo "                🚀 Hysteria2 服务已启动"
echo "=============================================="
echo "🔗 客户端链接（请复制使用）："
echo "$LINK"
echo

# ======== 异步通知（防阻塞主进程） ========
if [ "${NOTIFY_DISABLE:-0}" = "1" ]; then
    echo "🔕 通知已禁用 (NOTIFY_DISABLE=1)"
elif [ -n "${NOTIFY_WEBHOOK}" ]; then
    echo "📩 正在异步发送通知至 webhook..."
    
    # 构造通知内容（隐藏密码防泄密！）
    NOTI_TITLE="🎉 Hysteria2 服务就绪"
    NOTI_CONTENT="\
🔹${LINK}

💡 提示：长按链接 → 全选 → 复制粘贴到客户端"

    # 异步发送（用 () & 避免子 shell 变量污染）
    (
        send_notification "$NOTIFY_WEBHOOK" "$NOTI_TITLE" "$NOTI_CONTENT"
    ) &
    # 小睡确保子进程 fork 成功（非必需，但更稳妥）
    sleep 0.05
else
    echo "ℹ️ 未设置 NOTIFY_WEBHOOK，跳过通知"
fi

# ======== 启动服务（exec 替换进程） ========
echo "🚀 启动 Hysteria2 服务（监听 :${IN_PORT}）..."
exec /app/hysteria server -c /app/config.yaml
