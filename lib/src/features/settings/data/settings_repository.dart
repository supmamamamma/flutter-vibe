import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import '../../../shared/persistence/app_database.dart';
import '../application/settings_state.dart';
import '../domain/llm_provider.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(db: ref.watch(appDatabaseProvider));
});

class SettingsRepository {
  SettingsRepository({required Future<Database> db}) : _db = db;

  final Future<Database> _db;

  static final _store = StoreRef<String, Object?>('app_settings');
  static const _key = 'settings';

  Future<SettingsState?> load() async {
    final db = await _db;
    final raw = await _store.record(_key).get(db);
    if (raw is! Map) return null;
    return _fromJson(raw.cast<String, Object?>());
  }

  Future<void> save(SettingsState state) async {
    final db = await _db;
    await _store.record(_key).put(db, _toJson(state));
  }

  Map<String, Object?> _toJson(SettingsState s) {
    return {
      'activeProvider': s.activeProvider.name,
      'useStreaming': s.useStreaming,
      'openAiApiKey': s.openAiApiKey,
      'geminiApiKey': s.geminiApiKey,
      'claudeApiKey': s.claudeApiKey,
      'openAiBaseUrl': s.openAiBaseUrl,
      'geminiBaseUrl': s.geminiBaseUrl,
      'claudeBaseUrl': s.claudeBaseUrl,
      'openAiModel': s.openAiModel,
      'geminiModel': s.geminiModel,
      'claudeModel': s.claudeModel,
      'claudeMaxTokens': s.claudeMaxTokens,
      'openAiMaxTokens': s.openAiMaxTokens,
      'schemaVersion': 1,
    };
  }

  SettingsState _fromJson(Map<String, Object?> json) {
    final providerName = json['activeProvider'] as String?;
    final activeProvider = LlmProvider.values
        .where((p) => p.name == providerName)
        .cast<LlmProvider?>()
        .firstWhere((p) => p != null, orElse: () => null);

    return SettingsState(
      activeProvider: activeProvider ?? LlmProvider.openai,
      useStreaming: (json['useStreaming'] as bool?) ?? false,
      openAiApiKey: (json['openAiApiKey'] as String?) ?? '',
      geminiApiKey: (json['geminiApiKey'] as String?) ?? '',
      claudeApiKey: (json['claudeApiKey'] as String?) ?? '',
      openAiBaseUrl: (json['openAiBaseUrl'] as String?) ?? 'https://api.openai.com',
      geminiBaseUrl: (json['geminiBaseUrl'] as String?) ??
          'https://generativelanguage.googleapis.com',
      claudeBaseUrl: (json['claudeBaseUrl'] as String?) ?? 'https://api.anthropic.com',
      openAiModel: (json['openAiModel'] as String?) ?? 'gpt-4o-mini',
      geminiModel: (json['geminiModel'] as String?) ?? 'gemini-1.5-flash',
      claudeModel: (json['claudeModel'] as String?) ?? 'claude-3-5-sonnet-latest',
      claudeMaxTokens: (json['claudeMaxTokens'] as int?) ?? 1024,
      openAiMaxTokens: json['openAiMaxTokens'] as int?,
    );
  }
}

