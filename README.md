# AI Chat PWA（Flutter Web）

一个可扩展的 AI 聊天前端（Flutter Web / PWA），支持 **OpenAI / Gemini / Claude** 多 Provider，支持会话管理与 System Prompt 管理，并将设置与聊天数据持久化到浏览器 **IndexedDB**。

> 安全模型：纯前端 BYO-Key（用户自行输入 Key，保存在浏览器 IndexedDB，前端直连各家 API）。这意味着 Key 可能暴露在浏览器环境中，且可能受到 CORS 限制影响。

## 功能概览

- 多 Provider：OpenAI / Gemini / Claude
  - 可分别配置 `baseUrl` / `model` / `apiKey`
  - 支持“流式/非流式”开关（当前流式为“回放模拟流式”，用于打通 UI 与未来真实流式抽象）
- Chat：
  - 会话管理：新建、切换、重命名、排序、删除
  - 消息渲染：Markdown（支持选择复制）
  - assistant 消息操作：**复制**、**重试（重新生成）**
- System Prompts：
  - CRUD（新增/编辑/删除）
  - 选择 active prompt，并在发送请求时注入 system message
- 持久化：
  - Settings / System Prompts / Chat Sessions 全部写入 IndexedDB（刷新后可恢复）

## 技术栈

- Flutter Web / PWA（`web/manifest.json`、`web/index.html`）
- 路由：go_router
- 状态管理：flutter_riverpod
- Markdown：flutter_markdown
- 持久化：sembast + sembast_web（IndexedDB）
- 网络：http

## 目录结构（简述）

- `lib/src/features/chat/`：聊天、会话管理、消息渲染、重试
- `lib/src/features/settings/`：Provider 设置（Key/baseUrl/model/流式开关）
- `lib/src/features/prompts/`：System Prompt 管理
- `lib/src/features/llm/`：多 Provider LLM 适配层
- `lib/src/shared/persistence/`：IndexedDB（sembast_web）数据库入口

## 快速开始

### 1) 安装依赖

```bash
flutter pub get
```

### 2) 启动 Web 预览

```bash
flutter run -d chrome
```

启动后：

1. 进入 Settings 页面，选择 Provider，并填写：
   - API Key
   - baseUrl（可选，支持自定义）
   - model（可选/必填取决于 Provider）
2. 回到 Chat 页面开始对话。

## 编译与部署指南（各平台）

### Web / PWA（推荐）

#### 本地构建（Release）

```bash
flutter build web --release
```

构建产物在 `build/web/`。

#### 本地验证（静态服务器）

> 直接双击打开 `build/web/index.html` 可能因为浏览器安全策略导致资源加载/路由异常，建议用静态服务器。

- 如果你有 Python：

```bash
cd build/web
python -m http.server 8080
```

然后访问 `http://localhost:8080/`。

#### 部署到静态站点

把 `build/web/` 目录内容上传到任意静态托管平台即可，例如：

- Nginx / Caddy / Apache
- GitHub Pages
- Cloudflare Pages
- Vercel / Netlify

注意：

- 如果使用前端路由（本项目使用 go_router），需要配置“History 模式回退”到 `index.html`。
  - Nginx 示例（概念）：所有未知路径重写到 `/index.html`。
- PWA 的图标与 manifest 在 [`web/manifest.json`](web/manifest.json:1) 与 [`web/index.html`](web/index.html:1)；若要自定义应用名/图标，从这两个文件入手。

### Android（APK / AAB）

#### 构建 APK

```bash
flutter build apk --release
```

产物一般在 `build/app/outputs/flutter-apk/app-release.apk`。

#### 构建 AAB（上架 Google Play）

```bash
flutter build appbundle --release
```

产物一般在 `build/app/outputs/bundle/release/app-release.aab`。

### iOS（IPA / App Store）

> iOS 构建需要 macOS + Xcode。

```bash
flutter build ios --release
```

然后使用 Xcode 打开 `ios/Runner.xcworkspace` 进行签名与归档（Archive）并分发。

### Windows（桌面版）

```bash
flutter build windows --release
```

产物一般在 `build/windows/x64/runner/Release/`。

### macOS（桌面版）

```bash
flutter build macos --release
```

产物一般在 `build/macos/Build/Products/Release/`。

### Linux（桌面版）

```bash
flutter build linux --release
```

产物一般在 `build/linux/x64/release/bundle/`。

### 重要说明（部署/运行时）

- **BYO-Key 风险**：Key 存在浏览器侧（IndexedDB），并由前端直接调用第三方 API。
- **CORS**：Web 直连第三方 API 可能被浏览器跨域限制；本项目已支持自定义 `baseUrl`，必要时可配合自建代理。
- **数据持久化**：Settings / Prompts / Sessions 均保存在本机浏览器 IndexedDB；清理站点数据会导致丢失。

## 关键交互说明

### assistant 消息的“复制/重试”

- 复制：将该条 assistant 的 Markdown 原始文本复制到剪贴板。
- 重试：对该条 assistant 重新生成，当前策略为：
  - 基于该条 assistant 之前的对话 history 重新请求
  - 将结果写回同一条 assistant 消息（覆盖原内容）

相关实现：

- UI：[`lib/src/features/chat/presentation/chat_page.dart`](lib/src/features/chat/presentation/chat_page.dart:1)
- Controller：[`retryAssistantMessage()`](lib/src/features/chat/application/chat_controller.dart:1)

## 持久化说明

本项目使用 IndexedDB 存储：

- 应用设置（Provider 配置、流式开关等）
- System Prompts
- Chat sessions 与消息列表

数据库入口：[`appDatabaseProvider`](lib/src/shared/persistence/app_database.dart:1)

## 已知限制 / 后续规划

- 真实流式输出（SSE/Fetch stream）尚未接入（目前为“回放模拟流式”）
- 纯前端直连第三方 API 可能受到 CORS 限制，需要配合可用的 baseUrl / 代理方案
- 会话搜索、富文本增强（代码块复制/KaTeX/图片查看器等）、单元测试仍在 backlog

## 版本与变更记录

详见 [`CHANGELOG.md`](CHANGELOG.md)
