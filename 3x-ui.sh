#!/bin/bash

set -Eeuo pipefail

# === 错误处理 ===
function error_handler() {
    local exit_code=$?
    local line_no=$1
    local cmd=$2
    echo -e "\n[❌] 脚本发生错误，退出码：$exit_code"
    echo "[🕯] 出错行号：$line_no"
    echo "[💥] 出错命令：$cmd"
    exit $exit_code
}
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

# === 路径 ===
WEB_BASE="/home/dockerdata/docker_3xui"
CADDYFILE="/home/dockerdata/docker_caddy/Caddyfile"
SITE_PORT=30080

# === 输入域名 ===
clear
read -ep "[+] 请输入域名（如 xui.example.com）: " domain
[[ -z "$domain" ]] && echo "[-] 域名不能为空" && exit 0

# === 标准化站点名 ===
sitename=$(echo "$domain" | sed 's/[^a-zA-Z0-9]/_/g')
site_dir="$WEB_BASE/$sitename"
mkdir -p "$site_dir/db"

# === 插入临时 Caddy 配置触发证书 ===
echo -e "\n$domain {
    reverse_proxy 127.0.0.1:$SITE_PORT
}" >> "$CADDYFILE"
docker exec caddy-proxy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile

# === 等待证书 ===
echo "[⏳] 正在等待 Caddy 为 $domain 签发证书..."
cert_path=""
for i in {1..20}; do
    cert_path=$(find /home/dockerdata/docker_caddy/certificates/ -type f -path "*/$domain/*cert.pem" | head -n1 || true)
    if [[ -n "$cert_path" ]]; then
        cert_dir=$(dirname "$cert_path")
        echo "[✅] 证书签发成功: $cert_dir"
        break
    fi
    sleep 3
    echo "[*] 远程证书未出现，等待... ($i/20)"
done

if [[ -z "$cert_path" ]]; then
    echo "[❌] 超时未检测到证书，请确保 DNS 解析正确或重试"
    exit 1
fi

# === 生成 docker-compose.yml ===
cat > "$site_dir/docker-compose.yml" <<EOF
version: '3'
services:
  3x-ui:
    image: hongcheng618/3x-ui:latest
    container_name: 3x-ui-$sitename
    hostname: dockerhost
    volumes:
      - ./db:/etc/x-ui/
      - $cert_dir:/root/cert/
    environment:
      XRAY_VMESS_AEAD_FORCED: "false"
      X_UI_ENABLE_FAIL2BAN: "true"
    tty: true
    network_mode: host
    restart: unless-stopped
EOF

# === 启动 ===
( cd "$site_dir" && docker-compose up -d )

# === 插入正常 Caddy 反代 ===
sed -i "/$domain {/,/^}/d" "$CADDYFILE"
echo "$domain {
    reverse_proxy 127.0.0.1:$SITE_PORT
}" >> "$CADDYFILE"
docker exec caddy-proxy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile

# === 输出 ===
echo -e "\n[✅] 3x-ui 站点部署成功"
echo "----------------------------------------------"
echo "🌐 域名: https://$domain"
echo "📂 路径: $site_dir"
echo "----------------------------------------------"
read -p "[↩️] 按 Enter 返回主菜单"
