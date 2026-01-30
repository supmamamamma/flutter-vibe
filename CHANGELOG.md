# 更新日志（Changelog）

本项目遵循「Keep a Changelog」的格式约定。

## [0.2.1] - 2026-01-30

### 新增（Added）
- Chat：user / assistant 消息支持“编辑”
  - 支持两种保存方式：仅修改 / 修改并截断后续消息（用于调整上下文）
  - user 消息支持附件编辑（删除/清空/重新选择）
  - 实现见：[`_ChatPanel.build()`](lib/src/features/chat/presentation/chat_page.dart:392)、[`ChatController.editMessage()`](lib/src/features/chat/application/chat_controller.dart:22)
- Settings：为 OpenAI / Gemini / Claude 增加可选生成参数（未填写则不传）
  - OpenAI：`temperature` / `top_p` / `top_k` / `max_tokens`
  - Gemini：`generationConfig.temperature` / `topP` / `topK` / `maxOutputTokens`
  - Claude：`temperature` / `top_p` / `top_k` / `max_tokens`

### 修复（Fixed）
- Gemini 流式回复：修复“请求成功但 UI 无增量输出”的解析问题
  - 强制请求 SSE（`alt=sse` + `Accept: text/event-stream`）
  - 解析兼容 JSON 数组 batch 形态
  - 实现见：[`_geminiStreamGenerateContent()`](lib/src/features/llm/application/llm_service.dart:400)

### 变更（Changed）
- OpenAI baseUrl 处理调整：不再自动附加 `/v1`，仅追加 `/chat/completions`；`/v1` 等前缀由用户在 baseUrl 中自行填写（Settings 中已增加提示）
- 跨平台 streaming POST：IO 端改为使用 `dart:io` 的 `HttpClient` 进行真正的响应流读取（避免缓冲完整响应），并与 Web 端 XHR 增量保持一致的 [`Stream<String>`](lib/src/shared/http/streaming_post.dart:12) API
  - 条件导入入口：[`postTextStream()`](lib/src/shared/http/streaming_post.dart:12)
  - IO 实现：[`postTextStreamImpl()`](lib/src/shared/http/streaming_post_io.dart:22)
- Settings 持久化结构升级（schemaVersion: 2 -> 3）：将各 Provider 的生成参数随 Profile 一并持久化

## [0.2.0] - 2026-01-29

### 新增（Added）
- Flutter Web/PWA 前端项目骨架：路由（Chat / Settings）、主题与基础页面框架。
- 聊天页：
  - 宽屏三栏布局（会话列表 / 对话区 / 输入区）。
  - Markdown 渲染。
  - 请求统计展示（Latency / In tokens / Out tokens）。
- 设置页：
  - 连接配置 Profile：支持多个 API 连接配置（下拉选择 + 新增/删除/重命名）。
  - Profile 字段：provider/baseUrl/apiKey/model（并支持 provider-specific：Claude max_tokens、OpenAI max_tokens）。
  - Provider Tab 与 Profile.provider 联动。
  - 流式/非流式开关（`Stream responses`）。
- LLM 适配层（非流式）：
  - OpenAI Chat Completions。
  - Gemini generateContent。
  - Claude Messages。

- Chat 交互增强：
  - assistant 消息支持“复制/重试”。
  - 移动端会话列表使用 Drawer 侧边栏（左上角菜单打开）。

- 文件上传（MVP，多模态）：
  - 支持上传图片（png/jpg/jpeg/webp/gif）与 txt。
  - 图片会作为 Vision 输入发送给 OpenAI/Gemini/Claude（按各家格式组装）。
  - txt 会按原文拼入上下文。

### 变更（Changed）
- 流式输出由“回放模拟”升级为真实 streaming：
  - OpenAI / Claude：SSE（text/event-stream）。
  - Web 端通过 XHR onProgress 读取响应增量。

- Settings 存储结构升级（schemaVersion: 1 -> 2）：
  - v1 的单配置会在首次读取时迁移为一个 Profile。

### 修复（Fixed）
- 修复 Web 端输入法组合态导致的 TextInput 断言崩溃/输入框卡死问题：将设置页输入从 `TextFormField(initialValue)` 改为 `TextEditingController` 并在失焦/提交时写回。

