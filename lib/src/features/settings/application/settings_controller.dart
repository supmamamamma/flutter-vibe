import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/llm_provider.dart';
import '../data/settings_repository.dart';
import 'settings_state.dart';

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

class SettingsController extends Notifier<SettingsState> {
  bool _hydrated = false;

  @override
  SettingsState build() {
    final repo = ref.read(settingsRepositoryProvider);

    final initial = const SettingsState(
      activeProvider: LlmProvider.openai,
      useStreaming: false,
      openAiApiKey: '',
      geminiApiKey: '',
      claudeApiKey: '',

      openAiBaseUrl: 'https://api.openai.com',
      geminiBaseUrl: 'https://generativelanguage.googleapis.com',
      claudeBaseUrl: 'https://api.anthropic.com',

      openAiModel: 'gpt-4o-mini',
      geminiModel: 'gemini-1.5-flash',
      claudeModel: 'claude-3-5-sonnet-latest',

      claudeMaxTokens: 1024,
      openAiMaxTokens: null,
    );

    if (!_hydrated) {
      _hydrated = true;
      unawaited(_hydrate(repo, fallback: initial));
    }

    return initial;
  }

  Future<void> _hydrate(
    SettingsRepository repo, {
    required SettingsState fallback,
  }) async {
    final loaded = await repo.load();
    if (loaded == null) {
      await repo.save(fallback);
      return;
    }
    state = loaded;
  }

  void _persist() {
    final repo = ref.read(settingsRepositoryProvider);
    unawaited(repo.save(state));
  }

  void setActiveProvider(LlmProvider provider) {
    state = state.copyWith(activeProvider: provider);
    _persist();
  }

  void setOpenAiApiKey(String value) {
    state = state.copyWith(openAiApiKey: value);
    _persist();
  }

  void setGeminiApiKey(String value) {
    state = state.copyWith(geminiApiKey: value);
    _persist();
  }

  void setClaudeApiKey(String value) {
    state = state.copyWith(claudeApiKey: value);
    _persist();
  }

  void setUseStreaming(bool value) {
    state = state.copyWith(useStreaming: value);
    _persist();
  }

  void setOpenAiBaseUrl(String value) {
    state = state.copyWith(openAiBaseUrl: value.trim());
    _persist();
  }

  void setGeminiBaseUrl(String value) {
    state = state.copyWith(geminiBaseUrl: value.trim());
    _persist();
  }

  void setClaudeBaseUrl(String value) {
    state = state.copyWith(claudeBaseUrl: value.trim());
    _persist();
  }

  void setOpenAiModel(String value) {
    state = state.copyWith(openAiModel: value.trim());
    _persist();
  }

  void setGeminiModel(String value) {
    state = state.copyWith(geminiModel: value.trim());
    _persist();
  }

  void setClaudeModel(String value) {
    state = state.copyWith(claudeModel: value.trim());
    _persist();
  }

  void setClaudeMaxTokens(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return;
    state = state.copyWith(claudeMaxTokens: parsed);
    _persist();
  }
}

