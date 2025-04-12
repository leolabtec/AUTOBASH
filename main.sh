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

# 主菜单函数
function main_menu() {
    while true; do
        clear
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
            1)
                curl -fsSL https://raw.githubusercontent.com/leolabtec/Autobuild_openwrt/main/deploy_wp.sh -o deploy_wp.sh
                chmod +x deploy_wp.sh && ./deploy_wp.sh
                read -p "[按 Enter 回车返回主菜单]" dummy
                ;;
            2)
                docker ps --format '{{.Names}}' | grep '^wp-' || echo "[!] 暂无 WordPress 容器"
                read -p "[按 Enter 回车返回主菜单]" dummy
                ;;
            3)
                docker ps --format '{{.Names}}' | grep '^db-' || echo "[!] 暂无数据库容器"
                read -p "[按 Enter 回车返回主菜单]" dummy
                ;;
            4)
                echo "[!] 删除功能开发中..."
                read -p "[按 Enter 回车返回主菜单]" dummy
                ;;
            5)
                echo "[!] 删除功能开发中..."
                read -p "[按 Enter 回车返回主菜单]" dummy
                ;;
            6)
                echo "[!] 快捷设置功能开发中..."
                read -p "[按 Enter 回车返回主菜单]" dummy
                ;;
            0)
                echo "退出"
                exit 0
                ;;
            *)
                echo "[!] 无效选项，请重新输入"
                sleep 1
                ;;
        esac
    done
}

main_menu
