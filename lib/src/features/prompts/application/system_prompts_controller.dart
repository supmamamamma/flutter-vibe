import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/system_prompts_repository.dart';
import '../domain/system_prompt.dart';
import 'system_prompts_state.dart';

final systemPromptsControllerProvider =
    NotifierProvider<SystemPromptsController, SystemPromptsState>(
  SystemPromptsController.new,
);

class SystemPromptsController extends Notifier<SystemPromptsState> {
  bool _hydrated = false;

  @override
  SystemPromptsState build() {
    final repo = ref.read(systemPromptsRepositoryProvider);

    final defaultPrompt = SystemPrompt.create(
      title: '默认（空）',
      content: '',
    );

    final initial = SystemPromptsState(
      prompts: [defaultPrompt],
      activePromptId: defaultPrompt.id,
    );

    // Fire-and-forget hydration from IndexedDB.
    if (!_hydrated) {
      _hydrated = true;
      unawaited(_hydrate(repo, fallback: initial));
    }

    return initial;
  }

  Future<void> _hydrate(
    SystemPromptsRepository repo, {
    required SystemPromptsState fallback,
  }) async {
    final (prompts, activeId) = await repo.loadAll();
    if (prompts.isEmpty) {
      // Ensure at least one prompt exists.
      await repo.upsert(fallback.activePrompt);
      await repo.setActiveId(fallback.activePromptId);
      return;
    }

    final resolvedActive =
        prompts.any((p) => p.id == activeId) ? activeId! : prompts.first.id;

    state = SystemPromptsState(prompts: prompts, activePromptId: resolvedActive);
  }

  void setActivePrompt(String id) {
    if (!state.prompts.any((p) => p.id == id)) return;
    state = state.copyWith(activePromptId: id);

    final repo = ref.read(systemPromptsRepositoryProvider);
    unawaited(repo.setActiveId(id));
  }

  void createPrompt({required String title, required String content}) {
    final prompt = SystemPrompt.create(title: title, content: content);
    state = state.copyWith(
      prompts: [prompt, ...state.prompts],
      activePromptId: prompt.id,
    );

    final repo = ref.read(systemPromptsRepositoryProvider);
    unawaited(repo.upsert(prompt));
    unawaited(repo.setActiveId(prompt.id));
  }

  void updatePrompt({
    required String id,
    required String title,
    required String content,
  }) {
    final now = DateTime.now();
    final nextTitle = title.trim().isEmpty ? 'Untitled' : title.trim();
    SystemPrompt? updated;
    final next = state.prompts.map((p) {
      if (p.id != id) return p;
      updated = p.copyWith(title: nextTitle, content: content, updatedAt: now);
      return updated!;
    }).toList(growable: false);
    state = state.copyWith(prompts: next);

    if (updated != null) {
      final repo = ref.read(systemPromptsRepositoryProvider);
      unawaited(repo.upsert(updated!));
    }
  }

  void deletePrompt(String id) {
    final next = state.prompts.where((p) => p.id != id).toList(growable: false);

    if (next.isEmpty) {
      final defaultPrompt = SystemPrompt.create(title: '默认（空）', content: '');
      state = state.copyWith(prompts: [defaultPrompt], activePromptId: defaultPrompt.id);

      final repo = ref.read(systemPromptsRepositoryProvider);
      unawaited(repo.upsert(defaultPrompt));
      unawaited(repo.setActiveId(defaultPrompt.id));
      return;
    }

    final nextActive = next.any((p) => p.id == state.activePromptId)
        ? state.activePromptId
        : next.first.id;
    state = state.copyWith(prompts: next, activePromptId: nextActive);

    final repo = ref.read(systemPromptsRepositoryProvider);
    unawaited(repo.delete(id));
    unawaited(repo.setActiveId(nextActive));
  }
}

