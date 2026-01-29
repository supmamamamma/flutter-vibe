import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/settings_controller.dart';
import '../application/settings_state.dart';
import '../domain/llm_provider.dart';

/// Settings
/// - Provider 三分页（Tab）
/// - Provider 下拉菜单（同步 Tab）
/// - 流式/非流式开关
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ProviderSubscription<SettingsState> _settingsSub;

  @override
  void initState() {
    super.initState();

    final initialIndex =
        LlmProvider.values.indexOf(ref.read(settingsControllerProvider).activeProvider);

    _tabController = TabController(
      length: LlmProvider.values.length,
      vsync: this,
      initialIndex: initialIndex,
    );

    // Tab（点击/滑动）-> provider
    _tabController.addListener(() {
      final provider = LlmProvider.values[_tabController.index];
      final current = ref.read(settingsControllerProvider).activeProvider;
      if (provider == current) return;
      ref.read(settingsControllerProvider.notifier).setActiveProvider(provider);
    });

    // provider（如下拉）-> Tab
    _settingsSub = ref.listenManual<SettingsState>(
      settingsControllerProvider,
      (prev, next) {
      final targetIndex = LlmProvider.values.indexOf(next.activeProvider);
      if (_tabController.index == targetIndex) return;
      _tabController.animateTo(targetIndex);
      },
    );
  }

  @override
  void dispose() {
    _settingsSub.close();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.go('/chat'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Settings'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                const Text(
                  'BYO-Key 模式：密钥仅保存在本地浏览器（后续将落地到 IndexedDB）。',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Active provider',
                          border: OutlineInputBorder(),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<LlmProvider>(
                            value: settings.activeProvider,
                            isExpanded: true,
                            items: LlmProvider.values
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p.label),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (p) {
                              if (p == null) return;
                              controller.setActiveProvider(p);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: settings.useStreaming,
                  onChanged: controller.setUseStreaming,
                  title: const Text('Stream responses'),
                  subtitle: const Text('开：流式（先用“回放”模拟）/ 关：非流式'),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () => context.go('/prompts'),
                  icon: const Icon(Icons.text_snippet_outlined),
                  label: const Text('System Prompts 管理'),
                ),
              ],
            ),
          ),
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'OpenAI'),
                Tab(text: 'Gemini'),
                Tab(text: 'Claude'),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: TabBarView(
              controller: _tabController,
              children: [
                _OpenAiSettingsTab(settings: settings, controller: controller),
                _GeminiSettingsTab(settings: settings, controller: controller),
                _ClaudeSettingsTab(settings: settings, controller: controller),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenAiSettingsTab extends StatelessWidget {
  const _OpenAiSettingsTab({required this.settings, required this.controller});

  final SettingsState settings;
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return _OpenAiSettingsTabBody(settings: settings, controller: controller);
  }
}

class _GeminiSettingsTab extends StatelessWidget {
  const _GeminiSettingsTab({required this.settings, required this.controller});

  final SettingsState settings;
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return _GeminiSettingsTabBody(settings: settings, controller: controller);
  }
}

class _ClaudeSettingsTab extends StatelessWidget {
  const _ClaudeSettingsTab({required this.settings, required this.controller});

  final SettingsState settings;
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return _ClaudeSettingsTabBody(settings: settings, controller: controller);
  }
}

class _OpenAiSettingsTabBody extends StatefulWidget {
  const _OpenAiSettingsTabBody({required this.settings, required this.controller});

  final SettingsState settings;
  final SettingsController controller;

  @override
  State<_OpenAiSettingsTabBody> createState() => _OpenAiSettingsTabBodyState();
}

