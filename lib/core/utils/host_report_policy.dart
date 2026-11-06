/// Điều kiện gửi báo cáo chủ trọ tới Admin. Chưa gồm bước Admin xử lý.
abstract final class HostReportPolicy {
  static const maxDetailLength = 500;
  static const maxEvidenceImages = 5;
  static const pendingStatus = 'pending';
  static const targetHost = 'host';

  static const reasons = [
    'Chủ nhà có dấu hiệu lừa đảo, yêu cầu chuyển cọc bất thường',
    'Thái độ ứng xử thiếu văn minh, quấy rối hoặc đe dọa',
    'Thông tin phòng sai sự thật hoặc hình ảnh giả mạo',
    'Giá thuê / tiền cọc thực tế khác xa giá đăng trên ứng dụng',
    'Phòng đã có người thuê nhưng không gỡ bài đăng',
    'Nhà trọ không đảm bảo PCCC hoặc điều kiện sống tối thiểu',
    'Lý do khác',
  ];

  static const otherReason = 'Lý do khác';

  static bool canReport({
    required String reporterId,
    required String hostId,
  }) {
    if (reporterId.isEmpty || hostId.isEmpty) return false;
    return reporterId != hostId;
  }

  static bool includesOther(Iterable<String> selected) =>
      selected.contains(otherReason);

  static String joinedReason(Iterable<String> selected, String otherText) {
    final custom = otherText.trim();
    return selected
        .map((reason) => reason == otherReason ? custom : reason)
        .where((reason) => reason.isNotEmpty)
        .join('; ');
  }

  static String? validate({
    required String reporterId,
    required String hostId,
    required Iterable<String> selectedReasons,
    required String otherText,
    int evidenceCount = 0,
  }) {
    if (reporterId.isEmpty) return 'Vui lòng đăng nhập để báo cáo.';
    if (!canReport(reporterId: reporterId, hostId: hostId)) {
      return 'Bạn không thể báo cáo chính mình.';
    }
    final selected = selectedReasons.toSet();
    if (selected.isEmpty) return 'Vui lòng chọn ít nhất một lý do.';
    if (selected.any((reason) => !reasons.contains(reason))) {
      return 'Vui lòng chọn lý do báo cáo.';
    }
    if (includesOther(selected) && otherText.trim().isEmpty) {
      return 'Vui lòng nhập lý do khác.';
    }
    if (otherText.trim().length > maxDetailLength) {
      return 'Lý do khác tối đa $maxDetailLength ký tự.';
    }
    if (evidenceCount <= 0) {
      return 'Vui lòng thêm ít nhất một ảnh minh chứng.';
    }
    if (evidenceCount > maxEvidenceImages) {
      return 'Tối đa $maxEvidenceImages ảnh minh chứng.';
    }
    return null;
  }
}
