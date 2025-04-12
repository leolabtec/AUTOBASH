#!/bin/bash

set -Eeuo pipefail

function error_handler() {
    echo -e "\n[❌] 卸载失败，退出码： $?"
    echo "[🧭] 出错行号： $1"
    echo "[💥] 出错命令： $2"
    exit 1
}
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

read -p "⚠️  确认要卸载整个 WordPress 多站部署环境？这将删除容器、数据、配置等（y/N）: " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "[-] 已取消卸载操作"
    exit 0
fi

# 停止并删除所有相关容器
echo "[*] 停止并删除 Caddy 容器..."
docker rm -f caddy-proxy 2>/dev/null || true

echo "[*] 删除所有 WordPress/MySQL 容器..."
for cname in $(docker ps -a --format '{{.Names}}' | grep -E '^wp-|^db-'); do
    docker rm -f "$cname"
done

# 删除 docker 网络
if docker network ls | grep -q caddy_net; then
    echo "[*] 删除 docker 网络 caddy_net"
    docker network rm caddy_net
fi

# 删除挂载数据目录
echo "[*] 删除数据目录 /home/dockerdata ..."
rm -rf /home/dockerdata

# 删除初始化标记
rm -f /etc/autowp_env_initialized

echo -e "\n[✅] 卸载完成，系统已恢复为干净状态"
