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

# === 配置路径 ===
WEB_BASE="/home/dockerdata/docker_halo"
CADDYFILE="/home/dockerdata/docker_caddy/Caddyfile"
CADDY_NET="caddy_net"

# === 输入域名 ===
clear
read -ep "[+] 请输入域名（如 blog.example.com）: " domain
[[ -z "$domain" ]] && echo "[-] 域名不能为空" && exit 0

# === 域名解析检查 ===
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

# === 标准化站点名 ===
sitename=$(echo "$domain" | sed 's/[^a-zA-Z0-9]/_/g')
site_dir="$WEB_BASE/$sitename"

[[ -d "$site_dir" ]] && echo "[🚫] 站点已存在: $site_dir" && exit 1

# === 自动生成密码 ===
db_user="halo"
db_name="halo"
db_pass=$(openssl rand -base64 12)

# === 创建目录结构 ===
echo "[📂] 创建目录: $site_dir"
mkdir -p "$site_dir"/{db,halo2}

# === 写入 docker-compose.yml ===
cat > "$site_dir/docker-compose.yml" <<EOF
version: "3"

services:
  halo:
    image: registry.fit2cloud.com/halo/halo:2.20
    restart: always
    depends_on:
      halodb:
        condition: service_healthy
    networks:
      - $CADDY_NET
    volumes:
      - ./halo2:/root/.halo2
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8090/actuator/health/readiness"]
      interval: 30s
      timeout: 5s
      retries: 5
      start_period: 30s
    environment:
      - JVM_OPTS=-Xmx256m -Xms256m
    command:
      - --spring.r2dbc.url=r2dbc:pool:postgresql://halodb/$db_name
      - --spring.r2dbc.username=$db_user
      - --spring.r2dbc.password=$db_pass
      - --spring.sql.init.platform=postgresql
      - --halo.external-url=https://$domain

  halodb:
    image: postgres:15.4
    restart: always
    networks:
      - $CADDY_NET
    volumes:
      - ./db:/var/lib/postgresql/data
    environment:
      - POSTGRES_PASSWORD=$db_pass
      - POSTGRES_USER=$db_user
      - POSTGRES_DB=$db_name
    healthcheck:
      test: ["CMD", "pg_isready"]
      interval: 10s
      timeout: 5s
      retries: 5

networks:
  $CADDY_NET:
    external: true
EOF

# === 启动服务 ===
( cd "$site_dir" && docker-compose up -d )

# === 写入 Caddy 配置 ===
echo "$domain {
    reverse_proxy halo-$sitename:8090
}" >> "$CADDYFILE"

docker exec caddy-proxy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile || echo "[!] Caddy 重载失败"

# === 完成提示 ===
echo -e "\n[✅] Halo 博客部署完成"
echo "----------------------------------------------"
echo "🌐 访问地址: https://$domain"
echo "🪪 数据库名: $db_name"
echo "👤 用户名: $db_user"
echo "🔑 密码: $db_pass"
echo "📂 路径: $site_dir"
echo "----------------------------------------------"
