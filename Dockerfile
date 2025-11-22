# 使用 Alpine 基础镜像
FROM alpine:latest

# 安装依赖
RUN apk add --no-cache ca-certificates tzdata curl

# 设置工作目录
WORKDIR /app

# 构建时下载 Hysteria2 二进制（用国内镜像加速）
RUN curl -Lk -o hysteria "http://ghproxy.com/https://github.com/apernet/hysteria/releases/download/app%2Fv2.6.2/hysteria-linux-amd64" \
    && chmod +x hysteria

# 复制证书和启动脚本
COPY cert.pem /app/cert.pem
COPY cert.key /app/cert.key
COPY entrypoint.sh /app/entrypoint.sh

# 赋予执行权限
RUN chmod +x /app/entrypoint.sh

# 设置时区
ENV TZ=Asia/Shanghai

# 启动命令
ENTRYPOINT ["/app/entrypoint.sh"]
