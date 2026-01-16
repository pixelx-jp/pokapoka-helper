# pokapoka Helper 发布指南

## 快速发布

```bash
# 1. 构建（自动生成图标、.app、.dmg）
./build-app.sh

# 2. 发布到 GitHub
gh release create v1.0.0 pokapoka-helper-mac.dmg --title "pokapoka Helper v1.0.0"
```

完成！用户就可以从前端下载了。

---

## 详细步骤

### 1. 准备 GitHub 仓库

```bash
# 创建仓库: pixelx-jp/pokapoka-helper
git init
git remote add origin https://github.com/pixelx-jp/pokapoka-helper.git
git add .
git commit -m "Initial commit"
git push -u origin main
```

### 2. 构建

```bash
./build-app.sh
```

脚本会自动：
- 从前端 logo 生成 AppIcon.icns
- 编译 Release 版本
- 创建 `pokapoka Helper.app`
- 打包 `pokapoka-helper-mac.dmg`

### 3. 发布

**方法 A: GitHub CLI（推荐）**
```bash
gh release create v1.0.0 pokapoka-helper-mac.dmg --title "pokapoka Helper v1.0.0"
```

**方法 B: 网页上传**
1. 打开 https://github.com/pixelx-jp/pokapoka-helper/releases
2. 点击 "Draft a new release"
3. Tag: `v1.0.0`
4. 拖入 `pokapoka-helper-mac.dmg`
5. 发布

---

## 前端下载链接

已配置好，DMG 文件名必须是 `pokapoka-helper-mac.dmg`：

| 类型 | URL |
|------|-----|
| 最新版 | `https://github.com/pixelx-jp/pokapoka-helper/releases/latest/download/pokapoka-helper-mac.dmg` |
| 指定版本 | `https://github.com/pixelx-jp/pokapoka-helper/releases/download/v1.0.0/pokapoka-helper-mac.dmg` |

---

## 代码签名（可选）

没有签名时，用户首次打开需要右键 →「打开」。前端 UI 已有提示。

如需签名（$99/年 Apple Developer）：
```bash
codesign --force --deep --sign "Developer ID Application: YOUR_NAME (TEAM_ID)" "pokapoka Helper.app"
```

---

## 版本更新

1. 修改 `build-app.sh` 中的 `VERSION="1.0.0"`
2. 重新运行 `./build-app.sh`
3. 发布新版本 `gh release create v1.1.0 pokapoka-helper-mac.dmg`

---

## FAQ

**Q: 用户无法打开应用？**
A: 右键点击 → 选择「打开」→ 确认

**Q: 支持 Intel Mac？**
```bash
swift build -c release --arch arm64 --arch x86_64
```
