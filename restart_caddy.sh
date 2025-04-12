#!/bin/bash
set -Eeuo pipefail

echo "[♻️] 正在重启 Caddy 容器..."
if docker restart caddy-proxy; then
    echo "[✅] Caddy 重启成功"
else
    echo "[❌] Caddy 重启失败，请手动检查容器状态"
    exit 1
fi
