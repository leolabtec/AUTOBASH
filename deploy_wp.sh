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

WEB_BASE="/home/dockerdata/docker_web"
CADDYFILE="/home/dockerdata/docker_caddy/Caddyfile"
CADDY_NET="caddy_net"

read -p "[+] 请输入要部署的域名（如 www.example.com）: " domain
[[ -z "$domain" ]] && echo "[-] 域名不能为空" && exit 1

# 替换非法字符
sitename=$(echo "$domain" | sed 's/[^a-zA-Z0-9]/_/g')

site_dir="$WEB_BASE/$sitename"
db_name="wp_${sitename}"
db_user="wpuser_${sitename}"
db_pass=$(openssl rand -base64 12)
db_root=$(openssl rand -base64 12)

echo "[*] 创建站点目录：$site_dir"
mkdir -p "$site_dir/html"

echo "[*] 下载并解压 WordPress..."
curl -sL https://cn.wordpress.org/latest-zh_CN.tar.gz | tar -xz -C "$site_dir/html" --strip-components=1

echo "[*] 生成环境配置文件 .env"
cat > "$site_dir/.env" <<EOF
DB_NAME=$db_name
DB_USER=$db_user
DB_PASS=$db_pass
DB_ROOT=$db_root
EOF

echo "[*] 创建 docker-compose.yml"
cat > "$site_dir/docker-compose.yml" <<EOF
version: '3.8'
services:
  wp-$sitename:
    image: wordpress:php8.2-apache
    container_name: wp-$sitename
    env_file:
      - .env
    environment:
      WORDPRESS_DB_HOST: db-$sitename
      WORDPRESS_DB_NAME: \${DB_NAME}
      WORDPRESS_DB_USER: \${DB_USER}
      WORDPRESS_DB_PASSWORD: \${DB_PASS}
    volumes:
      - ./html:/var/www/html
    networks:
      - $CADDY_NET
    restart: unless-stopped

  db-$sitename:
    image: mysql:8.0
    container_name: db-$sitename
    env_file:
      - .env
    environment:
      MYSQL_ROOT_PASSWORD: \${DB_ROOT}
      MYSQL_DATABASE: \${DB_NAME}
      MYSQL_USER: \${DB_USER}
      MYSQL_PASSWORD: \${DB_PASS}
    volumes:
      - ./db:/var/lib/mysql
    networks:
      - $CADDY_NET
    restart: unless-stopped

networks:
  $CADDY_NET:
    external: true
EOF

echo "[*] 启动容器..."
(cd "$site_dir" && docker-compose up -d)

echo "[*] 写入 Caddy 配置..."
cat >> "$CADDYFILE" <<EOF

$domain {
    reverse_proxy wp-$sitename:80
}
EOF

echo "[*] 重载 Caddy 配置..."
docker exec caddy-proxy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile || {
    echo "[❌] Caddy 重载失败，请检查配置语法"
    exit 1
}

echo -e "\n[✅] WordPress 站点部署成功"
echo "----------------------------------------------"
echo "🌐 访问地址: https://$domain"
echo "🔐 数据库名: $db_name"
echo "👤 数据库用户: $db_user"
echo "🔑 数据库密码: $db_pass"
echo "🔐 Root 密码: $db_root"
echo "📁 站点目录: $site_dir"
echo "----------------------------------------------"
