#!/bin/sh
set -e  # 遇错立即退出

# ========================
# 环境变量默认值 & 校验
# ========================

# 必填项校验
[ -z "$IN_PORT" ] && { echo "❌ IN_PORT 未设置"; exit 1; }
[ -z "$HOST"    ] && { echo "❌ HOST 未设置";    exit 1; }
[ -z "$PORT"    ] && { echo "❌ PORT 未设置";    exit 1; }
[ -z "$SNI"     ] && SNI="www.bing.com"  # 默认 SNI

# 密码处理：必须设置，否则报错
if [ -z "$PW" ]; then
    echo "❌ PW 环境变量未设置，请指定密码！"
    exit 1
fi

echo "✅ 使用密码: ${PW:0:3}***"

# 检查端口是否为数字
case $IN_PORT in
  ''|*[!0-9]*) echo "❌ IN_PORT 必须是数字"; exit 1 ;;
esac
case $PORT in
  ''|*[!0-9]*) echo "❌ PORT 必须是数字"; exit 1 ;;
esac

# ========================
# 生成配置文件 config.yaml
# ========================

cat > /app/config.yaml <<EOF
listen: :${IN_PORT}

auth:
  type: password
  password: $PW

tls:
  cert: /app/cert.pem
  key: /app/cert.key
EOF

echo "✅ 配置文件已生成: /app/config.yaml"

# ========================
# 输出客户端连接信息
# ========================

LINK="hy2://${PW}@${HOST}:${PORT}?sni=${SNI}&insecure=1&alpn=h3#my_hy2"
echo "=============================================="
echo "                🚀 Hysteria2 服务已启动"
echo "=============================================="
echo "🔗 客户端链接:"
echo "$LINK"
echo "$LINK" > /app/link.txt
echo "📌 链接已保存至 /app/link.txt"

# ========================
# 启动服务（前台运行！）
# ========================

echo "🚀 正在启动 Hysteria2 服务..."
exec /app/hysteria server -c /app/config.yaml
