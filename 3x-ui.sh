#!/bin/bash

set -Eeuo pipefail

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

WEB_BASE="/home/dockerdata/docker_3xui"
CADDYFILE="/home/dockerdata/docker_caddy/Caddyfile"
CADDY_NET="caddy_net"

clear
read -ep "[+] 请输入域名（如 xui.example.com）: " domain
[[ -z "$domain" ]] && echo "[-] 域名不能为空" && exit 0

# ==== 检查域名解析 ====
echo "[🌐] 检查域名解析..."
public_ip=$(curl -s https://api.ipify.org || curl -s https://ifconfig.me)
resolved_a=$(dig +short A "$domain" | tail -n1)
resolved_aaaa=$(dig +short AAAA "$domain" | tail -n1)

if [[ -z "$resolved_a" && -z "$resolved_aaaa" ]]; then
    echo "[❌] 域名未解析：未找到 A 或 AAAA 记录"
    echo "[💡] 请确保 DNS 已配置域名指向：$public_ip"
    read -p "是否仍要强制继续部署？(y/N): " force_continue
    [[ "$force_continue" != "y" && "$force_continue" != "Y" ]] && echo "[-] 已取消" && exit 0
else
    echo "[✅] 已检测解析："
    [[ -n "$resolved_a" ]] && echo "    A 记录 ➔ $resolved_a"
    [[ -n "$resolved_aaaa" ]] && echo "    AAAA 记录 ➔ $resolved_aaaa"
fi

sitename=$(echo "$domain" | sed 's/[^a-zA-Z0-9]/_/g')
site_dir="$WEB_BASE/$sitename"
cert_path="/home/dockerdata/docker_caddy/certificates/acme-v02.api.letsencrypt.org-directory/$domain"

if [[ -d "$site_dir" ]]; then
    echo "[🚫] 已存在站点：$site_dir"
    exit 0
fi

mkdir -p "$site_dir/db"

# ==== 生成 5 位未占用端口 ====
function get_random_port() {
    while :; do
        port=$(( (RANDOM % 64512) + 1024 ))
        [[ $port -ge 10000 && $port -le 65535 ]] || continue
        if ! lsof -iTCP:$port -sTCP:LISTEN -t >/dev/null; then
            echo "$port"
            return
        fi
    done
}

rand1=$(get_random_port)
rand2=$(get_random_port)
rand3=$(get_random_port)

# ==== 生成 docker-compose.yml ====
cat > "$site_dir/docker-compose.yml" <<EOF
version: '3'
services:
  3x-ui:
    image: hongcheng618/3x-ui:v0.1
    container_name: 3x-ui-$sitename
    hostname: dockerhost
    volumes:
      - ./db/:/etc/x-ui/
      - $cert_path:/root/cert/
    environment:
      XRAY_VMESS_AEAD_FORCED: "false"
      X_UI_ENABLE_FAIL2BAN: "true"
    tty: true
    network_mode: host
    restart: unless-stopped
    ports:
      - "28990:80"
      - "28991:443"
      - "38621:2052"
      - "$rand1:$rand1"
      - "$rand2:$rand2"
      - "$rand3:$rand3"
EOF

# ==== 修改 xray 配置占用端口 ====
config_file="$site_dir/db/config.json"
if [[ -f "$config_file" ]]; then
    sed -i 's/\"port\": 80/\"port\": 30080/' "$config_file"
    sed -i 's/\"port\": 443/\"port\": 30443/' "$config_file"
fi

# ==== 启动容器 ====
( cd "$site_dir" && docker-compose up -d )

# ==== 写入 Caddy 配置 ====
echo "$domain {
    reverse_proxy localhost:30080
}" >> "$CADDYFILE"

docker exec caddy-proxy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile || echo "[!] Caddy reload 失败"

# ==== 提示信息 ====
echo -e "\n[✅] 3x-ui 部署成功"
echo "----------------------------------------------"
echo "🌐 面板地址: https://$domain"
echo "📂 路径: $site_dir"
echo "🧪 备用端口: $rand1, $rand2, $rand3"
echo "----------------------------------------------"
read -p "[↩️] 按 Enter 返回主菜单..."
