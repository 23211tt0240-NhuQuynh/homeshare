/// Định nghĩa các loại thông báo cho Role Chủ Trọ
/// Tuân thủ quy chuẩn enum và ánh xạ dữ liệu theo Database.docx
library;

/// Phân loại thông báo chủ trọ
enum HostNotificationType {
  /// Đang chờ chủ trọ xử lý (Yêu cầu đặt phòng mới, yêu cầu duyệt ở ghép, check-in, vi phạm, xác nhận bàn giao...)
  pendingAction,

  /// Đang ở (Khách đang sinh sống tại phòng, bao gồm người ở ghép đã duyệt vào phòng)
  staying,

  /// Thông báo liên quan đến tiền cọc (Người thuê đặt cọc, chờ xác nhận cọc, đã xác nhận cọc)
  deposit,

  /// Thanh toán hoàn tất (Tiền thuê, cọc, điện/nước, phí phạt đã hoàn tất)
  paymentCompleted,
}

/// Tiện ích mở rộng cho [HostNotificationType]
extension HostNotificationTypeX on HostNotificationType {
  /// Mã lưu trữ chuẩn vào Firestore
  String get code {
    switch (this) {
      case HostNotificationType.pendingAction:
        return 'pendingAction';
      case HostNotificationType.staying:
        return 'staying';
      case HostNotificationType.deposit:
        return 'deposit';
      case HostNotificationType.paymentCompleted:
        return 'paymentCompleted';
    }
  }

  /// Nhãn hiển thị trên thanh tab/chip của giao diện Figma
  String get label {
    switch (this) {
      case HostNotificationType.pendingAction:
        return 'Đang xử lý';
      case HostNotificationType.staying:
        return 'Đang ở';
      case HostNotificationType.deposit:
        return 'Đã cọc';
      case HostNotificationType.paymentCompleted:
        return 'Đã thanh toán hết';
    }
  }

  /// Chuyển đổi an toàn từ chuỗi (hỗ trợ cả tiếng Anh lẫn tiếng Việt từ Database cũ)
  static HostNotificationType fromString(String? value) {
    if (value == null) return HostNotificationType.pendingAction;
    final val = value.toLowerCase().trim();
    if (val == 'staying' ||
        val == 'dango' ||
        val == 'dang_o' ||
        val == 'living' ||
        val == 'occupying' ||
        val == 'active') {
      return HostNotificationType.staying;
    }
    if (val == 'deposit' ||
        val == 'tiencoc' ||
        val == 'dacoc' ||
        val == 'thongbaotiencoc' ||
        val == 'thong_bao_tien_coc') {
      return HostNotificationType.deposit;
    }
    if (val == 'paymentcompleted' ||
        val == 'payment_completed' ||
        val == 'thanhtoan' ||
        val == 'dathanhtoan' ||
        val == 'dathanhtoanhet' ||
        val == 'da_thanh_toan_het' ||
        val == 'thanh_toan_hoan_tat') {
      return HostNotificationType.paymentCompleted;
    }
    return HostNotificationType.pendingAction;
  }
}
