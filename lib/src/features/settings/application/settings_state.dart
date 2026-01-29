import '../domain/llm_provider.dart';

class SettingsState {
  const SettingsState({
    required this.activeProvider,
    required this.useStreaming,
    required this.openAiApiKey,
    required this.geminiApiKey,
    required this.claudeApiKey,
    required this.openAiBaseUrl,
    required this.geminiBaseUrl,
    required this.claudeBaseUrl,
    required this.openAiModel,
    required this.geminiModel,
    required this.claudeModel,
    required this.claudeMaxTokens,
    required this.openAiMaxTokens,
  });

  final LlmProvider activeProvider;
  /// 是否启用流式输出。
  ///
  /// 目前 UI/状态已支持；实际 streaming 实现将在后续里程碑接入。
  final bool useStreaming;
  final String openAiApiKey;
  final String geminiApiKey;
  final String claudeApiKey;

  final String openAiBaseUrl;
  final String geminiBaseUrl;
  final String claudeBaseUrl;

  final String openAiModel;
  final String geminiModel;
  final String claudeModel;

  final int claudeMaxTokens;
  final int? openAiMaxTokens;

  SettingsState copyWith({
    LlmProvider? activeProvider,
    bool? useStreaming,
    String? openAiApiKey,
    String? geminiApiKey,
    String? claudeApiKey,
    String? openAiBaseUrl,
    String? geminiBaseUrl,
    String? claudeBaseUrl,
    String? openAiModel,
    String? geminiModel,
    String? claudeModel,
    int? claudeMaxTokens,
    int? openAiMaxTokens,
  }) {
    return SettingsState(
      activeProvider: activeProvider ?? this.activeProvider,
      useStreaming: useStreaming ?? this.useStreaming,
      openAiApiKey: openAiApiKey ?? this.openAiApiKey,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      claudeApiKey: claudeApiKey ?? this.claudeApiKey,
      openAiBaseUrl: openAiBaseUrl ?? this.openAiBaseUrl,
      geminiBaseUrl: geminiBaseUrl ?? this.geminiBaseUrl,
      claudeBaseUrl: claudeBaseUrl ?? this.claudeBaseUrl,
      openAiModel: openAiModel ?? this.openAiModel,
      geminiModel: geminiModel ?? this.geminiModel,
      claudeModel: claudeModel ?? this.claudeModel,
      claudeMaxTokens: claudeMaxTokens ?? this.claudeMaxTokens,
      openAiMaxTokens: openAiMaxTokens ?? this.openAiMaxTokens,
    );
  }
}

