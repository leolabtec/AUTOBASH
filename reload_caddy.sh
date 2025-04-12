#!/bin/bash

set -Eeuo pipefail

# ==== 错误处理函数 ====
function error_handler() {
    local exit_code=$?
    local line_no=$1
    local cmd=$2
    echo -e "\n[❌] 脚本出错，退出码：$exit_code"
    echo "[📍] 出错行号：$line_no"
    echo "[⚠️] 出错命令：$cmd"
    exit $exit_code
}
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

# ==== Caddy 热重载 ====
echo "[🔁] 正在热重载 Caddy 配置..."
docker exec caddy-proxy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile

echo -e "\n[✅] Caddy 配置已成功热重载"
