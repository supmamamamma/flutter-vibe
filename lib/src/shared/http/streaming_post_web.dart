// ignore_for_file: avoid_web_libraries_in_flutter, avoid_web_libraries_in_flutter3, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'package:http/http.dart' as http;

Stream<String> postTextStreamImpl({
  required http.Client client,
  required Uri uri,
  required Map<String, String> headers,
  required String body,
}) {
  // Web 端不使用 package:http 的 client（BrowserClient 会缓冲整个响应）。
  // 这里使用 XHR 的 onProgress 读取 responseText 的增量来实现流式。
  // ignore: avoid_unused_constructor_parameters
  final _ = client;

  final controller = StreamController<String>(sync: true);
  final xhr = html.HttpRequest();

  var lastLen = 0;
  var sawAnyProgress = false;

  xhr
    ..open('POST', uri.toString())
    ..withCredentials = false;

  for (final e in headers.entries) {
    xhr.setRequestHeader(e.key, e.value);
  }

  xhr.onProgress.listen((_) {
    final text = xhr.responseText ?? '';
    if (text.length <= lastLen) return;
    sawAnyProgress = true;
    controller.add(text.substring(lastLen));
    lastLen = text.length;
  });

  xhr.onError.listen((event) {
    controller.addError(http.ClientException('Network error', uri));
    controller.close();
  });

  xhr.onLoadEnd.listen((_) {
    final status = xhr.status ?? 0;
    // 在某些场景下，XHR 会等到完成才触发 onProgress；此处兜底补一次增量。
    if (!sawAnyProgress) {
      final text = xhr.responseText ?? '';
      if (text.length > lastLen) {
        controller.add(text.substring(lastLen));
        lastLen = text.length;
      }
    }

    if (status < 200 || status >= 300) {
      controller.addError(
        http.ClientException('HTTP $status: ${xhr.responseText ?? ''}', uri),
      );
    }
    controller.close();
  });

  controller.onCancel = () {
    try {
      xhr.abort();
    } catch (_) {
      // ignore
    }
  };

  xhr.send(body);
  return controller.stream;
}

