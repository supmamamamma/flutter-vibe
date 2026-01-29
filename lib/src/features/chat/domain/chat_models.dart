import 'package:uuid/uuid.dart';

enum ChatRole { system, user, assistant }

enum ChatAttachmentKind { image, text }

/// 用户消息的附件（MVP：图片、txt）。
///
/// - 图片：存 base64（不含 data: 前缀），并带 mimeType。
/// - 文本：存原始文本内容（UTF-8 解码后的字符串）。
class ChatAttachment {
  ChatAttachment({
    required this.id,
    required this.kind,
    required this.name,
    required this.mimeType,
    required this.data,
    required this.sizeBytes,
    required this.createdAt,
  });

  factory ChatAttachment.image({
    required String name,
    required String mimeType,
    required String base64,
    required int sizeBytes,
  }) {
    return ChatAttachment(
      id: const Uuid().v4(),
      kind: ChatAttachmentKind.image,
      name: name,
      mimeType: mimeType,
      data: base64,
      sizeBytes: sizeBytes,
      createdAt: DateTime.now(),
    );
  }

  factory ChatAttachment.text({
    required String name,
    required String text,
    required int sizeBytes,
  }) {
    return ChatAttachment(
      id: const Uuid().v4(),
      kind: ChatAttachmentKind.text,
      name: name,
      mimeType: 'text/plain',
      data: text,
      sizeBytes: sizeBytes,
      createdAt: DateTime.now(),
    );
  }

  final String id;
  final ChatAttachmentKind kind;
  final String name;
  final String mimeType;
  /// image: base64；text: 原始字符串。
  final String data;
  final int sizeBytes;
  final DateTime createdAt;

  bool get isImage => kind == ChatAttachmentKind.image;
  bool get isText => kind == ChatAttachmentKind.text;
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.attachments,
    required this.createdAt,
  });

  factory ChatMessage.user(
    String content, {
    List<ChatAttachment> attachments = const [],
  }) {
    return ChatMessage(
      id: const Uuid().v4(),
      role: ChatRole.user,
      content: content,
      attachments: attachments,
      createdAt: DateTime.now(),
    );
  }

  factory ChatMessage.system(String content) {
    return ChatMessage(
      id: const Uuid().v4(),
      role: ChatRole.system,
      content: content,
      attachments: const [],
      createdAt: DateTime.now(),
    );
  }

  factory ChatMessage.assistant(String content) {
    return ChatMessage(
      id: const Uuid().v4(),
      role: ChatRole.assistant,
      content: content,
      attachments: const [],
      createdAt: DateTime.now(),
    );
  }

  final String id;
  final ChatRole role;
  final String content;
  final List<ChatAttachment> attachments;
  final DateTime createdAt;

  ChatMessage copyWith({
    String? content,
    List<ChatAttachment>? attachments,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt,
    );
  }
}

class ChatSession {
  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  factory ChatSession.empty() {
    final now = DateTime.now();
    return ChatSession(
      id: const Uuid().v4(),
      title: 'New chat',
      createdAt: now,
      updatedAt: now,
      messages: const [],
    );
  }

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  ChatSession copyWith({
    String? title,
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  }) {
    return ChatSession(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }
}

