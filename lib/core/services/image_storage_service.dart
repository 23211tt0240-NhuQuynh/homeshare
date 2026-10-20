import 'dart:convert';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
<<<<<<< HEAD
import 'package:image/image.dart' as img;

/// Nén JPEG trong isolate để ảnh bài đăng nằm dưới giới hạn 1MB của Firestore.
Uint8List compressJpegToLimit((Uint8List, int) args) {
  final (bytes, maxBytes) = args;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  Uint8List? last;
  const steps = <(int, int)>[
    (1024, 70),
    (800, 60),
    (640, 50),
    (480, 40),
  ];

  for (final step in steps) {
    final maxSide = step.$1;
    final quality = step.$2;
    var output = decoded;
    if (output.width > maxSide || output.height > maxSide) {
      output = output.width >= output.height
          ? img.copyResize(output, width: maxSide)
          : img.copyResize(output, height: maxSide);
    }
    final encoded = Uint8List.fromList(img.encodeJpg(output, quality: quality));
    last = encoded;
    if (encoded.length <= maxBytes) return encoded;
  }

  return last ?? bytes;
}

/// Dịch vụ tải ảnh đa phương tiện đồng bộ cho toàn bộ ứng dụng HomeShare.
/// Cùng cơ chế với ảnh chat: Storage nếu có, không thì Base64 Data URI của ảnh thật
/// để máy khác đọc được từ Firestore. Không thay ảnh người dùng bằng ảnh mẫu.
class ImageStorageService {
  final FirebaseStorage? _customStorage;
  final bool skipRemoteUpload;

  ImageStorageService({
    FirebaseStorage? storage,
    this.skipRemoteUpload = false,
  }) : _customStorage = storage;
=======

/// Dịch vụ tải ảnh đa phương tiện đồng bộ cho toàn bộ ứng dụng HomeShare
/// Đảm bảo ảnh luôn hiển thị được trên tất cả các thiết bị khác nhau:
/// 1. Ưu tiên tải lên Firebase Storage lấy public downloadURL.
/// 2. Hỗ trợ Timeout an toàn 12s tránh đơ giao diện khi mạng kém / chưa bật bucket.
/// 3. Tự động fallback nén dữ liệu Base64 Data URI hoặc link ảnh phòng chuẩn khi Storage gặp sự cố.
class ImageStorageService {
  final FirebaseStorage? _customStorage;

  ImageStorageService({FirebaseStorage? storage}) : _customStorage = storage;
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62

  FirebaseStorage get _storage => _customStorage ?? FirebaseStorage.instance;

  // Danh sách ảnh mẫu phòng trọ chất lượng cao phòng khi Storage offline/thiếu cấu hình
  static const List<String> _sampleRoomImages = [
    'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=800',
    'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=800',
    'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=800',
    'https://images.unsplash.com/photo-1513694203232-719a280e022f?w=800',
    'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?w=800',
  ];

<<<<<<< HEAD
  /// Tải 1 ảnh lên Firebase Storage. Khi Storage chưa bật hoặc lỗi,
  /// lưu chính ảnh đó dạng Base64 (giống tin nhắn chat) để máy khác xem được.
=======
  /// Tải 1 ảnh lên Firebase Storage với cơ chế fallback tự động
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
  Future<String> uploadSingleImage({
    required String filePath,
    required String folder,
    required String fileName,
    int sampleIndex = 0,
<<<<<<< HEAD
    int maxBytes = 180 * 1024,
=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
  }) async {
    // Nếu là URL online sẵn hoặc Base64 data thì giữ nguyên
    if (filePath.startsWith('http://') ||
        filePath.startsWith('https://') ||
        filePath.startsWith('data:image')) {
      return filePath;
    }

    final file = File(filePath);
    if (!file.existsSync()) {
      debugPrint('[ImageStorageService] File không tồn tại tại $filePath, dùng ảnh fallback.');
      return _sampleRoomImages[sampleIndex % _sampleRoomImages.length];
    }

<<<<<<< HEAD
    Uint8List prepared;
    try {
      final raw = await file.readAsBytes();
      prepared = raw.length <= maxBytes ? raw : await compute(compressJpegToLimit, (raw, maxBytes));
      if (prepared.length > maxBytes && prepared != raw) {
        debugPrint('[ImageStorageService] Ảnh sau nén vẫn ${prepared.length} bytes (ngưỡng $maxBytes).');
      }
    } catch (e) {
      debugPrint('[ImageStorageService] Không đọc được file $filePath: $e');
      return _sampleRoomImages[sampleIndex % _sampleRoomImages.length];
    }

    if (!skipRemoteUpload) {
      try {
        final storageRef = _storage.ref().child('$folder/$fileName');
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'uploadedAt': DateTime.now().toIso8601String()},
        );

        final uploadTask = storageRef.putData(prepared, metadata);
        final snapshot = await uploadTask.timeout(const Duration(seconds: 8));
        final downloadUrl = await snapshot.ref.getDownloadURL();
        debugPrint('[ImageStorageService] Tải ảnh lên Firebase Storage thành công: $downloadUrl');
        return downloadUrl;
      } catch (e) {
        debugPrint('[ImageStorageService] Storage chưa dùng được ($e). Lưu ảnh thật vào Firestore dạng Base64.');
      }
    }

