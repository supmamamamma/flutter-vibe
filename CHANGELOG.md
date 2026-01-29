# 更新日志（Changelog）

本项目遵循「Keep a Changelog」的格式约定。

## [0.1.0] - 2026-01-29

### 新增（Added）
- Flutter Web/PWA 前端项目骨架：路由（Chat / Settings）、主题与基础页面框架。
- 聊天页：
  - 宽屏三栏布局（会话列表 / 对话区 / 输入区）。
  - Markdown 渲染。
  - 请求统计展示（Latency / In tokens / Out tokens）。
- 设置页：
  - 三提供商分页（TabBar/TabBarView）：OpenAI / Gemini / Claude。
  - Provider 下拉菜单与分页双向同步。
  - 三家 API 的 `base_url` 可配置。
  - 三家模型名可配置（Claude 额外支持 `max_tokens`）。
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

### 修复（Fixed）
- 修复 Web 端输入法组合态导致的 TextInput 断言崩溃/输入框卡死问题：将设置页输入从 `TextFormField(initialValue)` 改为 `TextEditingController` 并在失焦/提交时写回。