class _OpenAiSettingsTabBodyState extends State<_OpenAiSettingsTabBody> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late final TextEditingController _apiKey;

  final FocusNode _baseUrlFocus = FocusNode();
  final FocusNode _modelFocus = FocusNode();
  final FocusNode _apiKeyFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _baseUrl = TextEditingController(text: widget.settings.openAiBaseUrl);
    _model = TextEditingController(text: widget.settings.openAiModel);
    _apiKey = TextEditingController(text: widget.settings.openAiApiKey);

    _baseUrlFocus.addListener(_commitIfNeeded);
    _modelFocus.addListener(_commitIfNeeded);
    _apiKeyFocus.addListener(_commitIfNeeded);
  }

  @override
  void didUpdateWidget(covariant _OpenAiSettingsTabBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_baseUrlFocus.hasFocus && _baseUrl.text != widget.settings.openAiBaseUrl) {
      _baseUrl.text = widget.settings.openAiBaseUrl;
    }
    if (!_modelFocus.hasFocus && _model.text != widget.settings.openAiModel) {
      _model.text = widget.settings.openAiModel;
    }
    if (!_apiKeyFocus.hasFocus && _apiKey.text != widget.settings.openAiApiKey) {
      _apiKey.text = widget.settings.openAiApiKey;
    }
  }

  void _commitIfNeeded() {
    // 只在失焦时提交，避免 Web 输入法组合态导致 TextInput 断言。
    if (_baseUrlFocus.hasFocus || _modelFocus.hasFocus || _apiKeyFocus.hasFocus) {
      return;
    }

    final s = widget.settings;
    if (_baseUrl.text.trim() != s.openAiBaseUrl) {
      widget.controller.setOpenAiBaseUrl(_baseUrl.text);
    }
    if (_model.text.trim() != s.openAiModel) {
      widget.controller.setOpenAiModel(_model.text);
    }
    if (_apiKey.text != s.openAiApiKey) {
      widget.controller.setOpenAiApiKey(_apiKey.text);
    }
  }

  @override
  void dispose() {
    _baseUrlFocus.removeListener(_commitIfNeeded);
    _modelFocus.removeListener(_commitIfNeeded);
    _apiKeyFocus.removeListener(_commitIfNeeded);
    _baseUrlFocus.dispose();
    _modelFocus.dispose();
    _apiKeyFocus.dispose();
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Base URL', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _baseUrl,
          focusNode: _baseUrlFocus,
          decoration: const InputDecoration(
            labelText: 'OpenAI base_url',
            helperText: 'Default: https://api.openai.com',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _commitIfNeeded(),
        ),
        const SizedBox(height: 16),
        const Text('Model', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _model,
          focusNode: _modelFocus,
          decoration: const InputDecoration(
            labelText: 'OpenAI model',
            helperText: 'Example: gpt-4o-mini',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _commitIfNeeded(),
        ),
        const SizedBox(height: 16),
        const Text('API Key', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _apiKey,
          focusNode: _apiKeyFocus,
          decoration: const InputDecoration(
            labelText: 'OpenAI API Key',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          onSubmitted: (_) => _commitIfNeeded(),
        ),
      ],
    );
  }
}

class _GeminiSettingsTabBody extends StatefulWidget {
  const _GeminiSettingsTabBody({required this.settings, required this.controller});

  final SettingsState settings;
  final SettingsController controller;

  @override
  State<_GeminiSettingsTabBody> createState() => _GeminiSettingsTabBodyState();
}

class _GeminiSettingsTabBodyState extends State<_GeminiSettingsTabBody> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late final TextEditingController _apiKey;

  final FocusNode _baseUrlFocus = FocusNode();
  final FocusNode _modelFocus = FocusNode();
  final FocusNode _apiKeyFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _baseUrl = TextEditingController(text: widget.settings.geminiBaseUrl);
    _model = TextEditingController(text: widget.settings.geminiModel);
    _apiKey = TextEditingController(text: widget.settings.geminiApiKey);

    _baseUrlFocus.addListener(_commitIfNeeded);
    _modelFocus.addListener(_commitIfNeeded);
    _apiKeyFocus.addListener(_commitIfNeeded);
  }

  @override
  void didUpdateWidget(covariant _GeminiSettingsTabBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_baseUrlFocus.hasFocus && _baseUrl.text != widget.settings.geminiBaseUrl) {
      _baseUrl.text = widget.settings.geminiBaseUrl;
    }
    if (!_modelFocus.hasFocus && _model.text != widget.settings.geminiModel) {
      _model.text = widget.settings.geminiModel;
    }
    if (!_apiKeyFocus.hasFocus && _apiKey.text != widget.settings.geminiApiKey) {
      _apiKey.text = widget.settings.geminiApiKey;
    }
  }

  void _commitIfNeeded() {
    if (_baseUrlFocus.hasFocus || _modelFocus.hasFocus || _apiKeyFocus.hasFocus) {
      return;
    }

    final s = widget.settings;
    if (_baseUrl.text.trim() != s.geminiBaseUrl) {
      widget.controller.setGeminiBaseUrl(_baseUrl.text);
    }
    if (_model.text.trim() != s.geminiModel) {
      widget.controller.setGeminiModel(_model.text);
    }
    if (_apiKey.text != s.geminiApiKey) {
      widget.controller.setGeminiApiKey(_apiKey.text);
    }
  }

  @override
  void dispose() {
    _baseUrlFocus.removeListener(_commitIfNeeded);
    _modelFocus.removeListener(_commitIfNeeded);
    _apiKeyFocus.removeListener(_commitIfNeeded);
    _baseUrlFocus.dispose();
    _modelFocus.dispose();
    _apiKeyFocus.dispose();
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Base URL', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _baseUrl,
          focusNode: _baseUrlFocus,
          decoration: const InputDecoration(
            labelText: 'Gemini base_url',
            helperText: 'Default: https://generativelanguage.googleapis.com',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _commitIfNeeded(),
        ),
        const SizedBox(height: 16),
        const Text('Model', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _model,
          focusNode: _modelFocus,
          decoration: const InputDecoration(
            labelText: 'Gemini model',
            helperText: 'Example: gemini-1.5-flash',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _commitIfNeeded(),
        ),
        const SizedBox(height: 16),
        const Text('API Key', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _apiKey,
          focusNode: _apiKeyFocus,
          decoration: const InputDecoration(
            labelText: 'Gemini API Key',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          onSubmitted: (_) => _commitIfNeeded(),
        ),
      ],
    );
  }
}

