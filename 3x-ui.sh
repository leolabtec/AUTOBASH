#!/bin/bash

set -Eeuo pipefail

# ==== 错误处理 ====
function error_handler() {
    local exit_code=$?
    local line_no=$1
    local cmd=$2
    echo -e "\n[\u274c] 脚本发生错误，退出码：$exit_code"
    echo "[\uD83D\uDD0E] 出错行号：$line_no"
    echo "[\uD83D\uDCA5] 出错命令：$cmd"
    exit $exit_code
}
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

# ==== 常量定义 ====
WEB_BASE="/home/dockerdata/docker_3xui"
CADDYFILE="/home/dockerdata/docker_caddy/Caddyfile"
CERT_BASE="/root/cert"
PORT_PANEL="2053"
XRAY_HTTP="30080"
XRAY_HTTPS="30443"

# ==== 输入域名 ====
clear
read -ep "[+] 请输入域名（如 xui.example.com）: " domain
[[ -z "$domain" ]] && echo "[-] 域名不能为空" && exit 1

# ==== 标准化站点名 ====
sitename=$(echo "$domain" | sed 's/[^a-zA-Z0-9]/_/g')
site_dir="$WEB_BASE/$sitename"
cert_path="$CERT_BASE/$domain"

# ==== 检查目录 ====
[[ -d "$site_dir" ]] && echo "[!] 已存在：$site_dir" && exit 1
mkdir -p "$site_dir/db" "$site_dir/cert"

# ==== 生成 config.json ====
cat > "$site_dir/db/config.json" <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": $XRAY_HTTP,
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "tcp"
      }
    },
    {
      "port": $XRAY_HTTPS,
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/root/cert/$domain/fullchain.cer",
              "keyFile": "/root/cert/$domain/$domain.key"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

# ==== 生成 docker-compose.yml ====
cat > "$site_dir/docker-compose.yml" <<EOF
version: '3'
services:
  3x-ui:
    image: hongcheng618/3x-ui
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

# ==== 启动容器 ====
(cd "$site_dir" && docker-compose up -d)

# ==== 写入 Caddy 配置 ====
echo "$domain {
    reverse_proxy localhost:$XRAY_HTTP
}" >> "$CADDYFILE"

docker exec caddy-proxy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile || echo "[!] Caddy reload 失败"

# ==== 输出信息 ====
echo -e "\n[✅] 3X-UI 部署完成！"
echo "----------------------------------------------"
echo "🌐 面板地址: https://$domain:$PORT_PANEL"
echo "🔐 本地端口: $XRAY_HTTP (HTTP), $XRAY_HTTPS (HTTPS)"
echo "📂 配置目录: $site_dir"
echo "📜 Caddy 配置: 已写入 $CADDYFILE"
echo "----------------------------------------------"
read -rp "[↩️] 按 Enter 返回主菜单..." dummy
