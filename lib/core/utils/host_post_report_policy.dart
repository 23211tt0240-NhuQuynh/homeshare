/// Điều kiện gửi báo cáo bài đăng chủ trọ tới Admin. Chưa gồm bước Admin xử lý.
abstract final class HostPostReportPolicy {
  static const maxDetailLength = 500;
  static const pendingStatus = 'pending';
  static const targetPost = 'post';

  static const reasons = [
    'Thông tin sai sự thật',
    'Hình ảnh giả mạo',
    'Giá thuê / tiền cọc không đúng',
    'Phòng không còn trống',
    'Lừa đảo',
    'Nội dung phản cảm',
    'Spam / bài trùng',
    'Quyền sở hữu trí tuệ',
    'Vấn đề khác',
  ];

  static const otherReason = 'Vấn đề khác';

  static bool canReport({
    required String reporterId,
    required String hostId,
    required String postId,
  }) {
    if (reporterId.isEmpty || hostId.isEmpty || postId.isEmpty) return false;
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
    required String postId,
    required Iterable<String> selectedReasons,
    required String otherText,
  }) {
    if (reporterId.isEmpty) return 'Vui lòng đăng nhập để báo cáo.';
    if (postId.trim().isEmpty) return 'Không xác định được bài đăng.';
    if (!canReport(
      reporterId: reporterId,
      hostId: hostId,
      postId: postId,
    )) {
      return 'Bạn không thể báo cáo bài đăng của chính mình.';
    }
    final selected = selectedReasons.toSet();
    if (selected.isEmpty) return 'Vui lòng chọn ít nhất một lý do.';
    if (selected.any((reason) => !reasons.contains(reason))) {
      return 'Vui lòng chọn lý do báo cáo.';
    }
    if (includesOther(selected) && otherText.trim().isEmpty) {
      return 'Vui lòng nhập vấn đề khác.';
    }
    if (otherText.trim().length > maxDetailLength) {
      return 'Vấn đề khác tối đa $maxDetailLength ký tự.';
    }
    return null;
  }
}
