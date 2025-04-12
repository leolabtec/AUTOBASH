#!/bin/bash

set -Eeuo pipefail

# ✅ 错误追踪机制
function error_handler() {
    local exit_code=$?
    local line_no=$1
    local cmd=$2
    echo -e "\n[❌] 安装失败，退出码：$exit_code"
    echo "[🧭] 出错行号：$line_no"
    echo "[💥] 出错命令：$cmd"
    exit $exit_code
}
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

# ✅ 环境检测：是否已由本脚本安装
FLAG_FILE="/etc/autowp_env_initialized"

function check_if_clean_env() {
    if [[ -f "$FLAG_FILE" ]]; then
        echo "[ℹ️] 检测到这是本系统脚本初始化的环境，继续执行"
        return
    fi

    echo "[🔍] 检测是否为非本系统脚本初始化的环境..."
    if command -v docker &>/dev/null || docker network ls | grep -q caddy_net; then
        echo "[⚠️] 检测到系统已有 docker / caddy_net，但未检测到脚本标记文件"
        read -p "❗这可能是非本脚本创建的环境，是否强制继续？(y/N): " force_confirm
        if [[ "$force_confirm" != "y" && "$force_confirm" != "Y" ]]; then
            echo "[-] 已取消安装操作"
            exit 1
        fi
    fi
}

function install_dependencies() {
    echo "[📦] 安装必要依赖 (docker、curl、unzip 等)"
    apt update
    apt install -y docker.io docker-compose curl unzip lsof jq
    systemctl enable docker
    systemctl start docker
}

function run_init_env() {
    echo "[🚀] 执行 init_env.sh 初始化环境..."
    curl -fsSL https://raw.githubusercontent.com/leolabtec/Autobuild_openwrt/main/init_env.sh | bash
    touch "$FLAG_FILE"
    echo "[✅] 初始化完成标记已写入 $FLAG_FILE"
}

function wait_for_caddy_network() {
    echo "[🕒] 等待 Docker 网络 caddy_net 建立..."
    for i in {1..5}; do
        if docker network ls | grep -q caddy_net; then
            echo "[√] Docker 网络 caddy_net 已检测到"
            return
        fi
        sleep 2
    done

    echo "[❌] caddy_net 创建失败，请手动检查或稍后重试"
    exit 1
}

function run_main() {
    echo "[🎮] 拉取并启动主菜单..."
    curl -fsSL https://raw.githubusercontent.com/leolabtec/Autobuild_openwrt/main/main.sh -o ~/main.sh
    chmod +x ~/main.sh && ~/main.sh
}

# 🔧 主流程
check_if_clean_env
install_dependencies
run_init_env
wait_for_caddy_network
run_main
