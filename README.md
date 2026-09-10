# 🎵 Rin — iOS 本地音乐播放器

一款精美的 iOS 本地离线音乐播放器，支持专辑级浏览、LRC 歌词同步和 AI 智能推荐。

## ✨ 功能特性

- 🎧 **本地音乐播放**：扫描并播放 MP3/M4A/MP4/FLAC/WAV 等 11 种格式音频
- 🎤 **歌手 · 专辑浏览**：歌手 → 歌手详情 → 专辑 → 单曲 的完整层级（Apple Music 风格）
- 🎵 **专辑曲序**：读取音频文件内的音轨号，按专辑原顺序 1、2、3… 排列
- 🎨 **精美 UI**：黑胶唱片旋转动画、毛玻璃效果、实时频谱、弹性按钮动效
- 📝 **歌词同步**：LRC/KRC 逐字解析、翻译歌词、三源在线搜索（网易云/QQ/酷狗）
- 🔍 **全文搜索**：基于 SQLite FTS5 的歌曲/歌手/专辑全文搜索
- 🤖 **AI 推荐**：Claude / OpenAI 双引擎，每日推荐 + 心情电台 + 发现相似
- 🎛️ **后台播放**：锁屏控制中心集成、音频中断自动恢复
- 🌓 **主题切换**：深色/浅色/跟随系统 + 8 种主题色自定义

## 📋 系统要求

| 项目 | 版本 |
|------|------|
| iOS | 16.0+ |
| Bundle ID | `com.rin.player` |

> ⚠️ **从 MusicApp 升级的用户注意**：Bundle ID 已变更为 `com.rin.player`，
> 系统会把它当成**全新 App**。请先卸载旧的 MusicApp 再安装 Rin。

---

## 🚀 方式一：GitHub Actions 云编译（无需 Mac）

> ✅ **推荐给 Windows / Linux 用户** — 全程在浏览器完成

### 第一步：触发编译

1. 进入仓库 → **Actions** 标签
2. 点击左侧 **Build iOS App**
3. 点击右侧 **Run workflow** 下拉按钮
4. 点击绿色 **Run workflow** 按钮

等待约 **8-15 分钟**：

5. 点击完成的工作流 → 页面底部 **Artifacts**
6. 下载 **Rin-Unsigned**（一个 .zip 文件）
7. 解压得到 `Rin.ipa`

### 第二步：签名并安装到 iPhone

