import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Model Đơn đặt phòng & Lịch hẹn xem phòng chuẩn hóa theo Database homeShare (DrawIO pkg_3: Đặt phòng và kỳ ở)
/// Bảng: Đơn đặt phòng (phongId, nguoiDung_Id, trangThai_id, ngayVao, soThangThue, tenNguoiO, sdtNguoiO...)
class BookingRequestModel {
  final String id;
  final String renterId; // nguoiDung_Id / khachXemId
  final String? _renterUserCode; // maNguoiDung 5 ký tự (3 số đầu + 2 chữ sau)
  final String renterName; // tenNguoiO / tenKhach
  final String renterPhone; // sdtNguoiO / sdtKhach
  final String renterGender; // gioiTinhNguoiO
  final String roomId; // phongId / baiDangId
  final String? _roomCode;
  final String roomTitle; // tieuDePhong
  final String roomAddress; // diaChiPhong
  final double roomPrice; // giaThue / giaPhong
  final double deposit; // tienCoc
  final double totalAmount; // tongPhaiTra
  final int rentalMonths; // soThangThue
  final String hostId; // chuNhaId
  final String hostName; // tenChuNha
  final String status; // trangThai: 'choDuyet' (pending), 'daDuyet' (approved), 'dangO' (active), 'daHuy' (cancelled), 'tuChoi' (rejected)
  final String paymentOption; // 'deposit' (tiền cọc) | 'full' (trả hết)
  final String? transferNote; // ghi chú chuyển khoản / mã người dùng
  final DateTime moveInDate; // ngayVao / thoiDiem
  final DateTime? acceptedDate; // ngayChapNhan
  final String note; // ghiChu
  final String? cancelReason; // lyDoHuy
  final DateTime createdAt; // ngayTao

  // Status Helper Getters
  bool get isPending {
    final s = status.toLowerCase();
    return s == 'pending' ||
        s == 'pending_payment' ||
        s == 'pending_confirmation' ||
        s == 'choduyet' ||
        s == 'cho_duyet' ||
        s == 'choxacnhan' ||
        s == 'dangxuly' ||
        s == 'disburse';
  }

  bool get isApproved {
    final s = status.toLowerCase();
    return s == 'approved' ||
        s == 'daduyet' ||
        s == 'da_duyet' ||
        s == 'deposit_paid' ||
        s == 'paid' ||
        s == 'completed' ||
        s == 'dacoc' ||
        s == 'chonhanphong';
  }

  bool get isActive {
    final s = status.toLowerCase();
    return s == 'active' ||
        s == 'dango' ||
        s == 'dang_o' ||
        s == 'danhanphong';
  }

  bool get isCancelled {
    final s = status.toLowerCase();
    return s == 'cancelled' ||
        s == 'dahuy' ||
        s == 'da_huy' ||
        s == 'rejected' ||
        s == 'tuchoi';
  }

  String get normalizedStatus {
    if (isCancelled) return 'daHuy';
    if (isActive) return 'dangO';
    if (isApproved) return 'daDuyet';
    return 'choDuyet';
  }

  String get statusDisplayVi {
    if (isCancelled) return 'Đã hủy';
    if (isActive) return 'Đang ở';
    if (isApproved) return 'Đã duyệt';
    return 'Chờ duyệt';
  }

  Map<String, dynamic> toQrData() {
    final effectiveTotal = totalAmount > 0
        ? totalAmount
        : (paymentOption == 'full' ? roomPrice : (deposit > 0 ? deposit : roomPrice));
    return {
      'type': 'checkin',
      'bookingId': id,
      'bookingCode': id,
      'roomId': roomId,
      'roomCode': roomCode.isNotEmpty ? roomCode : roomTitle,
      'roomTitle': roomTitle,
      'roomAddress': roomAddress,
      'roomPrice': roomPrice,
      'deposit': deposit,
      'totalAmount': effectiveTotal,
      'paymentAmount': effectiveTotal,
      'paidAmount': effectiveTotal,
      'rentalMonths': rentalMonths,
      'paymentOption': paymentOption,
      'paymentType': paymentOption,
      'renterId': renterId,
      'renterUserCode': renterUserCode,
      'renterName': renterName,
      'renterPhone': renterPhone,
      'renterGender': renterGender,
      'moveInDate': moveInDate.toIso8601String(),
      'status': status,
    };
  }

