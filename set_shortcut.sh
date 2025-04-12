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

# 🔧 设置快捷命令
echo -e "\n[🔧] 开始配置快捷启动命令..."
read -rp "[+] 请输入你想使用的快捷命令名称（例如 mywp 或 wpctl）: " shortcut

# 检查输入是否合法
if [[ -z "$shortcut" || ! "$shortcut" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "[❌] 快捷命令名称不能为空，且只能包含字母、数字、- 或 _"
    exit 1
fi

# 获取当前主菜单路径
main_path=$(realpath ./main.sh)
echo "[📌] 主菜单路径: $main_path"

# 检查目标是否已存在
target_path="/usr/local/bin/$shortcut"
if [[ -e "$target_path" ]]; then
    echo "[⚠️] 已存在命令 $shortcut，是否覆盖？(y/N): "
    read -r confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && echo "[-] 已取消" && exit 1
    rm -f "$target_path"
fi

# 写入软链接
ln -s "$main_path" "$target_path"
chmod +x "$main_path"

echo -e "\n[✅] 设置成功！你现在可以直接通过命令 [ $shortcut ] 启动 WordPress 多站管理面板。"
