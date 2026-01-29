import 'package:uuid/uuid.dart';

enum ChatRole { system, user, assistant }

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.user(String content) {
    return ChatMessage(
      id: const Uuid().v4(),
      role: ChatRole.user,
      content: content,
      createdAt: DateTime.now(),
    );
  }

  factory ChatMessage.system(String content) {
    return ChatMessage(
      id: const Uuid().v4(),
      role: ChatRole.system,
      content: content,
      createdAt: DateTime.now(),
    );
  }

  factory ChatMessage.assistant(String content) {
    return ChatMessage(
      id: const Uuid().v4(),
      role: ChatRole.assistant,
      content: content,
      createdAt: DateTime.now(),
    );
  }

  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;

  ChatMessage copyWith({
    String? content,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
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