  // Vietnamese DrawIO Alias Getters
  String get donId => id;
  String get phongId => roomId;
  String get roomCode => _roomCode ?? '';
  String get maPhong => roomCode;
  String get nguoiDungId => renterId;
  String get renterUserCode => _renterUserCode ?? '';
  String get maNguoiDung => renterUserCode;
  String get tenNguoiO => renterName;
  String get sdtNguoiO => renterPhone;
  String get gioiTinhNguoiO => renterGender;
  String get tieuDePhong => roomTitle;
  String get diaChiPhong => roomAddress;
  double get giaThue => roomPrice;
  double get tienCoc => deposit;
  double get tongPhaiTra => totalAmount;
  int get soThangThue => rentalMonths;
  String get chuNhaId => hostId;
  String get tenChuNha => hostName;
  String get trangThai => status;
  String get hinhThucThanhToan => paymentOption;
  String get ghiChuChuyenKhoan => transferNote ?? renterUserCode;
  DateTime get ngayVao => moveInDate;
  DateTime? get ngayChapNhan => acceptedDate;
  String get ghiChu => note;
  String? get lyDoHuy => cancelReason;
  DateTime get ngayTao => createdAt;

  BookingRequestModel({
    required this.id,
    required this.renterId,
    String? renterUserCode = '',
    required this.renterName,
    required this.renterPhone,
    this.renterGender = 'nam',
    required this.roomId,
    String? roomCode = '',
    required this.roomTitle,
    required this.roomAddress,
    required this.roomPrice,
    this.deposit = 0.0,
    this.totalAmount = 0.0,
    this.rentalMonths = 1,
    this.hostId = '',
    required this.hostName,
    this.status = 'pending',
    this.paymentOption = 'deposit',
    this.transferNote,
    required this.moveInDate,
    this.acceptedDate,
    this.note = '',
    this.cancelReason,
    required this.createdAt,
  })  : _renterUserCode = renterUserCode ?? '',
        _roomCode = roomCode ?? '';

