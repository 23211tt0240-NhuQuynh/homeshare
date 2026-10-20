import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../notification_types.dart';

/// Model thông báo dành cho Role Chủ Trọ
/// Ánh xạ chuẩn theo Database.docx và [NotificationFields]
class HostNotificationModel {
  final String id;
  final String receiverId;
  final String senderId;
  final HostNotificationType type;
  final String title;
  final String message;
  final String bookingId;
  final String paymentId;
  final String roomId;
  final String propertyId;
  final double amount;
  final String statusId;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Thuộc tính phụ trợ hiển thị giao diện theo Figma
  final String bookingCode;
  final String roomCode;
  final String roomTitle;
  final String roomFloorInfo;
  final String renterName;
  final String renterAvatarUrl;
  final DateTime? checkInDate;
  final String paymentMethod;
  final String? oldRoomId;
  final String? newRoomId;
  final String? oldRoomTitle;
  final String? newRoomTitle;
  final DateTime? oldCheckInDate;
  final DateTime? newCheckInDate;
  final String? adjustmentReason;
  final String primaryTenantId;
  final String primaryTenantName;
  final String newRoommateId;
  final String newRoommateName;
  final String actionType;
  final String userNotificationId;

  const HostNotificationModel({
    required this.id,
    required this.receiverId,
    this.senderId = '',
    required this.type,
    required this.title,
    this.message = '',
    this.bookingId = '',
    this.paymentId = '',
    this.roomId = '',
    this.propertyId = '',
    this.amount = 0.0,
    this.statusId = 'pending',
    this.isRead = false,
    required this.createdAt,
    this.updatedAt,
    this.bookingCode = '',
    this.roomCode = '',
    this.roomTitle = '',
    this.roomFloorInfo = '',
    this.renterName = '',
    this.renterAvatarUrl = '',
    this.checkInDate,
    this.paymentMethod = 'Chuyển khoản QR',
    this.oldRoomId,
    this.newRoomId,
    this.oldRoomTitle,
    this.newRoomTitle,
    this.oldCheckInDate,
    this.newCheckInDate,
    this.adjustmentReason,
    this.primaryTenantId = '',
    this.primaryTenantName = '',
    this.newRoommateId = '',
    this.newRoommateName = '',
    this.actionType = '',
    this.userNotificationId = '',
  });

  bool get isRoommateApproval =>
      actionType == 'roommate_approval' ||
      newRoommateId.isNotEmpty ||
      title.contains('ở ghép') ||
      message.contains('ở ghép');

  // Vietnamese Database.docx Alias Getters
  String get notificationId => id;
  String get thongBaoId => id;
  String get nguoiNhanId => receiverId;
  String get nguoiGuiId => senderId;
  String get loaiThongBao => type.code;
  String get tieuDe => title;
  String get noiDung => message;
  String get donId => bookingId;
  String get thanhToanId => paymentId;
  String get phongId => roomId;
  String get nhaTroId => propertyId;
  double get soTien => amount;
  String get trangThaiId => statusId;
  bool get daDoc => isRead;
  DateTime get ngayTao => createdAt;
  DateTime? get ngayCapNhat => updatedAt;

  /// Hiển thị mã booking dạng chuẩn #BK12345 hoặc #DP_...
  String get displayBookingCode {
    if (bookingCode.isNotEmpty) {
      if (bookingCode.length > 15) {
        final clean = bookingCode.replaceAll('#', '');
        final parts = clean.split('_');
        if (parts.length > 1) {
          final last = parts.last;
          final sub = last.length > 6 ? last.substring(last.length - 6) : last;
          return '#DP_${sub.toUpperCase()}';
        }
        return '#${clean.substring(0, 10).toUpperCase()}...';
      }
      return bookingCode.startsWith('#') ? bookingCode : '#$bookingCode';
    }
    if (bookingId.isNotEmpty) {
      final clean = bookingId.replaceAll('#', '');
      final sub = clean.length > 5 ? clean.substring(0, 5).toUpperCase() : clean.toUpperCase();
      return '#BK$sub';
    }
    return '#BK12345';
  }

  /// Hiển thị số phòng gắn trên huy hiệu đầu card (vd: "101")
  String get displayRoomCode {
    if (roomCode.isNotEmpty) {
      if (roomCode.length > 5) {
        final match = RegExp(r'\d+').firstMatch(roomTitle);
        if (match != null) return 'P.${match.group(0)!}';
        return roomCode.substring(0, 4).toUpperCase();
      }
      return roomCode;
    }
    final match = RegExp(r'\d+').firstMatch(roomTitle);
    if (match != null) return match.group(0)!;
    return '101';
  }

