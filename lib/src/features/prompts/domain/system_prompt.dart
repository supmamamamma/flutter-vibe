import 'package:uuid/uuid.dart';

class SystemPrompt {
  const SystemPrompt({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SystemPrompt.create({
    required String title,
    required String content,
  }) {
    final now = DateTime.now();
    return SystemPrompt(
      id: const Uuid().v4(),
      title: title.trim().isEmpty ? 'Untitled' : title.trim(),
      content: content,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  SystemPrompt copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
  }) {
    return SystemPrompt(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