  BookingRequestModel copyWith({
    String? id,
    String? renterId,
    String? renterUserCode,
    String? renterName,
    String? renterPhone,
    String? renterGender,
    String? roomId,
    String? roomCode,
    String? roomTitle,
    String? roomAddress,
    double? roomPrice,
    double? deposit,
    double? totalAmount,
    int? rentalMonths,
    String? hostId,
    String? hostName,
    String? status,
    String? paymentOption,
    String? transferNote,
    DateTime? moveInDate,
    DateTime? acceptedDate,
    String? note,
    String? cancelReason,
    DateTime? createdAt,
  }) {
    return BookingRequestModel(
      id: id ?? this.id,
      renterId: renterId ?? this.renterId,
      renterUserCode: renterUserCode ?? this.renterUserCode,
      renterName: renterName ?? this.renterName,
      renterPhone: renterPhone ?? this.renterPhone,
      renterGender: renterGender ?? this.renterGender,
      roomId: roomId ?? this.roomId,
      roomCode: roomCode ?? this.roomCode,
      roomTitle: roomTitle ?? this.roomTitle,
      roomAddress: roomAddress ?? this.roomAddress,
      roomPrice: roomPrice ?? this.roomPrice,
      deposit: deposit ?? this.deposit,
      totalAmount: totalAmount ?? this.totalAmount,
      rentalMonths: rentalMonths ?? this.rentalMonths,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      status: status ?? this.status,
      paymentOption: paymentOption ?? this.paymentOption,
      transferNote: transferNote ?? this.transferNote,
      moveInDate: moveInDate ?? this.moveInDate,
      acceptedDate: acceptedDate ?? this.acceptedDate,
      note: note ?? this.note,
      cancelReason: cancelReason ?? this.cancelReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory BookingRequestModel.fromFirestore(DocumentSnapshot doc) {
    return BookingRequestModel.fromMap(doc.data() as Map<String, dynamic>? ?? {}, doc.id);
  }

  factory BookingRequestModel.fromMap(Map<String, dynamic> data, String id) {
    return BookingRequestModel(
      id: id,
      renterId: data['nguoiDungId'] ?? data['nguoiDung_Id'] ?? data['renterId'] ?? data['khachXemId'] ?? '',
      renterUserCode: data['maNguoiDung'] ?? data['renterUserCode'] ?? data['userCode'] ?? '',
      renterName: data['tenNguoiO'] ?? data['renterName'] ?? data['tenKhach'] ?? '',
      renterPhone: data['sdtNguoiO'] ?? data['renterPhone'] ?? data['sdtKhach'] ?? '',
      renterGender: data['gioiTinhNguoiO'] ?? data['renterGender'] ?? 'nam',
      roomId: data['phongId'] ?? data['roomId'] ?? data['baiDangId'] ?? '',
      roomCode: (data['roomCode'] ?? data['maPhong'] ?? '').toString(),
      roomTitle: data['tieuDePhong'] ?? data['roomTitle'] ?? data['tieuDe'] ?? '',
      roomAddress: data['diaChiPhong'] ?? data['roomAddress'] ?? data['diaChi'] ?? '',
      roomPrice: ((data['giaThue'] ?? data['giaPhong'] ?? data['roomPrice'] ?? data['price'] ?? data['rentalPrice']) as num?)?.toDouble() ?? 0.0,
      deposit: ((data['tienCoc'] ?? data['deposit'] ?? data['depositAmount']) as num?)?.toDouble() ?? 0.0,
      totalAmount: ((data['tongPhaiTra'] ?? data['totalAmount'] ?? data['paymentAmount'] ?? data['amount'] ?? data['paidAmount']) as num?)?.toDouble() ?? 0.0,
      rentalMonths: ((data['soThangThue'] ?? data['rentalMonths']) as num?)?.toInt() ?? 1,
      hostId: data['chuNhaId'] ?? data['hostId'] ?? '',
      hostName: data['tenChuNha'] ?? data['hostName'] ?? '',
      status: data['status'] ?? data['trangThai'] ?? 'pending',
      paymentOption: (data['hinhThucThanhToan'] ?? data['paymentOption'] ?? data['paymentType'] ?? 'deposit').toString(),
      transferNote: data['ghiChuChuyenKhoan'] ?? data['maNguoiDung'] ?? data['transferNote'] ?? data['renterUserCode'] ?? data['userCode'],
      moveInDate: (data['ngayVao'] is Timestamp)
          ? (data['ngayVao'] as Timestamp).toDate()
          : (data['thoiDiem'] is Timestamp)
              ? (data['thoiDiem'] as Timestamp).toDate()
              : (data['moveInDate'] is Timestamp)
                  ? (data['moveInDate'] as Timestamp).toDate()
                  : DateTime.now(),
      acceptedDate: (data['ngayChapNhan'] is Timestamp)
          ? (data['ngayChapNhan'] as Timestamp).toDate()
          : (data['acceptedDate'] is Timestamp)
              ? (data['acceptedDate'] as Timestamp).toDate()
              : null,
      note: data['ghiChu'] ?? data['note'] ?? '',
      cancelReason: data['cancelReason'] ?? data['lyDoHuy'],
      createdAt: (data['ngayTao'] is Timestamp)
          ? (data['ngayTao'] as Timestamp).toDate()
          : (data['createdAt'] is Timestamp)
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookingId': id,
      'userId': renterId,
      'renterId': renterId,
      'renterUserCode': renterUserCode,
      'renterName': renterName,
      'renterPhone': renterPhone,
      'renterGender': renterGender,
      'roomId': roomId,
      'roomCode': roomCode,
      'roomTitle': roomTitle,
      'roomAddress': roomAddress,
      'rentalPrice': roomPrice,
      'depositAmount': deposit,
      'totalAmount': totalAmount,
      'rentalMonths': rentalMonths,
      'hostId': hostId,
      'hostName': hostName,
      'status': status,
      'paymentOption': paymentOption,
      'transferNote': transferNote ?? renterUserCode,
      'moveInDate': Timestamp.fromDate(moveInDate),
      if (acceptedDate != null) 'acceptedDate': Timestamp.fromDate(acceptedDate!),
      'note': note,
      if (cancelReason != null) 'cancelReason': cancelReason,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  String toQrJson() => jsonEncode(toQrData());
}
