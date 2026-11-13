#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null 2>&1 || { echo "缺少 xcodegen:brew install xcodegen"; exit 1; }
xcodegen generate
SCHEME=YunmeiLock
MODE="${1:-build}"

case "$MODE" in
  test)
    SIM=$(xcrun simctl list devices available 2>/dev/null | grep -oE 'iPhone [0-9][^(]*' | head -1 | sed 's/ *$//' || true)
    [ -n "$SIM" ] || SIM="iPhone 16"
    echo "使用模拟器:$SIM"
    xcodebuild -project YunmeiLock.xcodeproj -scheme "$SCHEME" \
      -destination "platform=iOS Simulator,name=$SIM" test
    ;;
  ipa)
    xcodebuild -project YunmeiLock.xcodeproj -scheme "$SCHEME" -configuration Release \
      -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build \
      CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
    APP=$(find build/Build/Products/Release-iphoneos -maxdepth 1 -name "*.app" | head -1)
    rm -rf Payload YunmeiLock-unsigned.ipa
    mkdir -p Payload
    cp -R "$APP" Payload/
    zip -qr YunmeiLock-unsigned.ipa Payload
    rm -rf Payload
    echo "已生成:$(pwd)/YunmeiLock-unsigned.ipa  (用 Sideloadly 侧载)"
    ;;
  *)
    xcodebuild -project YunmeiLock.xcodeproj -scheme "$SCHEME" \
      -destination 'generic/platform=iOS' -configuration Release \
      CODE_SIGNING_ALLOWED=NO build
    echo "OK:未签名构建完成;要 ipa 请跑 ./scripts/build-macos.sh ipa"
    ;;
esac
