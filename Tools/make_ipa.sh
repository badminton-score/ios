#!/bin/bash
# 打一个无签名 IPA，给 SideStore / Sideloadly / ESign 之类的自签工具用。
#
#   ./Tools/make_ipa.sh
#   产物：build/BadmintonScore-<版本>-unsigned.ipa
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_DIR="$PWD/build"
DD="$BUILD_DIR/DerivedData"

echo "==> Release 构建（不签名）"
xcodebuild -project BadmintonScore.xcodeproj -scheme BadmintonScore \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DD" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -5

APP="$DD/Build/Products/Release-iphoneos/BadmintonScore.app"
[ -d "$APP" ] || { echo "构建产物不存在：$APP" >&2; exit 1; }

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP/Info.plist")
OUT="$BUILD_DIR/BadmintonScore-${VERSION}-unsigned.ipa"

echo "==> 组装 IPA: version=${VERSION} build=${BUILD}"
rm -rf "$BUILD_DIR/ipa"
mkdir -p "$BUILD_DIR/ipa/Payload"
cp -R "$APP" "$BUILD_DIR/ipa/Payload/"
rm -f "$OUT"
( cd "$BUILD_DIR/ipa" && zip -qry "$OUT" Payload )

echo
echo "完成: ${OUT}  ($(du -h "${OUT}" | cut -f1))"
echo "sha256: $(shasum -a 256 "$OUT" | cut -d' ' -f1)"
echo
echo "安装：把 IPA 拖进 SideStore / Sideloadly / ESign，用自己的 Apple ID 签名。"
