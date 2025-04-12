#!/bin/bash
set -Eeuo pipefail

# ✅ 错误追踪机制
function error_handler() {
    local exit_code=$?
    local line_no=$1
    local cmd=$2
    echo -e "\n[❌] 卸载失败，退出码：$exit_code"
    echo "[🧭] 出错行号：$line_no"
    echo "[💥] 出错命令：$cmd"
    exit $exit_code
}
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

# ✅ 路径定义
WEB_DIR="/home/dockerdata/docker_web"
CADDY_DIR="/home/dockerdata/docker_caddy"
CADDYFILE="$CADDY_DIR/Caddyfile"
FLAG_FILE="/etc/autowp_env_initialized"

echo -e "⚠️  确认要卸载整个 WordPress 多站部署环境？这将删除容器、数据、配置等（y/N）: \c"
read confirm
[[ "$confirm" != "y" && "$confirm" != "Y" ]] && echo "[-] 已取消卸载" && exit 0

# ✅ 停止 Caddy
echo "[*] 停止并删除 Caddy 容器..."
docker rm -f caddy-proxy 2>/dev/null || true

# ✅ 删除所有 WordPress & 数据库容器
echo "[*] 删除所有 WordPress/MySQL 容器..."
containers=$(docker ps -a --format '{{.Names}}' | grep -E '^wp-|^db-' || true)
for cname in $containers; do
    docker rm -f "$cname" || echo "[!] 容器 $cname 删除失败"
done

# ✅ 删除数据目录
echo "[*] 删除站点目录与 Caddy 配置..."
rm -rf "$WEB_DIR"
rm -rf "$CADDY_DIR"

# ✅ 删除初始化标志
echo "[*] 删除初始化标记文件..."
rm -f "$FLAG_FILE"

echo -e "\n[✅] WordPress 多站部署环境已彻底卸载"
echo -e "\n[✅] 卸载完成，所有相关内容已被清理干净"
echo "[⚠️] 当前正在运行的主菜单脚本将不可用，请关闭终端或退出后重新进入。"
