#!/bin/bash
# ====================================================
#  MusicApp — 本地构建脚本 (需要 macOS + Xcode)
#  用法: bash Scripts/build.sh [debug|release]
# ====================================================

set -e

CONFIG="${1:-debug}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "========================================="
echo "  🎵 MusicApp Build Script"
echo "  Configuration: $CONFIG"
echo "========================================="

# 1. Install XcodeGen if not present
if ! command -v xcodegen &> /dev/null; then
    echo "📦 Installing XcodeGen..."
    brew install xcodegen
fi

# 2. Generate Xcode project
echo "🔧 Generating Xcode project..."
xcodegen generate

# 3. Resolve SPM dependencies
echo "📥 Resolving dependencies..."
xcodebuild -resolvePackageDependencies \
    -project MusicApp.xcodeproj \
    -scheme MusicApp

# 4. Build
echo "🔨 Building for iOS device..."
if [ "$CONFIG" = "release" ]; then
    BUILD_CONFIG="Release"
else
    BUILD_CONFIG="Debug"
fi

xcodebuild build \
    -project MusicApp.xcodeproj \
    -scheme MusicApp \
    -configuration "$BUILD_CONFIG" \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -derivedDataPath ./DerivedData \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    DEVELOPMENT_TEAM="" \
    ONLY_ACTIVE_ARCH=NO

# 5. Package as IPA
echo "📦 Packaging IPA..."
APP_PATH=$(find ./DerivedData -name "MusicApp.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Error: App bundle not found!"
    exit 1
fi

mkdir -p Payload
cp -R "$APP_PATH" Payload/
zip -r MusicApp.ipa Payload
rm -rf Payload

echo "========================================="
echo "  ✅ Build complete!"
echo "  📱 IPA: $(pwd)/MusicApp.ipa"
echo "  📏 Size: $(ls -lh MusicApp.ipa | awk '{print $5}')"
echo "========================================="
echo ""
echo "  Next steps:"
echo "  1. Sign IPA with AltStore / SideStore"
echo "  2. Or use 爱思助手 to install"
echo "========================================="
