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

echo "🧹 清除旧 OpenWrt 配置..."
rm -rf "$WORK_DIR/openwrt"
cd "$WORK_DIR"
git clone --depth=1 https://github.com/openwrt/openwrt.git
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

echo "🚀 开始编译最小固件..."
make -j$(nproc --ignore=1) V=s | tee "$BUILD_LOG"

echo "📦 拷贝固件至 $OUT_DIR..."
cp -r bin/targets/* "$OUT_DIR/"
echo "✅ 编译完成！固件已输出至：$OUT_DIR"
EOF
