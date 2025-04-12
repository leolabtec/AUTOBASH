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

WEB_BASE="/home/dockerdata/docker_web"
CADDYFILE="/home/dockerdata/docker_caddy/Caddyfile"

# ==== 删除站点 ====
delete_site() {
    echo "[📂] 可用站点列表："
    mapfile -t sites < <(ls -1 "$WEB_BASE" | grep -v '^config$')
    if [[ ${#sites[@]} -eq 0 ]]; then
        echo "[!] 无可删除的站点"
        return
    fi

    for i in "${!sites[@]}"; do
        printf "%d) %s\n" $((i+1)) "${sites[$i]}"
    done
    echo "$(( ${#sites[@]} + 1 ))) 取消"

    read -p "#? " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#sites[@]} + 1 )); then
        echo "[!] 选择无效"
        return
    elif (( choice == ${#sites[@]} + 1 )); then
        echo "[-] 已取消"
        return
    fi

    sitename="${sites[$((choice - 1))]}"
    domain_guess=$(echo "$sitename" | sed 's/_/./g')

    echo -e "\n⚠️ 即将删除站点：$sitename"
    echo "📌 删除内容包括："
    echo "  - WordPress 容器 wp-$sitename"
    echo "  - MySQL 容器 db-$sitename"
    echo "  - 文件目录 $WEB_BASE/$sitename"
    echo "  - Caddy 配置中对应域名 $domain_guess"

    read -p "确认继续删除该站点及其所有数据？(y/N): " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && echo "[-] 已取消" && return

    echo "[🧹] 停止并删除容器..."
    docker rm -f "wp-$sitename" "db-$sitename" 2>/dev/null || true

    echo "[🗑️] 删除站点目录..."
    rm -rf "$WEB_BASE/$sitename"

    echo "[🧾] 清理 Caddyfile 配置..."
    tmp_file=$(mktemp)
    awk -v domain="$domain_guess" '
        BEGIN { skip = 0 }
        $0 ~ "^[ \t]*" domain "[ \t]*\\{" { skip = 1; next }
        skip && $0 ~ /^[ \t]*\}/ { skip = 0; next }
        !skip { print }
    ' "$CADDYFILE" > "$tmp_file" && mv "$tmp_file" "$CADDYFILE"

    if grep -q "$domain_guess" "$CADDYFILE"; then
        echo "[⚠️] 警告：Caddyfile 中仍残留 $domain_guess，建议手动检查清理"
    fi

    echo "[♻️] 重载 Caddy..."
    docker exec caddy-proxy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile || {
        echo "[❌] Caddy reload 失败，请手动检查配置"
    }

    echo "[✅] 站点 $sitename 删除完成"
}

# 主入口
if [[ "${1:-}" == "site" ]]; then
    delete_site
else
    echo "用法: $0 site"
    exit 1
fi
