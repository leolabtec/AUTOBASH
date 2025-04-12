# ==== 删除 Caddy 配置段 ====
echo "[🧹] 正在从 Caddy 配置中移除域名 $domain ..."
if grep -q "^$domain {" "$CADDYFILE"; then
    # 删除从该行到下一个闭合括号之间的所有行
    sed -i "/^$domain {/,/^}/d" "$CADDYFILE"
    echo "[✔] 已从 Caddyfile 移除 $domain 的配置"

    # 重载 Caddy 配置
    echo "[♻️] 正在重载 Caddy 配置..."
    if docker exec caddy-proxy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile; then
        echo "[✅] Caddy 配置重载成功"
    else
        echo "[❌] Caddy reload 失败，请手动检查 Caddyfile"
    fi

    # 二次验证是否还残留该域名
    if grep -q "$domain" "$CADDYFILE"; then
        echo "[⚠️] 警告：Caddyfile 中仍存在 $domain，请手动确认是否清除干净"
    fi
else
    echo "[ℹ️] 未在 Caddyfile 中找到 $domain 的配置段"
fi
