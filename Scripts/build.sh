#!/bin/bash
# ====================================================
#  Rin — 本地构建脚本 (需要 macOS + Xcode)
#  用法: bash Scripts/build.sh [debug|release]
# ====================================================

set -e

CONFIG="${1:-debug}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "========================================="
echo "  🎵 Rin Build Script"
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
    -project Rin.xcodeproj \
    -scheme Rin

# 4. Build
echo "🔨 Building for iOS device..."
if [ "$CONFIG" = "release" ]; then
    BUILD_CONFIG="Release"
else
    BUILD_CONFIG="Debug"
fi

xcodebuild build \
    -project Rin.xcodeproj \
    -scheme Rin \
    -configuration "$BUILD_CONFIG" \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -derivedDataPath ./DerivedData \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    DEVELOPMENT_TEAM="" \
    ENABLE_DEBUG_DYLIB=NO \
    ENABLE_PREVIEWS=NO \
    ONLY_ACTIVE_ARCH=NO

# 5. Package as IPA
echo "📦 Packaging IPA..."
APP_PATH=$(find ./DerivedData -name "Rin.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Error: Rin.app not found!"
    exit 1
fi

rm -rf Payload Rin.ipa
mkdir -p Payload
cp -R "$APP_PATH" Payload/
xattr -cr Payload || true
zip -r -X -y Rin.ipa Payload
zip -d Rin.ipa "__MACOSX/*" 2>/dev/null || true
rm -rf Payload

echo "========================================="
echo "  ✅ Build complete!"
echo "  📱 IPA: $(pwd)/Rin.ipa"
echo "  📏 Size: $(ls -lh Rin.ipa | awk '{print $5}')"
echo "========================================="
echo ""
echo "  Next steps:"
echo "  1. Sign IPA with Sideloadly / SideStore / AltStore"
echo "  2. Or use 爱思助手 to install"
echo "========================================="
