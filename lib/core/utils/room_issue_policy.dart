import '../../data/models/room_issue_model.dart';

/// Quy tắc kiểm tra tính hợp lệ của báo cáo sự cố phòng trọ
class RoomIssuePolicy {
  static const int minDescriptionLength = 5;

  /// Kiểm tra dữ liệu đầu vào khi người thuê báo sự cố
  static String? validate({
    required String category,
    required String description,
    required String reporterPhone,
  }) {
    if (category.trim().isEmpty) {
      return 'Vui lòng chọn danh mục sự cố';
    }
    if (!RoomIssueCategories.all.contains(category.trim())) {
      return 'Danh mục sự cố không hợp lệ';
    }
    final cleanDesc = description.trim();
    if (cleanDesc.isEmpty) {
      return 'Vui lòng nhập mô tả chi tiết sự cố';
    }
    if (cleanDesc.length < minDescriptionLength) {
      return 'Mô tả sự cố quá ngắn. Vui lòng nhập chi tiết hơn (ít nhất $minDescriptionLength ký tự)';
    }
    final cleanPhone = reporterPhone.trim();
    if (cleanPhone.isEmpty) {
      return 'Vui lòng cung cấp số điện thoại liên hệ';
    }
    final digitsOnly = cleanPhone.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 9 || digitsOnly.length > 11) {
      return 'Số điện thoại liên hệ không hợp lệ (cần 9-11 chữ số)';
    }
    return null;
  }

  /// Khởi tạo tiêu đề tóm tắt sự cố
  static String formatTitle({
    required String category,
    required String roomTitle,
  }) {
    return '[$category] $roomTitle';
  }

  /// Khởi tạo nội dung thông báo gửi cho chủ trọ
  static String formatHostMessage({
    required String reporterName,
    required String reporterPhone,
    required String category,
    required String severity,
    required String description,
  }) {
    final sevText = RoomIssueSeverities.toDisplayVi(severity);
    return 'Khách thuê $reporterName ($reporterPhone) báo sự cố [$category] (Mức độ: $sevText): "$description"';
  }

  /// Khởi tạo nội dung thông báo xác nhận gửi cho khách thuê
  static String formatTenantMessage({
    required String category,
    required String hostName,
  }) {
    final host = hostName.trim().isEmpty ? 'chủ trọ' : 'chủ trọ $hostName';
    return 'Yêu cầu hỗ trợ sự cố [$category] đã được chuyển đến $host. Chúng tôi sẽ sớm liên hệ xử lý.';
  }
}

