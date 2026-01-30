import 'package:uuid/uuid.dart';

import 'llm_provider.dart';

class LlmProfile {
  const LlmProfile({
    required this.id,
    required this.name,
    required this.provider,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    required this.openAiTemperature,
    required this.openAiTopP,
    required this.openAiTopK,
    required this.openAiMaxTokens,
    required this.geminiTemperature,
    required this.geminiTopP,
    required this.geminiTopK,
    required this.geminiMaxOutputTokens,
    required this.claudeTemperature,
    required this.claudeTopP,
    required this.claudeTopK,
    required this.claudeMaxTokens,
  });

  factory LlmProfile.create({
    required String name,
    required LlmProvider provider,
    required String baseUrl,
    required String model,
  }) {
    return LlmProfile(
      id: const Uuid().v4(),
      name: name,
      provider: provider,
      baseUrl: baseUrl,
      apiKey: '',
      model: model,
      // generation params（可选）
      openAiTemperature: null,
      openAiTopP: null,
      openAiTopK: null,
      openAiMaxTokens: null,

      geminiTemperature: null,
      geminiTopP: null,
      geminiTopK: null,
      geminiMaxOutputTokens: null,

      claudeTemperature: null,
      claudeTopP: null,
      claudeTopK: null,
      // Claude 的 max_tokens 在官方 API 是必填；这里给一个默认值。
      claudeMaxTokens: 1024,
    );
  }

  final String id;
  final String name;
  final LlmProvider provider;

  final String baseUrl;
  final String apiKey;
  final String model;

  // provider-specific
  final double? openAiTemperature;
  final double? openAiTopP;
  final int? openAiTopK;
  final int? openAiMaxTokens;

  final double? geminiTemperature;
  final double? geminiTopP;
  final int? geminiTopK;
  final int? geminiMaxOutputTokens;

  final double? claudeTemperature;
  final double? claudeTopP;
  final int? claudeTopK;
  final int claudeMaxTokens;

  LlmProfile copyWith({
    String? name,
    LlmProvider? provider,
    String? baseUrl,
    String? apiKey,
    String? model,
    double? openAiTemperature,
    bool clearOpenAiTemperature = false,
    double? openAiTopP,
    bool clearOpenAiTopP = false,
    int? openAiTopK,
    bool clearOpenAiTopK = false,
    int? openAiMaxTokens,
    bool clearOpenAiMaxTokens = false,
    double? geminiTemperature,
    bool clearGeminiTemperature = false,
    double? geminiTopP,
    bool clearGeminiTopP = false,
    int? geminiTopK,
    bool clearGeminiTopK = false,
    int? geminiMaxOutputTokens,
    bool clearGeminiMaxOutputTokens = false,
    double? claudeTemperature,
    bool clearClaudeTemperature = false,
    double? claudeTopP,
    bool clearClaudeTopP = false,
    int? claudeTopK,
    bool clearClaudeTopK = false,
    int? claudeMaxTokens,
  }) {
    return LlmProfile(
      id: id,
      name: name ?? this.name,
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      openAiTemperature: clearOpenAiTemperature
          ? null
          : (openAiTemperature ?? this.openAiTemperature),
      openAiTopP: clearOpenAiTopP ? null : (openAiTopP ?? this.openAiTopP),
      openAiTopK: clearOpenAiTopK ? null : (openAiTopK ?? this.openAiTopK),
      openAiMaxTokens:
          clearOpenAiMaxTokens ? null : (openAiMaxTokens ?? this.openAiMaxTokens),

      geminiTemperature: clearGeminiTemperature
          ? null
          : (geminiTemperature ?? this.geminiTemperature),
      geminiTopP: clearGeminiTopP ? null : (geminiTopP ?? this.geminiTopP),
      geminiTopK: clearGeminiTopK ? null : (geminiTopK ?? this.geminiTopK),
      geminiMaxOutputTokens: clearGeminiMaxOutputTokens
          ? null
          : (geminiMaxOutputTokens ?? this.geminiMaxOutputTokens),

      claudeTemperature: clearClaudeTemperature
          ? null
          : (claudeTemperature ?? this.claudeTemperature),
      claudeTopP: clearClaudeTopP ? null : (claudeTopP ?? this.claudeTopP),
      claudeTopK: clearClaudeTopK ? null : (claudeTopK ?? this.claudeTopK),
      claudeMaxTokens: claudeMaxTokens ?? this.claudeMaxTokens,
    );
  }
}

