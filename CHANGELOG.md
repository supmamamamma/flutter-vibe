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

### 变更（Changed）
- 流式输出在 0.1.0 阶段为“回放模拟”：先走非流式拿到完整结果，再逐字渲染以模拟流式体验。

### 修复（Fixed）
- 修复 Web 端输入法组合态导致的 TextInput 断言崩溃/输入框卡死问题：将设置页输入从 `TextFormField(initialValue)` 改为 `TextEditingController` 并在失焦/提交时写回。

