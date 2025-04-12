#!/bin/bash

set -Eeuo pipefail

# === 错误追踪机制 ===
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

# === 基础变量 ===
WEB_BASE="/home/dockerdata/docker_3xui"
CADDYFILE="/home/dockerdata/docker_caddy/Caddyfile"
CERT_BASE="/home/dockerdata/docker_caddy/certificates/acme-v02.api.letsencrypt.org-directory"

# === 输入域名 ===
clear
read -ep "[+] 请输入域名（如 xui.example.com）: " domain
[[ -z "$domain" ]] && echo "[-] 域名不能为空" && exit 1

# === 标准化名称 ===
sitename=$(echo "$domain" | sed 's/[^a-zA-Z0-9]/_/g')
site_dir="$WEB_BASE/$sitename"

# === 是否已部署 ===
if docker ps --format '{{.Names}}' | grep -q "^3x-ui-"; then
  echo -e "[🔍] 已检测到 3x-ui 容器，进入控制台...\n"
  container_name=$(docker ps --format '{{.Names}}' | grep '^3x-ui-')
  docker exec -it "$container_name" bash -c "x-ui"
  read -p "[↩️] 按 Enter 返回主菜单" dummy
  exit 0
fi

# === 自动生成端口与证书路径 ===
db_dir="$site_dir/db"
mkdir -p "$db_dir"
cert_path="$CERT_BASE/$domain"

# === 创建 Caddy 反代配置（并确保证书路径存在） ===
echo "$domain {
    reverse_proxy localhost:30080
}" >> "$CADDYFILE"

docker exec caddy-proxy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile

# === 写入 config.json ===
cat > "$db_dir/config.json" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 30080,
      "protocol": "vmess",
      "settings": {
        "clients": []
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

# === 写入 docker-compose.yml ===
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
EOF

# === 启动容器 ===
cd "$site_dir" && docker-compose up -d

# === 提示 ===
echo -e "\n[✅] 3x-ui 部署完成"
echo "----------------------------------------------"
echo "🌐 访问地址: https://$domain"
echo "📂 配置路径: $db_dir"
echo "📃 config.json 已写入默认监听 30080"
echo "----------------------------------------------"
read -p "[↩️] 按 Enter 返回主菜单" dummy
