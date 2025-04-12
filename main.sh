#!/bin/bash

set -Eeuo pipefail

# 错误追踪
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

# 全局路径
WEB_DIR="/home/dockerdata/docker_web"
CADDYFILE="/home/dockerdata/docker_caddy/Caddyfile"
RAW_DEPLOY_URL="https://raw.githubusercontent.com/leolabtec/Autobuild_openwrt/refs/heads/main/deploy_wp.sh"

function list_sites() {
    echo -e "\n[🌐] 已部署站点列表："
    ls -1 "$WEB_DIR"
}

function list_databases() {
    echo -e "\n[🗃] 所有数据库 (容器 MySQL 实例)："
    docker ps --filter ancestor=mysql:8.0 --format "容器：{{.Names}}"
}

function delete_site() {
    echo -e "\n[⚠] 当前站点："
    ls -1 "$WEB_DIR"
    read -p "请输入要删除的站点名（如 w1）: " sitename
    [[ -z "$sitename" ]] && echo "[-] 取消删除" && return
    read -p "确认删除站点 $sitename？[y/N]: " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && echo "[-] 操作取消" && return

    docker rm -f wp-$sitename db-$sitename &>/dev/null || true
    rm -rf "$WEB_DIR/$sitename"
    sed -i "/^$sitename\./,/^}/d" "$CADDYFILE"
    docker exec caddy-proxy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile &>/dev/null || true
    echo "[🧹] 站点 $sitename 已删除"
}

delete_database() {
    echo -e "\n[⚠] 当前数据库容器："
    docker ps --filter ancestor=mysql:8.0 --format "{{.Names}}"
    read -p "请输入要删除的数据库容器名（如 db-w1）: " dbname
    [[ -z "$dbname" ]] && echo "[-] 取消操作" && return
    read -p "确认删除数据库容器 $dbname？[y/N]: " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && echo "[-] 操作取消" && return

    docker rm -f "$dbname"
    echo "[✅] 数据库容器 $dbname 已删除"
}

function set_alias() {
    echo "alias wp='bash ~/main.sh'" >> ~/.bashrc && source ~/.bashrc
    echo "[🚀] 添加快捷命令 wp 成功，重新登录终端即可生效"
}

function main_menu() {
    clear
    echo "🧩 WordPress 多站自动部署系统"
    echo "--------------------------------"
    echo "1) 创建新站点"
    echo "2) 查看已部署站点"
    echo "3) 查看数据库容器"
    echo "4) 删除站点"
    echo "5) 删除数据库容器"
    echo "6) 设置快捷启动命令"
    echo "0) 退出"
    echo -n "请选择操作: "
    read choice
    case $choice in
        1) curl -fsSL "$RAW_DEPLOY_URL" | bash ;;
        2) list_sites ;;
        3) list_databases ;;
        4) delete_site ;;
        5) delete_database ;;
        6) set_alias ;;
        0) exit 0 ;;
        *) echo "[!] 无效选项" ;;
    esac
    echo -e "\n按任意键返回主菜单..."
    read -n 1 -s
    main_menu
}

main_menu
