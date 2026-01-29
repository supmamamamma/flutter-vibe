import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_sessions_repository.dart';
import '../domain/chat_models.dart';
import '../../llm/application/providers.dart';
import '../../llm/domain/llm_exception.dart';
import '../../llm/domain/llm_stream_event.dart';
import '../../prompts/application/system_prompts_controller.dart';
import '../../settings/application/settings_controller.dart';
import 'chat_state.dart';

final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);

class ChatController extends Notifier<ChatState> {
  bool _hydrated = false;

  void setSessionSortMode(SessionSortMode mode) {
    state = state.copyWith(
      sessionSortMode: mode,
      sessions: _sortedSessions(state.sessions, mode),
    );

    final repo = ref.read(chatSessionsRepositoryProvider);
    unawaited(repo.setSortMode(mode));
  }

  @override
  ChatState build() {
    final repo = ref.read(chatSessionsRepositoryProvider);

    final session = ChatSession.empty();
    final initial = ChatState(
      sessions: [session],
      activeSessionId: session.id,
      sessionSortMode: SessionSortMode.updatedAtDesc,
      isGenerating: false,
      latencyMs: null,
      promptTokens: null,
      completionTokens: null,
    );

    if (!_hydrated) {
      _hydrated = true;
      unawaited(_hydrate(repo, fallback: initial));
    }

    return initial;
  }

  Future<void> _hydrate(
    ChatSessionsRepository repo, {
    required ChatState fallback,
  }) async {
    final snapshot = await repo.loadAll();
    final loadedSessions = snapshot.sessions;
    final sortMode = snapshot.sortMode ?? fallback.sessionSortMode;

    if (loadedSessions.isEmpty) {
      await repo.upsertSession(fallback.sessions.first);
      await repo.setActiveSessionId(fallback.activeSessionId);
      await repo.setSortMode(sortMode);
      return;
    }

    final sorted = _sortedSessions(loadedSessions, sortMode);
    final activeId = (snapshot.activeSessionId != null &&
            sorted.any((s) => s.id == snapshot.activeSessionId))
        ? snapshot.activeSessionId!
        : sorted.first.id;

    state = ChatState(
      sessions: sorted,
      activeSessionId: activeId,
      sessionSortMode: sortMode,
      isGenerating: false,
      latencyMs: null,
      promptTokens: null,
      completionTokens: null,
    );
  }

  void _persistMeta() {
    final repo = ref.read(chatSessionsRepositoryProvider);
    unawaited(repo.setActiveSessionId(state.activeSessionId));
    unawaited(repo.setSortMode(state.sessionSortMode));
  }

  void _persistSessionById(String sessionId) {
    final repo = ref.read(chatSessionsRepositoryProvider);
    final session = state.sessions.firstWhere((s) => s.id == sessionId);
    unawaited(repo.upsertSession(session));
  }

  void newSession() {
    final session = ChatSession.empty();
    state = state.copyWith(
      sessions:
          _sortedSessions([session, ...state.sessions], state.sessionSortMode),
      activeSessionId: session.id,
      isGenerating: false,
      latencyMs: null,
      promptTokens: null,
      completionTokens: null,
    );

    final repo = ref.read(chatSessionsRepositoryProvider);
    unawaited(repo.upsertSession(session));
    _persistMeta();
  }

  void setActiveSession(String id) {
    state = state.copyWith(activeSessionId: id);
    _persistMeta();
  }

  void renameSession({required String sessionId, required String title}) {
    final nextTitle = title.trim().isEmpty ? 'Untitled' : title.trim();
    final updated = state.sessions
        .map(
          (s) => s.id == sessionId
              ? s.copyWith(title: nextTitle, updatedAt: DateTime.now())
              : s,
        )
        .toList(growable: false);

    state = state.copyWith(
      sessions: _sortedSessions(updated, state.sessionSortMode),
    );

    _persistSessionById(sessionId);
    _persistMeta();
  }

