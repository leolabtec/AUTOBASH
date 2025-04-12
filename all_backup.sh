#!/bin/bash

set -Eeuo pipefail

backup_time=$(date +"%Y%m%d_%H%M%S")
backup_dir="all_backup_$backup_time"
mkdir -p "$backup_dir"

echo "[🛑] 停止所有 docker-compose 容器..."
find . -name "docker-compose.yml" -execdir docker-compose down \;

echo "[📦] 备份 /home/dockerdata ..."
cp -a /home/dockerdata "$backup_dir/"

echo "[📜] 备份当前目录下所有 .sh 脚本 ..."
mkdir -p "$backup_dir/scripts"
find . -maxdepth 1 -name "*.sh" -exec cp {} "$backup_dir/scripts/" \;

echo "[🗃️] 打包备份文件为 ${backup_dir}.tar.gz ..."
tar -zcf "${backup_dir}.tar.gz" "$backup_dir"
rm -rf "$backup_dir"

echo "[✅] 全部备份完成：${backup_dir}.tar.gz"
