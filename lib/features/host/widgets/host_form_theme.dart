import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../providers/host_management_provider.dart';

/// Bộ Theme, Token màu và Styles dùng chung cho các màn hình Host
class HostTheme {
  const HostTheme._();

  // Bảng màu chuẩn Host
  static const Color primary = Color(0xFF1E60F2);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0xFFEFF6FF);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color cardBorder = Color(0xFFD9E7FF);
  static const Color inputBorder = Color(0xFFCBD5E1);
  static const Color inputFocusBorder = Color(0xFF1E60F2);
  static const Color inputEnabledBorder = Color(0xFF93C5FD);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color chipBorder = Color(0xFF93C5FD);
  static const Color chipSelectedBg = Color(0xFFDBEAFE);
  static const Color chipSelectedText = Color(0xFF1D4ED8);
  static const Color disabledBackground = Color(0xFFF1F5F9);

  // Border radius chuẩn
  static final BorderRadius radius12 = BorderRadius.circular(12);
  static final BorderRadius radius14 = BorderRadius.circular(14);
  static final BorderRadius radius16 = BorderRadius.circular(16);

  // BoxDecorations dùng chung
  static BoxDecoration cardDecoration({
    Color backgroundColor = Colors.white,
    Color borderColor = cardBorder,
    double borderWidth = 1.2,
    BorderRadius? borderRadius,
  }) => BoxDecoration(
    color: backgroundColor,
    borderRadius: borderRadius ?? radius16,
    border: Border.all(color: borderColor, width: borderWidth),
  );

  // InputDecoration dùng chung cho các TextFormField & DropdownFormField
  static InputDecoration inputDecoration({
    String? labelText,
    String? hintText,
    String? suffixText,
    TextStyle? suffixStyle,
    Widget? prefixIcon,
    Widget? suffixIcon,
    Color? fillColor,
    bool isFilled = true,
    bool filled = true,
    EdgeInsetsGeometry? contentPadding,
    Color borderColor = inputBorder,
    Color focusedBorderColor = inputFocusBorder,
    double focusedBorderWidth = 1.5,
    Color? enabledBorderColor,
    double enabledBorderWidth = 1.0,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 13, color: textMuted),
      suffixText: suffixText,
      suffixStyle:
          suffixStyle ??
          const TextStyle(
            color: textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: isFilled && filled,
      fillColor: fillColor ?? Colors.white,
      contentPadding:
          contentPadding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: radius14,
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius14,
        borderSide: BorderSide(
          color: enabledBorderColor ?? borderColor,
          width: enabledBorderWidth,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius14,
        borderSide: BorderSide(
          color: focusedBorderColor,
          width: focusedBorderWidth,
        ),
      ),
    );
  }
}

/// Tiện ích hình ảnh & tiền tệ dùng chung cho các màn hình Host
class HostImageUtils {
  const HostImageUtils._();

