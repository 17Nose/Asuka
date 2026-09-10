# 🎵 MusicApp — iOS 本地音乐播放器

一款精美的 iOS 本地离线音乐播放器，支持 LRC 歌词同步和 AI 智能推荐。

## ✨ 功能特性

- 🎧 **本地音乐播放**：扫描并播放设备上的 MP3/FLAC/WAV/M4A 等 10 种格式音频
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
| Swift | 5.9+ |

---

## 🚀 方式一：GitHub Actions 云编译（无需 Mac）

> ✅ **推荐给 Windows / Linux 用户** — 全程在浏览器完成

### 第一步：Fork 并上传代码

1. 点击本仓库右上角 **Fork** 
2. 你的代码已经在仓库中了，无需额外操作

### 第二步：触发编译

1. 进入你 Fork 的仓库 → **Actions** 标签
2. 点击左侧 **Build iOS App**
3. 点击右侧 **Run workflow** 下拉按钮
4. 选择 `debug`（首次建议）或 `release`
5. 点击绿色 **Run workflow** 按钮

等待约 **8-15 分钟**，编译完成后：

6. 点击完成的工作流 → 页面底部 **Artifacts**
7. 下载 **MusicApp-Unsigned** (一个 .zip 文件)
8. 解压得到 `MusicApp.ipa`

### 第三步：签名并安装到 iPhone

下载到 IPA 后，用以下任一工具签名安装：

| 工具 | 平台 | 说明 |
|------|------|------|
| **[SideStore](https://sidestore.io/)** | Windows/Mac | 开源，免费，WiFi 自动续签 |
| **[AltStore](https://altstore.io/)** | Windows/Mac | 经典工具，需电脑配合续签 |
| **[爱思助手](https://www.i4.cn/)** | Windows | 中文界面，操作简单 |

**以 SideStore 为例（推荐）：**

```
1. 下载 SideStore 到你的电脑
2. 用数据线连接 iPhone → 安装 SideStore 到手机
3. iPhone 上打开 SideStore → Settings → 登录你的 Apple ID
4. 把 MusicApp.ipa 通过 AirDrop/文件 传到 iPhone
5. 在 iPhone 上用 SideStore 打开 IPA → 签名安装
6. 去 设置 → 通用 → VPN与设备管理 → 信任证书
7. 打开 MusicApp！
```

> ⚠️ 免费 Apple ID 每 7 天需续签。SideStore 支持 WiFi 自动续签。

---

## 💻 方式二：Mac + Xcode 本地编译

### 1. 一键构建

```bash
# 安装 XcodeGen
brew install xcodegen

# 生成项目
xcodegen generate

# 解析依赖
xcodebuild -resolvePackageDependencies -project MusicApp.xcodeproj -scheme MusicApp

# 用 Xcode 打开
open MusicApp.xcodeproj
```

### 2. 或使用构建脚本

```bash
bash Scripts/build.sh debug    # Debug 构建
bash Scripts/build.sh release  # Release 构建
```

### 3. 在 Xcode 中运行

1. 选择你的 iPhone 作为目标设备
2. Signing & Capabilities → Team 选择你的 Apple ID
3. `Cmd + R` 运行

---

## 🎵 导入音乐文件

App 支持**三种**导入方式，可按需选择。

### 方式一：内置打包（在电脑端预先放好）

适合「一次性整理好一整批音乐，装完就能听」。

1. 在 GitHub 网页打开仓库的 `Resources/Music/` 目录
2. 点 **Add file → Upload files**，把音频文件拖进去（支持建子文件夹分类）
3. 提交后等 CI 构建完成，下载新的 IPA 重新签名安装
4. 打开 App → 点右上角 🔄 **扫描**，所有内置音乐就会出现

> ⚠️ 仓库是公开的，请勿上传有版权的商业音乐（DMCA 风险）。
> 📦 建议总量控制在 200MB 以内，否则构建会变慢。
> 🔄 每次新增文件都要重新构建 + 重新签名才能生效。

### 方式二：应用内导入（手机端，最方便）

1. 把音频文件传到 iPhone（AirDrop / 微信 / 网盘 / QQ 均可）
2. 保存到「**文件**」App
3. 打开 MusicApp → 点右上角 ➕ **导入** 按钮
4. 选中文件即可，App 会自动复制并扫描入库

> 支持一次选多个文件，也支持从 iCloud Drive 导入。

### 方式三：文件共享（连电脑批量拷）

App 已开启文件共享，它的 Documents 目录会出现在：

- **iPhone 上**：「文件」App → 我的 iPhone → **MusicApp**
- **Windows 上**：爱思助手 → 应用 → MusicApp → 文件管理 → Documents
- **Mac 上**：Finder → iPhone → 文件 → MusicApp

直接把音频文件拖进去，然后在 App 里点 🔄 **扫描** 即可。

### 歌词文件

在同名音频文件旁边放 `.lrc` 文件即可自动识别，或者：
- 在播放器中点击 `歌词` → 在线搜索（网易云 / QQ 音乐 / 酷狗）→ 一键下载并缓存

---

## 📂 项目结构

```
MusicApp/
├── App/MusicApp.swift              ← @main 入口
├── Core/
│   ├── Audio/AudioPlayer.swift     ← AVFoundation 播放引擎
│   ├── Database/                   ← SQLite + FTS5 + 数据仓库
│   ├── FileManager/                ← 文件扫描 + ID3 元数据提取
│   └── Network/                    ← 歌词搜索 + AI 推荐 API
├── Modules/
│   ├── Player/                     ← 播放器（全屏 + 迷你 + 歌词）
│   ├── Library/                    ← 音乐库（歌曲/专辑/歌手）
│   └── AI/                         ← 智能推荐（每日混音 + 心情电台）
├── UI/
│   ├── Theme/                      ← 主题管理 + 色彩系统
│   ├── Components/                 ← 唱片动画 + 波形 + 毛玻璃等
│   └── Animation/                  ← 转场 + 微动效
├── Utilities/
│   ├── LRC/Parser.swift            ← LRC/KRC 歌词解析器
│   └── Constants.swift
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