  void deleteSession(String sessionId) {
    final remaining =
        state.sessions.where((s) => s.id != sessionId).toList(growable: false);

    if (remaining.isEmpty) {
      final session = ChatSession.empty();
      state = state.copyWith(
        sessions: [session],
        activeSessionId: session.id,
        sessionSortMode: state.sessionSortMode,
        isGenerating: false,
        latencyMs: null,
        promptTokens: null,
        completionTokens: null,
      );

      final repo = ref.read(chatSessionsRepositoryProvider);
      unawaited(repo.deleteSession(sessionId));
      unawaited(repo.upsertSession(session));
      _persistMeta();
      return;
    }

    final sorted = _sortedSessions(remaining, state.sessionSortMode);
    final nextActive = sorted.any((s) => s.id == state.activeSessionId)
        ? state.activeSessionId
        : sorted.first.id;

    state = state.copyWith(
      sessions: sorted,
      activeSessionId: nextActive,
      isGenerating: false,
    );

    final repo = ref.read(chatSessionsRepositoryProvider);
    unawaited(repo.deleteSession(sessionId));
    _persistMeta();
  }

  List<ChatSession> _sortedSessions(
    List<ChatSession> sessions,
    SessionSortMode mode,
  ) {
    final copy = List<ChatSession>.of(sessions);
    copy.sort((a, b) {
      return switch (mode) {
        SessionSortMode.updatedAtDesc => b.updatedAt.compareTo(a.updatedAt),
        SessionSortMode.createdAtDesc => b.createdAt.compareTo(a.createdAt),
        SessionSortMode.titleAsc =>
          a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      };
    });
    return copy;
  }

  Future<void> sendUserMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (state.isGenerating) return;

    final userMsg = ChatMessage.user(trimmed);
    final assistantMsg = ChatMessage.assistant('');
    final sessionId = state.activeSessionId;
    final assistantId = assistantMsg.id;

    state = state.copyWith(
      isGenerating: true,
      latencyMs: null,
      promptTokens: null,
      completionTokens: null,
      sessions: state.sessions
          .map((s) => s.id == sessionId
              ? s.copyWith(
                  updatedAt: DateTime.now(),
                  messages: [...s.messages, userMsg, assistantMsg],
                )
              : s)
          .toList(growable: false),
    );

    state = state.copyWith(
      sessions: _sortedSessions(state.sessions, state.sessionSortMode),
    );

    _persistSessionById(sessionId);
    _persistMeta();

