enum LlmProvider {
  openai,
  gemini,
  claude;

  String get label {
    return switch (this) {
      LlmProvider.openai => 'OpenAI',
      LlmProvider.gemini => 'Gemini',
      LlmProvider.claude => 'Claude',
    };
  }
}

