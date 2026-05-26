import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Read picked file bytes on mobile, desktop, and web.
///
/// On Flutter web, [PlatformFile.bytes] is often null even with `withData: true`;
/// use `withReadStream: true` and this helper instead of `file.bytes!`.
Future<Uint8List> readPlatformFileBytes(PlatformFile file) async {
  final Uint8List? direct = file.bytes;
  if (direct != null && direct.isNotEmpty) {
    return direct;
  }

  final Stream<List<int>>? stream = file.readStream;
  if (stream != null) {
    final List<int> chunks = <int>[];
    await for (final List<int> chunk in stream) {
      chunks.addAll(chunk);
    }
    if (chunks.isNotEmpty) {
      return Uint8List.fromList(chunks);
    }
  }

  throw Exception(
    'Could not read "${file.name}". '
    'On web, pick the file again or try a smaller PDF/DOCX.',
  );
}
