import '../domain/llm_profile.dart';
import '../domain/llm_provider.dart';

class SettingsState {
  const SettingsState({
    required this.profiles,
    required this.activeProfileId,
    required this.useStreaming,
  });

  final List<LlmProfile> profiles;
  final String activeProfileId;

  LlmProfile get activeProfile =>
      profiles.firstWhere((p) => p.id == activeProfileId);

  LlmProvider get activeProvider => activeProfile.provider;
  /// 是否启用流式输出。
  ///
  /// 目前 UI/状态已支持；实际 streaming 实现将在后续里程碑接入。
  final bool useStreaming;

  SettingsState copyWith({
    List<LlmProfile>? profiles,
    String? activeProfileId,
    bool? useStreaming,
  }) {
    return SettingsState(
      profiles: profiles ?? this.profiles,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      useStreaming: useStreaming ?? this.useStreaming,
    );
  }
}

