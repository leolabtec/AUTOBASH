#!/bin/bash
set -Eeuo pipefail

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

ROOT_DIR="/home/dockerdata"
WEB_DIR="$ROOT_DIR/docker_web"
CADDY_DIR="$ROOT_DIR/docker_caddy"
CADDYFILE="$CADDY_DIR/Caddyfile"
FLAG_FILE="/etc/autowp_env_initialized"

UPLOADS_DIR="/home/size"
UPLOADS_INI="$UPLOADS_DIR/uploads.ini"

# 创建必要目录
mkdir -p "$WEB_DIR"
mkdir -p "$CADDY_DIR"

echo "[*] 创建目录成功"
echo "[*] Caddyfile 路径: $CADDYFILE"

# 创建 uploads.ini（全局 PHP 上传限制配置）
if [[ ! -f "$UPLOADS_INI" ]]; then
    echo "[*] 创建 PHP 上传配置文件: $UPLOADS_INI"
    mkdir -p "$UPLOADS_DIR"
    cat > "$UPLOADS_INI" <<EOF
upload_max_filesize = 64M
post_max_size = 64M
memory_limit = 128M
EOF
else
    echo "[✓] 已存在 uploads.ini，跳过"
fi

# 初始化空白 Caddyfile（首次）
if [[ ! -f "$CADDYFILE" ]]; then
    echo "[*] 初始化 Caddyfile"
    cat > "$CADDYFILE" <<EOF
{
    email admin@yourdomain.com
}
EOF
fi

# 创建专属网络
if ! docker network ls | grep -q caddy_net; then
    echo "[*] 创建 Docker 网络 caddy_net..."
    docker network create caddy_net
else
    echo "[✓] 网络 caddy_net 已存在，跳过"
fi

# 启动 Caddy 容器
if ! docker ps | grep -q caddy-proxy; then
    echo "[*] 启动 Caddy 容器..."
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
    echo "[√] Caddy 启动成功"
else
    echo "[✓] Caddy 容器已在运行，跳过"
fi

# 写入初始化标记
touch "$FLAG_FILE"
echo "[✅] 初始化完成，标记写入 $FLAG_FILE"
echo "[🎮] 可执行主菜单：./main.sh"
