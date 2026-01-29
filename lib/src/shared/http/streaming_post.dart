import 'package:http/http.dart' as http;

import 'streaming_post_stub.dart'
    if (dart.library.html) 'streaming_post_web.dart'
    if (dart.library.io) 'streaming_post_io.dart';

/// 发起 POST 请求并以“文本流”的方式产出响应数据。
///
/// 说明：
/// - 在 IO 平台：基于 `http.Client.send`，支持真正的字节流。
/// - 在 Web：基于 XHR `onProgress` 读取 `responseText` 的增量。
Stream<String> postTextStream({
  required http.Client client,
  required Uri uri,
  required Map<String, String> headers,
  required String body,
}) {
  return postTextStreamImpl(
    client: client,
    uri: uri,
    headers: headers,
    body: body,
  );
}

