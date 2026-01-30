import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/llm_provider.dart';
import '../domain/llm_profile.dart';
import '../data/settings_repository.dart';
import 'settings_state.dart';

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

class SettingsController extends Notifier<SettingsState> {
  bool _hydrated = false;

  @override
  SettingsState build() {
    final repo = ref.read(settingsRepositoryProvider);

    final defaultProfile = LlmProfile.create(
      name: 'OpenAI 默认',
      provider: LlmProvider.openai,
      baseUrl: 'https://api.openai.com',
      model: 'gpt-4o-mini',
    );

    final initial = SettingsState(
      profiles: [defaultProfile],
      activeProfileId: defaultProfile.id,
      useStreaming: false,
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

  void setActiveProfile(String profileId) {
    if (!state.profiles.any((p) => p.id == profileId)) return;
    state = state.copyWith(activeProfileId: profileId);
    _persist();
  }

  void addProfile(LlmProfile profile) {
    state = state.copyWith(
      profiles: [...state.profiles, profile],
      activeProfileId: profile.id,
    );
    _persist();
  }

  void renameProfile({required String profileId, required String name}) {
    final nextName = name.trim().isEmpty ? '未命名' : name.trim();
    state = state.copyWith(
      profiles: state.profiles
          .map((p) => p.id == profileId ? p.copyWith(name: nextName) : p)
          .toList(growable: false),
    );
    _persist();
  }

  void deleteProfile(String profileId) {
    final remaining =
        state.profiles.where((p) => p.id != profileId).toList(growable: false);
    if (remaining.isEmpty) return;
    final nextActive = (state.activeProfileId == profileId)
        ? remaining.first.id
        : state.activeProfileId;

    state = state.copyWith(profiles: remaining, activeProfileId: nextActive);
    _persist();
  }

  void setUseStreaming(bool value) {
    state = state.copyWith(useStreaming: value);
    _persist();
  }

  void setProfileProvider(LlmProvider provider) {
    final id = state.activeProfileId;
    state = state.copyWith(
      profiles: state.profiles
          .map((p) => p.id == id ? p.copyWith(provider: provider) : p)
          .toList(growable: false),
    );
    _persist();
  }

  void setProfileApiKey(String value) {
    final id = state.activeProfileId;
    state = state.copyWith(
      profiles: state.profiles
          .map((p) => p.id == id ? p.copyWith(apiKey: value) : p)
          .toList(growable: false),
    );
    _persist();
  }

  void setProfileBaseUrl(String value) {
    final id = state.activeProfileId;
    state = state.copyWith(
      profiles: state.profiles
          .map((p) => p.id == id ? p.copyWith(baseUrl: value.trim()) : p)
          .toList(growable: false),
    );
    _persist();
  }

  void setProfileModel(String value) {
    final id = state.activeProfileId;
    state = state.copyWith(
      profiles: state.profiles
          .map((p) => p.id == id ? p.copyWith(model: value.trim()) : p)
          .toList(growable: false),
    );
    _persist();
  }

  void setProfileClaudeMaxTokens(String value) {
    final trimmed = value.trim();
    final parsed = trimmed.isEmpty ? 1024 : int.tryParse(trimmed);
    if (parsed == null) return;
    final id = state.activeProfileId;
    state = state.copyWith(
      profiles: state.profiles
          .map((p) => p.id == id ? p.copyWith(claudeMaxTokens: parsed) : p)
          .toList(growable: false),
    );
    _persist();
  }

  void setProfileOpenAiTemperature(String value) {
    final id = state.activeProfileId;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        profiles: state.profiles
            .map((p) => p.id == id ? p.copyWith(clearOpenAiTemperature: true) : p)
            .toList(growable: false),
      );
      _persist();
      return;
    }

    final parsed = double.tryParse(trimmed);
    if (parsed == null) return;
    state = state.copyWith(
      profiles: state.profiles
          .map((p) => p.id == id ? p.copyWith(openAiTemperature: parsed) : p)
          .toList(growable: false),
    );
    _persist();
  }

