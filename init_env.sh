#!/bin/bash

# ===========================
# WordPress 多站部署环境初始化脚本
# 作者：LEOLAB
# 说明：用于首次运行时部署 Docker + Caddy 所需环境
# ===========================
# ===========================

# ✅ 启用严格模式 + 错误追踪
set -Eeuo pipefail

# ✅ 错误处理函数
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

# ✅ 捕获错误
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

# ========== 正文 ==========

# 定义全局路径
ROOT_DIR="/home/dockerdata"
WEB_DIR="$ROOT_DIR/docker_web"
CADDY_DIR="$ROOT_DIR/docker_caddy"
CADDYFILE="$CADDY_DIR/Caddyfile"

# 安装依赖包
function install_dependencies() {
    echo "[*] 安装必要依赖 (curl unzip docker docker-compose)..."
    apt update
    apt install -y curl unzip docker.io docker-compose
    systemctl enable docker
    systemctl start docker
}

# 初始化目录结构
function init_directories() {
    echo "[*] 创建站点与 Caddy 配置目录..."
    mkdir -p "$WEB_DIR"
    mkdir -p "$CADDY_DIR"
    touch "$CADDYFILE"
    echo "[*] Caddyfile 路径: $CADDYFILE"
    
    # 若为空则初始化默认 Caddyfile 内容
    if [ ! -s "$CADDYFILE" ]; then
        cat > "$CADDYFILE" <<EOF
{
    email admin@yourdomain.com
}

:80 {
    respond "Hello from Caddy!"
}
EOF
    fi
}

# 创建 docker 网络
function create_docker_network() {
    if ! docker network ls | grep -q caddy_net; then
        echo "[*] 创建 Caddy 专用 Docker 网络 (caddy_net)..."
        docker network create caddy_net
    else
        echo "[√] Docker 网络 caddy_net 已存在"
    fi
}

# 启动 Caddy 容器
function start_caddy_container() {
    echo "[*] 启动 Caddy 反向代理容器..."

    docker rm -f caddy-proxy &>/dev/null || true

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
}

# 主执行入口
function main() {
    install_dependencies
    init_directories
    create_docker_network
    start_caddy_container
    echo "\n[✅] 初始化完成，可运行主菜单脚本 main.sh 开始部署站点"
}

main
