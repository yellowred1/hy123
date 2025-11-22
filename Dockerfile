# Dockerfile
FROM alpine:latest
RUN apk add --no-cache ca-certificates tzdata
WORKDIR /app
COPY hysteria /app/hysteria          # 二进制（见下方说明）
COPY cert.pem /app/cert.pem
COPY cert.key /app/cert.key
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/hysteria /app/entrypoint.sh
ENV TZ=Asia/Shanghai
ENTRYPOINT ["/app/entrypoint.sh"]
