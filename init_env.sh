#!/bin/bash

set -Eeuo pipefail

# ✅ 错误追踪机制
function error_handler() {
    local exit_code=$?
    local line_no=$1
    local cmd=$2
    echo -e "\n[❌] 脚本发生错误，退出码：$exit_code"
    echo "[🧭] 出错行号：$line_no"
    echo "[💥] 出错命令：$cmd"
    echo "[📌] 脚本路径：$(realpath "$0")"
    exit $exit_code
}
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

# 定义全局路径
ROOT_DIR="/home/dockerdata"
WEB_DIR="$ROOT_DIR/docker_web"
CADDY_DIR="$ROOT_DIR/docker_caddy"
CADDYFILE="$CADDY_DIR/Caddyfile"

# 创建目录结构
mkdir -p "$WEB_DIR"
mkdir -p "$CADDY_DIR"

echo "[*] 创建站点与 Caddy 配置目录..."
echo "[*] Caddyfile 路径: $CADDYFILE"

# 创建空 Caddyfile 如未存在
if [[ ! -f "$CADDYFILE" ]]; then
    echo "[*] 初始化空白 Caddyfile"
    echo "{" > "$CADDYFILE"
    echo "    email admin@yourdomain.com" >> "$CADDYFILE"
    echo "}" >> "$CADDYFILE"
fi

# 创建 Docker 网络（仅在不存在时）
if ! docker network ls | grep -q caddy_net; then
    echo "[*] 创建 Caddy 专用 Docker 网络 (caddy_net)..."
    docker network create caddy_net
else
    echo "[✓] Docker 网络 caddy_net 已存在，跳过创建"
fi

# 启动 Caddy 容器（Docker 版）
if ! docker ps | grep -q caddy-proxy; then
    echo "[*] 启动 Caddy 反向代理容器..."
    docker run -d \
        --name caddy-proxy \
        --restart unless-stopped \
        -p 80:80 -p 443:443 \
        -v "$CADDYFILE":/etc/caddy/Caddyfile:ro \
        -v caddy_data:/data \
        -v caddy_config:/config \
        --network caddy_net \
        caddy:2 \
        caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
    echo "[√] Caddy 已启动并监听 80/443 端口"
else
    echo "[✓] Caddy 容器已在运行中，跳过启动"
fi

echo -e "\n[✅] 初始化完成，可运行主菜单脚本 main.sh 开始部署站点"
