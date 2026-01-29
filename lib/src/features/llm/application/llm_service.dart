import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../chat/domain/chat_models.dart';
import '../../settings/application/settings_state.dart';
import '../../settings/domain/llm_provider.dart';
import '../domain/llm_exception.dart';
import '../domain/llm_result.dart';

class LlmService {
  LlmService({required this.httpClient, required this.settings});

  final http.Client httpClient;
  final SettingsState settings;

  Future<LlmResult> generate({required List<ChatMessage> messages}) async {
    final start = DateTime.now();
    return switch (settings.activeProvider) {
      LlmProvider.openai => _openAiChatCompletions(start: start, messages: messages),
      LlmProvider.gemini => _geminiGenerateContent(start: start, messages: messages),
      LlmProvider.claude => _claudeMessages(start: start, messages: messages),
    };
  }

  String _systemFromHistory(List<ChatMessage> messages) {
    return messages
        .where((m) => m.role == ChatRole.system)
        .map((m) => m.content)
        .join('\n')
        .trim();
  }

  List<ChatMessage> _nonSystemHistory(List<ChatMessage> messages) {
    return messages.where((m) => m.role != ChatRole.system).toList(growable: false);
  }

  Future<LlmResult> _openAiChatCompletions({
    required DateTime start,
    required List<ChatMessage> messages,
  }) async {
    final key = settings.openAiApiKey.trim();
    if (key.isEmpty) {
      throw const LlmException('OpenAI API Key 为空，请先在 Settings 填写。');
    }

    final uri = Uri.parse('${settings.openAiBaseUrl}/v1/chat/completions');
    final body = {
      'model': settings.openAiModel,
      'stream': false,
      if (settings.openAiMaxTokens != null) 'max_tokens': settings.openAiMaxTokens,
      'messages': [
        for (final m in messages)
          {
            'role': switch (m.role) {
              ChatRole.system => 'system',
              ChatRole.user => 'user',
              ChatRole.assistant => 'assistant',
            },
            'content': m.content,
          },
      ],
    };

    final resp = await httpClient.post(
      uri,
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw LlmException('OpenAI HTTP ${resp.statusCode}: ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final choices = (json['choices'] as List).cast<Map<String, dynamic>>();
    final message = choices.first['message'] as Map<String, dynamic>;
    final text = (message['content'] as String?)?.trim() ?? '';

    final usage = json['usage'] as Map<String, dynamic>?;
    final promptTokens = usage?['prompt_tokens'] as int?;
    final completionTokens = usage?['completion_tokens'] as int?;

    return LlmResult(
      text: text,
      latencyMs: DateTime.now().difference(start).inMilliseconds,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    );
  }

  Future<LlmResult> _geminiGenerateContent({
    required DateTime start,
    required List<ChatMessage> messages,
  }) async {
    final key = settings.geminiApiKey.trim();
    if (key.isEmpty) {
      throw const LlmException('Gemini API Key 为空，请先在 Settings 填写。');
    }

    final system = _systemFromHistory(messages);
    final history = _nonSystemHistory(messages);

    // Gemini expects roles: user / model
    final contents = [
      for (final m in history)
        {
          'role': m.role == ChatRole.user ? 'user' : 'model',
          'parts': [
            {'text': m.content},
          ],
        },
    ];

    final uri = Uri.parse(
      '${settings.geminiBaseUrl}/v1beta/models/${settings.geminiModel}:generateContent',
    ).replace(queryParameters: {'key': key});

    final body = {
      if (system.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
      'contents': contents,
    };

    final resp = await httpClient.post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw LlmException('Gemini HTTP ${resp.statusCode}: ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final candidates = (json['candidates'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final content = candidates.isEmpty ? null : candidates.first['content'] as Map<String, dynamic>?;
    final parts = (content?['parts'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final text = parts.isEmpty ? '' : (parts.first['text'] as String?)?.trim() ?? '';

    final usage = json['usageMetadata'] as Map<String, dynamic>?;
    final promptTokens = usage?['promptTokenCount'] as int?;
    final completionTokens = usage?['candidatesTokenCount'] as int?;

    return LlmResult(
      text: text,
      latencyMs: DateTime.now().difference(start).inMilliseconds,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    );
  }

  Future<LlmResult> _claudeMessages({
    required DateTime start,
    required List<ChatMessage> messages,
  }) async {
    final key = settings.claudeApiKey.trim();
    if (key.isEmpty) {
      throw const LlmException('Claude API Key 为空，请先在 Settings 填写。');
    }

    final system = _systemFromHistory(messages);
    final history = _nonSystemHistory(messages);

    final uri = Uri.parse('${settings.claudeBaseUrl}/v1/messages');
    final body = {
      'model': settings.claudeModel,
      'max_tokens': settings.claudeMaxTokens,
      if (system.isNotEmpty) 'system': system,
      'messages': [
        for (final m in history)
          {
            'role': m.role == ChatRole.user ? 'user' : 'assistant',
            'content': [
              {
                'type': 'text',
                'text': m.content,
              }
            ],
          },
      ],
    };

    final resp = await httpClient.post(
      uri,
      headers: {
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
        // 允许浏览器直连（BYO-Key 风险由用户承担）
        'anthropic-dangerous-direct-browser-access': 'true',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw LlmException('Claude HTTP ${resp.statusCode}: ${resp.body}');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final content = (json['content'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final text = content.isEmpty ? '' : (content.first['text'] as String?)?.trim() ?? '';

    final usage = json['usage'] as Map<String, dynamic>?;
    final promptTokens = usage?['input_tokens'] as int?;
    final completionTokens = usage?['output_tokens'] as int?;

    return LlmResult(
      text: text,
      latencyMs: DateTime.now().difference(start).inMilliseconds,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    );
  }
}