| 工具 | 平台 | 说明 |
|------|------|------|
| **[Sideloadly](https://sideloadly.io/)** | Windows/Mac | 简单直接，需数据线 |
| **[SideStore](https://sidestore.io/)** | Windows/Mac | 开源，支持 WiFi 自动续签 |
| **[爱思助手](https://www.i4.cn/)** | Windows | 中文界面，操作简单 |

**以 Sideloadly 为例：**

```
1. 电脑打开 Sideloadly，用数据线连接 iPhone
2. 把 Rin.ipa 拖进 Sideloadly
3. 输入 Apple ID → Start
4. iPhone 上：设置 → 通用 → VPN与设备管理 → 信任证书
5. 打开 Rin！
```

> ⚠️ 免费 Apple ID 每 7 天需续签。

---

## 💻 方式二：Mac + Xcode 本地编译

```bash
# 一键构建
brew install xcodegen
xcodegen generate
xcodebuild -resolvePackageDependencies -project Rin.xcodeproj -scheme Rin
open Rin.xcodeproj

# 或使用构建脚本
bash Scripts/build.sh debug
```

在 Xcode 中：Signing & Capabilities → Team 选你的 Apple ID → `Cmd + R`

---

## 🎨 更换 App 图标

**只需要替换一个图片文件，不用改任何代码。**

### 图片要求

| 项目 | 要求 |
|------|------|
| 尺寸 | **1024 × 1024** 像素（正方形） |
| 格式 | PNG |
| 圆角 | ❌ 不要自己做圆角 —— iOS 会自动裁切 |
| 透明背景 | ❌ 不要透明 —— 必须是实心背景 |
| 主体 | 建议居中，四周留出约 10% 安全边距 |

### 替换步骤

1. 打开仓库目录 `Resources/Assets.xcassets/AppIcon.appiconset/`
2. 删除现有的 `icon-1024.png`（点文件 → 右上角 🗑 Delete）
3. 回到该目录 → **Add file → Upload files**
4. 上传你的图片，**文件名必须改成 `icon-1024.png`**
5. 提交后等 CI 构建完成 → 下载新 IPA → 重新签名安装

> 💡 也可以直接把图片发给我，我来提交。
>
> 🔍 构建时 CI 会自动校验图标是否打包成功，缺失会直接报错，不会出现「以为换了其实没换」的情况。

---

## 🎵 导入音乐文件

App 支持**三种**导入方式，可按需选择。

### 方式一：内置打包（在电脑端预先放好）

适合「一次性整理好一整批音乐，装完就能听」。**推荐用于整张专辑收藏。**

1. 在 GitHub 网页打开仓库的 `Resources/Music/` 目录
2. 点 **Add file → Upload files**，把音频文件拖进去
3. 提交后等 CI 构建完成，下载新的 IPA 重新签名安装
4. 打开 App → 点右上角 🔄 **扫描**，所有内置音乐就会出现

**按专辑建子文件夹**（推荐，扫描器是递归的，任意层级都能识别）：

```
Resources/Music/
├── Jay/
│   ├── 可爱女人.m4a
│   ├── 完美主义.m4a
│   └── ...
├── 范特西/
│   ├── 爱在西元前.m4a
│   └── ...
└── 叶惠美/
    └── ...
```

> ⚠️ 仓库是公开的，请勿上传有版权的商业音乐（DMCA 下架风险）。
> 📦 建议总量控制在 200MB 以内，否则构建会变慢。
> 🔄 每次新增文件都要重新构建 + 重新签名才能生效。

### 方式二：应用内导入（手机端，最方便）

1. 把音频文件传到 iPhone（AirDrop / 微信 / 网盘 / QQ 均可）
2. 保存到「**文件**」App
3. 打开 Rin → 点右上角 ➕ **导入** 按钮
4. 选中文件即可，App 会自动复制并扫描入库

### 方式三：文件共享（连电脑批量拷）

App 的 Documents 目录会出现在：

- **iPhone 上**：「文件」App → 我的 iPhone → **Rin**
- **Windows 上**：爱思助手 → 应用 → Rin → 文件管理 → Documents
- **Mac 上**：Finder → iPhone → 文件 → Rin

拖进去后，在 App 里点 🔄 **扫描** 即可。

### 歌词文件

在同名音频文件旁边放 `.lrc` 文件即可自动识别，或者：
- 在播放器中点击 `歌词` → 在线搜索（网易云 / QQ 音乐 / 酷狗）→ 一键下载并缓存

---

## 📂 项目结构

```
Rin/
├── App/RinApp.swift                ← @main 入口
├── Core/
│   ├── Audio/AudioPlayer.swift     ← AVFoundation 播放引擎
│   ├── Database/                   ← SQLite + FTS5 + 数据仓库
│   ├── FileManager/                ← 文件扫描 + ID3 元数据提取
│   └── Network/                    ← 歌词搜索 + AI 推荐 API
├── Modules/
│   ├── Player/                     ← 播放器（全屏 + 迷你 + 歌词）
│   ├── Library/                    ← 音乐库（歌曲/专辑/歌手 + 详情页）
│   └── AI/                         ← 智能推荐
├── UI/
│   ├── Theme/                      ← 主题管理 + 色彩系统
│   ├── Components/                 ← 唱片动画 + 波形 + 毛玻璃等
│   └── Animation/                  ← 转场 + 微动效
├── Utilities/
│   ├── LRC/Parser.swift            ← LRC/KRC 歌词解析器
│   └── Constants.swift
├── Resources/
│   ├── Assets.xcassets/            ← App 图标等资源
│   └── Music/                      ← 内置音乐（随 IPA 打包）
├── Scripts/build.sh                ← 本地构建脚本
├── project.yml                     ← XcodeGen 项目配置
└── .github/workflows/build.yml     ← GitHub Actions 云编译
```

## 🎯 技术架构

| 层级 | 技术 |
|------|------|
| UI 框架 | SwiftUI |
| 架构 | MVVM + Combine |
| 音频引擎 | AVFoundation + MediaPlayer |
| 数据库 | SQLite (GRDB.swift + FTS5) |
| 图片加载 | Kingfisher |
| 歌词解析 | 自研 LRC/KRC Parser |
| AI 引擎 | Claude API / OpenAI API + 离线算法 |

## 📖 参考项目

- [local-music-player](https://github.com/caiyy/local-music-player) — 均衡器设计
- [music-app](https://github.com/nexo-tech/music-app) — 离线播放架构
- [KMusic](https://github.com/Mac-XK/KMusic) — 歌词同步实现
- [YouTag](https://github.com/youstanzr/YouTag) — 标签管理
- [SwiftUI-Music-Player](https://github.com/SwiftieDev/SwiftUI-Music-Player) — UI 设计
- [HMP](https://github.com/InfiniteMotion/HMP) — AI 推荐模块

## 📝 许可

MIT License
