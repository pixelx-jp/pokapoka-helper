# pokapoka Helper 发布指南

本指南介绍如何将 pokapoka Helper (CueCompanion) 发布到 GitHub Releases，让用户可以自动下载。

## 目录

1. [准备工作](#准备工作)
2. [构建发布版本](#构建发布版本)
3. [创建 DMG 安装包](#创建-dmg-安装包)
4. [发布到 GitHub Releases](#发布到-github-releases)
5. [自动化发布 (GitHub Actions)](#自动化发布-github-actions)
6. [前端集成](#前端集成)

---

## 准备工作

### 1. 创建 GitHub 仓库

如果还没有独立仓库，建议创建一个：

```bash
# 在 GitHub 上创建新仓库: pixelx-jp/pokapoka-helper
# 然后推送代码
cd /path/to/CueCompanion
git init
git remote add origin https://github.com/pixelx-jp/pokapoka-helper.git
git add .
git commit -m "Initial commit"
git push -u origin main
```

### 2. 确保代码签名 (可选但推荐)

为了避免 macOS Gatekeeper 警告，建议使用 Apple Developer 证书签名：

```bash
# 检查可用的签名身份
security find-identity -v -p codesigning

# 签名应用
codesign --force --deep --sign "Developer ID Application: YOUR_NAME (TEAM_ID)" \
    CueCompanion.app
```

---

## 构建发布版本

### 方法 A: 命令行构建

```bash
cd /path/to/CueCompanion

# 清理旧构建
rm -rf .build/release

# Release 构建
swift build -c release

# 构建产物位置
ls -la .build/arm64-apple-macosx/release/CueCompanion
```

### 方法 B: 创建 .app 包

创建一个脚本 `build-app.sh`:

```bash
#!/bin/bash
set -e

APP_NAME="pokapoka Helper"
BUNDLE_ID="com.pixelx.pokapoka-helper"
VERSION="1.0.0"

# 构建 Release 版本
swift build -c release

# 创建 .app 目录结构
APP_DIR="${APP_NAME}.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 复制可执行文件
cp .build/arm64-apple-macosx/release/CueCompanion "$APP_DIR/Contents/MacOS/${APP_NAME}"

# 创建 Info.plist
cat > "$APP_DIR/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>pokapoka Helper needs microphone access to capture system audio.</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>pokapoka Helper needs screen recording permission to capture system audio.</string>
</dict>
</plist>
EOF

# 复制图标 (如果有)
# cp AppIcon.icns "$APP_DIR/Contents/Resources/"

echo "Created: $APP_DIR"
```

运行：
```bash
chmod +x build-app.sh
./build-app.sh
```

---

## 创建 DMG 安装包

### 方法 A: 使用 hdiutil (简单)

```bash
#!/bin/bash
APP_NAME="pokapoka Helper"
DMG_NAME="pokapoka-helper-mac"
VERSION="1.0.0"

# 创建临时目录
mkdir -p dmg-temp
cp -R "${APP_NAME}.app" dmg-temp/

# 创建 DMG
hdiutil create -volname "${APP_NAME}" \
    -srcfolder dmg-temp \
    -ov -format UDZO \
    "${DMG_NAME}-${VERSION}.dmg"

# 清理
rm -rf dmg-temp

echo "Created: ${DMG_NAME}-${VERSION}.dmg"
```

### 方法 B: 使用 create-dmg (美观)

```bash
# 安装 create-dmg
brew install create-dmg

# 创建漂亮的 DMG
create-dmg \
    --volname "pokapoka Helper" \
    --volicon "AppIcon.icns" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "pokapoka Helper.app" 175 190 \
    --hide-extension "pokapoka Helper.app" \
    --app-drop-link 425 190 \
    "pokapoka-helper-mac.dmg" \
    "pokapoka Helper.app"
```

---

## 发布到 GitHub Releases

### 方法 A: 手动发布 (GitHub 网页)

1. 打开仓库页面: `https://github.com/pixelx-jp/pokapoka-helper`
2. 点击右侧 **Releases**
3. 点击 **Draft a new release**
4. 填写信息：
   - **Tag**: `v1.0.0` (创建新标签)
   - **Release title**: `pokapoka Helper v1.0.0`
   - **Description**:
     ```markdown
     ## pokapoka Helper v1.0.0

     macOS 专用助手应用，用于捕获系统音频。

     ### 安装方法
     1. 下载 `pokapoka-helper-mac.dmg`
     2. 打开 DMG，将应用拖入 Applications 文件夹
     3. 首次运行时，在系统偏好设置中授予"屏幕录制"权限

     ### 系统要求
     - macOS 14.0 (Sonoma) 或更高版本
     - Apple Silicon (M1/M2/M3) 或 Intel Mac
     ```
5. 拖入 `pokapoka-helper-mac.dmg` 文件
6. 点击 **Publish release**

### 方法 B: 使用 GitHub CLI

```bash
# 安装 GitHub CLI
brew install gh

# 登录
gh auth login

# 创建 Release
gh release create v1.0.0 \
    --repo pixelx-jp/pokapoka-helper \
    --title "pokapoka Helper v1.0.0" \
    --notes "macOS 系统音频捕获助手" \
    pokapoka-helper-mac.dmg
```

---

## 自动化发布 (GitHub Actions)

创建 `.github/workflows/release.yml`:

```yaml
name: Build and Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-14

    steps:
      - uses: actions/checkout@v4

      - name: Setup Swift
        uses: swift-actions/setup-swift@v2
        with:
          swift-version: '5.9'

      - name: Build Release
        run: swift build -c release

      - name: Create App Bundle
        run: |
          APP_NAME="pokapoka Helper"
          mkdir -p "${APP_NAME}.app/Contents/MacOS"
          mkdir -p "${APP_NAME}.app/Contents/Resources"
          cp .build/release/CueCompanion "${APP_NAME}.app/Contents/MacOS/${APP_NAME}"
          cp Sources/CueCompanion/Info.plist "${APP_NAME}.app/Contents/"

      - name: Create DMG
        run: |
          hdiutil create -volname "pokapoka Helper" \
              -srcfolder "pokapoka Helper.app" \
              -ov -format UDZO \
              pokapoka-helper-mac.dmg

      - name: Upload Release Asset
        uses: softprops/action-gh-release@v1
        with:
          files: pokapoka-helper-mac.dmg
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

使用方法：
```bash
# 创建并推送标签触发自动构建
git tag v1.0.0
git push origin v1.0.0
```

---

## 前端集成

pokapoka 前端已配置好下载链接：

```typescript
// AudioDeviceSelector.tsx
const GITHUB_RELEASES_BASE = 'https://github.com/pixelx-jp/pokapoka-helper/releases';
const MACOS_DOWNLOAD_URL = `${GITHUB_RELEASES_BASE}/latest/download/pokapoka-helper-mac.dmg`;
```

**重要**: DMG 文件名必须是 `pokapoka-helper-mac.dmg`，这样 `/latest/download/` 链接才能正常工作。

### 下载 URL 格式

| 类型 | URL |
|------|-----|
| 最新版本 | `https://github.com/pixelx-jp/pokapoka-helper/releases/latest/download/pokapoka-helper-mac.dmg` |
| 指定版本 | `https://github.com/pixelx-jp/pokapoka-helper/releases/download/v1.0.0/pokapoka-helper-mac.dmg` |
| Releases 页面 | `https://github.com/pixelx-jp/pokapoka-helper/releases` |

---

## 检查清单

发布前检查：

- [ ] 版本号已更新 (Info.plist, Package.swift)
- [ ] Release 构建成功
- [ ] 应用可以正常启动
- [ ] DMG 文件名正确: `pokapoka-helper-mac.dmg`
- [ ] GitHub Release 已发布
- [ ] 下载链接可以正常访问

---

## 常见问题

### Q: 用户下载后无法打开应用？

A: 这是 macOS Gatekeeper 的安全限制。用户需要：
1. 右键点击应用 → 选择"打开"
2. 或在系统偏好设置 → 隐私与安全性 中允许

### Q: 如何支持 Intel Mac？

A: 构建 Universal Binary：
```bash
swift build -c release --arch arm64 --arch x86_64
```

### Q: 如何自动更新？

A: 可以集成 Sparkle 框架，但对于简单应用，建议让用户手动检查更新。
