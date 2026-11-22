import 'dart:math';
import 'package:intl/intl.dart';
import 'transfer_order_code.dart';
import 'vietnamese_utils.dart';

/// Bộ sinh mã định danh và Document ID chuẩn hóa cho hệ thống HomeShare
/// Nguồn chân lý: SQL_NHOM4_CHUYENDEDIDONG.sql & Database homeShare.drawio
class IdGenerator {
  /// Sinh mã người dùng theo vai trò chuẩn SQL:
  /// - Chủ trọ (Host): CT001, CT002, CT358...
  /// - Người thuê (Renter): NT001, NT002, NT358...
  /// - Quản trị viên (Admin): ADMIN01, ADMIN02...
  static String userCode({String role = 'renter', String? seed, int? orderNumber}) {
    final cleanRole = role.toLowerCase().trim();
    final isHost = cleanRole == 'host' || cleanRole == 'chutro' || cleanRole == 'chu tro';
    final isAdmin = cleanRole == 'admin' || cleanRole == 'quantri' || cleanRole == 'quan tri vien';

    final prefix = isHost
        ? 'CT'
        : isAdmin
            ? 'ADMIN'
            : 'NT';

    if (orderNumber != null) {
      if (isAdmin) {
        return '$prefix${orderNumber.toString().padLeft(2, '0')}';
      }
      return '$prefix${orderNumber.toString().padLeft(3, '0')}';
    }

    if (seed != null && seed.isNotEmpty) {
      var hash = 0;
      for (var i = 0; i < seed.length; i++) {
        hash = (hash * 31 + seed.codeUnitAt(i)) & 0x7FFFFFFF;
      }
      if (isAdmin) {
        final val = (hash % 90) + 10;
        return '$prefix$val';
      }
      final val = (hash % 900) + 100;
      return '$prefix$val';
    }

    final rand = Random();
    if (isAdmin) {
      return '$prefix${10 + rand.nextInt(90)}';
    }
    return '$prefix${100 + rand.nextInt(900)}';
  }

  /// Sinh Document ID Tiện ích (amenities):
  /// "Wifi tốc độ cao" -> "TI_WIFI_TOC_DO_CAO"
  /// "Máy lạnh" -> "TI_MAY_LANH"
  static String amenity(String name) {
    final clean = removeVietnameseDiacritics(name)
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return clean.startsWith('TI_') ? clean : 'TI_$clean';
  }

  /// Sinh Mã phòng tự động theo thứ tự tăng dần (Lựa chọn A):
  /// orderNumber = 1 -> "P001"
  /// orderNumber = 2 -> "P002"
  static String roomCode(int orderNumber) {
    final safeOrder = orderNumber > 0 ? orderNumber : 1;
    final numStr = safeOrder.toString().padLeft(3, '0');
    return 'P$numStr';
  }

  /// Sinh Document ID Phòng trọ trong Firestore:
  /// - Nếu có mã chủ trọ: P_CT001_P001
  /// - Nếu không: P_P001 hoặc P001
  static String roomDocId(String roomCode, {String? hostCode}) {
    final clean = roomCode.trim().toUpperCase().replaceAll(' ', '_');
    if (hostCode != null && hostCode.isNotEmpty) {
      final cleanHost = hostCode.trim().toUpperCase();
      return 'P_${cleanHost}_$clean';
    }
    return clean.startsWith('P_') ? clean : 'P_$clean';
  }

  /// Sinh Document ID Bài đăng cho thuê (posts):
  /// BD_20261016_1001
  static String post({String? roomCode}) {
    final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    final rand = 1000 + Random().nextInt(9000);
    final pCode = (roomCode != null && roomCode.isNotEmpty) ? '_${roomCode.trim().toUpperCase()}' : '';
    return 'BD_$dateStr${pCode}_$rand';
  }

  /// Sinh Document ID Đơn đặt phòng (bookings):
  /// DP_20261016_P001_NT001
  static String booking({String? renterCode, String? roomCode}) {
    final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
    final rCode = (renterCode != null && renterCode.isNotEmpty) ? renterCode : 'NT001';
    final pCode = (roomCode != null && roomCode.isNotEmpty && roomCode != 'P001') ? roomCode : '';
    final rand = 1000 + Random().nextInt(9000);
    return pCode.isNotEmpty ? 'DP_${dateStr}_${pCode}_${rCode}_$rand' : 'DP_${dateStr}_${rCode}_$rand';
  }

  /// Sinh nội dung chuyển khoản ngắn: `{hostIndex}-{ABCD}`.
  /// ABCD = 4 ký tự cuối `orderCode` (hoặc bookingId).
  static String transferContent({
    int hostIndex = 1,
    String? orderCode,
    String bookingId = '',
    String? renterCode,
    String? hostCode,
    String? roomCode,
  }) {
    if (orderCode != null || bookingId.isNotEmpty || (renterCode == null && roomCode == null)) {
      return TransferOrderCode.build(
        hostIndex: hostIndex,
        orderCode: orderCode,
        bookingId: bookingId,
      );
    }
    final r = (renterCode ?? '').trim().toUpperCase();
    final p = (roomCode ?? '').trim().toUpperCase();
    final parts = <String>[];
    if (r.isNotEmpty) parts.add(r);
    if (p.isNotEmpty) parts.add(p);
    return parts.join(' ');
  }

  /// Sinh Document ID Thông báo (notifications):
  /// TB_1729053891000
  static String notification() {
    return 'TB_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Sinh Document ID báo cáo chủ trọ (reports):
  /// BC_1729053891000
  static String hostReport() {
    return 'BC_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Sinh Document ID Nhật ký kiểm toán (audit_logs):
  /// LOG_1729053891000
  static String auditLog() {
    return 'LOG_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Sinh Document ID liên kết phòng - tiện ích (TienIch_Phong):
  /// P001_TI_WIFI_TOC_DO_CAO
  static String roomAmenity(String roomId, String amenityId) {
    return '${roomId}_$amenityId';
  }

  /// Sinh Document ID Báo cáo bài đăng chủ trọ (reports):
  /// BCB_1729837200000
  static String postReport() {
    return 'BCB_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Sinh Document ID Báo cáo sự cố phòng (reports):
  /// SC_1729837200000
  static String roomIssue() {
    return 'SC_${DateTime.now().millisecondsSinceEpoch}';
  }
}
