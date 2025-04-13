#!/bin/bash
set -Eeuo pipefail

# ✅ 错误追踪机制
function error_handler() {
    local exit_code=$?
    local line_no=$1
    local cmd=$2
    echo -e "\n[❌] 卸载失败，退出码：$exit_code"
    echo "[🧭] 出错行号：$line_no"
    echo "[💥] 出错命令：$cmd"
    exit $exit_code
}
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

# ✅ 提示确认
echo -e "⚠️  确认要卸载整个部署环境？将删除所有容器、数据、脚本和快捷命令。(y/N): \c"
read confirm
[[ "$confirm" != "y" && "$confirm" != "Y" ]] && echo "[-] 已取消卸载" && exit 0

# ✅ 卸载 /home/dockerdata 下的容器和数据
echo "[*] 清理 /home/dockerdata 中的所有部署服务..."
if [[ -d /home/dockerdata ]]; then
    for subdir in /home/dockerdata/*; do
        if [[ -d "$subdir" ]]; then
            for site in "$subdir"/*; do
                if [[ -f "$site/docker-compose.yml" ]]; then
                    echo "[🔽] 停止并删除容器: $site"
                    (cd "$site" && docker-compose down || true)
                fi
            done
        fi
    done
    echo "[🗑️] 删除整个 dockerdata 数据目录..."
    rm -rf /home/dockerdata
fi

# ✅ 删除 main.sh 所在目录的所有 .sh 脚本
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
echo "[🧹] 删除主控目录下所有 .sh 脚本..."
find "$SCRIPT_DIR" -maxdepth 1 -type f -name "*.sh" -exec rm -f {} \;

# ✅ 删除快捷命令（软链接）
echo "[🧼] 检查并删除设置的快捷命令..."
for file in /usr/local/bin/*; do
    if [[ -L "$file" ]] && [[ "$(readlink -f "$file")" == "$SCRIPT_DIR/main.sh" ]]; then
        echo "[❎] 删除快捷命令: $(basename "$file")"
        rm -f "$file"
    fi
done

# ✅ 卸载成功提示
echo -e "\n[✅] 卸载完成，所有部署相关内容已被清理干净"
echo "[⚠️] 当前终端仍在运行，建议重新连接 SSH 或关闭窗口。"
