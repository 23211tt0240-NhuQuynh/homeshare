import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';

/// Model Biên bản trả phòng theo Database homeShare & SDS
/// Collection: checkout_records/{checkoutId}
class CheckoutRecordModel {
  final String id;
  final String periodId;
  final String roomId;
  final String renterId;
  final String residentId;
  final DateTime checkoutTime;
  final double depositAmount;
  final double deductionAmount;
  final double refundAmount;
  final double finalElectricityMeter;
  final double finalWaterMeter;
  final bool isConfirmedByBoth;
  final String status; // 'daCheckout', 'daHoanCoc'
  final String note;

  // SDS Dual Aliases
  String get checkoutId => id;
  String get kyOId => periodId;
  String get phongId => roomId;
  String get nguoiDungId => renterId;
  String get cuDanId => residentId.isNotEmpty ? residentId : renterId;
  DateTime get thoiGianCheckout => checkoutTime;
  double get tienCoc => depositAmount;
  double get khoanKhauTru => deductionAmount;
  double get tienHoan => refundAmount;
  double get chiSoDienCuoi => finalElectricityMeter;
  double get chiSoNuocCuoi => finalWaterMeter;
  bool get xacNhanHaiBen => isConfirmedByBoth;
  String get trangThai => status;
  String get ghiChu => note;

  const CheckoutRecordModel({
    required this.id,
    required this.periodId,
    required this.roomId,
    required this.renterId,
    this.residentId = '',
    required this.checkoutTime,
    required this.depositAmount,
    this.deductionAmount = 0.0,
    required this.refundAmount,
    this.finalElectricityMeter = 0.0,
    this.finalWaterMeter = 0.0,
    this.isConfirmedByBoth = true,
    this.status = 'daCheckout',
    this.note = '',
  });

  CheckoutRecordModel copyWith({
    String? id,
    String? periodId,
    String? roomId,
    String? renterId,
    String? residentId,
    DateTime? checkoutTime,
    double? depositAmount,
    double? deductionAmount,
    double? refundAmount,
    double? finalElectricityMeter,
    double? finalWaterMeter,
    bool? isConfirmedByBoth,
    String? status,
    String? note,
  }) {
    return CheckoutRecordModel(
      id: id ?? this.id,
      periodId: periodId ?? this.periodId,
      roomId: roomId ?? this.roomId,
      renterId: renterId ?? this.renterId,
      residentId: residentId ?? this.residentId,
      checkoutTime: checkoutTime ?? this.checkoutTime,
      depositAmount: depositAmount ?? this.depositAmount,
      deductionAmount: deductionAmount ?? this.deductionAmount,
      refundAmount: refundAmount ?? this.refundAmount,
      finalElectricityMeter:
          finalElectricityMeter ?? this.finalElectricityMeter,
      finalWaterMeter: finalWaterMeter ?? this.finalWaterMeter,
      isConfirmedByBoth: isConfirmedByBoth ?? this.isConfirmedByBoth,
      status: status ?? this.status,
      note: note ?? this.note,
    );
  }

