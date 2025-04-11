#!/bin/bash

set -e
export NEEDRESTART_MODE=a

# === 🧠 目录设置 ===
WORK_DIR="/build"
OUT_DIR="/outbuild"
BUILD_LOG="$WORK_DIR/build.log"

DEFAULT_PLUGINS="luci-app-passwall luci-app-openclash luci-app-wireguard ip-full resolveip luci-app-ddns-go netdata luci-app-mwan3 luci-app-udpxy luci-app-vnstat"
DEFAULT_ARCH="x86_64"

# === 拉取源码（默认超时选择稳定版） ===
fetch_sources() {
  cd "$WORK_DIR"
  echo "🌐 正在拉取 OpenWrt 官方源码..."
  rm -rf openwrt

  echo "📦 正在获取可用版本信息..."
  STABLE_TAG=$(git ls-remote --tags https://github.com/openwrt/openwrt.git | grep -Eo 'refs/tags/v[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -n1 | awk -F/ '{print $3}')
  echo "🔖 检测到最新稳定版: $STABLE_TAG"

  echo "
请选择要拉取的源码版本："
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
  echo "🔧 添加第三方 feeds..."
  cd "$WORK_DIR/openwrt"
  echo "src-git kenzo https://github.com/kenzok8/openwrt-packages" >> feeds.conf.default
  echo "src-git small https://github.com/kenzok8/small" >> feeds.conf.default
  ./scripts/feeds update -a && ./scripts/feeds install -a
}

generate_default_config() {
  cd "$WORK_DIR/openwrt"

  if [ -f .config ]; then
    echo "✅ 检测到已有 .config，跳过生成"
    return
  fi

  echo "⚙️ 生成默认 .config 配置（架构：$DEFAULT_ARCH）..."
  make defconfig
  for pkg in $DEFAULT_PLUGINS; do
    echo "CONFIG_PACKAGE_${pkg}=y" >> .config
  done
  echo "CONFIG_TARGET_${DEFAULT_ARCH}_Generic=y" >> .config
  echo "CONFIG_TARGET_${DEFAULT_ARCH}=y" >> .config
  make defconfig
}

build_firmware() {
  cd "$WORK_DIR/openwrt"
  echo "🚀 开始编译固件，日志输出至 $BUILD_LOG"
  make -j$(nproc) V=s | tee "$BUILD_LOG"
}

save_output() {
  cd "$WORK_DIR/openwrt"
  local out_path=bin/targets
  if [ -d "$out_path" ]; then
    cp -r $out_path/* "$OUT_DIR/"
    echo "✅ 固件已保存至：$OUT_DIR"
  else
    echo "❌ 编译失败：未找到输出目录"
  fi
}

# === 主流程 ===
cd "$WORK_DIR"
fetch_sources
add_feeds
generate_default_config
build_firmware
save_output

echo "🎉 编译完成，Enjoy your OpenWrt!"
exit 0