  /// Sao chép với các trường mới
  HostNotificationModel copyWith({
    String? id,
    String? receiverId,
    String? senderId,
    HostNotificationType? type,
    String? title,
    String? message,
    String? bookingId,
    String? paymentId,
    String? roomId,
    String? propertyId,
    double? amount,
    String? statusId,
    bool? isRead,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? bookingCode,
    String? roomCode,
    String? roomTitle,
    String? roomFloorInfo,
    String? renterName,
    String? renterAvatarUrl,
    DateTime? checkInDate,
    String? paymentMethod,
    String? oldRoomId,
    String? newRoomId,
    String? oldRoomTitle,
    String? newRoomTitle,
    DateTime? oldCheckInDate,
    DateTime? newCheckInDate,
    String? adjustmentReason,
  }) {
    return HostNotificationModel(
      id: id ?? this.id,
      receiverId: receiverId ?? this.receiverId,
      senderId: senderId ?? this.senderId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      bookingId: bookingId ?? this.bookingId,
      paymentId: paymentId ?? this.paymentId,
      roomId: roomId ?? this.roomId,
      propertyId: propertyId ?? this.propertyId,
      amount: amount ?? this.amount,
      statusId: statusId ?? this.statusId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      bookingCode: bookingCode ?? this.bookingCode,
      roomCode: roomCode ?? this.roomCode,
      roomTitle: roomTitle ?? this.roomTitle,
      roomFloorInfo: roomFloorInfo ?? this.roomFloorInfo,
      renterName: renterName ?? this.renterName,
      renterAvatarUrl: renterAvatarUrl ?? this.renterAvatarUrl,
      checkInDate: checkInDate ?? this.checkInDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      oldRoomId: oldRoomId ?? this.oldRoomId,
      newRoomId: newRoomId ?? this.newRoomId,
      oldRoomTitle: oldRoomTitle ?? this.oldRoomTitle,
      newRoomTitle: newRoomTitle ?? this.newRoomTitle,
      oldCheckInDate: oldCheckInDate ?? this.oldCheckInDate,
      newCheckInDate: newCheckInDate ?? this.newCheckInDate,
      adjustmentReason: adjustmentReason ?? this.adjustmentReason,
    );
  }

