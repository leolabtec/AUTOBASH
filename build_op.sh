#!/bin/bash

set -e
cd /mnt/work

echo "📂 正在准备环境..."
apt update && apt install -y \
  build-essential clang flex bison g++ gawk gcc-multilib gettext \
  git libncurses-dev libssl-dev python3-distutils rsync unzip zlib1g-dev \
  file wget curl python3

echo "📄 读取配置文件..."
TARGET=$(grep "^TARGET=" config-list | cut -d= -f2)
PLUGINS_RAW=$(grep "^PLUGINS=" config-list | cut -d= -f2 | tr ',' ' ')

# === 加载插件依赖关系 ===
declare -A PLUGIN_DESC
declare -A PLUGIN_DEPS

while IFS='|' read -r name desc deps; do
  [ -z "$name" ] && continue
  PLUGIN_DESC["$name"]="$desc"
  PLUGIN_DEPS["$name"]="$deps"
done < plugin_list.txt

# === 拉取源码 ===
echo "📥 拉取 OpenWrt 源码..."
rm -rf openwrt
git clone https://github.com/openwrt/openwrt.git
cd openwrt

# === 加入第三方源 ===
echo "src-git kenzok8 https://github.com/kenzok8/openwrt-packages" >> feeds.conf.default
echo "src-git small https://github.com/kenzok8/small" >> feeds.conf.default
./scripts/feeds update -a || true
./scripts/feeds install -a || true

# === 生成配置 ===
echo "🔧 生成 .config..."
make defconfig
echo "CONFIG_TARGET_${TARGET}=y" > .config

for plugin in $PLUGINS_RAW; do
  echo "CONFIG_PACKAGE_$plugin=y" >> .config
  for dep in ${PLUGIN_DEPS[$plugin]}; do
    echo "CONFIG_PACKAGE_$dep=y" >> .config
  done
done

# === 校验配置 ===
echo "🧪 检查配置有效性..."
make defconfig || {
  echo "❌ config-list 存在错误，请检查插件名称是否拼写正确"
  exit 1
}

# === 编译过程 ===
echo "🚀 开始编译..."
if make -j$(nproc); then
  echo "✅ 编译完成，导出镜像..."
  cp -r bin/targets/*/* /mnt/out/
else
  echo "⚠️ 编译失败，尝试自动修复..."
  make clean
  ./scripts/feeds update -a
  ./scripts/feeds install -a
  make -j$(nproc) || {
    echo "❌ 修复失败，可能是 config-list 配置错误，请检查后重试"
    exit 1
  }
  cp -r bin/targets/*/* /mnt/out/
fi