class _ClaudeSettingsTabBody extends StatefulWidget {
  const _ClaudeSettingsTabBody({required this.settings, required this.controller});

  final SettingsState settings;
  final SettingsController controller;

  @override
  State<_ClaudeSettingsTabBody> createState() => _ClaudeSettingsTabBodyState();
}

class _ClaudeSettingsTabBodyState extends State<_ClaudeSettingsTabBody> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late final TextEditingController _maxTokens;
  late final TextEditingController _apiKey;

  final FocusNode _baseUrlFocus = FocusNode();
  final FocusNode _modelFocus = FocusNode();
  final FocusNode _maxTokensFocus = FocusNode();
  final FocusNode _apiKeyFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _baseUrl = TextEditingController(text: widget.settings.claudeBaseUrl);
    _model = TextEditingController(text: widget.settings.claudeModel);
    _maxTokens =
        TextEditingController(text: widget.settings.claudeMaxTokens.toString());
    _apiKey = TextEditingController(text: widget.settings.claudeApiKey);

    _baseUrlFocus.addListener(_commitIfNeeded);
    _modelFocus.addListener(_commitIfNeeded);
    _maxTokensFocus.addListener(_commitIfNeeded);
    _apiKeyFocus.addListener(_commitIfNeeded);
  }

  @override
  void didUpdateWidget(covariant _ClaudeSettingsTabBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_baseUrlFocus.hasFocus && _baseUrl.text != widget.settings.claudeBaseUrl) {
      _baseUrl.text = widget.settings.claudeBaseUrl;
    }
    if (!_modelFocus.hasFocus && _model.text != widget.settings.claudeModel) {
      _model.text = widget.settings.claudeModel;
    }
    final maxTokensText = widget.settings.claudeMaxTokens.toString();
    if (!_maxTokensFocus.hasFocus && _maxTokens.text != maxTokensText) {
      _maxTokens.text = maxTokensText;
    }
    if (!_apiKeyFocus.hasFocus && _apiKey.text != widget.settings.claudeApiKey) {
      _apiKey.text = widget.settings.claudeApiKey;
    }
  }

  void _commitIfNeeded() {
    if (_baseUrlFocus.hasFocus ||
        _modelFocus.hasFocus ||
        _maxTokensFocus.hasFocus ||
        _apiKeyFocus.hasFocus) {
      return;
    }

    final s = widget.settings;
    if (_baseUrl.text.trim() != s.claudeBaseUrl) {
      widget.controller.setClaudeBaseUrl(_baseUrl.text);
    }
    if (_model.text.trim() != s.claudeModel) {
      widget.controller.setClaudeModel(_model.text);
    }
    if (_maxTokens.text.trim() != s.claudeMaxTokens.toString()) {
      widget.controller.setClaudeMaxTokens(_maxTokens.text);
    }
    if (_apiKey.text != s.claudeApiKey) {
      widget.controller.setClaudeApiKey(_apiKey.text);
    }
  }

  @override
  void dispose() {
    _baseUrlFocus.removeListener(_commitIfNeeded);
    _modelFocus.removeListener(_commitIfNeeded);
    _maxTokensFocus.removeListener(_commitIfNeeded);
    _apiKeyFocus.removeListener(_commitIfNeeded);
    _baseUrlFocus.dispose();
    _modelFocus.dispose();
    _maxTokensFocus.dispose();
    _apiKeyFocus.dispose();
    _baseUrl.dispose();
    _model.dispose();
    _maxTokens.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Base URL', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _baseUrl,
          focusNode: _baseUrlFocus,
          decoration: const InputDecoration(
            labelText: 'Claude base_url',
            helperText: 'Default: https://api.anthropic.com',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _commitIfNeeded(),
        ),
        const SizedBox(height: 16),
        const Text('Model', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _model,
          focusNode: _modelFocus,
          decoration: const InputDecoration(
            labelText: 'Claude model',
            helperText: 'Example: claude-3-5-sonnet-latest',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _commitIfNeeded(),
        ),
        const SizedBox(height: 16),
        const Text('Limits', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _maxTokens,
          focusNode: _maxTokensFocus,
          decoration: const InputDecoration(
            labelText: 'Claude max_tokens',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onSubmitted: (_) => _commitIfNeeded(),
        ),
        const SizedBox(height: 16),
        const Text('API Key', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _apiKey,
          focusNode: _apiKeyFocus,
          decoration: const InputDecoration(
            labelText: 'Claude API Key',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          onSubmitted: (_) => _commitIfNeeded(),
        ),
      ],
    );
  }
}

