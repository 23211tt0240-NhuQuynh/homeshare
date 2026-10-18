import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';

/// Model Cư dân theo Database homeShare & SDS
/// Collection: residents/{residentId}
class ResidentModel {
  final String id;
  final String periodId;
  final String roomId;
  final String userId;
  final String fullName;
  final String phone;
  final String avatar;
  final String roommateRequestId;
  final String formId; // 'chinh', 'oGhep'
  final String statusId; // 'dangO', 'daRoi'
  final DateTime moveInDate;
  final DateTime? moveOutDate;

  // SDS Dual Aliases
  String get residentId => id;
  String get phongId => roomId;
  String get phongTroId => roomId;
  // ignore: non_constant_identifier_names
  String get kyThue_id => periodId;
  String get kyOId => periodId;
  String get nguoiDungId => userId;
  String get hoTen => fullName;
  String get sdt => phone;
  String get soDienThoai => phone;
  String get yeuCauOGhepId => roommateRequestId;
  // ignore: non_constant_identifier_names
  String get hinhThuc_id => formId;
  // ignore: non_constant_identifier_names
  String get trangThai_id => statusId;
  DateTime get ngayVao => moveInDate;
  DateTime? get ngayRoi => moveOutDate;

  const ResidentModel({
    required this.id,
    required this.periodId,
    this.roomId = '',
    required this.userId,
    required this.fullName,
    this.phone = '',
    this.avatar = '',
    this.roommateRequestId = '',
    this.formId = 'chinh',
    this.statusId = 'dangO',
    required this.moveInDate,
    this.moveOutDate,
  });

  ResidentModel copyWith({
    String? id,
    String? periodId,
    String? roomId,
    String? userId,
    String? fullName,
    String? phone,
    String? avatar,
    String? roommateRequestId,
    String? formId,
    String? statusId,
    DateTime? moveInDate,
    DateTime? moveOutDate,
  }) {
    return ResidentModel(
      id: id ?? this.id,
      periodId: periodId ?? this.periodId,
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      roommateRequestId: roommateRequestId ?? this.roommateRequestId,
      formId: formId ?? this.formId,
      statusId: statusId ?? this.statusId,
      moveInDate: moveInDate ?? this.moveInDate,
      moveOutDate: moveOutDate ?? this.moveOutDate,
    );
  }

  factory ResidentModel.fromFirestore(DocumentSnapshot doc) {
    return ResidentModel.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      doc.id,
    );
  }

  factory ResidentModel.fromMap(Map<String, dynamic> data, String id) {
    return ResidentModel(
      id: id,
      periodId: data['periodId'] ?? data['kyThue_id'] ?? data['kyOId'] ?? '',
      roomId: data[CuDanDangOSqlFields.phongTroId] ?? data['roomId'] ?? data['phongId'] ?? '',
      userId: data['userId'] ?? data['nguoiDungId'] ?? '',
      fullName:
          data['fullName'] ?? data['hoTen'] ?? data['ten'] ?? data['name'] ?? '',
      phone:
          data['phone'] ??
          data['soDienThoai'] ??
          data['sdt'] ??
          '',
      avatar: data['avatar'] ?? data['anhDaiDien'] ?? '',
      roommateRequestId:
          data['roommateRequestId'] ?? data['yeuCauOGhepId'] ?? '',
      formId: data['formId'] ?? data['hinhThuc_id'] ?? 'chinh',
      statusId: data['statusId'] ?? data['trangThai_id'] ?? 'dangO',
      moveInDate: (data['moveInDate'] is Timestamp)
          ? (data['moveInDate'] as Timestamp).toDate()
          : (data['ngayVao'] is Timestamp)
          ? (data['ngayVao'] as Timestamp).toDate()
          : DateTime.now(),
      moveOutDate: (data['moveOutDate'] is Timestamp)
          ? (data['moveOutDate'] as Timestamp).toDate()
          : (data['ngayRoi'] is Timestamp)
          ? (data['ngayRoi'] as Timestamp).toDate()
          : null,
    );
  }

  /// Đường dẫn Sub-collection trên Firestore theo quan hệ 1-N:
  /// Path: rooms/{roomId}/residents
  static String subCollectionPath(String roomId) =>
      HostFirestorePaths.residents(roomId);

  /// Đường dẫn Document trong Sub-collection:
  /// Path: rooms/{roomId}/residents/{residentId}
  static String docPath(String roomId, String residentId) =>
      HostFirestorePaths.residentDoc(roomId, residentId);

  /// CollectionReference cho Sub-collection residents
  static CollectionReference<Map<String, dynamic>> subColRef(
    String roomId, [
    FirebaseFirestore? firestore,
  ]) => (firestore ?? FirebaseFirestore.instance)
      .collection(FirestoreCollections.rooms)
      .doc(roomId)
      .collection(FirestoreCollections.residents);

  /// Mapper chuẩn theo bảng cu_dan_dang_o (SQL_NHOM4_CHUYENDEDIDONG.sql)
  Map<String, dynamic> toCuDanDangOSql() => {
    CuDanDangOSqlFields.id: id,
    CuDanDangOSqlFields.phongTroId: roomId,
    CuDanDangOSqlFields.nguoiDungId: userId,
    CuDanDangOSqlFields.ngayBatDau: Timestamp.fromDate(moveInDate),
    if (moveOutDate != null)
      CuDanDangOSqlFields.ngayKetThuc: Timestamp.fromDate(moveOutDate!),
    CuDanDangOSqlFields.trangThai:
        statusId == 'dangO' ? 'DANG_O' : 'DA_CHUYEN_DI',
  };

  /// Factory đọc từ dữ liệu bảng cu_dan_dang_o chuẩn SQL
  factory ResidentModel.fromCuDanDangOSql(Map<String, dynamic> data, String id) {
    return ResidentModel.fromMap(data, id);
  }

  /// Ghi Firestore 100% tiếng Anh chuẩn Firebase Console
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'roomId': roomId,
      'userId': userId,
      'periodId': periodId,
      'fullName': fullName,
      'phone': phone,
      'avatar': avatar,
      'roommateRequestId': roommateRequestId,
      'formId': formId,
      'status': statusId == 'dangO' ? 'active' : 'moved_out',
      'statusId': statusId,
      'moveInDate': Timestamp.fromDate(moveInDate),
      if (moveOutDate != null)
        'moveOutDate': Timestamp.fromDate(moveOutDate!),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toMap() => toFirestore();
}

