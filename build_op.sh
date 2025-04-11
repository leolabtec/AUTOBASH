#!/bin/bash

set -e
export NEEDRESTART_MODE=a

# === 📁 目录设置 ===
WORK_DIR="/build"
OUT_DIR="/outbuild"
BUILD_LOG="$WORK_DIR/build.log"

DEFAULT_PLUGINS_FILE="$WORK_DIR/plugin_list.txt"
CONFIG_SEED_FILE="$WORK_DIR/.config.seed"

# === 拉取源码 ===
fetch_sources() {
  cd "$WORK_DIR"
  echo "🌐 正在拉取 OpenWrt 官方源码..."
  rm -rf openwrt

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

# === 添加第三方 feeds ===
add_feeds() {
  echo "🔧 添加第三方 feeds..."
  cd "$WORK_DIR/openwrt"
  echo "src-git kenzo https://github.com/kenzok8/openwrt-packages" >> feeds.conf.default
  echo "src-git small https://github.com/kenzok8/small" >> feeds.conf.default
  ./scripts/feeds update -a && ./scripts/feeds install -a
}

# === 生成 .config 配置 ===
generate_config() {
  cd "$WORK_DIR/openwrt"
  echo "⚙️ 生成 .config 配置..."
  cp /dev/null .config

  if [ -f "$CONFIG_SEED_FILE" ]; then
    cat "$CONFIG_SEED_FILE" >> .config
  fi

  if [ -f "$DEFAULT_PLUGINS_FILE" ]; then
    while read -r plugin; do
      echo "CONFIG_PACKAGE_${plugin}=y" >> .config
    done < "$DEFAULT_PLUGINS_FILE"
  fi

  make defconfig
}

# === 编译 OpenWrt 并记录日志 ===
build_firmware() {
  cd "$WORK_DIR/openwrt"
  echo "🚀 开始编译 OpenWrt..."
  make -j$(nproc) V=s | tee "$BUILD_LOG"

  if grep -qi 'error' "$BUILD_LOG"; then
    echo "❌ 编译中出现错误，请查看日志：$BUILD_LOG"
    grep -i 'error' "$BUILD_LOG" | tail -n 20
    exit 1
  fi
}

# === 拷贝输出固件 ===
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
generate_config
build_firmware
save_output

echo "🎉 编译完成，Enjoy your OpenWrt!"
exit 0
