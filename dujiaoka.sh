#!/bin/bash

set -Eeuo pipefail

# ==== 错误处理 ====
function error_handler() {
    local exit_code=$?
    local line_no=$1
    local cmd=$2
    echo -e "\n[\u274c] 脚本发生错误，退出码：$exit_code"
    echo "[🗭] 出错行号：$line_no"
    echo "[💥] 出错命令：$cmd"
    exit $exit_code
}
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

# ==== 路径 ====
WEB_BASE="/home/dockerdata/docker_dujiaoka"
CADDYFILE="/home/dockerdata/docker_caddy/Caddyfile"
CADDY_NET="caddy_net"

# ==== 输入域名 ====
clear
read -ep "[+] 请输入域名（如 dj1.example.com）: " domain
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

# ==== 标准化站点名 ====
sitename=$(echo "$domain" | sed 's/[^a-zA-Z0-9]/_/g')
site_dir="$WEB_BASE/$sitename"

# ==== 是否已存在 ====
if [[ -d "$site_dir" ]]; then
    echo "[🚫] 站点目录已存在：$site_dir"
    exit 0
fi

# ==== 自动生成 DB ====
db_name="dj_${sitename}"
db_user="djuser_${sitename}"
db_pass=$(openssl rand -base64 12)
db_root=$(openssl rand -base64 12)

# ==== 创建目录 ====
echo "[*] 创建站点目录..."
mkdir -p "$site_dir/public/uploads"

# ==== 写入 .env ====
cat > "$site_dir/.env" <<EOF
APP_ENV=production
APP_DEBUG=false
APP_URL=https://$domain
ADMIN_HTTPS=true
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=$db_name
DB_USERNAME=$db_user
DB_PASSWORD=$db_pass
EOF

# ==== 生成 docker-compose.yml ====
cat > "$site_dir/docker-compose.yml" <<EOF
version: "2.2"
services:
  web:
    image: jiangjuhong/dujiaoka
    container_name: dj-$sitename
    ports:
      - "${RANDOM:0:2}80:80"
      - "${RANDOM:0:2}90:9000"
    volumes:
      - ./public/uploads:/app/public/uploads
      - ./install.lock:/app/install.lock
      - ./.env:/app/.env
    environment:
      WEB_DOCUMENT_ROOT: "/app/public"
      TZ: Asia/Shanghai
    tty: true
    restart: always
  db:
    image: mysql:8.0
    container_name: db-dj-$sitename
    environment:
      MYSQL_ROOT_PASSWORD: $db_root
      MYSQL_DATABASE: $db_name
      MYSQL_USER: $db_user
      MYSQL_PASSWORD: $db_pass
    volumes:
      - ./db:/var/lib/mysql
    restart: always
    networks:
      - $CADDY_NET
networks:
  $CADDY_NET:
    external: true
EOF

# ==== 启动 ====
( cd "$site_dir" && docker-compose up -d )

# ==== 写入 Caddy ====
echo "$domain {
    reverse_proxy dj-$sitename:80
}" >> "$CADDYFILE"

docker exec caddy-proxy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile || echo "[!] Caddy reload 失败"

# ==== 提示 ====
echo -e "\n[✅] 站点部署成功"
echo "----------------------------------------------"
echo "🌐 域名: https://$domain"
echo "🔢 数据库名: $db_name"
echo "👤 用户名: $db_user"
echo "🔐 密码: $db_pass"
echo "🔑 Root 密码: $db_root"
echo "📂 路径: $site_dir"
echo "----------------------------------------------"
