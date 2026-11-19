/// Mã chuyển khoản ngắn: `{hostIndex}-{ABCD}` (ví dụ `1-L69H`).
///
/// ABCD = 4 ký tự cuối của `orderCode` (hoặc đoạn định danh đơn / bookingId
/// theo cùng quy tắc admin đang dùng).
abstract final class TransferOrderCode {
  /// Lấy 4 ký tự cuối dùng làm đuôi mã đơn.
  static String last4FromOrderCode(String? orderCode, {String bookingId = ''}) {
    final raw = (orderCode ?? '').trim().toUpperCase();
    if (raw.isNotEmpty) {
      // orderCode dạng "3-L69H" → lấy phần sau dấu "-" nếu đủ 3–4 ký tự.
      final dash = raw.lastIndexOf('-');
      if (dash >= 0 && dash < raw.length - 1) {
        final tail = raw.substring(dash + 1).replaceAll(RegExp(r'[^A-Z0-9]'), '');
        if (tail.length >= 3) {
          return tail.length > 4 ? tail.substring(tail.length - 4) : tail;
        }
      }
      final clean = raw.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (clean.length >= 4) return clean.substring(clean.length - 4);
      if (clean.isNotEmpty) return clean;
    }
    return last4FromBookingId(bookingId);
  }

  /// Trích 4 ký tự cuối từ document ID booking (logic admin hiện có).
  static String last4FromBookingId(String docId) {
    final cleanDoc = docId.trim().toUpperCase();
    if (cleanDoc.isEmpty) return '0000';

    final idParts = cleanDoc.split('_');
    for (var i = 2; i < idParts.length - 1; i++) {
      final part = idParts[i];
      if (part.length >= 8 && !RegExp(r'^20\d{6}$').hasMatch(part)) {
        return part.substring(part.length - 4);
      }
    }

    // Fallback ổn định cho ID cũ không có đoạn mã riêng đủ dài.
    var hash = 0x811C9DC5;
    for (final unit in cleanDoc.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    return hash
        .toRadixString(36)
        .toUpperCase()
        .padLeft(7, '0')
        .substring(3, 7);
  }

  /// Ghép `hostIndex` + 4 ký tự cuối orderCode/bookingId → `1-ABCD`.
  static String build({
    required int hostIndex,
    String? orderCode,
    String bookingId = '',
  }) {
    final index = hostIndex < 1 ? 1 : hostIndex;
    final suffix = last4FromOrderCode(orderCode, bookingId: bookingId);
    return '$index-$suffix';
  }
}
