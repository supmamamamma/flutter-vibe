import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../chat/domain/chat_models.dart';
import '../../settings/application/settings_state.dart';
import '../../settings/domain/llm_provider.dart';
import '../../../shared/http/streaming_post.dart';
import '../domain/llm_exception.dart';
import '../domain/llm_result.dart';
import '../domain/llm_stream_event.dart';

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

  /// 流式生成（真实 streaming）。
  ///
  /// - OpenAI / Claude：SSE（`text/event-stream`）。
  /// - Gemini：尝试使用 `:streamGenerateContent`（若后端不支持，会抛错）。
  Stream<LlmStreamEvent> generateStream({required List<ChatMessage> messages}) {
    final start = DateTime.now();
    return switch (settings.activeProvider) {
      LlmProvider.openai => _openAiChatCompletionsStream(start: start, messages: messages),
      LlmProvider.gemini => _geminiStreamGenerateContent(start: start, messages: messages),
      LlmProvider.claude => _claudeMessagesStream(start: start, messages: messages),
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

  Map<String, Object?> _openAiMessage(ChatMessage m) {
    final role = switch (m.role) {
      ChatRole.system => 'system',
      ChatRole.user => 'user',
      ChatRole.assistant => 'assistant',
    };

    // 仅 user 消息允许携带附件（MVP）。其它角色保持纯文本。
    if (m.role != ChatRole.user || m.attachments.isEmpty) {
      return {
        'role': role,
        'content': m.content,
      };
    }

    final parts = <Map<String, Object?>>[];
    if (m.content.trim().isNotEmpty) {
      parts.add({'type': 'text', 'text': m.content});
    }

    for (final a in m.attachments) {
      if (a.isText) {
        parts.add({
          'type': 'text',
          'text': '【文件：${a.name}】\n${a.data}',
        });
      } else if (a.isImage) {
        parts.add({
          'type': 'image_url',
          'image_url': {
            'url': 'data:${a.mimeType};base64,${a.data}',
          },
        });
      }
    }

    if (parts.isEmpty) {
      parts.add({'type': 'text', 'text': ''});
    }

    return {
      'role': role,
      'content': parts,
    };
  }

  Map<String, Object?> _geminiContent(ChatMessage m) {
    final role = m.role == ChatRole.user ? 'user' : 'model';
    final parts = <Map<String, Object?>>[];

    if (m.content.trim().isNotEmpty) {
      parts.add({'text': m.content});
    }
    for (final a in m.attachments) {
      if (a.isText) {
        parts.add({'text': '【文件：${a.name}】\n${a.data}'});
      } else if (a.isImage) {
        parts.add({
          'inlineData': {
            'mimeType': a.mimeType,
            'data': a.data,
          },
        });
      }
    }
    if (parts.isEmpty) {
      parts.add({'text': ''});
    }

    return {
      'role': role,
      'parts': parts,
    };
  }

  Map<String, Object?> _claudeMessage(ChatMessage m) {
    final role = m.role == ChatRole.user ? 'user' : 'assistant';
    final content = <Map<String, Object?>>[];

    if (m.content.trim().isNotEmpty) {
      content.add({'type': 'text', 'text': m.content});
    }

    for (final a in m.attachments) {
      if (a.isText) {
        content.add({
          'type': 'text',
          'text': '【文件：${a.name}】\n${a.data}',
        });
      } else if (a.isImage) {
        content.add({
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': a.mimeType,
            'data': a.data,
          },
        });
      }
    }

    if (content.isEmpty) {
      content.add({'type': 'text', 'text': ''});
    }

    return {
      'role': role,
      'content': content,
    };
  }

  Stream<String> _linesFromChunks(Stream<String> chunks) async* {
    var buffer = '';
    await for (final chunk in chunks) {
      buffer += chunk;
      while (true) {
        final idx = buffer.indexOf('\n');
        if (idx < 0) break;
        final line = buffer.substring(0, idx).replaceAll('\r', '');
        buffer = buffer.substring(idx + 1);
        yield line;
      }
    }
    if (buffer.isNotEmpty) {
      yield buffer.replaceAll('\r', '');
    }
  }

  Stream<({String? event, String data})> _sseEvents(Stream<String> lines) async* {
    String? event;
    final dataLines = <String>[];

    await for (final raw in lines) {
      final line = raw;
      if (line.isEmpty) {
        if (dataLines.isNotEmpty) {
          yield (event: event, data: dataLines.join('\n'));
          event = null;
          dataLines.clear();
        }
        continue;
      }

      if (line.startsWith('event:')) {
        event = line.substring('event:'.length).trim();
        continue;
      }
      if (line.startsWith('data:')) {
        dataLines.add(line.substring('data:'.length).trimLeft());
        continue;
      }

      // comment/unknown fields, ignore.
    }

    if (dataLines.isNotEmpty) {
      yield (event: event, data: dataLines.join('\n'));
    }
  }

  Future<LlmResult> _openAiChatCompletions({
    required DateTime start,
    required List<ChatMessage> messages,
  }) async {
    final p = settings.activeProfile;
    final key = p.apiKey.trim();
    if (key.isEmpty) {
      throw const LlmException('OpenAI API Key 为空，请先在 Settings 填写。');
    }

    final uri = Uri.parse('${p.baseUrl}/v1/chat/completions');
    final body = {
      'model': p.model,
      'stream': false,
      if (p.openAiMaxTokens != null) 'max_tokens': p.openAiMaxTokens,
      'messages': [
        for (final m in messages) _openAiMessage(m),
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

  Stream<LlmStreamEvent> _openAiChatCompletionsStream({
    required DateTime start,
    required List<ChatMessage> messages,
  }) async* {
    final p = settings.activeProfile;
    final key = p.apiKey.trim();
    if (key.isEmpty) {
      throw const LlmException('OpenAI API Key 为空，请先在 Settings 填写。');
    }

    final uri = Uri.parse('${p.baseUrl}/v1/chat/completions');
    final body = {
      'model': p.model,
      'stream': true,
      // OpenAI 兼容接口：请求在流的最后一个 chunk 中包含 usage。
      'stream_options': {
        'include_usage': true,
      },
      if (p.openAiMaxTokens != null) 'max_tokens': p.openAiMaxTokens,
      'messages': [
        for (final m in messages) _openAiMessage(m),
      ],
    };

    final chunks = postTextStream(
      client: httpClient,
      uri: uri,
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      },
      body: jsonEncode(body),
    );

    int? promptTokens;
    int? completionTokens;
    var done = false;
    await for (final ev in _sseEvents(_linesFromChunks(chunks))) {
      final data = ev.data.trim();
      if (data.isEmpty) continue;
      if (data == '[DONE]') {
        done = true;
        break;
      }

      final obj = jsonDecode(data);
      if (obj is! Map<String, dynamic>) continue;

       final usage = obj['usage'];
       if (usage is Map<String, dynamic>) {
         promptTokens ??= usage['prompt_tokens'] as int?;
         completionTokens ??= usage['completion_tokens'] as int?;
       }

      final choices = (obj['choices'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      if (choices.isEmpty) continue;
      final delta = choices.first['delta'];
      if (delta is Map<String, dynamic>) {
        final content = delta['content'];
        if (content is String && content.isNotEmpty) {
          yield LlmStreamText(content);
        }
      }
    }

    if (!done) {
      // 即使没有显式 [DONE]，也在流结束时收尾。
    }

    yield LlmStreamDone(
      latencyMs: DateTime.now().difference(start).inMilliseconds,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    );
  }

  Future<LlmResult> _geminiGenerateContent({
    required DateTime start,
    required List<ChatMessage> messages,
  }) async {
    final p = settings.activeProfile;
    final key = p.apiKey.trim();
    if (key.isEmpty) {
      throw const LlmException('Gemini API Key 为空，请先在 Settings 填写。');
    }

    final system = _systemFromHistory(messages);
    final history = _nonSystemHistory(messages);

    // Gemini expects roles: user / model
    final contents = [for (final m in history) _geminiContent(m)];

    final uri = Uri.parse(
      '${p.baseUrl}/v1beta/models/${p.model}:generateContent',
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

  Stream<LlmStreamEvent> _geminiStreamGenerateContent({
    required DateTime start,
    required List<ChatMessage> messages,
  }) async* {
    final p = settings.activeProfile;
    final key = p.apiKey.trim();
    if (key.isEmpty) {
      throw const LlmException('Gemini API Key 为空，请先在 Settings 填写。');
    }

    final system = _systemFromHistory(messages);
    final history = _nonSystemHistory(messages);

    final contents = [for (final m in history) _geminiContent(m)];

    // Gemini REST Streaming: :streamGenerateContent
    //
    // 关键点：默认返回可能是 JSON 数组/多行格式（Web 端按行解析会拿不到 chunk）。
    // 这里显式请求 SSE（alt=sse），可稳定获得 `data: {json}` 的逐条事件。
    final uri = Uri.parse(
      '${p.baseUrl}/v1beta/models/${p.model}:streamGenerateContent',
    ).replace(queryParameters: {
      'key': key,
      'alt': 'sse',
    });

    final body = {
      if (system.isNotEmpty)
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
      'contents': contents,
    };

    final chunks = postTextStream(
      client: httpClient,
      uri: uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      },
      body: jsonEncode(body),
    );

    var acc = '';
    int? promptTokens;
    int? completionTokens;

    await for (final line in _linesFromChunks(chunks)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // 兼容 SSE 形态：data: {json}
      final payload = trimmed.startsWith('data:')
          ? trimmed.substring('data:'.length).trimLeft()
          : trimmed;

      // 部分实现可能在开头带 XSSI 前缀。
      final jsonText = payload.startsWith(")]}'")
          ? payload.substring(")]}'".length)
          : payload;

      dynamic obj;
      try {
        obj = jsonDecode(jsonText);
      } catch (_) {
        continue;
      }

      // Gemini streaming 在某些形态下可能返回 JSON 数组（一次性 batch），这里做兼容。
      final items = switch (obj) {
        Map<String, dynamic>() => <Map<String, dynamic>>[obj],
        List() => obj
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList(growable: false),
        _ => const <Map<String, dynamic>>[],
      };

      for (final item in items) {
        final candidates =
            (item['candidates'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
        final content =
            candidates.isEmpty ? null : candidates.first['content'] as Map<String, dynamic>?;
        final parts = (content?['parts'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

        // parts 可能包含多个 text 段，拼接起来。
        final chunkText = parts
            .map((p) => p['text'])
            .whereType<String>()
            .join();

        if (chunkText.isNotEmpty) {
          // 有的实现返回“累积文本”，有的返回“增量文本”。这里用前缀差分做兼容。
          final next = chunkText;
          final delta = next.startsWith(acc) ? next.substring(acc.length) : next;
          acc = next;
          if (delta.isNotEmpty) {
            yield LlmStreamText(delta);
          }
        }

        final usage = item['usageMetadata'] as Map<String, dynamic>?;
        promptTokens ??= usage?['promptTokenCount'] as int?;
        completionTokens ??= usage?['candidatesTokenCount'] as int?;
      }
    }

    yield LlmStreamDone(
      latencyMs: DateTime.now().difference(start).inMilliseconds,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    );
  }

  Future<LlmResult> _claudeMessages({
    required DateTime start,
    required List<ChatMessage> messages,
  }) async {
    final p = settings.activeProfile;
    final key = p.apiKey.trim();
    if (key.isEmpty) {
      throw const LlmException('Claude API Key 为空，请先在 Settings 填写。');
    }

    final system = _systemFromHistory(messages);
    final history = _nonSystemHistory(messages);

    final uri = Uri.parse('${p.baseUrl}/v1/messages');
    final body = {
      'model': p.model,
      'max_tokens': p.claudeMaxTokens,
      if (system.isNotEmpty) 'system': system,
      'messages': [for (final m in history) _claudeMessage(m)],
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

  Stream<LlmStreamEvent> _claudeMessagesStream({
    required DateTime start,
    required List<ChatMessage> messages,
  }) async* {
    final p = settings.activeProfile;
    final key = p.apiKey.trim();
    if (key.isEmpty) {
      throw const LlmException('Claude API Key 为空，请先在 Settings 填写。');
    }

    final system = _systemFromHistory(messages);
    final history = _nonSystemHistory(messages);

    final uri = Uri.parse('${p.baseUrl}/v1/messages');
    final body = {
      'model': p.model,
      'max_tokens': p.claudeMaxTokens,
      'stream': true,
      if (system.isNotEmpty) 'system': system,
      'messages': [for (final m in history) _claudeMessage(m)],
    };

    final chunks = postTextStream(
      client: httpClient,
      uri: uri,
      headers: {
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
        'anthropic-dangerous-direct-browser-access': 'true',
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      },
      body: jsonEncode(body),
    );

    int? promptTokens;
    int? completionTokens;

    await for (final ev in _sseEvents(_linesFromChunks(chunks))) {
      final data = ev.data.trim();
      if (data.isEmpty) continue;

      dynamic obj;
      try {
        obj = jsonDecode(data);
      } catch (_) {
        continue;
      }
      if (obj is! Map<String, dynamic>) continue;

      final type = obj['type'];
      if (type == 'content_block_delta') {
        final delta = obj['delta'];
        if (delta is Map<String, dynamic>) {
          final text = delta['text'];
          if (text is String && text.isNotEmpty) {
            yield LlmStreamText(text);
          }
        }
      } else if (type == 'message_delta') {
        final usage = obj['usage'];
        if (usage is Map<String, dynamic>) {
          promptTokens ??= usage['input_tokens'] as int?;
          completionTokens ??= usage['output_tokens'] as int?;
        }
      } else if (type == 'message_stop') {
        break;
      }
    }

    yield LlmStreamDone(
      latencyMs: DateTime.now().difference(start).inMilliseconds,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
    );
  }
}

