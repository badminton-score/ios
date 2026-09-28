#!/bin/bash
# 用 Debug 预览场景重新生成 README / 视频使用的模拟器截图。
#
#   ./Tools/capture_screenshots.sh
#   SIM=<UDID> ./Tools/capture_screenshots.sh
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"

if [ -z "${SIM:-}" ]; then
  SIM=$(xcrun simctl list devices available | grep -E "iPhone.*\(Booted\)" | head -1 | grep -oE "\(([0-9A-F-]{36})\)" | tr -d '()' || true)
fi
if [ -z "${SIM:-}" ]; then
  SIM=$(xcrun simctl list devices available | grep -E "^ +iPhone" | head -1 | grep -oE "\(([0-9A-F-]{36})\)" | tr -d '()' || true)
fi
[ -n "${SIM:-}" ] || { echo "找不到可用的 iPhone 模拟器" >&2; exit 1; }

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" -b

echo "==> 编译 $SIM"
xcodebuild -project BadmintonScore.xcodeproj -scheme BadmintonScore \
  -destination "id=$SIM" -derivedDataPath build/DerivedData build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | tail -5

APP="build/DerivedData/Build/Products/Debug-iphonesimulator/BadmintonScore.app"
BUNDLE="com.alex.BadmintonScore"
[ -d "$APP" ] || { echo "构建产物不存在：$APP" >&2; exit 1; }

xcrun simctl install "$SIM" "$APP"
xcrun simctl status_bar "$SIM" override \
  --time "9:41" \
  --batteryState charged \
  --batteryLevel 100 \
  --wifiBars 3 \
  --cellularBars 4

capture() {
  local output="$1"
  shift
  echo "==> $output"
  xcrun simctl launch --terminate-running-process "$SIM" "$BUNDLE" "$@" >/dev/null
  sleep 1.5
  # simctl 不能直接写入桌面 App 的受保护目录，先落 /tmp 再复制。
  local temp="/tmp/badminton-${output}"
  xcrun simctl io "$SIM" screenshot "$temp"
  cp "$temp" "$ROOT/Screenshots/$output"
  rm -f "$temp"
}

capture "01-home.png" -uiPreview home
capture "02-match.png" -uiPreview match
capture "03-doubles.png" -uiPreview doubles
capture "04-custom.png" -uiPreview custom
capture "05-custom-match.png" -uiPreview customMatch
capture "06-win.png" -uiPreview win
capture "07-game-point.png" -uiPreview gamePoint
capture "08-records.png" -uiPreview records
capture "09-records-select.png" -uiPreview records -selectRecords
capture "11-cards.png" -uiPreview cards
capture "12-card-red.png" -uiPreview cardRed
capture "13-card-yellow.png" -uiPreview cardYellow

echo
echo "完成：Screenshots/01-home.png ... Screenshots/13-card-yellow.png"