    try {
      final llm = ref.read(llmServiceProvider);
      final settings = ref.read(settingsControllerProvider);
      final prompts = ref.read(systemPromptsControllerProvider);
      final history = state.sessions
          .firstWhere((s) => s.id == sessionId)
          .messages
          .where((m) => m.id != assistantId)
          .toList(growable: false);

      final systemText = prompts.activePrompt.content.trim();
      final requestMessages = <ChatMessage>[
        if (systemText.isNotEmpty) ChatMessage.system(systemText),
        ...history,
      ];

      if (settings.useStreaming) {
        await _consumeLlmStream(
          sessionId: sessionId,
          assistantId: assistantId,
          stream: llm.generateStream(messages: requestMessages),
        );
      } else {
        final result = await llm.generate(messages: requestMessages);
        state = state.copyWith(
          isGenerating: false,
          latencyMs: result.latencyMs,
          promptTokens: result.promptTokens,
          completionTokens: result.completionTokens,
          sessions: state.sessions.map((s) {
            if (s.id != sessionId) return s;
            final msgs = s.messages
                .map((m) => m.id == assistantId
                    ? m.copyWith(content: result.text)
                    : m)
                .toList(growable: false);
            return s.copyWith(messages: msgs, updatedAt: DateTime.now());
          }).toList(growable: false),
        );
      }

      _persistSessionById(sessionId);
      _persistMeta();
    } on LlmException catch (e) {
      _setAssistantError(
        sessionId: sessionId,
        assistantId: assistantId,
        message: e.message,
      );
    } catch (e) {
      _setAssistantError(
        sessionId: sessionId,
        assistantId: assistantId,
        message: e.toString(),
      );
    }
  }

  /// 以指定 assistant 消息为目标，基于其之前的对话历史重新生成该条回复。
  ///
  /// 当前实现策略：
  /// - 仅重写该 assistant 消息的 content（保留同一 messageId 与后续消息）。
  /// - 请求 history 取该 assistant 之前的所有消息，并额外注入 active system prompt。
  Future<void> retryAssistantMessage(String assistantMessageId) async {
    if (state.isGenerating) return;

    final sessionId = state.activeSessionId;
    final session = state.sessions.firstWhere((s) => s.id == sessionId);
    final idx = session.messages.indexWhere((m) => m.id == assistantMessageId);
    if (idx < 0) return;

    final target = session.messages[idx];
    if (target.role != ChatRole.assistant) return;

    // 复用与 sendUserMessage() 一致的“system prompt 注入 + history”策略：
    // history 只取该 assistant 之前的消息。
    final history = session.messages.take(idx).toList(growable: false);

    state = state.copyWith(
      isGenerating: true,
      latencyMs: null,
      promptTokens: null,
      completionTokens: null,
      sessions: state.sessions.map((s) {
        if (s.id != sessionId) return s;
        final msgs = s.messages
            .map((m) => m.id == assistantMessageId ? m.copyWith(content: '') : m)
            .toList(growable: false);
        return s.copyWith(messages: msgs, updatedAt: DateTime.now());
      }).toList(growable: false),
    );

    state = state.copyWith(
      sessions: _sortedSessions(state.sessions, state.sessionSortMode),
    );

    _persistSessionById(sessionId);
    _persistMeta();

    try {
      final llm = ref.read(llmServiceProvider);
      final settings = ref.read(settingsControllerProvider);
      final prompts = ref.read(systemPromptsControllerProvider);

      final systemText = prompts.activePrompt.content.trim();
      final requestMessages = <ChatMessage>[
        if (systemText.isNotEmpty) ChatMessage.system(systemText),
        ...history,
      ];

      if (settings.useStreaming) {
        await _consumeLlmStream(
          sessionId: sessionId,
          assistantId: assistantMessageId,
          stream: llm.generateStream(messages: requestMessages),
        );
      } else {
        final result = await llm.generate(messages: requestMessages);
        state = state.copyWith(
          isGenerating: false,
          latencyMs: result.latencyMs,
          promptTokens: result.promptTokens,
          completionTokens: result.completionTokens,
          sessions: state.sessions.map((s) {
            if (s.id != sessionId) return s;
            final msgs = s.messages
                .map((m) => m.id == assistantMessageId
                    ? m.copyWith(content: result.text)
                    : m)
                .toList(growable: false);
            return s.copyWith(messages: msgs, updatedAt: DateTime.now());
          }).toList(growable: false),
        );
      }

      _persistSessionById(sessionId);
      _persistMeta();
    } on LlmException catch (e) {
      _setAssistantError(
        sessionId: sessionId,
        assistantId: assistantMessageId,
        message: e.message,
      );
    } catch (e) {
      _setAssistantError(
        sessionId: sessionId,
        assistantId: assistantMessageId,
        message: e.toString(),
      );
    }
  }

  Future<void> _consumeLlmStream({
    required String sessionId,
    required String assistantId,
    required Stream<LlmStreamEvent> stream,
  }) async {
    try {
      await for (final event in stream) {
        if (event is LlmStreamText) {
          final delta = event.delta;
          if (delta.isEmpty) continue;

          state = state.copyWith(
            sessions: state.sessions.map((s) {
              if (s.id != sessionId) return s;
              final msgs = s.messages.map((m) {
                if (m.id != assistantId) return m;
                return m.copyWith(content: m.content + delta);
              }).toList(growable: false);
              return s.copyWith(messages: msgs);
            }).toList(growable: false),
          );
        } else if (event is LlmStreamDone) {
          state = state.copyWith(
            isGenerating: false,
            latencyMs: event.latencyMs,
            promptTokens: event.promptTokens,
            completionTokens: event.completionTokens,
            sessions: state.sessions.map((s) {
              if (s.id != sessionId) return s;
              return s.copyWith(updatedAt: DateTime.now());
            }).toList(growable: false),
          );
        }
      }

      // 如果 provider 没有显式发 done 事件，这里兜底结束 generating。
      if (state.isGenerating) {
        state = state.copyWith(isGenerating: false);
      }
    } finally {
      // streaming 过程中不做高频持久化，统一在流结束后落库。
      _persistSessionById(sessionId);
      _persistMeta();
    }
  }

  void _setAssistantError({
    required String sessionId,
    required String assistantId,
    required String message,
  }) {
    state = state.copyWith(
      isGenerating: false,
      sessions: state.sessions.map((s) {
        if (s.id != sessionId) return s;
        final msgs = s.messages
            .map((m) => m.id == assistantId
                ? m.copyWith(content: '**Error**: $message')
                : m)
            .toList(growable: false);
        return s.copyWith(messages: msgs, updatedAt: DateTime.now());
      }).toList(growable: false),
    );
  }
}

