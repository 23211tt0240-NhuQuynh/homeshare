import 'package:cloud_firestore/cloud_firestore.dart';

/// Danh mục các loại sự cố phòng trọ chuẩn hóa
class RoomIssueCategories {
  static const electricity = 'Điện & Chiếu sáng';
  static const plumbing = 'Nước & Thiết bị vệ sinh';
  static const hvac = 'Máy lạnh / Điều hòa';
  static const doorLock = 'Khóa cửa & An ninh';
  static const wifi = 'Mạng Internet / Wifi';
  static const furniture = 'Đồ đạc & Nội thất';
  static const leaksWalls = 'Thấm dột & Tường nhà';
  static const other = 'Sự cố khác';

  static const List<String> all = [
    electricity,
    plumbing,
    hvac,
    doorLock,
    wifi,
    furniture,
    leaksWalls,
    other,
  ];
}

/// Mức độ khẩn cấp của sự cố
class RoomIssueSeverities {
  static const low = 'low';
  static const medium = 'medium';
  static const high = 'high';

  static String toDisplayVi(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
      case 'khan_cap':
        return 'Khẩn cấp';
      case 'low':
      case 'thap':
        return 'Bình thường';
      case 'medium':
      default:
        return 'Cần sửa sớm';
    }
  }
}

/// Trạng thái xử lý sự cố phòng trọ
class RoomIssueStatuses {
  static const pending = 'pending';
  static const inProgress = 'in_progress';
  static const resolved = 'resolved';
  static const cancelled = 'cancelled';

  static String toDisplayVi(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
      case 'dangxuly':
        return 'Đang xử lý';
      case 'resolved':
      case 'dakhacphuc':
      case 'completed':
        return 'Đã khắc phục';
      case 'cancelled':
      case 'dahuy':
        return 'Đã hủy';
      case 'pending':
      default:
        return 'Chờ tiếp nhận';
    }
  }
}

/// Thực thể Báo cáo sự cố phòng trọ (Room Incident Report)
class RoomIssueModel {
  final String id;
  final String bookingId;
  final String roomId;
  final String roomTitle;
  final String hostId;
  final String hostName;
  final String reporterId;
  final String reporterName;
  final String reporterPhone;
  final String category;
  final String severity; // 'low', 'medium', 'high'
  final String description;
  final List<String> imageUrls;
  final String status; // 'pending', 'in_progress', 'resolved', 'cancelled'
  final String? hostNotes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;

  const RoomIssueModel({
    required this.id,
    required this.bookingId,
    required this.roomId,
    required this.roomTitle,
    required this.hostId,
    this.hostName = '',
    required this.reporterId,
    required this.reporterName,
    required this.reporterPhone,
    required this.category,
    this.severity = RoomIssueSeverities.medium,
    required this.description,
    this.imageUrls = const [],
    this.status = RoomIssueStatuses.pending,
    this.hostNotes,
    required this.createdAt,
    this.updatedAt,
    this.resolvedAt,
  });

  bool get isPending =>
      status == RoomIssueStatuses.pending || status == 'choTiepNhan';
  bool get isInProgress =>
      status == RoomIssueStatuses.inProgress || status == 'dangXuLy';
  bool get isResolved =>
      status == RoomIssueStatuses.resolved ||
      status == 'daKhacPhuc' ||
      status == 'completed';
  bool get isCancelled =>
      status == RoomIssueStatuses.cancelled || status == 'daHuy';

  String get severityDisplayVi => RoomIssueSeverities.toDisplayVi(severity);
  String get statusDisplayVi => RoomIssueStatuses.toDisplayVi(status);

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'targetType': 'room_issue',
      'type': 'room_issue',
      'bookingId': bookingId,
      'roomId': roomId,
      'roomTitle': roomTitle,
      'hostId': hostId,
      'hostName': hostName,
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reporterPhone': reporterPhone,
      'category': category,
      'severity': severity,
      'description': description,
      'imageUrls': imageUrls,
      'status': status,
      'hostNotes': hostNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
    };
  }

  factory RoomIssueModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return RoomIssueModel.fromMap(data, doc.id);
  }

  factory RoomIssueModel.fromMap(Map<String, dynamic> data, [String? id]) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawImages = data['imageUrls'] ?? data['images'] ?? [];
    final List<String> images = (rawImages is List)
        ? rawImages.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : [];

    return RoomIssueModel(
      id: id ?? data['id'] ?? '',
      bookingId: data['bookingId'] ?? '',
      roomId: data['roomId'] ?? '',
      roomTitle: data['roomTitle'] ?? data['title'] ?? '',
      hostId: data['hostId'] ?? data['recipientId'] ?? '',
      hostName: data['hostName'] ?? '',
      reporterId: data['reporterId'] ?? data['senderId'] ?? '',
      reporterName: data['reporterName'] ?? data['senderName'] ?? '',
      reporterPhone: data['reporterPhone'] ?? '',
      category: data['category'] ?? RoomIssueCategories.other,
      severity: data['severity'] ?? RoomIssueSeverities.medium,
      description: data['description'] ?? data['message'] ?? '',
      imageUrls: images,
      status: data['status'] ?? RoomIssueStatuses.pending,
      hostNotes: data['hostNotes'],
      createdAt: parseDate(data['createdAt']),
      updatedAt: data['updatedAt'] != null ? parseDate(data['updatedAt']) : null,
      resolvedAt:
          data['resolvedAt'] != null ? parseDate(data['resolvedAt']) : null,
    );
  }

  RoomIssueModel copyWith({
    String? id,
    String? bookingId,
    String? roomId,
    String? roomTitle,
    String? hostId,
    String? hostName,
    String? reporterId,
    String? reporterName,
    String? reporterPhone,
    String? category,
    String? severity,
    String? description,
    List<String>? imageUrls,
    String? status,
    String? hostNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
  }) {
    return RoomIssueModel(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      roomId: roomId ?? this.roomId,
      roomTitle: roomTitle ?? this.roomTitle,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      reporterPhone: reporterPhone ?? this.reporterPhone,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      description: description ?? this.description,
      imageUrls: imageUrls ?? this.imageUrls,
      status: status ?? this.status,
      hostNotes: hostNotes ?? this.hostNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

