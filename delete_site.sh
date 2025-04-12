#!/bin/bash
set -Eeuo pipefail

# ==== 路径设置 ====
WEB_BASE="/home/dockerdata/docker_web"
CADDYFILE="/home/dockerdata/docker_caddy/Caddyfile"
CADDY_CONTAINER="caddy-proxy"

# ==== 检查已部署站点 ====
echo "[🔍] 正在查找已部署的站点..."
sites=($(ls "$WEB_BASE"))
if [[ ${#sites[@]} -eq 0 ]]; then
    echo "[-] 没有找到任何已部署的站点。"
    exit 0
fi

# ==== 选择要删除的站点 ====
echo "请选择要删除的站点："
select sitename in "${sites[@]}" "退出"; do
    if [[ "$REPLY" -ge 1 && "$REPLY" -le ${#sites[@]} ]]; then
        break
    elif [[ "$REPLY" == $(( ${#sites[@]} + 1 )) ]]; then
        echo "已取消"
        exit 0
    else
        echo "无效选择，请重试"
    fi
done

site_dir="$WEB_BASE/$sitename"
domain=$(grep -Po '^\s*\K[^ ]+(?= \{)' "$CADDYFILE" | grep -i "$sitename" || true)

echo -e "\n[⚠️] 即将删除站点：$sitename"
echo "🗂️ 路径：$site_dir"
[[ -n "$domain" ]] && echo "🌐 域名：$domain"
read -p "确认删除？(y/N): " confirm
[[ "$confirm" != "y" && "$confirm" != "Y" ]] && echo "已取消操作。" && exit 0

# ==== 停止并删除容器 ====
echo "[🛑] 停止并移除容器..."
docker compose -f "$site_dir/docker-compose.yml" down || true

# ==== 删除站点目录 ====
echo "[🧹] 删除目录 $site_dir ..."
rm -rf "$site_dir"

# ==== 删除 Caddy 配置 ====
if [[ -n "$domain" ]]; then
    echo "[✂️] 清理 Caddy 配置中与 $domain 相关的段落..."
    tmp_file=$(mktemp)
    awk -v target="$domain" '
        BEGIN { skip = 0 }
        $0 ~ "^" target "[ \t]*\\{" { skip = 1; next }
        skip && $0 ~ /^[ \t]*\}/ { skip = 0; next }
        !skip { print }
    ' "$CADDYFILE" > "$tmp_file" && mv "$tmp_file" "$CADDYFILE"
else
    echo "[i] 未在 Caddyfile 中找到匹配域名配置，跳过清理"
fi

# ==== 重载 Caddy ====
echo "[🔄] 重载 Caddy 配置..."
docker exec "$CADDY_CONTAINER" caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile || {
    echo "[⚠️] Caddy 重载失败，请手动检查配置。"
}

echo -e "\n[✅] 删除完成，站点 $sitename 已彻底清除。"
