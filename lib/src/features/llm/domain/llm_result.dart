class LlmResult {
  const LlmResult({
    required this.text,
    required this.latencyMs,
    this.promptTokens,
    this.completionTokens,
  });

  final String text;
  final int latencyMs;
  final int? promptTokens;
  final int? completionTokens;
}