  /// Làm sạch URL ảnh từ String, Map Firestore, JSON hoặc URL đã bọc ngoặc kép
  static String cleanImageUrl(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map) {
      final u =
          (raw['url'] ??
                  raw['duongDan'] ??
                  raw['image'] ??
                  raw['imageUrl'] ??
                  raw['link'] ??
                  '')
              .toString()
              .trim();
      return cleanImageUrl(u);
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

  /// Nhận diện Content-Type của file ảnh qua magic bytes (PNG / JPEG)
  static String? detectContentType(Uint8List bytes) {
    final isPng =
        bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71 &&
        bytes[4] == 13 &&
        bytes[5] == 10 &&
        bytes[6] == 26 &&
        bytes[7] == 10;
    final isJpg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    final isWebp =
        bytes.length >= 12 &&
        bytes[0] == 82 &&
        bytes[1] == 73 &&
        bytes[2] == 70 &&
        bytes[3] == 70 &&
        bytes[8] == 87 &&
        bytes[9] == 69 &&
        bytes[10] == 66 &&
        bytes[11] == 80;
    if (isPng) return 'image/png';
    if (isJpg) return 'image/jpeg';
    if (isWebp) return 'image/webp';
    return null;
  }

  /// Định dạng tiền tệ VNĐ có dấu chấm (.) ngăn cách hàng nghìn (vd: 1000000 -> 1.000.000)
  static String formatCurrency(String text) {
    if (text.isEmpty) return 'Chưa nhập';
    final clean = text.replaceAll(RegExp(r'[^0-9]'), '');
    final numVal = int.tryParse(clean);
    if (numVal == null || numVal <= 0) return 'Chưa nhập';
    return clean.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}

/// Thẻ Card bao bọc một phần form với Header icon + title + trailing
class HostCardSection extends StatelessWidget {
  const HostCardSection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(14),
    this.margin,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: HostTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: HostTheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: HostTheme.textDark,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Tiêu đề phân đoạn lớn có icon và tuỳ chọn chevron bên phải
class HostSectionTitle extends StatelessWidget {
  const HostSectionTitle({
    super.key,
    required this.title,
    required this.icon,
    this.showChevron = false,
  });

  final String title;
  final IconData icon;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: HostTheme.primary, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: HostTheme.textDark,
            ),
          ),
        ),
        if (showChevron)
          const Icon(
            Icons.chevron_right_rounded,
            color: HostTheme.primary,
            size: 22,
          ),
      ],
    );
  }
}

