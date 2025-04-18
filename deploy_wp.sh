
#!/bin/bash
set -Eeuo pipefail

# ==== 错误处理 ====
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

# ==== 路径设置 ====
WEB_BASE="/home/dockerdata/docker_web"
CADDYFILE="/home/dockerdata/docker_caddy/Caddyfile"
UPLOADS_INI="/home/size/uploads.ini"
CADDY_NET="caddy_net"

# ==== 确保 uploads.ini 存在 ====
if [[ ! -f "$UPLOADS_INI" ]]; then
    echo "[*] 创建 PHP 上传配置 uploads.ini..."
    mkdir -p "$(dirname "$UPLOADS_INI")"
    cat > "$UPLOADS_INI" <<EOF
upload_max_filesize = 64M
post_max_size = 64M
memory_limit = 128M
EOF
fi

# ==== 输入域名 ====
read -p "[+] 请输入要部署的域名（如 wp1.example.com）: " domain
[[ -z "$domain" ]] && echo "[-] 域名不能为空" && exit 0

# ==== 检查域名是否解析到本机公网 IP（A 或 AAAA）====
echo "[🌐] 检查域名解析..."
public_ip=$(curl -s https://api.ipify.org || curl -s https://ifconfig.me)
resolved_a=$(dig +short A "$domain" | tail -n1)
resolved_aaaa=$(dig +short AAAA "$domain" | tail -n1)

if [[ -z "$resolved_a" && -z "$resolved_aaaa" ]]; then
    echo "[❌] 域名未解析：未找到 A 或 AAAA 记录"
    echo "[💡] 请前往 DNS 服务商设置解析记录，确保域名指向公网 IP：$public_ip"
    echo "   - 示例记录：$domain A $public_ip"
    echo "   - 或 AAAA 记录用于 IPv6 环境"
    read -p "是否仍要强制继续部署？(y/N): " force_continue

    if [[ "$force_continue" != "y" && "$force_continue" != "Y" ]]; then
        echo "[-] 已取消部署"
        read -p "[按 Enter 返回]"
        exit 0
    fi
else
    echo "[✅] 已检测到解析记录："
    [[ -n "$resolved_a" ]] && echo "    A 记录 ➜ $resolved_a"
    [[ -n "$resolved_aaaa" ]] && echo "    AAAA 记录 ➜ $resolved_aaaa"
fi

# ==== 标准化站点名 ====
sitename=$(echo "$domain" | sed 's/[^a-zA-Z0-9]/_/g')
site_dir="$WEB_BASE/$sitename"

# ==== 检查是否已部署 ====
if [[ -d "$site_dir" ]]; then
    echo "[🚫] 检测到站点目录已存在：$site_dir"
    echo "请先删除旧站点或更换其他域名后重试"
    read -p "[按 Enter 回车返回主菜单]"
    exit 0
fi

# ==== 数据库配置 ====
db_name="wp_${sitename}"
db_user="wpuser_${sitename}"
db_pass=$(openssl rand -base64 12)
db_root=$(openssl rand -base64 12)

# ==== 创建目录结构 ====
echo "[*] 创建站点目录：$site_dir"
mkdir -p "$site_dir/html" "$site_dir/db"

# ==== 下载 WordPress ====
echo "[*] 下载并解压 WordPress..."
curl -sL https://cn.wordpress.org/latest-zh_CN.tar.gz | tar -xz -C "$site_dir/html" --strip-components=1
chown -R 33:33 "$site_dir/html"

# ==== 写入 .env 文件 ====
echo "[*] 写入 .env 配置..."
cat > "$site_dir/.env" <<EOF
DB_NAME=$db_name
DB_USER=$db_user
DB_PASS=$db_pass
DB_ROOT=$db_root
EOF

# ==== 生成 docker-compose.yml ====
echo "[*] 生成 docker-compose.yml..."
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
      - $UPLOADS_INI:/usr/local/etc/php/conf.d/uploads.ini
    restart: unless-stopped
    networks:
      - $CADDY_NET

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
    restart: unless-stopped
    networks:
      - $CADDY_NET

networks:
  $CADDY_NET:
    external: true
EOF

# ==== 启动容器 ====
echo "[*] 启动服务容器..."
( cd "$site_dir" && docker-compose up -d )

# ==== 写入 Caddy 配置 ====
echo "[*] 写入 Caddy 配置..."
cat >> "$CADDYFILE" <<EOF

$domain {
    reverse_proxy wp-$sitename:80
}
EOF

# ==== 重载 Caddy ====
echo "[*] 重载 Caddy..."
docker exec caddy-proxy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile || {
    echo "[❌] Caddy reload 失败，请手动检查配置"
    exit 1
}

# ==== 完成提示 ====
echo -e "\n[✅] 站点部署成功"
echo "----------------------------------------------"
echo "🌐 域名: https://$domain"
echo "🪪 数据库名: $db_name"
echo "👤 用户名: $db_user"
echo "🔑 密码: $db_pass"
echo "🔐 Root 密码: $db_root"
echo "📂 路径: $site_dir"
echo "----------------------------------------------"

