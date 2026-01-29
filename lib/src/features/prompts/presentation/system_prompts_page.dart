import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/system_prompts_controller.dart';
import '../domain/system_prompt.dart';

class SystemPromptsPage extends ConsumerWidget {
  const SystemPromptsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(systemPromptsControllerProvider);
    final controller = ref.read(systemPromptsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/chat');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('System Prompts'),
        actions: [
          IconButton(
            tooltip: 'Add',
            onPressed: () async {
              final draft = await showDialog<_PromptDraft>(
                context: context,
                builder: (_) => const _PromptEditorDialog(),
              );
              if (draft == null) return;
              controller.createPrompt(title: draft.title, content: draft.content);
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: state.prompts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final p = state.prompts[index];
          final selected = p.id == state.activePromptId;
          return Card(
            child: ListTile(
              leading: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
              ),
              title: Text(
                p.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                p.content.trim().isEmpty ? '（空）' : p.content.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => controller.setActivePrompt(p.id),
              trailing: PopupMenuButton<String>(
                tooltip: 'Actions',
                onSelected: (action) async {
                  switch (action) {
                    case 'edit':
                      final draft = await showDialog<_PromptDraft>(
                        context: context,
                        builder: (_) => _PromptEditorDialog(initial: p),
                      );
                      if (draft == null) return;
                      controller.updatePrompt(
                        id: p.id,
                        title: draft.title,
                        content: draft.content,
                      );
                      break;
                    case 'delete':
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('删除提示词'),
                          content: Text('确定删除“${p.title}”？此操作不可撤销。'),
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
                        ),
                      );
                      if (ok != true) return;
                      controller.deletePrompt(p.id);
                      break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PromptDraft {
  const _PromptDraft({required this.title, required this.content});

  final String title;
  final String content;
}

class _PromptEditorDialog extends StatefulWidget {
  const _PromptEditorDialog({this.initial});

  final SystemPrompt? initial;

  @override
  State<_PromptEditorDialog> createState() => _PromptEditorDialogState();
}

class _PromptEditorDialogState extends State<_PromptEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _content;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial?.title ?? '');
    _content = TextEditingController(text: widget.initial?.content ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? '新增提示词' : '编辑提示词'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _content,
              minLines: 6,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'System prompt 内容',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _PromptDraft(
                title: _title.text,
                content: _content.text,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