    return 'data:image/jpeg;base64,${base64Encode(prepared)}';
=======
    try {
      final storageRef = _storage.ref().child('$folder/$fileName');
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploadedAt': DateTime.now().toIso8601String()},
      );

      final uploadTask = storageRef.putFile(file, metadata);
      final snapshot = await uploadTask.timeout(const Duration(seconds: 12));
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('[ImageStorageService] Tải ảnh lên Firebase Storage thành công: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('[ImageStorageService] Lỗi upload Firebase Storage ($e), tiến hành fallback đa nền tảng...');

      try {
        // Fallback 1: Nếu file nhỏ hơn 300KB, mã hóa Base64 Data URI để các máy khác hiển thị được 100%
        final fileLength = await file.length();
        if (fileLength <= 300 * 1024) {
          final bytes = await file.readAsBytes();
          final base64String = base64Encode(bytes);
          return 'data:image/jpeg;base64,$base64String';
        }
      } catch (encodeErr) {
        debugPrint('[ImageStorageService] Lỗi mã hóa Base64: $encodeErr');
      }

      // Fallback 2: Sử dụng bộ ảnh phòng chuẩn đẹp của HomeShare
      return _sampleRoomImages[sampleIndex % _sampleRoomImages.length];
    }
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
  }

  /// Tải danh sách nhiều ảnh cùng lúc cho bài đăng ở ghép / đăng phòng
  Future<List<String>> uploadRoommateImages({
    required List<String> localPaths,
    required String postId,
  }) async {
    if (localPaths.isEmpty) return [];

    final List<String> uploadedUrls = [];
    final timestamp = DateTime.now().millisecondsSinceEpoch;

<<<<<<< HEAD
    // Base64 phình ~4/3 và model ghi ảnh ở cả `images` lẫn `anhTinOGhep`.
    // Giữ tổng ảnh thô khoảng 220KB để document Firestore không vượt 1MB.
    final perImageBudget = ((220 * 1024) / localPaths.length).floor().clamp(40 * 1024, 120 * 1024).toInt();

=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
    for (int i = 0; i < localPaths.length; i++) {
      final path = localPaths[i];
      final fileName = '${postId}_img_${timestamp}_$i.jpg';
      final url = await uploadSingleImage(
        filePath: path,
        folder: 'roommate_posts/$postId',
        fileName: fileName,
        sampleIndex: i,
<<<<<<< HEAD
        maxBytes: perImageBudget,
=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
      );
      uploadedUrls.add(url);
    }

    return uploadedUrls;
  }
<<<<<<< HEAD

  /// Tải ảnh đại diện từ bộ nhớ. Storage nếu có, không thì Base64 của chính ảnh đó.
  Future<String> uploadImageBytes({
    required Uint8List bytes,
    required String folder,
    required String fileName,
  }) async {
    const maxBytes = 180 * 1024;
    final prepared = bytes.length <= maxBytes ? bytes : await compute(compressJpegToLimit, (bytes, maxBytes));

    if (!skipRemoteUpload) {
      try {
        final storageRef = _storage.ref().child('$folder/$fileName');
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'uploadedAt': DateTime.now().toIso8601String()},
        );
        final snapshot = await storageRef.putData(prepared, metadata).timeout(const Duration(seconds: 8));
        return await snapshot.ref.getDownloadURL();
      } catch (e) {
        debugPrint('[ImageStorageService] Storage chưa dùng được ($e). Lưu ảnh đại diện dạng Base64.');
      }
    }

    return 'data:image/jpeg;base64,${base64Encode(prepared)}';
  }
=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
}

final imageStorageServiceProvider = Provider<ImageStorageService>((ref) {
  return ImageStorageService();
});
