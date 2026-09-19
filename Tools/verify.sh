#!/bin/bash
# 一键校验：编译 + 跑全部单元测试。
#
#   ./Tools/verify.sh              用默认模拟器
#   SIM=<UDID> ./Tools/verify.sh   指定模拟器
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -z "${SIM:-}" ]; then
  SIM=$(xcrun simctl list devices available | grep -E "iPhone.*\(Booted\)" | head -1 | grep -oE "\(([0-9A-F-]{36})\)" | tr -d '()')
fi
if [ -z "${SIM:-}" ]; then
  SIM=$(xcrun simctl list devices available | grep -E "^ +iPhone" | head -1 | grep -oE "\(([0-9A-F-]{36})\)" | tr -d '()')
fi
[ -n "${SIM:-}" ] || { echo "找不到可用的 iPhone 模拟器" >&2; exit 1; }
echo "==> 模拟器 $SIM"

echo "==> 编译"
xcodebuild -project BadmintonScore.xcodeproj -scheme BadmintonScore \
  -destination "id=$SIM" -derivedDataPath build/DerivedData build 2>&1 \
  | grep -E "error:|BUILD" | head -20

echo
echo "==> 测试"
xcodebuild test -project BadmintonScore.xcodeproj -scheme BadmintonScore \
  -destination "id=$SIM" -derivedDataPath build/DerivedData 2>&1 \
  | grep -E "Test run with|✘|error:|TEST (SUCCEEDED|FAILED)" | tail -20
