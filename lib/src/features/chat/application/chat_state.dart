import '../domain/chat_models.dart';

enum SessionSortMode {
  updatedAtDesc,
  createdAtDesc,
  titleAsc;

  String get label {
    return switch (this) {
      SessionSortMode.updatedAtDesc => '最近活动',
      SessionSortMode.createdAtDesc => '创建时间',
      SessionSortMode.titleAsc => '标题',
    };
  }
}

class ChatState {
  const ChatState({
    required this.sessions,
    required this.activeSessionId,
    required this.sessionSortMode,
    required this.isGenerating,
    required this.latencyMs,
    required this.promptTokens,
    required this.completionTokens,
  });

  final List<ChatSession> sessions;
  final String activeSessionId;
  final SessionSortMode sessionSortMode;
  final bool isGenerating;
  final int? latencyMs;
  final int? promptTokens;
  final int? completionTokens;

  ChatSession get activeSession =>
      sessions.firstWhere((s) => s.id == activeSessionId);

  ChatState copyWith({
    List<ChatSession>? sessions,
    String? activeSessionId,
    SessionSortMode? sessionSortMode,
    bool? isGenerating,
    int? latencyMs,
    int? promptTokens,
    int? completionTokens,
  }) {
    return ChatState(
      sessions: sessions ?? this.sessions,
      activeSessionId: activeSessionId ?? this.activeSessionId,
      sessionSortMode: sessionSortMode ?? this.sessionSortMode,
      isGenerating: isGenerating ?? this.isGenerating,
      latencyMs: latencyMs ?? this.latencyMs,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
    );
  }
}

