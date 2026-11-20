#!/bin/bash
# WCLiquidArc 云端编译脚本
set +e
cd "$(dirname "$0")" || exit 1

echo "===== 1. 当前结构 ====="
ls -la

echo "===== 2. 解压 zip（如果有）====="
for z in *.zip; do
  [ -f "$z" ] || continue
  echo "解压 $z"
  unzip -q "$z" -d _unz
  cp -R _unz/liquidbar/. . 2>/dev/null
  cp -R _unz/. . 2>/dev/null
done

echo "===== 3. 整理源码到 src/ ====="
if [ ! -d src ]; then
  mkdir -p src
  mv *.m *.h src/ 2>/dev/null
fi
echo "src 内容:"
ls -la src

echo "===== 4. 生成 Makefile ====="
cat > Makefile <<'MK'
export TARGET = iphone:clang:latest:15.0
export ARCHS = arm64 arm64e
export DEBUG = 0

TWEAK_NAME = WCLiquidArc
WCLiquidArc_FILES = $(wildcard src/*.m)
WCLiquidArc_CFLAGS = -fobjc-arc -I./src -Wno-unused-parameter -Wno-unused-variable -Wno-incompatible-pointer-types
WCLiquidArc_FRAMEWORKS = UIKit QuartzCore Foundation WebKit AVFoundation CoreGraphics

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
MK
cat Makefile

echo "===== 5. 安装 Theos ====="
export THEOS=$HOME/theos
if [ ! -d "$THEOS" ]; then
  git clone --recursive --depth 1 https://github.com/theos/theos.git "$THEOS"
fi
mkdir -p "$THEOS/sdks"
if [ -z "$(ls -A "$THEOS/sdks" 2>/dev/null)" ]; then
  curl -fsSL -o /tmp/sdks.tar.gz https://github.com/theos/sdks/archive/refs/heads/master.tar.gz
  tar -xzf /tmp/sdks.tar.gz -C /tmp
  cp -R /tmp/sdks-master/*.sdk "$THEOS/sdks/" 2>/dev/null
fi
echo "SDK 列表:"
ls "$THEOS/sdks"
export PATH="$THEOS/bin:$PATH"

echo "===== 6. ldid ====="
brew install ldid dpkg 2>/dev/null
curl -fsSL -o /tmp/ldid https://github.com/ProcursusTeam/ldid/releases/latest/download/ldid_macosx_arm64 2>/dev/null
if [ -s /tmp/ldid ]; then
  chmod +x /tmp/ldid
  sudo cp /tmp/ldid /usr/local/bin/ldid 2>/dev/null
fi
which ldid

echo "===== 7. 编译 ====="
make clean 2>/dev/null
make -j4 2>&1 | tee build.log

echo "===== 8. 收集产物 ====="
mkdir -p out
find . -name "WCLiquidArc.dylib" -not -path "./.git/*" -exec cp {} out/ \; 2>/dev/null
find . -name "*.deb" -exec cp {} out/ \; 2>/dev/null
cp build.log out/ 2>/dev/null
echo "产物:"
ls -la out

echo "===== 完成 ====="
exit 0
