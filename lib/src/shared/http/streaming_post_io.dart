import 'dart:convert';

import 'package:http/http.dart' as http;

Stream<String> postTextStreamImpl({
  required http.Client client,
  required Uri uri,
  required Map<String, String> headers,
  required String body,
}) async* {
  final req = http.Request('POST', uri);
  req.headers.addAll(headers);
  req.body = body;

  final resp = await client.send(req);
  if (resp.statusCode < 200 || resp.statusCode >= 300) {
    final text = await resp.stream.bytesToString();
    throw http.ClientException('HTTP ${resp.statusCode}: $text', uri);
  }

  yield* resp.stream.transform(utf8.decoder);
}