  factory HostNotificationModel.fromFirestore(DocumentSnapshot doc) {
    return HostNotificationModel.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      doc.id,
    );
  }

  factory HostNotificationModel.fromMap(Map<String, dynamic> data, String id) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      return fallback;
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final rawType = data[NotificationFields.notificationType] ??
        data[NotificationFields.legacyNotificationType] ??
        data['type'];

    final amtVal = data[NotificationFields.amount] ??
        data[NotificationFields.legacyAmount] ??
        data['tienCoc'] ??
        data['depositAmount'];

    return HostNotificationModel(
      id: id,
      receiverId: data[NotificationFields.receiverId] ??
          data[NotificationFields.legacyReceiverId] ??
          data['chuNhaId'] ??
          data['hostId'] ??
          '',
      senderId: data[NotificationFields.senderId] ??
          data[NotificationFields.legacySenderId] ??
          data['nguoiDungId'] ??
          data['renterId'] ??
          '',
      type: HostNotificationTypeX.fromString(rawType?.toString()),
      title: data[NotificationFields.title] ??
          data[NotificationFields.legacyTitle] ??
          'Thông báo hệ thống',
      message: data[NotificationFields.message] ??
          data[NotificationFields.legacyMessage] ??
          '',
      bookingId: data[NotificationFields.bookingId] ??
          data[NotificationFields.legacyBookingId] ??
          data['donDatPhongId'] ??
          '',
      paymentId: data[NotificationFields.paymentId] ??
          data[NotificationFields.legacyPaymentId] ??
          '',
      roomId: data[NotificationFields.roomId] ??
          data[NotificationFields.legacyRoomId] ??
          '',
      propertyId: data[NotificationFields.propertyId] ??
          data[NotificationFields.legacyPropertyId] ??
          '',
      amount: (amtVal is num)
          ? amtVal.toDouble()
          : (double.tryParse(amtVal?.toString() ?? '') ?? 0.0),
      statusId: data[NotificationFields.statusId] ??
          data[NotificationFields.legacyStatusId] ??
          data['status'] ??
          'pending',
      isRead: (data[NotificationFields.isRead] ??
              data[NotificationFields.legacyIsRead] ??
              false) ==
          true,
      createdAt: parseDate(
        data[NotificationFields.createdAt] ??
            data[NotificationFields.legacyCreatedAt],
        DateTime.now(),
      ),
      updatedAt: parseNullableDate(
        data[NotificationFields.updatedAt] ??
            data[NotificationFields.legacyUpdatedAt],
      ),
      bookingCode: data[NotificationFields.bookingCode] ?? '',
      roomCode: data[NotificationFields.roomCode] ?? '',
      roomTitle: data[NotificationFields.roomTitle] ??
          data['tieuDePhong'] ??
          data['tenPhong'] ??
          '',
      roomFloorInfo: data['roomFloorInfo'] ??
          data['thongTinTang'] ??
          data['tang']?.toString() ??
          '',
      renterName: data[NotificationFields.renterName] ??
          data['tenNguoiO'] ??
          data['tenKhach'] ??
          '',
      renterAvatarUrl: data['renterAvatarUrl'] ??
          data['anhKhach'] ??
          data['anhDaiDien'] ??
          '',
      checkInDate: parseNullableDate(
        data[NotificationFields.checkInDate] ??
            data['ngayVao'] ??
            data['ngayCheckIn'],
      ),
      paymentMethod: data[NotificationFields.paymentMethod] ??
          data['phuongThucThanhToan'] ??
          'Chuyển khoản QR',
      oldRoomId: data[NotificationFields.oldRoomId],
      newRoomId: data[NotificationFields.newRoomId],
      oldRoomTitle: data['oldRoomTitle'],
      newRoomTitle: data['newRoomTitle'],
      oldCheckInDate: parseNullableDate(data[NotificationFields.oldCheckInDate]),
      newCheckInDate: parseNullableDate(data[NotificationFields.newCheckInDate]),
      adjustmentReason: data[NotificationFields.adjustmentReason] ??
          data['lyDoDieuChinh'],
      primaryTenantId: data['primaryTenantId']?.toString() ?? '',
      primaryTenantName: data['primaryTenantName']?.toString() ?? '',
      newRoommateId: data['newRoommateId']?.toString() ?? '',
      newRoommateName: data['newRoommateName']?.toString() ?? '',
      actionType: data['actionType']?.toString() ?? (data['notificationType'] == 'roommate_approval' ? 'roommate_approval' : ''),
      userNotificationId: data['userNotificationId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      NotificationFields.notificationId: id,
      NotificationFields.legacyNotificationId: id,
      NotificationFields.receiverId: receiverId,
      NotificationFields.legacyReceiverId: receiverId,
      NotificationFields.senderId: senderId,
      NotificationFields.legacySenderId: senderId,
      NotificationFields.notificationType: type.code,
      NotificationFields.title: title,
      NotificationFields.message: message,
      NotificationFields.bookingId: bookingId,
      NotificationFields.paymentId: paymentId,
      NotificationFields.roomId: roomId,
      NotificationFields.propertyId: propertyId,
      NotificationFields.amount: amount,
      NotificationFields.legacyAmount: amount,
      NotificationFields.statusId: statusId,
      NotificationFields.isRead: isRead,
      NotificationFields.createdAt: Timestamp.fromDate(createdAt),
      if (updatedAt != null)
        NotificationFields.updatedAt: Timestamp.fromDate(updatedAt!),
      NotificationFields.bookingCode: bookingCode,
      NotificationFields.roomCode: roomCode,
      NotificationFields.roomTitle: roomTitle,
      'roomFloorInfo': roomFloorInfo,
      NotificationFields.renterName: renterName,
      'renterAvatarUrl': renterAvatarUrl,
      if (checkInDate != null)
        NotificationFields.checkInDate: Timestamp.fromDate(checkInDate!),
      NotificationFields.paymentMethod: paymentMethod,
      if (oldRoomId != null) NotificationFields.oldRoomId: oldRoomId,
      if (newRoomId != null) NotificationFields.newRoomId: newRoomId,
      if (oldRoomTitle != null) 'oldRoomTitle': oldRoomTitle,
      if (newRoomTitle != null) 'newRoomTitle': newRoomTitle,
      if (oldCheckInDate != null)
        NotificationFields.oldCheckInDate: Timestamp.fromDate(oldCheckInDate!),
      if (newCheckInDate != null)
        NotificationFields.newCheckInDate: Timestamp.fromDate(newCheckInDate!),
      if (adjustmentReason != null)
        NotificationFields.adjustmentReason: adjustmentReason,
      if (primaryTenantId.isNotEmpty) 'primaryTenantId': primaryTenantId,
      if (primaryTenantName.isNotEmpty) 'primaryTenantName': primaryTenantName,
      if (newRoommateId.isNotEmpty) 'newRoommateId': newRoommateId,
      if (newRoommateName.isNotEmpty) 'newRoommateName': newRoommateName,
      if (actionType.isNotEmpty) 'actionType': actionType,
      if (userNotificationId.isNotEmpty) 'userNotificationId': userNotificationId,
    };
  }
}
