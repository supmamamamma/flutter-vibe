import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import '../../../shared/persistence/app_database.dart';
import '../application/settings_state.dart';
import '../domain/llm_profile.dart';
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
      'activeProfileId': s.activeProfileId,
      'useStreaming': s.useStreaming,
      'profiles': [
        for (final p in s.profiles)
          {
            'id': p.id,
            'name': p.name,
            'provider': p.provider.name,
            'baseUrl': p.baseUrl,
            'apiKey': p.apiKey,
            'model': p.model,
            'claudeMaxTokens': p.claudeMaxTokens,
            'openAiMaxTokens': p.openAiMaxTokens,
          },
      ],
      'schemaVersion': 2,
    };
  }

  SettingsState _fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion'] as int?;

    // v1 -> v2 迁移：将原 activeProvider + 各家配置折叠为一个 profile。
    if (schemaVersion == null || schemaVersion <= 1) {
      final providerName = json['activeProvider'] as String?;
      final provider = LlmProvider.values
          .where((p) => p.name == providerName)
          .cast<LlmProvider?>()
          .firstWhere((p) => p != null, orElse: () => null);

      final activeProvider = provider ?? LlmProvider.openai;
      final useStreaming = (json['useStreaming'] as bool?) ?? false;

      final profile = switch (activeProvider) {
        LlmProvider.openai => LlmProfile.create(
            name: 'OpenAI 默认',
            provider: LlmProvider.openai,
            baseUrl: (json['openAiBaseUrl'] as String?) ?? 'https://api.openai.com',
            model: (json['openAiModel'] as String?) ?? 'gpt-4o-mini',
          ).copyWith(
            apiKey: (json['openAiApiKey'] as String?) ?? '',
            openAiMaxTokens: json['openAiMaxTokens'] as int?,
          ),
        LlmProvider.gemini => LlmProfile.create(
            name: 'Gemini 默认',
            provider: LlmProvider.gemini,
            baseUrl: (json['geminiBaseUrl'] as String?) ??
                'https://generativelanguage.googleapis.com',
            model: (json['geminiModel'] as String?) ?? 'gemini-1.5-flash',
          ).copyWith(
            apiKey: (json['geminiApiKey'] as String?) ?? '',
          ),
        LlmProvider.claude => LlmProfile.create(
            name: 'Claude 默认',
            provider: LlmProvider.claude,
            baseUrl:
                (json['claudeBaseUrl'] as String?) ?? 'https://api.anthropic.com',
            model: (json['claudeModel'] as String?) ?? 'claude-3-5-sonnet-latest',
          ).copyWith(
            apiKey: (json['claudeApiKey'] as String?) ?? '',
            claudeMaxTokens: (json['claudeMaxTokens'] as int?) ?? 1024,
          ),
      };

      return SettingsState(
        profiles: [profile],
        activeProfileId: profile.id,
        useStreaming: useStreaming,
      );
    }

    final profilesRaw = json['profiles'] as List?;
    final profiles = profilesRaw
            ?.whereType<Map>()
            .map((m) {
              final p = m.cast<String, Object?>();
              final providerName = p['provider'] as String?;
              final provider = LlmProvider.values
                  .where((x) => x.name == providerName)
                  .cast<LlmProvider?>()
                  .firstWhere((x) => x != null, orElse: () => null);
              return LlmProfile(
                id: (p['id'] as String?) ?? '',
                name: (p['name'] as String?) ?? '未命名',
                provider: provider ?? LlmProvider.openai,
                baseUrl: (p['baseUrl'] as String?) ?? 'https://api.openai.com',
                apiKey: (p['apiKey'] as String?) ?? '',
                model: (p['model'] as String?) ?? 'gpt-4o-mini',
                claudeMaxTokens: (p['claudeMaxTokens'] as int?) ?? 1024,
                openAiMaxTokens: p['openAiMaxTokens'] as int?,
              );
            })
            .where((p) => p.id.isNotEmpty)
            .toList(growable: false) ??
        const <LlmProfile>[];

    final activeProfileId = (json['activeProfileId'] as String?) ?? '';
    final safeProfiles = profiles.isNotEmpty
        ? profiles
        : [
            LlmProfile.create(
              name: 'OpenAI 默认',
              provider: LlmProvider.openai,
              baseUrl: 'https://api.openai.com',
              model: 'gpt-4o-mini',
            ),
          ];
    final resolvedActiveId = safeProfiles.any((p) => p.id == activeProfileId)
        ? activeProfileId
        : safeProfiles.first.id;

    return SettingsState(
      profiles: safeProfiles,
      activeProfileId: resolvedActiveId,
      useStreaming: (json['useStreaming'] as bool?) ?? false,
    );
  }
}

