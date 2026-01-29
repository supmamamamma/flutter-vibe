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

详见 [`CHANGELOG.md`](CHANGELOG.md:1)
