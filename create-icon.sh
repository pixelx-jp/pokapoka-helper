#!/bin/bash
# Convert PNG to macOS .icns icon

set -e

# 源图像路径
SOURCE_PNG="../front/public/logo-512.png"
ICONSET_DIR="AppIcon.iconset"
OUTPUT="AppIcon.icns"

if [ ! -f "$SOURCE_PNG" ]; then
    echo "Error: $SOURCE_PNG not found"
    exit 1
fi

echo "Creating macOS icon from $SOURCE_PNG..."

# 清理
rm -rf "$ICONSET_DIR" "$OUTPUT"
mkdir -p "$ICONSET_DIR"

# 生成各种尺寸 (macOS 需要这些)
sips -z 16 16     "$SOURCE_PNG" --out "$ICONSET_DIR/icon_16x16.png"
sips -z 32 32     "$SOURCE_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png"
sips -z 32 32     "$SOURCE_PNG" --out "$ICONSET_DIR/icon_32x32.png"
sips -z 64 64     "$SOURCE_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png"
sips -z 128 128   "$SOURCE_PNG" --out "$ICONSET_DIR/icon_128x128.png"
sips -z 256 256   "$SOURCE_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png"
sips -z 256 256   "$SOURCE_PNG" --out "$ICONSET_DIR/icon_256x256.png"
sips -z 512 512   "$SOURCE_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png"
sips -z 512 512   "$SOURCE_PNG" --out "$ICONSET_DIR/icon_512x512.png"
cp "$SOURCE_PNG"               "$ICONSET_DIR/icon_512x512@2x.png"

# 转换为 .icns
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT"

# 清理临时文件
rm -rf "$ICONSET_DIR"

echo "Created: $OUTPUT"
