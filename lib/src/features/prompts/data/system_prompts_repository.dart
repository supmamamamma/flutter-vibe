import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';

import '../../../shared/persistence/app_database.dart';
import '../domain/system_prompt.dart';

final systemPromptsRepositoryProvider = Provider<SystemPromptsRepository>((ref) {
  return SystemPromptsRepository(db: ref.watch(appDatabaseProvider));
});

class SystemPromptsRepository {
  SystemPromptsRepository({required Future<Database> db}) : _db = db;

  final Future<Database> _db;

  static final _store = stringMapStoreFactory.store('system_prompts');
  static final _meta = StoreRef<String, Object?>('meta');

  static const _activePromptIdKey = 'activeSystemPromptId';

  Future<(List<SystemPrompt> prompts, String? activeId)> loadAll() async {
    final db = await _db;
    final records = await _store.find(db);

    final prompts = records
        .map((r) => _fromJson(r.value))
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final activeId = await _meta.record(_activePromptIdKey).get(db) as String?;
    return (prompts, activeId);
  }

  Future<void> upsert(SystemPrompt prompt) async {
    final db = await _db;
    await _store.record(prompt.id).put(db, _toJson(prompt));
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await _store.record(id).delete(db);
  }

  Future<void> setActiveId(String? id) async {
    final db = await _db;
    await _meta.record(_activePromptIdKey).put(db, id);
  }

  Map<String, Object?> _toJson(SystemPrompt p) {
    return {
      'id': p.id,
      'title': p.title,
      'content': p.content,
      'createdAt': p.createdAt.millisecondsSinceEpoch,
      'updatedAt': p.updatedAt.millisecondsSinceEpoch,
    };
  }

  SystemPrompt _fromJson(Map<String, Object?> json) {
    return SystemPrompt(
      id: json['id']! as String,
      title: (json['title'] as String?) ?? 'Untitled',
      content: (json['content'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updatedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

