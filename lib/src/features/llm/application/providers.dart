import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../settings/application/settings_controller.dart';
import 'llm_service.dart';

final llmServiceProvider = Provider<LlmService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);

  final settings = ref.watch(settingsControllerProvider);
  return LlmService(httpClient: client, settings: settings);
});

