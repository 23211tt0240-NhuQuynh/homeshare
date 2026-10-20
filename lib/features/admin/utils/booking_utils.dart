import 'package:cloud_firestore/cloud_firestore.dart';

/// Chuẩn dữ liệu đơn (collection `bookings`) dùng chung cho app Admin và app Người thuê.
///
/// TRƯỜNG `status` (giá trị tiếng Anh, khớp màn đơn thuê của người thuê):
///   pending_payment  đã tạo đơn, chưa báo chuyển khoản
///   pending          người thuê báo đã chuyển khoản, chờ admin xác nhận
///   approved         admin đã xác nhận tiền cọc
///   paid             admin đã xác nhận thanh toán đủ
///   active           đang ở
///   cancelled / rejected
///
/// Giải ngân cho chủ trọ KHÔNG đổi `status`, mà đánh dấu bằng `disbursedAt` + `isDisbursed`.
///
/// Các trường khác: orderCode, userCode, renterId, renterName, renterPhone,
/// roomId, roomTitle, roomAddress, rentPrice, depositAmount, totalPayable,
/// paymentAmount, paymentOption ('deposit' | 'full'), transferNote, deadline,
/// note, subTag, hostName, isPaid, isCheckIn, isDisbursed,
/// createdAt, approvedAt, updatedAt, disbursedAt.
class BookingUtils {
  // Nhóm hiển thị trong app Admin (tính từ status + disbursedAt)
  static const String statusPending = 'pending'; // tab Chờ xác nhận
  static const String statusDepositPaid = 'deposit_paid'; // tab Đã cọc
  static const String statusCompleted = 'completed'; // tab Đã giải ngân / trả hết

  /// Tên trường tiếng Việt cũ -> tên chuẩn. Chỉ để đọc dữ liệu cũ và để migrate.
  /// Xóa map này sau khi đã migrate xong.
  static const Map<String, String> _legacyVietnamese = {
    'trangThai': 'status',
    'maDon': 'orderCode',
    'maNguoiDung': 'userCode',
    'nguoiDungId': 'renterId',
    'nguoiDung_Id': 'renterId',
    'khachXemId': 'renterId',
    'tenNguoiO': 'renterName',
    'sdtNguoiO': 'renterPhone',
    'tieuDePhong': 'roomTitle',
    'diaChiPhong': 'roomAddress',
    'giaThue': 'rentPrice',
    'tienCoc': 'depositAmount',
    'tongPhaiTra': 'totalPayable',
    'hinhThucThanhToan': 'paymentOption',
    'ghiChuChuyenKhoan': 'transferNote',
    'hanChuyen': 'deadline',
    'ghiChu': 'note',
    'moTa': 'subTag',
    'tenChuNha': 'hostName',
    'daThanhToan': 'isPaid',
    'daNhanPhong': 'isCheckIn',
    'ngayTao': 'createdAt',
    'ngayDuyet': 'approvedAt',
    'ngayCapNhat': 'updatedAt',
    'ngayGiaiNgan': 'disbursedAt',
    'ngayXacNhan': 'confirmedAt',
  };

  /// Tên khác (chỉ để đọc, không bị xóa khi migrate).
  static const Map<String, String> _aliases = {
    'bookingCode': 'orderCode',
    'renterUserCode': 'userCode',
    'userName': 'renterName',
    'landlordName': 'hostName',
    'paymentType': 'paymentOption',
    'deposit': 'depositAmount',
    'totalAmount': 'totalPayable',
    'amount': 'depositAmount',
    'userId': 'renterId',
    'soTienThanhToan': 'paymentAmount',
    'description': 'subTag',
  };

  static const Map<String, int> _rank = {
    'pending_payment': 0,
    'pending': 1,
    'approved': 2,
    'paid': 3,
    'active': 4,
    'completed': 5, // đã giải ngân
  };

  /// Chuẩn hóa một giá trị trạng thái (cũ/mới) về giá trị chuẩn; null nếu không nhận ra.
  static String? _normalizeStatusValue(dynamic v) {
    switch ((v ?? '').toString().trim().toLowerCase()) {
      case 'pending_payment':
      case 'chothanhtoan':
        return 'pending_payment';
      case 'pending':
      case 'choxacnhan':
      case 'choduyet':
      case 'dangxuly':
      case 'pending_confirmation':
      case 'disburse':
        return 'pending';
      case 'approved':
      case 'deposit_paid':
      case 'dacoc':
      case 'daduyet':
      case 'confirmed':
        return 'approved';
      case 'paid':
      case 'full_paid':
      case 'dathanhtoan':
        return 'paid';
      case 'active':
      case 'dango':
      case 'danhanphong':
        return 'active';
      case 'completed':
      case 'dagiaingan':
        return 'completed';
      case 'cancelled':
      case 'canceled':
      case 'dahuy':
        return 'cancelled';
      case 'rejected':
      case 'tuchoi':
        return 'rejected';
    }
    return null;
  }

