#!/bin/bash
set -Eeuo pipefail

# ✅ 错误处理
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

FLAG_FILE="/etc/autowp_env_initialized"

# ✅ 环境判断
function check_if_clean_env() {
    echo "[🔍] 检查环境是否由脚本初始化..."
    if [[ -f "$FLAG_FILE" ]]; then
        echo "[✓] 脚本初始化环境，继续"
        return
    fi

    if command -v docker &>/dev/null || docker network ls | grep -q caddy_net; then
        echo "[⚠️] 检测到系统已有 Docker 或 caddy_net，但缺少初始化标志"
        read -p "❗可能不是由本脚本部署的环境，是否强制继续？(y/N): " force_confirm
        [[ "$force_confirm" =~ ^[Yy]$ ]] || { echo "[-] 已取消安装"; exit 1; }
    fi
}

# ✅ 安装必要依赖（仅支持 Debian/Ubuntu）
function install_dependencies() {
    echo "[📦] 检测系统环境..."

    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        os=$ID
    else
        echo "[❌] 无法识别系统类型，终止安装"
        exit 1
    fi

    if [[ "$os" != "debian" && "$os" != "ubuntu" ]]; then
        echo "[❌] 当前系统不是 Debian/Ubuntu，终止安装"
        exit 1
    fi

    echo ""
    echo "[❓] 是否重新安装所有依赖？"
    echo "    y = 强制重新安装全部依赖（包括已安装的）"
    echo "    n = 跳过已安装的，仅安装缺失部分"
    read -rp "[👉] 请输入选择 (y/n): " reinstall_all

    function install_if_missing() {
        local name=$1
        local check_cmd=$2
        local install_cmd=$3

        if [[ "$reinstall_all" =~ ^[Yy]$ ]]; then
            echo "[🔁] 正在安装 $name（强制模式）..."
            eval "$install_cmd"
        else
            if eval "$check_cmd" &>/dev/null; then
                echo "[✅] $name 已安装，跳过"
            else
                echo "[📥] 检测到 $name 未安装，正在安装..."
                eval "$install_cmd"
            fi
        fi
    }

    # 更新 apt 缓存
    apt update -y

    # Docker
    install_if_missing "Docker" "command -v docker" "apt install -y docker.io" 

    # Docker Compose
    install_if_missing "Docker Compose" "command -v docker-compose" "apt install -y docker-compose"

    # Caddy（可选示例）
    # install_if_missing "Caddy" "command -v caddy" "apt install -y caddy"
}
# ✅ 初始化环境
function run_init_env() {
    echo "[🚀] 初始化环境 init_env.sh ..."
    curl -fsSL https://raw.githubusercontent.com/leolabtec/Autobuild_openwrt/main/init_env.sh | bash
}

# ✅ 等待 Docker 网络
function wait_for_network() {
    echo "[🕒] 等待网络 caddy_net 创建..."
    for i in {1..5}; do
        if docker network ls | grep -q caddy_net; then
            echo "[✓] 网络 caddy_net 可用"
            return
        fi
        sleep 1
    done
    echo "[❌] 网络 caddy_net 创建失败，请检查"
    exit 1
}

# ✅ 启动主菜单
function run_main_menu() {
    echo "[🎮] 启动主菜单..."
    curl -fsSL https://raw.githubusercontent.com/leolabtec/Autobuild_openwrt/main/main.sh -o ~/main.sh
    chmod +x ~/main.sh && ~/main.sh
}

# === 主流程 ===
check_if_clean_env
install_dependencies
run_init_env
wait_for_network
run_main_menu
