#!/bin/bash

set -Eeuo pipefail

# ==== 通用错误处理 ====
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

# ==== 设置路径 ====
WEB_BASE="/home/dockerdata/docker_web"
CADDYFILE="/home/dockerdata/docker_caddy/Caddyfile"

# ==== 删除站点 ====
delete_site() {
    echo "[📂] 可用站点列表："
    sites=( $(ls -1 $WEB_BASE 2>/dev/null) )
    [[ ${#sites[@]} -eq 0 ]] && echo "[!] 没有可删除的站点" && return

    select site in "${sites[@]}" "取消"; do
        [[ $REPLY -gt 0 && $REPLY -le ${#sites[@]} ]] || { echo "[-] 取消操作"; return; }
        sitename="$site"
        break
    done

    domain_guess="$sitename.9333.network"

    echo "⚠️ 即将删除站点：$sitename (域名猜测: $domain_guess)"
    read -p "确认继续？(y/N): " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && echo "[-] 已取消" && return

    echo "[*] 停止并删除容器..."
    docker rm -f "wp-$sitename" "db-$sitename" 2>/dev/null || true

    echo "[*] 删除站点目录..."
    rm -rf "$WEB_BASE/$sitename"

    echo "[*] 删除 Caddy 配置片段..."
    sed -i "/^$domain_guess {/,/^}/d" "$CADDYFILE"

    echo "[*] 重载 Caddy..."
    docker exec caddy-proxy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile || {
        echo "[!] Caddy 重载失败，请手动检查配置"
    }

    echo "[✅] 站点 $sitename 已删除"
}

# ==== 删除数据库 ====
delete_db() {
    echo "[🛢️] 数据库容器："
    dbs=( $(docker ps -a --format '{{.Names}}' | grep '^db-' || true) )
    [[ ${#dbs[@]} -eq 0 ]] && echo "[!] 无数据库容器" && return

    select db in "${dbs[@]}" "取消"; do
        [[ $REPLY -gt 0 && $REPLY -le ${#dbs[@]} ]] || { echo "[-] 取消操作"; return; }
        dbname="$db"
        break
    done

    echo "⚠️ 即将删除数据库容器：$dbname"
    read -p "确认继续？(y/N): " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && echo "[-] 已取消" && return

    echo "[*] 停止并删除 $dbname ..."
    docker rm -f "$dbname" || echo "[!] 删除失败或容器不存在"

    echo "[✅] 数据库容器 $dbname 已删除"
}

# ==== 主入口判断 ====
if [[ "$1" == "site" ]]; then
    delete_site
elif [[ "$1" == "db" ]]; then
    delete_db
else
    echo "用法: $0 site | db"
    exit 1
fi