  /// Bản sao của [data] với đủ trường tên chuẩn (tiếng Anh) và `status` đã chuẩn hóa.
  /// Khi `status` và `trangThai` mâu thuẫn, lấy trạng thái tiến xa hơn
  /// (trừ khi đơn đã hủy/từ chối).
  static Map<String, dynamic> canonical(Map<String, dynamic> data) {
    final out = Map<String, dynamic>.from(data);

    void fill(Map<String, String> map) {
      map.forEach((oldKey, newKey) {
        if (data[oldKey] != null && out[newKey] == null) {
          out[newKey] = data[oldKey];
        }
      });
    }

    fill(_legacyVietnamese);
    fill(_aliases);

    final a = _normalizeStatusValue(data['status']);
    final b = _normalizeStatusValue(data['trangThai']);
    String? resolved;
    if (a == 'cancelled' || a == 'rejected') {
      resolved = a;
    } else if (b == 'cancelled' || b == 'rejected') {
      resolved = b;
    } else if (a != null && b != null) {
      resolved = (_rank[b] ?? 0) > (_rank[a] ?? 0) ? b : a;
    } else {
      resolved = a ?? b;
    }

    final po = (out['paymentOption'] ?? 'deposit').toString().toLowerCase();
    out['paymentOption'] =
        (po == 'full' || po == 'toanbo' || po == 'trahet') ? 'full' : 'deposit';

    // Đơn chỉ được coi là đã giải ngân khi Admin thực sự đã chuyển tiền và ghi nhận
    bool disbursed = out['disbursedAt'] != null ||
        out['isDisbursed'] == true ||
        data['daGiaiNgan'] == true ||
        data['dagiaingan'] == true;

    if (resolved == 'completed' && !disbursed) {
      resolved = out['paymentOption'] == 'full' ? 'paid' : 'approved';
    }
    if (resolved == null && out['isPaid'] == true) resolved = 'approved';

    final rawSt = (data['status'] ?? '').toString().toLowerCase();
    final rawTrangThai = (data['trangThai'] ?? '').toString().toLowerCase();
    final bool isCheckIn = out['isCheckIn'] == true ||
        out['daNhanPhong'] == true ||
        rawSt == 'dango' ||
        rawSt == 'danhanphong' ||
        rawTrangThai == 'dango' ||
        rawTrangThai == 'danhanphong' ||
        resolved == 'active';

    out['status'] = resolved;
    out['isDisbursed'] = disbursed;
    out['isCheckIn'] = isCheckIn;
    out['isPaid'] = data['isPaid'] == true ||
        data['daThanhToan'] == true ||
        resolved == 'approved' ||
        resolved == 'paid' ||
        resolved == 'active';
    return out;
  }

  /// Nhóm hiển thị trong Admin từ map đã [canonical]: 'pending' | 'deposit_paid' |
  /// 'completed' | null (đơn chưa báo chuyển khoản / đã hủy -> không hiện).
  static String? uiStatus(Map<String, dynamic> c) {
    final s = c['status'];
    if (s == 'cancelled' || s == 'rejected' || s == 'pending_payment' || s == null) {
      return null;
    }
    if (c['isDisbursed'] == true || s == 'paid') return statusCompleted;
    if (s == 'approved' || s == 'active') return statusDepositPaid;
    if (s == 'pending') return statusPending;
    return null;
  }

  /// Tiện ích: nhóm hiển thị từ dữ liệu thô.
  static String? status(Map<String, dynamic> data) => uiStatus(canonical(data));

  // ── Chính sách hủy đơn (tính trên số tiền cọc đã nhận) ──
  static const double cancelPlatformRate = 0.05; // sàn giữ 5%
  static const double cancelHostRate = 0.10; // chuyển chủ trọ 10%

  /// Chia tiền cọc khi người thuê hủy đơn. Đơn vị: đồng, làm tròn số nguyên;
  /// phần hoàn lại = phần còn lại nên tổng luôn khớp đúng [deposit].
  static Map<String, int> cancellationSplit(double deposit) {
    final total = deposit.round();
    final platform = (deposit * cancelPlatformRate).round();
    final host = (deposit * cancelHostRate).round();
    return {
      'deposit': total,
      'platformFee': platform,
      'hostAmount': host,
      'refundAmount': total - platform - host,
    };
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  /// Số tiền của đơn.
  static double amount(Map<String, dynamic> data) {
    final c = canonical(data);
    return _toDouble(c['depositAmount'] ??
        c['paymentAmount'] ??
        c['totalPayable'] ??
        c['rentPrice']);
  }

  /// Ngày tạo đơn; null nếu document không có ngày.
  static DateTime? createdAt(Map<String, dynamic> data) {
    final c = canonical(data);
    final v = c['createdAt'] ?? c['approvedAt'];
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  /// Chuyển đơn cũ sang tên trường/giá trị chuẩn. Chạy MỘT LẦN sau khi cả app Admin
  /// và app Người thuê đã cập nhật. Trả về số đơn đã sửa.
  static Future<int> migrateLegacyBookings() async {
    final db = FirebaseFirestore.instance;
    final snap = await db.collection('bookings').get();

    int updated = 0;
    int pendingOps = 0;
    WriteBatch batch = db.batch();

    for (final doc in snap.docs) {
      final data = doc.data();
      final update = <String, dynamic>{};

      _legacyVietnamese.forEach((oldKey, newKey) {
        if (data.containsKey(oldKey)) {
          if (data[newKey] == null) update[newKey] = data[oldKey];
          update[oldKey] = FieldValue.delete();
        }
      });

      final canon = canonical(data);
      if (canon['status'] != null && canon['status'] != data['status']) {
        update['status'] = canon['status'];
      }
      if (canon['isDisbursed'] == true && data['isDisbursed'] != true) {
        update['isDisbursed'] = true;
      }
      // Dọn cờ cũ
      if (data.containsKey('daHoanTat')) update['daHoanTat'] = FieldValue.delete();
      if (data.containsKey('isCompleted')) update['isCompleted'] = FieldValue.delete();

      if (update.isEmpty) continue;
      batch.update(doc.reference, update);
      updated++;
      pendingOps++;

      if (pendingOps >= 400) {
        await batch.commit();
        batch = db.batch();
        pendingOps = 0;
      }
    }

    if (pendingOps > 0) await batch.commit();
    return updated;
  }
}