#!/bin/bash

set -Eeuo pipefail

# ==== 通用错误处理 ====
function error_handler() {
    local exit_code=$?
    local line_no=$1
    local cmd=$2
    echo -e "\n[❌] 脚本发生错误，退出码：$exit_code"
    echo "[🧭] 出错行号：$line_no"
    echo "[💥] 出错命令：$cmd"
    exit $exit_code
}
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

WEB_BASE="/home/dockerdata/docker_web"
CADDYFILE="/home/dockerdata/docker_caddy/Caddyfile"

echo "[📂] 可用站点列表："
sites=("$(ls -1 $WEB_BASE 2>/dev/null)")
[[ ${#sites[@]} -eq 0 ]] && echo "[!] 没有可删除的站点" && exit 0

select site in "${sites[@]}" "取消"; do
    [[ $REPLY -gt 0 && $REPLY -le ${#sites[@]} ]] || { echo "[-] 取消操作"; exit 0; }
    sitename="$site"
    break
done

domain_guess="$sitename.9333.network"

echo "⚠️ 即将删除站点：$sitename (域名猜测: $domain_guess)"
read -p "确认继续？(y/N): " confirm
[[ "$confirm" != "y" && "$confirm" != "Y" ]] && echo "[-] 已取消" && exit 0

echo "[*] 停止并删除容器..."
docker rm -f "wp-$sitename" "db-$sitename" 2>/dev/null || true

echo "[*] 删除站点目录..."
rm -rf "$WEB_BASE/$sitename"

echo "[*] 删除 Caddy 配置片段..."
sed -i "/^$domain_guess {/,/^}/d" "$CADDYFILE"

echo "[*] 重载 Caddy..."
docker exec caddy-proxy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile || {
    echo "[!] Caddy 重载失败，请手动检查配置"
}

echo "[✅] 站点 $sitename 已删除"
