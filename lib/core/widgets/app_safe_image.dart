import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

/// Widget hiển thị ảnh an toàn, đồng bộ cho toàn bộ ứng dụng HomeShare:
/// Hỗ trợ cả 4 trường hợp từ Firebase:
/// 1. HTTP/HTTPS (Firebase Storage download URL, web URL)
/// 2. Base64 Data URI (`data:image/jpeg;base64,...`) khi Storage fallback
/// 3. Chuỗi Base64 thô (raw base64 string)
/// 4. Đường dẫn File cục bộ
/// Tự động làm sạch URL bị bọc ngoặc kép hoặc định dạng JSON từ Firestore.
class AppSafeImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadiusGeometry? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final IconData fallbackIcon;
  final double iconSize;

  const AppSafeImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.fallbackIcon = Icons.apartment,
    this.iconSize = 40,
  });

  /// Làm sạch URL ảnh từ String thô, JSON map, hoặc bị bọc quote
  static String cleanUrl(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map) {
      final u = (raw['url'] ??
              raw['duongDan'] ??
              raw['image'] ??
              raw['imageUrl'] ??
              raw['link'] ??
              '')
          .toString()
          .trim();
      return cleanUrl(u);
    }
    var s = raw.toString().trim();
    if (s.startsWith('"') && s.endsWith('"') && s.length > 2) {
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.startsWith("'") && s.endsWith("'") && s.length > 2) {
      s = s.substring(1, s.length - 1).trim();
    }
    if (s.startsWith('{') && s.endsWith('}')) {
      final match = RegExp(
        r'(?:duongDan|url|image|imageUrl|link):\s*([^,}]+)',
      ).firstMatch(s);
      if (match != null) {
        s = match.group(1)!.trim().replaceAll('"', '').replaceAll("'", "");
      }
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final clean = cleanUrl(imageUrl);
    Widget content;

    if (clean.isEmpty) {
      content = _buildFallback();
    } else if (clean.startsWith('data:image') || clean.contains('base64,')) {
      content = _buildBase64Image(clean);
    } else if (clean.startsWith('http://') || clean.startsWith('https://')) {
      content = _buildNetworkImage(clean);
    } else if (!clean.startsWith('http') && clean.length > 120 && _looksLikeBase64(clean)) {
      content = _buildBase64Image(clean);
    } else {
      content = _buildFileOrFallback(clean);
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: SizedBox(
          width: width,
          height: height,
          child: content,
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: content,
    );
  }

  bool _looksLikeBase64(String str) {
    final s = str.trim();
    if (s.length < 50) return false;
    final validChars = RegExp(r'^[A-Za-z0-9+/=]+$');
    final sample = s.length > 200 ? s.substring(0, 200) : s;
    return validChars.hasMatch(sample);
  }

  Widget _buildNetworkImage(String url) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('[AppSafeImage] Lỗi tải ảnh network $url: $error');
        return _buildFallback();
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ??
            Container(
              width: width,
              height: height,
              color: const Color(0xFFF1F5F9),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
      },
    );
  }

  Widget _buildBase64Image(String rawBase64) {
    try {
      final comma = rawBase64.indexOf(',');
      final cleanBase64 = comma != -1 ? rawBase64.substring(comma + 1) : rawBase64;
      final bytes = base64Decode(cleanBase64.trim().replaceAll(RegExp(r'\s+'), ''));
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('[AppSafeImage] Lỗi giải mã ảnh Base64: $error');
          return _buildFallback();
        },
      );
    } catch (e) {
      debugPrint('[AppSafeImage] Exception decode Base64: $e');
      return _buildFallback();
    }
  }

  Widget _buildFileOrFallback(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => _buildFallback(),
        );
      }
    } catch (_) {}
    return _buildFallback();
  }

  Widget _buildFallback() {
    return errorWidget ??
        placeholder ??
        Container(
          width: width,
          height: height,
          color: const Color(0xFFF1F5F9),
          alignment: Alignment.center,
          child: Icon(
            fallbackIcon,
            size: iconSize,
            color: const Color(0xFF94A3B8),
          ),
        );
  }
}

/// Helper phân giải ImageProvider cho CircleAvatar / BoxDecoration
class AppSafeImageProvider {
  const AppSafeImageProvider._();

  static ImageProvider? resolve(dynamic raw) {
    if (raw == null) return null;
    final clean = AppSafeImage.cleanUrl(raw);
    if (clean.isEmpty) return null;

    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      return NetworkImage(clean);
    }
    if (clean.startsWith('data:image') || clean.contains('base64,')) {
      try {
        final comma = clean.indexOf(',');
        final data = comma == -1 ? clean : clean.substring(comma + 1);
        final bytes = base64Decode(data.trim().replaceAll(RegExp(r'\s+'), ''));
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
