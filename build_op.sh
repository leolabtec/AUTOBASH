#!/bin/bash
set -e

WORK_DIR="/build"
OUT_DIR="/outbuild"
SEED="$WORK_DIR/.config.seed"
BUILD_LOG="$WORK_DIR/build.log"

if [ ! -f "$SEED" ]; then
  echo "❌ 缺少编译种子文件 .config.seed"
  echo "请先运行 make menuconfig 并保存为 $SEED"
  exit 1
fi

echo "🔄 请选择要拉取的 lede 源码分支："
echo "1) 最新版（dev）"
echo "2) 稳定版（21.02）"
read -p "请输入选项编号 [1-2]，默认 1: " BRANCH_CHOICE
BRANCH_CHOICE=${BRANCH_CHOICE:-1}

if [ "$BRANCH_CHOICE" == "2" ]; then
  LEDE_BRANCH="21.02"
else
  LEDE_BRANCH="dev"
fi

echo "🧹 清除旧 OpenWrt 配置..."
rm -rf "$WORK_DIR/openwrt"
cd "$WORK_DIR"

echo "🌐 克隆 lede ($LEDE_BRANCH) 源码中..."
git clone --depth=1 -b "$LEDE_BRANCH" https://github.com/Lienol/openwrt.git
cd openwrt

echo "⚙️ 复制种子配置..."
cp "$SEED" .config
make defconfig

echo "🎯 当前配置架构："
grep CONFIG_TARGET_ .config | grep '=y'

if ! grep -q 'CONFIG_TARGET_x86_64=y' .config; then
  echo "❌ 架构不是 x86_64，中止编译"
  exit 1
fi

echo "🚀 开始编译固件..."
make -j$(nproc --ignore=1) V=s | tee "$BUILD_LOG"

echo "📦 拷贝固件至 $OUT_DIR..."
cp -r bin/targets/* "$OUT_DIR/"
echo "✅ 编译完成！固件已输出至：$OUT_DIR"
