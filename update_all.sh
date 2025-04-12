#!/bin/bash

SCRIPTS=(
  main.sh
  deploy_wp.sh
  delete_site.sh
  uninstall.sh
  set_shortcut.sh
  restart_caddy.sh
  reload_caddy.sh
  install_halo.sh
  all_backup.sh
)

BASE_URL="https://raw.githubusercontent.com/leolabtec/AUTOBASH/main"

echo "[🔄] 开始更新脚本..."

for script in "${SCRIPTS[@]}"; do
    echo "⬇️  更新: $script"
    curl -fsSL "$BASE_URL/$script" -o "$script"
    chmod +x "$script"
done

echo "[✅] 所有脚本更新完成！"
