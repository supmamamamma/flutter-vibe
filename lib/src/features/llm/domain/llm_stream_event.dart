/// LLM 流式输出事件。
///
/// - [LlmStreamText]：增量文本（delta）。
/// - [LlmStreamDone]：流结束，包含统计信息（如果可用）。
abstract class LlmStreamEvent {
  const LlmStreamEvent();
}

class LlmStreamText extends LlmStreamEvent {
  const LlmStreamText(this.delta);

  final String delta;
}

class LlmStreamDone extends LlmStreamEvent {
  const LlmStreamDone({
    required this.latencyMs,
    required this.promptTokens,
    required this.completionTokens,
  });

  final int latencyMs;
  final int? promptTokens;
  final int? completionTokens;
}

