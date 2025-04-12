#!/bin/bash
set -Eeuo pipefail

# ==== 错误处理 ====
trap 'echo -e "\n[❌] 脚本发生错误，退出码：$?"; exit 1' ERR

WEB_BASE="/home/dockerdata/docker_3xui"
CADDYFILE="/home/dockerdata/docker_caddy/Caddyfile"
CADDY_CERT_DIR="/home/dockerdata/docker_caddy/certificates/acme-v02.api.letsencrypt.org-directory"
CADDY_NET="host"

# ==== 检查是否已存在 3x-ui 容器 ====
if docker ps -a --format '{{.Names}}' | grep -q '^x-ui$'; then
    echo "[📦] 已检测到系统中存在 3x-ui 容器，信息如下："
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep x-ui
    echo -e "\n[📌] 当前系统只允许部署一个 3x-ui 实例。"
    read -p "[按 Enter 回车返回上级菜单]"
    exit 0
fi

# ==== 获取域名 ====
clear
read -ep "[+] 请输入域名（如 xui.example.com）: " domain
[[ -z "$domain" ]] && echo "[-] 域名不能为空" && exit 1

sitename=$(echo "$domain" | sed 's/[^a-zA-Z0-9]/_/g')
site_dir="$WEB_BASE/$sitename"
mkdir -p "$site_dir/db"

# ==== 生成 config.json ====
cat > "$site_dir/db/config.json" <<EOF
{
  "port": 30080,
  "tls": {
    "enable": true,
    "cert_file": "/root/cert/cert.pem",
    "key_file": "/root/cert/key.pem",
    "port": 30443
  }
}
EOF

# ==== 查找 Caddy 签发证书路径 ====
cert_path=$(find "$CADDY_CERT_DIR" -type d -name "$domain" 2>/dev/null | head -n1)
if [[ -z "$cert_path" ]]; then
    echo "[!] 未找到 Caddy 为 $domain 签发的证书，请确保域名正确解析并部署了站点"
    exit 1
fi

# ==== 写入 docker-compose.yml ====
cat > "$site_dir/docker-compose.yml" <<EOF
version: "3"
services:
  3x-ui:
    image: hongcheng618/3x-ui:v0.1
    container_name: x-ui
    hostname: dockerhost
    volumes:
      - ./db:/etc/x-ui/
      - ${cert_path}:/root/cert/
    environment:
      XRAY_VMESS_AEAD_FORCED: "false"
      X_UI_ENABLE_FAIL2BAN: "true"
    tty: true
    network_mode: host
    restart: unless-stopped
EOF

# ==== 写入 Caddy 配置 ====
echo "$domain {
    reverse_proxy localhost:30080
}" >> "$CADDYFILE"

docker exec caddy-proxy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile || echo "[❌] Caddy 热更新失败"

# ==== 启动容器 ====
(cd "$site_dir" && docker-compose up -d)

# ==== 成功提示 ====
echo -e "\n[✅] 3x-ui 部署完成"
echo "----------------------------------------------"
echo "🌐 管理地址: https://$domain"
echo "🛡️ 默认端口: 2053"
echo "📁 配置路径: $site_dir/db"
echo "🔐 证书映射: $cert_path"
echo "----------------------------------------------"
read -p "[按 Enter 回车返回主菜单]"
