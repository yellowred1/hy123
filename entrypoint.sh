#!/bin/sh
set -e

# 校验必要环境变量
[ -z "$IN_PORT" ] && { echo "❌ IN_PORT 未设置"; exit 1; }
[ -z "$HOST"    ] && { echo "❌ HOST 未设置";    exit 1; }
[ -z "$PORT"    ] && { echo "❌ PORT 未设置";    exit 1; }
[ -z "$PW"      ] && { echo "❌ PW 未设置";      exit 1; }

# 生成配置文件
cat > /app/config.yaml <<EOF
listen: :${IN_PORT}

auth:
  type: password
  password: $PW

tls:
  cert: /app/cert.pem
  key: /app/cert.key
EOF

# 输出客户端链接
LINK="hy2://${PW}@${HOST}:${PORT}?sni=www.bing.com&insecure=1&alpn=h3#my_hy2"
echo "=============================================="
echo "                🚀 Hysteria2 服务已启动"
echo "=============================================="
echo "🔗 客户端链接:"
echo "$LINK"

# 前台启动服务
exec /app/hysteria server -c /app/config.yaml
