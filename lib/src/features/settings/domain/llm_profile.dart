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
    required this.claudeMaxTokens,
    required this.openAiMaxTokens,
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
      claudeMaxTokens: 1024,
      openAiMaxTokens: null,
    );
  }

  final String id;
  final String name;
  final LlmProvider provider;

  final String baseUrl;
  final String apiKey;
  final String model;

  // provider-specific
  final int claudeMaxTokens;
  final int? openAiMaxTokens;

  LlmProfile copyWith({
    String? name,
    LlmProvider? provider,
    String? baseUrl,
    String? apiKey,
    String? model,
    int? claudeMaxTokens,
    int? openAiMaxTokens,
    bool clearOpenAiMaxTokens = false,
  }) {
    return LlmProfile(
      id: id,
      name: name ?? this.name,
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      claudeMaxTokens: claudeMaxTokens ?? this.claudeMaxTokens,
      openAiMaxTokens:
          clearOpenAiMaxTokens ? null : (openAiMaxTokens ?? this.openAiMaxTokens),
    );
  }
}

