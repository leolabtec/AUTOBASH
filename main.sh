#!/bin/bash

set -Eeuo pipefail

# === 错误追踪机制 ===
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

# === LOGO ===
function show_logo() {
cat <<'EOF'
 _      ______  ____  _        ____  _____  
| |    |  ____|/ __ \| |      |  _ \|  __ \ 
| |    | |__  | |  | | |      | |_) | |  | |
| |    |  __| | |  | | |      |  _ <| |  | |
| |____| |____| |__| | |____  | |_) | |__| |
|______|______|\____/|______| |____/|_____/ 
              L E O L A B                
EOF
}

# === 主菜单函数 ===
function main_menu() {
    while true; do
        clear
        show_logo
        echo
        echo "🌐 WEB 多站部署管理 - 创建 WordPress 新站点"
        echo "----------------------------------------"
        echo "1) 创建New WordPress 站点"
        echo "2) 查看已部署站点"
        echo "3) 查看数据库容器"
        echo "4) 删除站点（包含数据库与配置）"
        echo "5) 设置快捷启动命令"
        echo "6) 卸载 Web 多站部署系统"
        echo "7) 创建 Halo 博客站点"
        echo "8) 重启 Caddy 容器"
        echo "9) 热更新Caddy 配置"
        echo "10) 一键备份所有容器和脚本"
        echo "11) 一键更新所有脚本代码"
        echo "0) 退出"
        echo "----------------------------------------"
        read -p "请选择操作: " choice

        case $choice in
            1)
                curl -fsSL https://raw.githubusercontent.com/leolabtec/Autobuild_openwrt/main/deploy_wp.sh -o deploy_wp.sh
                chmod +x deploy_wp.sh && ./deploy_wp.sh
                read -p "[按 Enter 回车返回主菜单]" dummy
                ;;
            2)
                echo "[📦] 当前部署的站点（WordPress 容器）："
                docker ps --format '{{.Names}}' | grep '^wp-' || echo "[!] 暂无 WordPress 容器"
                read -p "[按 Enter 回车返回主菜单]" dummy
                ;;
            3)
                echo "[🛢️] 当前数据库容器："
                docker ps --format '{{.Names}}' | grep '^db-' || echo "[!] 暂无数据库容器"
                read -p "[按 Enter 回车返回主菜单]" dummy
                ;;
            4)
                curl -fsSL https://raw.githubusercontent.com/leolabtec/Autobuild_openwrt/main/delete_site.sh -o delete_site.sh
                chmod +x delete_site.sh && ./delete_site.sh site
                read -p "[按 Enter 回车返回主菜单]" dummy
                ;;
            5)
                curl -fsSL https://raw.githubusercontent.com/leolabtec/Autobuild_openwrt/main/set_shortcut.sh -o set_shortcut.sh
                chmod +x set_shortcut.sh && ./set_shortcut.sh
                read -p "[按 Enter 回车返回主菜单]" dummy
                ;;
            6)
                echo "[⚠️] 即将运行卸载脚本 uninstall.sh..."
                curl -fsSL https://raw.githubusercontent.com/leolabtec/Autobuild_openwrt/main/uninstall.sh -o uninstall.sh
                chmod +x uninstall.sh && ./uninstall.sh
                read -p "[按 Enter 回车返回主菜单]" dummy
                ;;
            7)
                curl -fsSL https://raw.githubusercontent.com/leolabtec/AUTOBASH/refs/heads/main/install_halo.sh -o install_halo.sh
                chmod +x install_halo.sh && ./install_halo.sh
                read -p "[按 Enter 回车返回主菜单]" dummy
                ;;
            8)
                curl -fsSL https://raw.githubusercontent.com/leolabtec/AUTOBASH/refs/heads/main/restart_caddy.sh -o restart_caddy.sh
                chmod +x restart_caddy.sh && ./restart_caddy.sh
                read -p "[按 Enter 回车返回主菜单]" dummy
                ;;            
            9)
                curl -fsSL https://raw.githubusercontent.com/leolabtec/AUTOBASH/main/reload_caddy.sh -o reload_caddy.sh
                chmod +x reload_caddy.sh && ./reload_caddy.sh
                read -p "[按 Enter 回车返回主菜单]" dummy
                ;;                    
            10)
                curl -fsSL https://raw.githubusercontent.com/leolabtec/AUTOBASH/main/all_backup.sh -o all_backup.sh
                chmod +x all_backup.sh && ./all_backup.sh
                read -p "[按 Enter 回车返回主菜单]" dummy
                ;;
            11)
                echo "[🌐] 正在更新所有脚本..."
                curl -fsSL https://raw.githubusercontent.com/leolabtec/AUTOBASH/refs/heads/main/update_all.sh -o update_all.sh
                chmod +x update_all.sh && ./update_all.sh
                read -p "[按 Enter 回车返回主菜单]" dummy
                ;;
            0)
                echo "[👋] 已退出"
                exit 0
                ;;
            *)
                echo "[!] 无效选项，请重新输入"
                sleep 1
                ;;
        esac
    done
}

# === 启动主菜单 ===
main_menu
