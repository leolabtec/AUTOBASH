#!/bin/bash

set -e
export NEEDRESTART_MODE=a

# === 🧠 目录设置 ===
WORK_DIR="/build"
OUT_DIR="/outbuild"
BUILD_LOG="$WORK_DIR/build.log"

DEFAULT_PLUGINS="luci-app-passwall luci-app-openclash luci-app-wireguard ip-full resolveip luci-app-ddns-go netdata luci-app-mwan3 luci-app-udpxy luci-app-vnstat"
DEFAULT_ARCH="x86_64"

fetch_sources() {
  cd "$WORK_DIR"
  echo "🌐 正在拉取 OpenWrt 官方源码..."
  rm -rf openwrt

  echo "📦 正在获取可用版本信息..."
  STABLE_TAG=$(git ls-remote --tags https://github.com/openwrt/openwrt.git | grep -Eo 'refs/tags/v[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -n1 | awk -F/ '{print $3}')
  echo "🔖 检测到最新稳定版: $STABLE_TAG"

  echo "\n请选择要拉取的源码版本："
  echo "  1) 最新开发版本 (master)"
  echo "  2) 稳定版本 ($STABLE_TAG)"
  echo -n "将在 60 秒后默认选择稳定版本。请输入选项 [1/2]: "
  read -t 60 CHOICE || CHOICE=2
  CHOICE=${CHOICE:-2}

  case $CHOICE in
    1)
      echo "➡️ 拉取 master 分支..."
      git clone --depth=1 https://github.com/openwrt/openwrt.git
      ;;
    2|*)
      echo "➡️ 拉取稳定版 $STABLE_TAG ..."
      git clone --branch "$STABLE_TAG" https://github.com/openwrt/openwrt.git
      ;;
  esac
}

add_feeds() {
  echo "🔧 添加 Lienol 第三方 feeds..."
  cd "$WORK_DIR/openwrt"
  echo "src-git lienol https://github.com/Lienol/openwrt-package" >> feeds.conf.default
  ./scripts/feeds update -a && ./scripts/feeds install -a
}

generate_default_config() {
  cd "$WORK_DIR/openwrt"
  echo "🧹 清除旧配置..."
  rm -f .config

  echo "⚙️ 写入 x86_64 默认配置"
  echo "CONFIG_TARGET_${DEFAULT_ARCH}=y" >> .config
  echo "CONFIG_TARGET_${DEFAULT_ARCH}_Generic=y" >> .config

  for pkg in $DEFAULT_PLUGINS; do
    echo "CONFIG_PACKAGE_${pkg}=y" >> .config
  done

  echo "🔄 执行 defconfig..."
  make defconfig

  echo "🌟 检测当前配置的编译架构："
  grep CONFIG_TARGET_ .config | grep '=y'

  if ! grep -q 'CONFIG_TARGET_x86_64=y' .config; then
    echo '❌ 编译配置中架构非 x86_64，中止编译。'
    exit 1
  fi
}

build_firmware() {
  cd "$WORK_DIR/openwrt"
  echo "🚀 开始编译，详细日志输出至 $BUILD_LOG"
  make -j$(nproc --ignore=1) V=s | tee "$BUILD_LOG"
}

save_output() {
  cd "$WORK_DIR/openwrt"
  local out_path=bin/targets
  if [ -d "$out_path" ]; then
    cp -r $out_path/* "$OUT_DIR/"
    echo "✅ 固件已保存至：$OUT_DIR"
  else
    echo "❌ 编译失败：未找到输出目录"
    exit 1
  fi
}

cd "$WORK_DIR"
fetch_sources
add_feeds
generate_default_config
build_firmware
save_output

echo "🎉 x86_64 OpenWrt 编译完成！"
exit 0
