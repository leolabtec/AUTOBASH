#!/bin/bash

set -Eeuo pipefail

function error_handler() {
    echo -e "\n[❌] 脚本错误，退出码：$?"
    echo "[📌] 脚本路径：$(realpath "$0")"
    exit 1
}
trap 'error_handler' ERR

MAIN_SCRIPT="$HOME/main.sh"
ALIAS_CMD="bash $MAIN_SCRIPT"
ALIAS_NAME="autowp"
LINK_PATH="/usr/local/bin/$ALIAS_NAME"

echo "[🔧] 开始配置快捷启动命令 autowp..."

# 方法 1: 添加到 /usr/local/bin
if [[ -f "$MAIN_SCRIPT" ]]; then
    echo "[📌] 主菜单路径: $MAIN_SCRIPT"

    echo "[+] 尝试写入快捷执行文件到 $LINK_PATH"
    echo "#!/bin/bash" > "$LINK_PATH"
    echo "$ALIAS_CMD" >> "$LINK_PATH"
    chmod +x "$LINK_PATH"

    if [[ -x "$LINK_PATH" ]]; then
        echo "[✅] 已可通过命令 autowp 直接启动主菜单"
        exit 0
    else
        echo "[!] 无法写入 /usr/local/bin，尝试写入 alias..."
    fi
else
    echo "[❌] 未找到 $MAIN_SCRIPT，请确保先运行 install.sh 初始化环境"
    exit 1
fi

# 方法 2: 添加到 shell 配置文件
SHELL_RC="$HOME/.bashrc"
[[ $SHELL == */zsh ]] && SHELL_RC="$HOME/.zshrc"

if grep -q "$ALIAS_NAME=" "$SHELL_RC"; then
    echo "[✓] alias 已存在于 $SHELL_RC，无需重复添加"
else
    echo "[+] 添加 alias 到 $SHELL_RC"
    echo "alias $ALIAS_NAME=\"$ALIAS_CMD\"" >> "$SHELL_RC"
    echo "[✅] 已添加 alias，请执行 'source $SHELL_RC' 或重启终端后生效"
fi
