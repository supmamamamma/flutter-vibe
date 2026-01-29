import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<String> _readErrorPreview(
  HttpClientResponse resp, {
  int maxChars = 4096,
}) async {
  // 读取响应但只保留前 maxChars 个字符作为错误预览，避免缓存整个响应体。
  final sb = StringBuffer();
  await for (final chunk in resp.transform(utf8.decoder)) {
    if (sb.length < maxChars) {
      final remain = maxChars - sb.length;
      sb.write(chunk.length <= remain ? chunk : chunk.substring(0, remain));
    }
    // 继续消费剩余数据，确保连接能正常结束（但不再累积到内存）。
  }
  return sb.toString();
}

Stream<String> postTextStreamImpl({
  required http.Client client,
  required Uri uri,
  required Map<String, String> headers,
  required String body,
}) async* {
  // IO 端直接用 dart:io 的 HttpClient 做“真正的字节流”读取。
  // `client` 参数仅用于保持跨平台 API 一致。
  final _ = client;

  final ioClient = HttpClient();
  try {
    final req = await ioClient.postUrl(uri);
    for (final e in headers.entries) {
      req.headers.set(e.key, e.value);
    }
    req.write(body);

    final resp = await req.close();
    final status = resp.statusCode;
    if (status < 200 || status >= 300) {
      final preview = await _readErrorPreview(resp);
      throw http.ClientException('HTTP $status: $preview', uri);
    }

    yield* resp.transform(utf8.decoder);
  } finally {
    // 订阅取消时会触发 finally，从而中断网络请求。
    ioClient.close(force: true);
  }
}