  void setProfileOpenAiTopP(String value) {
    final id = state.activeProfileId;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        profiles: state.profiles
            .map((p) => p.id == id ? p.copyWith(clearOpenAiTopP: true) : p)
            .toList(growable: false),
      );
      _persist();
      return;
    }

    final parsed = double.tryParse(trimmed);
    if (parsed == null) return;
    state = state.copyWith(
      profiles: state.profiles
          .map((p) => p.id == id ? p.copyWith(openAiTopP: parsed) : p)
          .toList(growable: false),
    );
    _persist();
  }

  void setProfileOpenAiTopK(String value) {
    final id = state.activeProfileId;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        profiles: state.profiles
            .map((p) => p.id == id ? p.copyWith(clearOpenAiTopK: true) : p)
            .toList(growable: false),
      );
      _persist();
      return;
    }

    final parsed = int.tryParse(trimmed);
    if (parsed == null) return;
    state = state.copyWith(
      profiles: state.profiles
          .map((p) => p.id == id ? p.copyWith(openAiTopK: parsed) : p)
          .toList(growable: false),
    );
    _persist();
  }

  void setProfileGeminiTemperature(String value) {
    final id = state.activeProfileId;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        profiles: state.profiles
            .map((p) => p.id == id ? p.copyWith(clearGeminiTemperature: true) : p)
            .toList(growable: false),
      );
      _persist();
      return;
    }

    final parsed = double.tryParse(trimmed);
    if (parsed == null) return;
    state = state.copyWith(
      profiles: state.profiles
          .map((p) => p.id == id ? p.copyWith(geminiTemperature: parsed) : p)
          .toList(growable: false),
    );
    _persist();
  }

  void setProfileGeminiTopP(String value) {
    final id = state.activeProfileId;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        profiles: state.profiles
            .map((p) => p.id == id ? p.copyWith(clearGeminiTopP: true) : p)
            .toList(growable: false),
      );
      _persist();
      return;
    }

    final parsed = double.tryParse(trimmed);
    if (parsed == null) return;
    state = state.copyWith(
      profiles: state.profiles
          .map((p) => p.id == id ? p.copyWith(geminiTopP: parsed) : p)
          .toList(growable: false),
    );
    _persist();
  }

  void setProfileGeminiTopK(String value) {
    final id = state.activeProfileId;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        profiles: state.profiles
            .map((p) => p.id == id ? p.copyWith(clearGeminiTopK: true) : p)
            .toList(growable: false),
      );
      _persist();
      return;
    }

    final parsed = int.tryParse(trimmed);
    if (parsed == null) return;
    state = state.copyWith(
      profiles: state.profiles
          .map((p) => p.id == id ? p.copyWith(geminiTopK: parsed) : p)
          .toList(growable: false),
    );
    _persist();
  }

  void setProfileGeminiMaxOutputTokens(String value) {
    final id = state.activeProfileId;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        profiles: state.profiles
            .map(
              (p) => p.id == id
                  ? p.copyWith(clearGeminiMaxOutputTokens: true)
                  : p,
            )
            .toList(growable: false),
      );
      _persist();
      return;
    }

    final parsed = int.tryParse(trimmed);
    if (parsed == null) return;
    state = state.copyWith(
      profiles: state.profiles
          .map((p) => p.id == id ? p.copyWith(geminiMaxOutputTokens: parsed) : p)
          .toList(growable: false),
    );
    _persist();
  }

  void setProfileClaudeTemperature(String value) {
    final id = state.activeProfileId;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        profiles: state.profiles
            .map((p) => p.id == id ? p.copyWith(clearClaudeTemperature: true) : p)
            .toList(growable: false),
      );
      _persist();
      return;
    }

    final parsed = double.tryParse(trimmed);
    if (parsed == null) return;
    state = state.copyWith(
      profiles: state.profiles
          .map((p) => p.id == id ? p.copyWith(claudeTemperature: parsed) : p)
          .toList(growable: false),
    );
    _persist();
  }

  void setProfileClaudeTopP(String value) {
    final id = state.activeProfileId;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        profiles: state.profiles
            .map((p) => p.id == id ? p.copyWith(clearClaudeTopP: true) : p)
            .toList(growable: false),
      );
      _persist();
      return;
    }

    final parsed = double.tryParse(trimmed);
    if (parsed == null) return;
    state = state.copyWith(
      profiles: state.profiles
          .map((p) => p.id == id ? p.copyWith(claudeTopP: parsed) : p)
          .toList(growable: false),
    );
    _persist();
  }

  void setProfileClaudeTopK(String value) {
    final id = state.activeProfileId;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        profiles: state.profiles
            .map((p) => p.id == id ? p.copyWith(clearClaudeTopK: true) : p)
            .toList(growable: false),
      );
      _persist();
      return;
    }

    final parsed = int.tryParse(trimmed);
    if (parsed == null) return;
    state = state.copyWith(
      profiles: state.profiles
          .map((p) => p.id == id ? p.copyWith(claudeTopK: parsed) : p)
          .toList(growable: false),
    );
    _persist();
  }

  void setProfileOpenAiMaxTokens(String value) {
    final id = state.activeProfileId;
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        profiles: state.profiles
            .map((p) => p.id == id ? p.copyWith(clearOpenAiMaxTokens: true) : p)
            .toList(growable: false),
      );
      _persist();
      return;
    }

    final parsed = int.tryParse(trimmed);
    if (parsed == null) return;
    state = state.copyWith(
      profiles: state.profiles
          .map((p) => p.id == id ? p.copyWith(openAiMaxTokens: parsed) : p)
          .toList(growable: false),
    );
    _persist();
  }
}