  factory CheckoutRecordModel.fromFirestore(DocumentSnapshot doc) {
    return CheckoutRecordModel.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      doc.id,
    );
  }

  factory CheckoutRecordModel.fromMap(Map<String, dynamic> data, String id) {
    return CheckoutRecordModel(
      id: id,
      periodId: data['periodId'] ?? data['kyOId'] ?? '',
      roomId: data['roomId'] ?? data['phongId'] ?? '',
      renterId: data['renterId'] ?? data['nguoiDungId'] ?? '',
      residentId: (data[BienBanCheckoutSqlFields.cuDanId] ??
              data['residentId'] ??
              data['cuDanId'] ??
              '')
          .toString(),
      checkoutTime: (data['checkoutTime'] is Timestamp)
          ? (data['checkoutTime'] as Timestamp).toDate()
          : (data[BienBanCheckoutSqlFields.ngayCheckout] is Timestamp)
              ? (data[BienBanCheckoutSqlFields.ngayCheckout] as Timestamp).toDate()
              : (data['thoiGianCheckout'] is Timestamp)
                  ? (data['thoiGianCheckout'] as Timestamp).toDate()
                  : DateTime.now(),
      depositAmount:
          ((data['depositAmount'] ?? data['tienCoc']) as num?)?.toDouble() ??
              0.0,
      deductionAmount: ((data[BienBanCheckoutSqlFields.chiPhiKhauTru] ??
                  data['deductionAmount'] ??
                  data['khoanKhauTru']) as num?)
              ?.toDouble() ??
          0.0,
      refundAmount:
          ((data['refundAmount'] ?? data['tienHoan']) as num?)?.toDouble() ??
              0.0,
      finalElectricityMeter: ((data[BienBanCheckoutSqlFields.chiSoDienCuoi] ??
                  data['finalElectricityMeter'] ??
                  data['chiSoDienCuoi']) as num?)
              ?.toDouble() ??
          0.0,
      finalWaterMeter: ((data[BienBanCheckoutSqlFields.chiSoNuocCuoi] ??
                  data['finalWaterMeter'] ??
                  data['chiSoNuocCuoi']) as num?)
              ?.toDouble() ??
          0.0,
      isConfirmedByBoth: data[BienBanCheckoutSqlFields.xacNhanHaiBen] == true ||
          data['xacNhanHaiBen'] == true ||
          data['isConfirmedByBoth'] == true,
      status: data['status'] ?? data['trangThai'] ?? 'daCheckout',
      note: (data[BienBanCheckoutSqlFields.huHongThietHai] ??
              data['note'] ??
              data['ghiChu'] ??
              '')
          .toString(),
    );
  }

  /// Đường dẫn Sub-collection trên Firestore theo quan hệ 1-1:
  /// Path: residents/{residentId}/checkout_records
  static String subCollectionPath(String residentId) =>
      HostFirestorePaths.checkoutRecords(residentId);

  /// Đường dẫn Document trong Sub-collection:
  /// Path: residents/{residentId}/checkout_records/{checkoutId}
  static String docPath(String residentId, String checkoutId) =>
      HostFirestorePaths.checkoutRecordDoc(residentId, checkoutId);

  /// CollectionReference cho Sub-collection checkout_records
  static CollectionReference<Map<String, dynamic>> subColRef(
    String residentId, [
    FirebaseFirestore? firestore,
  ]) => (firestore ?? FirebaseFirestore.instance)
      .collection(FirestoreCollections.residents)
      .doc(residentId)
      .collection(FirestoreCollections.checkoutRecords);

  /// Mapper chuẩn theo bảng bien_ban_tra_phong_checkout (SQL_NHOM4_CHUYENDEDIDONG.sql)
  Map<String, dynamic> toBienBanCheckoutSql() => {
    BienBanCheckoutSqlFields.id: id,
    BienBanCheckoutSqlFields.cuDanId: cuDanId,
    BienBanCheckoutSqlFields.chiSoDienCuoi: finalElectricityMeter,
    BienBanCheckoutSqlFields.chiSoNuocCuoi: finalWaterMeter,
    BienBanCheckoutSqlFields.huHongThietHai: note,
    BienBanCheckoutSqlFields.chiPhiKhauTru: deductionAmount,
    BienBanCheckoutSqlFields.xacNhanHaiBen: isConfirmedByBoth ? 1 : 0,
    BienBanCheckoutSqlFields.ngayCheckout: Timestamp.fromDate(checkoutTime),
  };

  /// Factory đọc từ dữ liệu bảng bien_ban_tra_phong_checkout chuẩn SQL
  factory CheckoutRecordModel.fromBienBanCheckoutSql(Map<String, dynamic> data, String id) {
    return CheckoutRecordModel.fromMap(data, id);
  }

  /// Ghi Firestore 100% tiếng Anh chuẩn Firebase Console
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'residentId': residentId,
      'roomId': roomId,
      'renterId': renterId,
      'periodId': periodId,
      'checkoutTime': Timestamp.fromDate(checkoutTime),
      'depositAmount': depositAmount,
      'deductionAmount': deductionAmount,
      'refundAmount': refundAmount,
      'finalElectricityMeter': finalElectricityMeter,
      'finalWaterMeter': finalWaterMeter,
      'isConfirmedByBoth': isConfirmedByBoth,
      'status': status,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toMap() => toFirestore();
}

