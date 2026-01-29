import 'package:http/http.dart' as http;

Stream<String> postTextStreamImpl({
  required http.Client client,
  required Uri uri,
  required Map<String, String> headers,
  required String body,
}) {
  throw UnsupportedError('streaming_post is not supported on this platform');
}

