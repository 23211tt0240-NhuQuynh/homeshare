import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

const _maxImageBytes = 8 * 1024 * 1024;
final supportsImageScanning = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

Future<Uint8List?> _downloadImage(String source) async {
  final value = source.trim();
  if (value.startsWith('data:image/')) {
    final comma = value.indexOf(',');
    if (comma < 0) return null;
    final bytes = base64Decode(value.substring(comma + 1));
    return bytes.length <= _maxImageBytes ? Uint8List.fromList(bytes) : null;
  }

  if (value.startsWith('gs://')) {
    try {
      final bytes = await FirebaseStorage.instance
          .refFromURL(value)
          .getData(_maxImageBytes)
          .timeout(const Duration(seconds: 12));
      if (bytes != null && bytes.isNotEmpty) return bytes;
    } catch (error) {
      debugPrint('OCR: Firebase Storage tải ảnh thất bại: $error');
    }
  }

  final uri = Uri.tryParse(value);
  if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 8));
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          response.contentLength <= _maxImageBytes) {
        final builder = BytesBuilder(copy: false);
        await for (final chunk in response.timeout(
          const Duration(seconds: 12),
        )) {
          if (builder.length + chunk.length > _maxImageBytes) return null;
          builder.add(chunk);
        }
        final bytes = builder.takeBytes();
        if (bytes.isNotEmpty) return bytes;
      }
    } catch (error) {
      debugPrint('OCR: tải ảnh qua HTTPS thất bại: $error');
    } finally {
      client.close(force: true);
    }
  }

  if (value.contains('firebasestorage.googleapis.com/')) {
    try {
      final bytes = await FirebaseStorage.instance
          .refFromURL(value)
          .getData(_maxImageBytes)
          .timeout(const Duration(seconds: 12));
      if (bytes != null && bytes.isNotEmpty) return bytes;
    } catch (error) {
      debugPrint('OCR: Firebase Storage fallback thất bại: $error');
    }
  }

  return null;
}

Future<String?> scan(List<String> urls) async {
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return null;
  if (urls.isEmpty) return '';

  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final recognized = <String>[];
  var scannedCount = 0;
  try {
    for (final url in urls.take(8)) {
      try {
        final bytes = await _downloadImage(url);
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
      } catch (error) {
        debugPrint('OCR: không quét được ảnh bài đăng: $error');
      }
    }
    return scannedCount == 0 ? null : recognized.join('\n');
  } finally {
    await recognizer.close();
  }
}
