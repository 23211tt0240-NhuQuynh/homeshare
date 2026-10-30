import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

Future<String?> scan(List<String> urls) async {
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return null;
  if (urls.isEmpty) return '';

  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final recognized = <String>[];
  var scannedCount = 0;
  try {
    for (final url in urls.take(8)) {
      try {
        final bytes = await FirebaseStorage.instance
            .refFromURL(url)
            .getData(8 * 1024 * 1024);
        if (bytes == null || bytes.isEmpty) continue;
        final fileName =
            'post_review_${DateTime.now().microsecondsSinceEpoch}.jpg';
        final file = File('${Directory.systemTemp.path}/$fileName');
        await file.writeAsBytes(bytes, flush: true);
        try {
          final result = await recognizer.processImage(
            InputImage.fromFilePath(file.path),
          );
          scannedCount++;
          if (result.text.trim().isNotEmpty) recognized.add(result.text);
        } finally {
          if (await file.exists()) await file.delete();
        }
      } catch (_) {
        // Skip an unreadable or non-Firebase image; continue with other photos.
      }
    }
    return scannedCount == 0 ? null : recognized.join('\n');
  } finally {
    await recognizer.close();
  }
}
