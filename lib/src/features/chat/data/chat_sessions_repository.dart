import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/persistence/app_database.dart';
import '../application/chat_state.dart';
import '../domain/chat_models.dart';

final chatSessionsRepositoryProvider = Provider<ChatSessionsRepository>((ref) {
  return ChatSessionsRepository(db: ref.watch(appDatabaseProvider));
});

class ChatSessionsRepository {
  ChatSessionsRepository({required Future<Database> db}) : _db = db;

  final Future<Database> _db;

  static final _store = stringMapStoreFactory.store('chat_sessions');
  static final _meta = StoreRef<String, Object?>('meta');

  static const _activeSessionIdKey = 'activeChatSessionId';
  static const _sortModeKey = 'chatSessionSortMode';

  Future<({
    List<ChatSession> sessions,
    String? activeSessionId,
    SessionSortMode? sortMode,
  })> loadAll() async {
    final db = await _db;
    final records = await _store.find(db);
    final sessions = records
        .map((r) => _sessionFromJson(r.value))
        .toList(growable: false);

    final activeSessionId =
        await _meta.record(_activeSessionIdKey).get(db) as String?;
    final sortModeName = await _meta.record(_sortModeKey).get(db) as String?;
    final sortMode = SessionSortMode.values
        .where((m) => m.name == sortModeName)
        .cast<SessionSortMode?>()
        .firstWhere((m) => m != null, orElse: () => null);

    return (
      sessions: sessions,
      activeSessionId: activeSessionId,
      sortMode: sortMode,
    );
  }

  Future<void> upsertSession(ChatSession session) async {
    final db = await _db;
    await _store.record(session.id).put(db, _sessionToJson(session));
  }

  Future<void> deleteSession(String id) async {
    final db = await _db;
    await _store.record(id).delete(db);
  }

  Future<void> setActiveSessionId(String? id) async {
    final db = await _db;
    await _meta.record(_activeSessionIdKey).put(db, id);
  }

  Future<void> setSortMode(SessionSortMode mode) async {
    final db = await _db;
    await _meta.record(_sortModeKey).put(db, mode.name);
  }

  Map<String, Object?> _sessionToJson(ChatSession s) {
    return {
      'id': s.id,
      'title': s.title,
      'createdAt': s.createdAt.millisecondsSinceEpoch,
      'updatedAt': s.updatedAt.millisecondsSinceEpoch,
      'messages': [
        for (final m in s.messages) _messageToJson(m),
      ],
    };
  }

  ChatSession _sessionFromJson(Map<String, Object?> json) {
    final messagesRaw = json['messages'] as List?;
    final messages = messagesRaw
            ?.whereType<Map>()
            .map((m) => _messageFromJson(m.cast<String, Object?>()))
            .toList(growable: false) ??
        const <ChatMessage>[];

    return ChatSession(
      id: json['id']! as String,
      title: (json['title'] as String?) ?? 'New chat',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['updatedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      messages: messages,
    );
  }

  Map<String, Object?> _messageToJson(ChatMessage m) {
    return {
      'id': m.id,
      'role': m.role.name,
      'content': m.content,
      'attachments': [
        for (final a in m.attachments)
          {
            'id': a.id,
            'kind': a.kind.name,
            'name': a.name,
            'mimeType': a.mimeType,
            'data': a.data,
            'sizeBytes': a.sizeBytes,
            'createdAt': a.createdAt.millisecondsSinceEpoch,
          },
      ],
      'createdAt': m.createdAt.millisecondsSinceEpoch,
    };
  }

  ChatMessage _messageFromJson(Map<String, Object?> json) {
    final roleName = json['role'] as String?;
    final role = ChatRole.values
        .where((r) => r.name == roleName)
        .cast<ChatRole?>()
        .firstWhere((r) => r != null, orElse: () => null);

    final attachmentsRaw = json['attachments'] as List?;
    final attachments = attachmentsRaw
            ?.whereType<Map>()
            .map((a) {
              final m = a.cast<String, Object?>();
              final kindName = m['kind'] as String?;
              final kind = ChatAttachmentKind.values
                  .where((k) => k.name == kindName)
                  .cast<ChatAttachmentKind?>()
                  .firstWhere((k) => k != null, orElse: () => null);
              final id = (m['id'] as String?) ?? '';
              if (id.isEmpty) {
                // 老数据兼容：如果缺 id，直接生成一个。
                // 这样可以避免丢弃附件。
                // ignore: prefer_const_constructors
              }
              return ChatAttachment(
                id: id.isEmpty ? const Uuid().v4() : id,
                kind: kind ?? ChatAttachmentKind.text,
                name: (m['name'] as String?) ?? 'file',
                mimeType: (m['mimeType'] as String?) ?? 'application/octet-stream',
                data: (m['data'] as String?) ?? '',
                sizeBytes: (m['sizeBytes'] as int?) ?? 0,
                createdAt: DateTime.fromMillisecondsSinceEpoch(
                  (m['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
                ),
              );
            })
            .toList(growable: false) ??
        const <ChatAttachment>[];

    return ChatMessage(
      id: json['id']! as String,
      role: role ?? ChatRole.user,
      content: (json['content'] as String?) ?? '',
      attachments: attachments,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (json['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

