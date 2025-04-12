#!/bin/bash

set -Eeuo pipefail

# ✅ 错误处理函数
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

ROOT_DIR="/home/dockerdata"
WEB_ROOT="$ROOT_DIR/docker_web"
CADDY_DIR="$ROOT_DIR/docker_caddy"
CADDYFILE="$CADDY_DIR/Caddyfile"
UPLOAD_INI="/home/wordpress/uploads.ini"

read -p "[+] 请输入要部署的域名（如 wp1.example.com）: " domain
sitename=$(echo "$domain" | cut -d. -f1)
sitedir="$WEB_ROOT/$sitename"
dbname="wp_$sitename"
dbuser="wpuser"
dbpass=$(openssl rand -base64 12)
rootpass=$(openssl rand -base64 16)

mkdir -p "$sitedir/html" "$sitedir/db-data"

# 下载 WordPress 中文版
curl -s -L https://cn.wordpress.org/latest-zh_CN.tar.gz -o "$sitedir/latest.tar.gz"
tar -xf "$sitedir/latest.tar.gz" -C "$sitedir"
mv "$sitedir/wordpress"/* "$sitedir/html/"
rm -rf "$sitedir/wordpress" "$sitedir/latest.tar.gz"

# 写入 docker-compose.yml
cat > "$sitedir/docker-compose.yml" <<EOF
version: '3.8'
services:
  wp-$sitename:
    image: wordpress:php8.2-apache
    container_name: wp-$sitename
    environment:
      WORDPRESS_DB_HOST: db-$sitename
      WORDPRESS_DB_NAME: $dbname
      WORDPRESS_DB_USER: $dbuser
      WORDPRESS_DB_PASSWORD: $dbpass
    volumes:
      - ./html:/var/www/html
      - $UPLOAD_INI:/usr/local/etc/php/conf.d/uploads.ini
    networks:
      caddy_net:
        aliases:
          - $sitename-frontend
    restart: unless-stopped

  db-$sitename:
    image: mysql:8.0
    container_name: db-$sitename
    environment:
      MYSQL_ROOT_PASSWORD: $rootpass
      MYSQL_DATABASE: $dbname
      MYSQL_USER: $dbuser
      MYSQL_PASSWORD: $dbpass
    volumes:
      - ./db-data:/var/lib/mysql
    networks:
      - caddy_net
    restart: unless-stopped

networks:
  caddy_net:
    external: true
EOF

# 写入 Caddy 配置
cat >> "$CADDYFILE" <<EOF

$domain {
    reverse_proxy wp-$sitename:80
}
EOF

# 启动服务
cd "$sitedir"
docker-compose up -d

# 重启 Caddy
docker restart caddy-proxy

# 输出部署信息
echo -e "\n[✅] 部署完成！"
echo "🌐 访问地址: https://$domain"
echo "📂 站点目录: $sitedir"
echo "🧰 数据库名: $dbname"
echo "👤 数据库用户: $dbuser"
echo "🔐 数据库密码: $dbpass"
echo "🔐 Root 密码: $rootpass"
echo
