import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/chat_controller.dart';
import '../application/chat_state.dart';
import '../domain/chat_models.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _composer = TextEditingController();
  final _composerFocus = FocusNode();

  @override
  void dispose() {
    _composer.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);

    final isWide = MediaQuery.sizeOf(context).width >= 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chat'),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: controller.newSession,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            tooltip: 'System prompts',
            onPressed: () => context.go('/prompts'),
            icon: const Icon(Icons.text_snippet_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Row(
        children: [
          if (isWide)
            SizedBox(
              width: 280,
              child: _SessionList(
                sessions: chat.sessions,
                activeId: chat.activeSessionId,
                sortMode: chat.sessionSortMode,
                onSelect: controller.setActiveSession,
                onChangeSortMode: controller.setSessionSortMode,
                onRename: (s) => _renameSession(context, s),
                onDelete: (s) => _deleteSession(context, s),
              ),
            )
          else
            const SizedBox.shrink(),
          Expanded(
            child: _ChatPanel(
              session: chat.activeSession,
              isGenerating: chat.isGenerating,
              latencyMs: chat.latencyMs,
              promptTokens: chat.promptTokens,
              completionTokens: chat.completionTokens,
              composer: _composer,
              composerFocus: _composerFocus,
              onSend: () async {
                final text = _composer.text;
                _composer.clear();
                _composerFocus.requestFocus();
                await controller.sendUserMessage(text);
              },
              onRetryAssistantMessage: controller.retryAssistantMessage,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _renameSession(BuildContext context, ChatSession session) async {
    final titleController = TextEditingController(text: session.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重命名会话'),
          content: TextField(
            controller: titleController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '标题',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(titleController.text),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (newTitle == null) return;
    ref
        .read(chatControllerProvider.notifier)
        .renameSession(sessionId: session.id, title: newTitle);
  }

  Future<void> _deleteSession(BuildContext context, ChatSession session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除会话'),
          content: Text('确定删除“${session.title}”？此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    ref.read(chatControllerProvider.notifier).deleteSession(session.id);
  }
}

class _SessionList extends StatelessWidget {
  const _SessionList({
    required this.sessions,
    required this.activeId,
    required this.sortMode,
    required this.onSelect,
    required this.onChangeSortMode,
    required this.onRename,
    required this.onDelete,
  });

  final List<ChatSession> sessions;
  final String activeId;
  final SessionSortMode sortMode;
  final ValueChanged<String> onSelect;
  final ValueChanged<SessionSortMode> onChangeSortMode;
  final ValueChanged<ChatSession> onRename;
  final ValueChanged<ChatSession> onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              children: [
                Text('会话', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                PopupMenuButton<SessionSortMode>(
                  tooltip: '排序',
                  initialValue: sortMode,
                  onSelected: onChangeSortMode,
                  itemBuilder: (context) {
                    return SessionSortMode.values
                        .map(
                          (m) => PopupMenuItem(
                            value: m,
                            child: Text(m.label),
                          ),
                        )
                        .toList(growable: false);
                  },
                  child: Row(
                    children: [
                      Text(sortMode.label),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: sessions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final s = sessions[index];
                final selected = s.id == activeId;
                return ListTile(
                  selected: selected,
                  selectedTileColor:
                      Theme.of(context).colorScheme.primary.withAlpha(20),
                  title: Text(
                    s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${s.messages.length} messages',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: '会话操作',
                    onSelected: (value) {
                      switch (value) {
                        case 'rename':
                          onRename(s);
                          break;
                        case 'delete':
                          onDelete(s);
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'rename', child: Text('重命名')),
                      PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                  ),
                  onTap: () => onSelect(s.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.session,
    required this.isGenerating,
    required this.latencyMs,
    required this.promptTokens,
    required this.completionTokens,
    required this.composer,
    required this.composerFocus,
    required this.onSend,
    required this.onRetryAssistantMessage,
  });

  final ChatSession session;
  final bool isGenerating;
  final int? latencyMs;
  final int? promptTokens;
  final int? completionTokens;
  final TextEditingController composer;
  final FocusNode composerFocus;
  final VoidCallback onSend;
  final Future<void> Function(String assistantMessageId) onRetryAssistantMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatsBar(
          latencyMs: latencyMs,
          promptTokens: promptTokens,
          completionTokens: completionTokens,
          isGenerating: isGenerating,
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: session.messages.length,
            itemBuilder: (context, index) {
              final m = session.messages[index];
              final isUser = m.role == ChatRole.user;
              final isAssistant = m.role == ChatRole.assistant;
              return Align(
                alignment:
                    isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Card(
                    color: isUser
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.10)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MarkdownBody(
                            data: m.content.isEmpty
                                ? (m.role == ChatRole.assistant && isGenerating
                                    ? '...'
                                    : '')
                                : m.content,
                            selectable: true,
                          ),
                          if (isAssistant) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                TextButton.icon(
                                  onPressed: (m.content.trim().isEmpty)
                                      ? null
                                      : () async {
                                          await Clipboard.setData(
                                            ClipboardData(text: m.content),
                                          );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text('已复制到剪贴板'),
                                            ),
                                          );
                                        },
                                  icon: const Icon(Icons.copy_outlined),
                                  label: const Text('复制'),
                                ),
                                TextButton.icon(
                                  onPressed: isGenerating
                                      ? null
                                      : () => onRetryAssistantMessage(m.id),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('重试'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: composer,
                  focusNode: composerFocus,
                  minLines: 1,
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: 'Type a message…',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: isGenerating ? null : onSend,
                icon: const Icon(Icons.send),
                label: const Text('Send'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({
    required this.latencyMs,
    required this.promptTokens,
    required this.completionTokens,
    required this.isGenerating,
  });

  final int? latencyMs;
  final int? promptTokens;
  final int? completionTokens;
  final bool isGenerating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text(
            isGenerating ? 'Generating…' : 'Idle',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const Spacer(),
          Text('Latency: ${latencyMs ?? '-'} ms'),
          const SizedBox(width: 12),
          Text('In: ${promptTokens ?? '-'} tok'),
          const SizedBox(width: 12),
          Text('Out: ${completionTokens ?? '-'} tok'),
        ],
      ),
    );
  }
}