/// Nút "Thêm ảnh" chuẩn 92x92 với viền bo tròn và icon
class HostAddImageButton extends StatelessWidget {
  const HostAddImageButton({
    super.key,
    required this.onTap,
    this.disabled = false,
  });

  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: HostTheme.radius12,
      child: Container(
        width: 92,
        height: 92,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: HostTheme.background,
          borderRadius: HostTheme.radius12,
          border: Border.all(color: const Color(0xFF8DB8FF), width: 1.5),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: HostTheme.primary,
              size: 26,
            ),
            SizedBox(height: 4),
            Text(
              'Thêm ảnh',
              style: TextStyle(
                fontSize: 11,
                color: HostTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ preview ảnh (hỗ trợ cả String URL, File, Base64 và HostUpload)
class HostImageThumbnail extends StatelessWidget {
  const HostImageThumbnail({
    super.key,
    required this.index,
    this.rawUrl,
    this.upload,
    this.isCover = false,
    this.isLocked = false,
    this.onRemove,
  });

  final int index;
  final String? rawUrl;
  final HostUpload? upload;
  final bool isCover;
  final bool isLocked;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 92,
          height: 92,
          margin: const EdgeInsets.only(right: 10),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: HostTheme.radius12,
            border: Border.all(
              color: rawUrl != null
                  ? HostTheme.cardBorder
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: upload != null
              ? Image.memory(upload!.bytes, fit: BoxFit.cover)
              : _buildImage(rawUrl ?? ''),
        ),
        if (!isLocked && onRemove != null)
          Positioned(
            top: 4,
            right: 14,
            child: InkWell(
              onTap: onRemove,
              child: const CircleAvatar(
                radius: 11,
                backgroundColor: Color(0x99000000),
                child: Icon(Icons.close, size: 13, color: Colors.white),
              ),
            ),
          ),
        if (isLocked)
          Positioned(
            top: 4,
            right: 14,
            child: Container(
              padding: const EdgeInsets.all(3.5),
              decoration: const BoxDecoration(
                color: Color(0xCC0F172A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, size: 12, color: Colors.white),
            ),
          ),
        if (isLocked)
          Positioned(
            left: 5,
            bottom: isCover ? 22 : 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Ảnh từ phòng',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        if (isCover)
          Positioned(
            left: 5,
            bottom: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: HostTheme.primary,
                borderRadius: BorderRadius.circular(5),
              ),
              child: const Text(
                'Ảnh bìa',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImage(String url) {
    final clean = HostImageUtils.cleanImageUrl(url);
    if (clean.isEmpty) return _buildPlaceholder();

    if (clean.startsWith('data:image') || clean.startsWith('base64,')) {
      try {
        final commaIdx = clean.indexOf(',');
        final base64Str = commaIdx != -1
            ? clean.substring(commaIdx + 1)
            : clean;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildPlaceholder(),
        );
      } catch (_) {
        return _buildPlaceholder();
      }
    }

    if (!kIsWeb &&
        (clean.startsWith('/') ||
            clean.startsWith('file:') ||
            clean.contains(':\\') ||
            clean.contains(':/'))) {
      try {
        final filePath = clean.startsWith('file://')
            ? clean.replaceFirst('file://', '')
            : clean;
        final file = File(filePath);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildPlaceholder(),
          );
        }
      } catch (_) {}
    }

    if (clean.startsWith('assets/')) {
      return Image.asset(
        clean,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildPlaceholder(),
      );
    }

    return Image.network(
      clean,
      fit: BoxFit.cover,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: HostTheme.background,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: HostTheme.primary,
              ),
            ),
          ),
        );
      },
      errorBuilder: (_, _, _) => _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, color: HostTheme.textMuted, size: 24),
            SizedBox(height: 2),
            Text(
              'Ảnh phòng',
              style: TextStyle(
                fontSize: 9,
                color: HostTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ tiện ích chuẩn (hỗ trợ checkbox, nhãn tùy chọn, nút xóa cho tiện ích riêng)
class HostAmenityTile extends StatelessWidget {
  const HostAmenityTile({
    super.key,
    required this.name,
    required this.isSelected,
    this.isCustom = false,
    this.isLocked = false,
    this.onTap,
    this.onDeleteCustom,
  });

  final String name;
  final bool isSelected;
  final bool isCustom;
  final bool isLocked;
  final VoidCallback? onTap;
  final VoidCallback? onDeleteCustom;

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    final Color bgColor;
    final Color checkColor;

    if (isSelected) {
      borderColor = isLocked
          ? const Color(0xFFCBD5E1)
          : (isCustom ? const Color(0xFF60A5FA) : const Color(0xFF93C5FD));
      bgColor = isLocked
          ? const Color(0xFFF1F5F9)
          : (isCustom ? const Color(0xFFEFF6FF) : const Color(0xFFF0F7FF));
      checkColor = isLocked ? const Color(0xFF64748B) : HostTheme.primary;
    } else {
      borderColor = const Color(0xFFE2E8F0);
      bgColor = HostTheme.background;
      checkColor = const Color(0xFFCBD5E1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: HostTheme.radius14,
        border: Border.all(color: borderColor, width: isSelected ? 1.4 : 1),
      ),
      child: InkWell(
        key: ValueKey('amenity_tile_$name'),
        borderRadius: HostTheme.radius14,
        onTap: isLocked ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isSelected ? checkColor : Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: isSelected ? checkColor : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isCustom
                              ? const Color(0xFF1E3A8A)
                              : const Color(0xFF1E40AF))
                        : HostTheme.textDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (isLocked) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 12, color: Color(0xFF475569)),
                      SizedBox(width: 4),
                      Text(
                        'Cố định từ phòng',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (isCustom) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: HostTheme.chipSelectedBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Tùy chọn',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: HostTheme.chipSelectedText,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  key: ValueKey('delete_custom_amenity_$name'),
                  icon: const Icon(
                    Icons.close,
                    size: 16,
                    color: HostTheme.textSecondary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onDeleteCustom,
                ),
              ] else if (isSelected) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: HostTheme.chipSelectedBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Đã chọn',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: HostTheme.chipSelectedText,
                    ),
                  ),
                ),
              ] else ...[
                const Icon(Icons.add, size: 18, color: HostTheme.textMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
