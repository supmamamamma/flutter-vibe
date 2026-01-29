import 'dart:convert';

import '../../features/chat/domain/chat_models.dart';

String attachmentsToInlinePrompt(List<ChatAttachment> attachments) {
  if (attachments.isEmpty) return '';

  final lines = <String>[];
  lines.add('【附件】');
  for (final a in attachments) {
    switch (a.kind) {
      case ChatAttachmentKind.text:
        final text = a.data;
        lines.add('---');
        lines.add('TXT: ${a.name} (${a.sizeBytes} bytes)');
        lines.add(text);
        break;
      case ChatAttachmentKind.image:
        lines.add('---');
        lines.add('IMAGE: ${a.name} (${a.mimeType}, ${a.sizeBytes} bytes, base64len=${a.data.length})');
        lines.add('[image data omitted in prompt builder]');
        break;
    }
  }
  return lines.join('\n');
}

String base64FromBytes(List<int> bytes) => base64Encode(bytes);

