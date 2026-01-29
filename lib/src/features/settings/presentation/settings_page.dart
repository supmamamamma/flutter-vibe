import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/settings_controller.dart';
import '../application/settings_state.dart';
import '../domain/llm_profile.dart';
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

    // 仍保留 provider 的 Tab 视图（便于不同 provider 的字段展示），
    // 但 active provider 由“当前 Profile.provider”决定。
    final initialIndex =
        LlmProvider.values.indexOf(ref.read(settingsControllerProvider).activeProvider);

    _tabController = TabController(
      length: LlmProvider.values.length,
      vsync: this,
      initialIndex: initialIndex,
    );

    // Tab -> 更新当前 profile 的 provider
    _tabController.addListener(() {
      final provider = LlmProvider.values[_tabController.index];
      final current = ref.read(settingsControllerProvider).activeProvider;
      if (provider == current) return;
      ref.read(settingsControllerProvider.notifier).setProfileProvider(provider);
    });

    // profile.provider -> Tab
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

    Future<void> renameActiveProfile() async {
      final nameController =
          TextEditingController(text: settings.activeProfile.name);
      final newName = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('重命名连接配置'),
            content: TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '名称',
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
                onPressed: () =>
                    Navigator.of(context).pop(nameController.text.trim()),
                child: const Text('保存'),
              ),
            ],
          );
        },
      );
      if (newName == null) return;
      controller.renameProfile(profileId: settings.activeProfileId, name: newName);
    }

    void addProfile(LlmProvider provider) {
      final profile = switch (provider) {
        LlmProvider.openai => LlmProfile.create(
            name: 'OpenAI 新连接',
            provider: LlmProvider.openai,
            baseUrl: 'https://api.openai.com',
            model: 'gpt-4o-mini',
          ),
        LlmProvider.gemini => LlmProfile.create(
            name: 'Gemini 新连接',
            provider: LlmProvider.gemini,
            baseUrl: 'https://generativelanguage.googleapis.com',
            model: 'gemini-1.5-flash',
          ),
        LlmProvider.claude => LlmProfile.create(
            name: 'Claude 新连接',
            provider: LlmProvider.claude,
            baseUrl: 'https://api.anthropic.com',
            model: 'claude-3-5-sonnet-latest',
          ),
      };
      controller.addProfile(profile);
    }

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
                          labelText: '连接配置（Profile）',
                          border: OutlineInputBorder(),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: settings.activeProfileId,
                            isExpanded: true,
                            items: settings.profiles
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p.id,
                                    child: Text('${p.name}（${p.provider.label}）'),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (id) {
                              if (id == null) return;
                              controller.setActiveProfile(id);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: '连接配置操作',
                      onSelected: (value) {
                        switch (value) {
                          case 'rename':
                            renameActiveProfile();
                            break;
                          case 'delete':
                            controller.deleteProfile(settings.activeProfileId);
                            break;
                          case 'add_openai':
                            addProfile(LlmProvider.openai);
                            break;
                          case 'add_gemini':
                            addProfile(LlmProvider.gemini);
                            break;
                          case 'add_claude':
                            addProfile(LlmProvider.claude);
                            break;
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'rename', child: Text('重命名当前配置')),
                        PopupMenuItem(value: 'delete', child: Text('删除当前配置')),
                        PopupMenuDivider(),
                        PopupMenuItem(value: 'add_openai', child: Text('新增 OpenAI 配置')),
                        PopupMenuItem(value: 'add_gemini', child: Text('新增 Gemini 配置')),
                        PopupMenuItem(value: 'add_claude', child: Text('新增 Claude 配置')),
                      ],
                      child: const Icon(Icons.more_vert),
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
  late final TextEditingController _maxTokens;

  final FocusNode _baseUrlFocus = FocusNode();
  final FocusNode _modelFocus = FocusNode();
  final FocusNode _apiKeyFocus = FocusNode();
  final FocusNode _maxTokensFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _baseUrl = TextEditingController(text: widget.settings.activeProfile.baseUrl);
    _model = TextEditingController(text: widget.settings.activeProfile.model);
    _apiKey = TextEditingController(text: widget.settings.activeProfile.apiKey);
    _maxTokens = TextEditingController(
      text: widget.settings.activeProfile.openAiMaxTokens?.toString() ?? '',
    );

    _baseUrlFocus.addListener(_commitIfNeeded);
    _modelFocus.addListener(_commitIfNeeded);
    _apiKeyFocus.addListener(_commitIfNeeded);
    _maxTokensFocus.addListener(_commitIfNeeded);
  }

  @override
  void didUpdateWidget(covariant _OpenAiSettingsTabBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final p = widget.settings.activeProfile;
    if (!_baseUrlFocus.hasFocus && _baseUrl.text != p.baseUrl) {
      _baseUrl.text = p.baseUrl;
    }
    if (!_modelFocus.hasFocus && _model.text != p.model) {
      _model.text = p.model;
    }
    if (!_apiKeyFocus.hasFocus && _apiKey.text != p.apiKey) {
      _apiKey.text = p.apiKey;
    }

    final maxTokensText = p.openAiMaxTokens?.toString() ?? '';
    if (!_maxTokensFocus.hasFocus && _maxTokens.text != maxTokensText) {
      _maxTokens.text = maxTokensText;
    }
  }

  void _commitIfNeeded() {
    // 只在失焦时提交，避免 Web 输入法组合态导致 TextInput 断言。
    if (_baseUrlFocus.hasFocus ||
        _modelFocus.hasFocus ||
        _apiKeyFocus.hasFocus ||
        _maxTokensFocus.hasFocus) {
      return;
    }

    final p = widget.settings.activeProfile;
    if (_baseUrl.text.trim() != p.baseUrl) {
      widget.controller.setProfileBaseUrl(_baseUrl.text);
    }
    if (_model.text.trim() != p.model) {
      widget.controller.setProfileModel(_model.text);
    }
    if (_apiKey.text != p.apiKey) {
      widget.controller.setProfileApiKey(_apiKey.text);
    }

    final maxTokensText = p.openAiMaxTokens?.toString() ?? '';
    if (_maxTokens.text.trim() != maxTokensText) {
      widget.controller.setProfileOpenAiMaxTokens(_maxTokens.text);
    }
  }

  @override
  void dispose() {
    _baseUrlFocus.removeListener(_commitIfNeeded);
    _modelFocus.removeListener(_commitIfNeeded);
    _apiKeyFocus.removeListener(_commitIfNeeded);
    _maxTokensFocus.removeListener(_commitIfNeeded);
    _baseUrlFocus.dispose();
    _modelFocus.dispose();
    _apiKeyFocus.dispose();
    _maxTokensFocus.dispose();
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    _maxTokens.dispose();
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
        const SizedBox(height: 16),
        const Text('Limits', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _maxTokens,
          focusNode: _maxTokensFocus,
          decoration: const InputDecoration(
            labelText: 'OpenAI max_tokens（可选，留空表示不传）',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
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
    _baseUrl = TextEditingController(text: widget.settings.activeProfile.baseUrl);
    _model = TextEditingController(text: widget.settings.activeProfile.model);
    _apiKey = TextEditingController(text: widget.settings.activeProfile.apiKey);

    _baseUrlFocus.addListener(_commitIfNeeded);
    _modelFocus.addListener(_commitIfNeeded);
    _apiKeyFocus.addListener(_commitIfNeeded);
  }

  @override
  void didUpdateWidget(covariant _GeminiSettingsTabBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final p = widget.settings.activeProfile;
    if (!_baseUrlFocus.hasFocus && _baseUrl.text != p.baseUrl) {
      _baseUrl.text = p.baseUrl;
    }
    if (!_modelFocus.hasFocus && _model.text != p.model) {
      _model.text = p.model;
    }
    if (!_apiKeyFocus.hasFocus && _apiKey.text != p.apiKey) {
      _apiKey.text = p.apiKey;
    }
  }

  void _commitIfNeeded() {
    if (_baseUrlFocus.hasFocus || _modelFocus.hasFocus || _apiKeyFocus.hasFocus) {
      return;
    }

    final p = widget.settings.activeProfile;
    if (_baseUrl.text.trim() != p.baseUrl) {
      widget.controller.setProfileBaseUrl(_baseUrl.text);
    }
    if (_model.text.trim() != p.model) {
      widget.controller.setProfileModel(_model.text);
    }
    if (_apiKey.text != p.apiKey) {
      widget.controller.setProfileApiKey(_apiKey.text);
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
    final p = widget.settings.activeProfile;
    _baseUrl = TextEditingController(text: p.baseUrl);
    _model = TextEditingController(text: p.model);
    _maxTokens = TextEditingController(text: p.claudeMaxTokens.toString());
    _apiKey = TextEditingController(text: p.apiKey);

    _baseUrlFocus.addListener(_commitIfNeeded);
    _modelFocus.addListener(_commitIfNeeded);
    _maxTokensFocus.addListener(_commitIfNeeded);
    _apiKeyFocus.addListener(_commitIfNeeded);
  }

  @override
  void didUpdateWidget(covariant _ClaudeSettingsTabBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    final p = widget.settings.activeProfile;
    if (!_baseUrlFocus.hasFocus && _baseUrl.text != p.baseUrl) {
      _baseUrl.text = p.baseUrl;
    }
    if (!_modelFocus.hasFocus && _model.text != p.model) {
      _model.text = p.model;
    }
    final maxTokensText = p.claudeMaxTokens.toString();
    if (!_maxTokensFocus.hasFocus && _maxTokens.text != maxTokensText) {
      _maxTokens.text = maxTokensText;
    }
    if (!_apiKeyFocus.hasFocus && _apiKey.text != p.apiKey) {
      _apiKey.text = p.apiKey;
    }
  }

  void _commitIfNeeded() {
    if (_baseUrlFocus.hasFocus ||
        _modelFocus.hasFocus ||
        _maxTokensFocus.hasFocus ||
        _apiKeyFocus.hasFocus) {
      return;
    }

    final p = widget.settings.activeProfile;
    if (_baseUrl.text.trim() != p.baseUrl) {
      widget.controller.setProfileBaseUrl(_baseUrl.text);
    }
    if (_model.text.trim() != p.model) {
      widget.controller.setProfileModel(_model.text);
    }
    if (_maxTokens.text.trim() != p.claudeMaxTokens.toString()) {
      widget.controller.setProfileClaudeMaxTokens(_maxTokens.text);
    }
    if (_apiKey.text != p.apiKey) {
      widget.controller.setProfileApiKey(_apiKey.text);
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

