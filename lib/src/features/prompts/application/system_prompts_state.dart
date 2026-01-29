import '../domain/system_prompt.dart';

class SystemPromptsState {
  const SystemPromptsState({
    required this.prompts,
    required this.activePromptId,
  });

  final List<SystemPrompt> prompts;
  final String activePromptId;

  SystemPrompt get activePrompt =>
      prompts.firstWhere((p) => p.id == activePromptId);

  SystemPromptsState copyWith({
    List<SystemPrompt>? prompts,
    String? activePromptId,
  }) {
    return SystemPromptsState(
      prompts: prompts ?? this.prompts,
      activePromptId: activePromptId ?? this.activePromptId,
    );
  }
}

