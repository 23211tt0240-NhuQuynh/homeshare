import 'package:cloud_firestore/cloud_firestore.dart';

import 'room_model.dart';

/// Phí phát sinh lấy từ phòng trên Firebase, dùng để ước tính chia đều.
class RoommateExtraFee {
  final String name;
  final double amount;
  final String unit;
  final bool isMonthly;

  const RoommateExtraFee({
    required this.name,
    required this.amount,
    required this.unit,
    this.isMonthly = false,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'amount': amount,
        'unit': unit,
        'isMonthly': isMonthly,
      };

  factory RoommateExtraFee.fromMap(Map<String, dynamic> data) {
    return RoommateExtraFee(
      name: (data['name'] ?? data['ten'] ?? '').toString().trim(),
      amount: ((data['amount'] ?? data['soTien']) as num?)?.toDouble() ?? 0,
      unit: (data['unit'] ?? data['donVi'] ?? 'đ').toString(),
      isMonthly: data['isMonthly'] == true || data['chiaTheoThang'] == true,
    );
  }

  static List<RoommateExtraFee> fromRoom(RoomModel room) {
    final fees = <RoommateExtraFee>[];
    final electricity = room.electricityRate ?? 0;
    if (electricity > 0) {
      fees.add(RoommateExtraFee(
        name: 'Tiền điện',
        amount: electricity,
        unit: 'đ/kWh',
      ));
    }
    final water = room.waterRate ?? 0;
    if (water > 0) {
      final monthly = water >= 50000;
      fees.add(RoommateExtraFee(
        name: 'Tiền nước',
        amount: water,
        unit: monthly ? 'đ/tháng' : 'đ/m³',
        isMonthly: monthly,
      ));
    }
    final service = room.serviceFee ?? 0;
    if (service > 0) {
      fees.add(RoommateExtraFee(
        name: 'Wifi, rác & dịch vụ',
        amount: service,
        unit: 'đ/tháng',
        isMonthly: true,
      ));
    }
    return fees;
  }
}

/// Model Tin ở ghép chuẩn hóa theo Database homeShare (DrawIO pkg_4: Ở ghép)
/// Bảng: Tin ở ghép, Ảnh tin ở ghép, Yêu cầu trao đổi ở ghép
class RoommatePostModel {
  final String id;
  final String authorId; // nguoiDangId
  final String authorName; // hoTen / tenNguoiDang
  final int authorAge; // tuoi
  final String authorGender; // Nam / Nữ (gioiTinh)
  final String authorOccupation; // ngheNghiep
  final String authorAvatar; // anhDaiDien
  final String title; // tieuDe
  final String description; // noiDung
  final String postType; // loaiTin: 'timNguoiOGhep' (daCoPhong) | 'dangTimPhong'
  final String? propertyType; // loaiNhaO: 'Căn hộ chung cư' | 'Nhà trọ / Phòng trọ / Căn hộ mini' | 'Nhà nguyên căn' | 'Ký túc xá / Sleepbox'
  final double pricePerPerson; // giaMoiNguoi
  final double budgetMin; // nganSachTu
  final double budgetMax; // nganSachDen
  final String address; // diaChi
  final double? latitude; // viDo, dùng để ghim bản đồ
  final double? longitude; // kinhDo, dùng để ghim bản đồ
  final String district; // khuVuc / quanHuyen (diaDiemId)
  final String targetGender; // gioiTinhMongMuon: nu | nam | tatCa
  final List<String> habits; // thoiQuen / soThich
  /// Ảnh chỉ dùng trên UI. Firestore lưu từng ảnh ở `roommate_post_images`.
  final List<String> images;
  final List<String> imageCaptions;
  final bool isVerified; // daXacThuc
  final int matchRate; // doTuongThich (AI Match Rate 0-100%)
  final bool hasRoom; // true = daCoPhong (timNguoiOGhep), false = dangTimPhong
  final String status; // trangThai: dangMo | daDong
  final String contactPhone; // soDienThoai / sdtLienHe
  final String roomId;
  final String bookingId;
  final double deposit;
  final DateTime? moveInDate;
  final List<RoommateExtraFee> extraFees;
  final double area;
  final int capacity;
  final List<String> amenities;
  final DateTime createdAt; // ngayTao
  final DateTime updatedAt; // ngayCapNhat

  // Vietnamese DrawIO Alias Getters
  String get tieuDe => title;
  String get noiDung => description;
  String get nguoiDangId => authorId;
  String get loaiTin => postType;
  String get displayPropertyType => (propertyType != null && propertyType!.isNotEmpty)
      ? propertyType!
      : (hasRoom ? 'Căn hộ chung cư' : 'Phòng trọ sinh viên');
  String get loaiNhaO => displayPropertyType;
  double get giaMoiNguoi => pricePerPerson;
  double get nganSachTu => budgetMin;
  double get nganSachDen => budgetMax;
  String get diaChi => address;
  String get gioiTinhMongMuon => targetGender;
  List<String> get thoiQuen => habits;
  List<String> get anhTinOGhep => images;
  String get trangThai => status;
  String get soDienThoai => contactPhone;
  DateTime get ngayTao => createdAt;
  DateTime get ngayCapNhat => updatedAt;

  RoommatePostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAge,
    required this.authorGender,
    required this.authorOccupation,
    this.authorAvatar = '',
    required this.title,
    required this.description,
    this.postType = 'timNguoiOGhep',
    this.propertyType,
    this.pricePerPerson = 0.0,
    required this.budgetMin,
    required this.budgetMax,
    this.address = '',
    this.latitude,
    this.longitude,
    required this.district,
    required this.targetGender,
    required this.habits,
    this.images = const [],
    this.imageCaptions = const [],
    this.isVerified = true,
    this.matchRate = 94,
    required this.hasRoom,
    this.status = 'dangMo',
    required this.contactPhone,
    this.roomId = '',
    this.bookingId = '',
    this.deposit = 0,
    this.moveInDate,
    this.extraFees = const [],
    this.area = 0,
    this.capacity = 0,
    this.amenities = const [],
    required this.createdAt,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? createdAt;

  RoommatePostModel copyWith({
    String? id,
    String? authorId,
    String? authorName,
    int? authorAge,
    String? authorGender,
    String? authorOccupation,
    String? authorAvatar,
    String? title,
    String? description,
    String? postType,
    String? propertyType,
    double? pricePerPerson,
    double? budgetMin,
    double? budgetMax,
    String? address,
    double? latitude,
    double? longitude,
    String? district,
    String? targetGender,
    List<String>? habits,
    List<String>? images,
    List<String>? imageCaptions,
    bool? isVerified,
    int? matchRate,
    bool? hasRoom,
    String? status,
    String? contactPhone,
    String? roomId,
    String? bookingId,
    double? deposit,
    DateTime? moveInDate,
    List<RoommateExtraFee>? extraFees,
    double? area,
    int? capacity,
    List<String>? amenities,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoommatePostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAge: authorAge ?? this.authorAge,
      authorGender: authorGender ?? this.authorGender,
      authorOccupation: authorOccupation ?? this.authorOccupation,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      title: title ?? this.title,
      description: description ?? this.description,
      postType: postType ?? this.postType,
      propertyType: propertyType ?? this.propertyType,
      pricePerPerson: pricePerPerson ?? this.pricePerPerson,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      district: district ?? this.district,
      targetGender: targetGender ?? this.targetGender,
      habits: habits ?? this.habits,
      images: images ?? this.images,
      imageCaptions: imageCaptions ?? this.imageCaptions,
      isVerified: isVerified ?? this.isVerified,
      matchRate: matchRate ?? this.matchRate,
      hasRoom: hasRoom ?? this.hasRoom,
      status: status ?? this.status,
      contactPhone: contactPhone ?? this.contactPhone,
      roomId: roomId ?? this.roomId,
      bookingId: bookingId ?? this.bookingId,
      deposit: deposit ?? this.deposit,
      moveInDate: moveInDate ?? this.moveInDate,
      extraFees: extraFees ?? this.extraFees,
      area: area ?? this.area,
      capacity: capacity ?? this.capacity,
      amenities: amenities ?? this.amenities,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory RoommatePostModel.fromFirestore(DocumentSnapshot doc) {
    return RoommatePostModel.fromMap(doc.data() as Map<String, dynamic>? ?? {}, doc.id);
  }

  factory RoommatePostModel.fromMap(Map<String, dynamic> data, String id) {
    final loaiTinVal = data['postType'] ?? data['loaiTin'] ?? (data['hasRoom'] == true ? 'timNguoiOGhep' : 'dangTimPhong');
    final hasRoomVal = data['hasRoom'] ?? (loaiTinVal == 'timNguoiOGhep' || loaiTinVal == 'daCoPhong');
    
    // Parse habits / thoiQuen
    final rawHabits = (data['habits'] ?? data['thoiQuen'] ?? data['soThich']) as List<dynamic>?;
    final parsedHabits = rawHabits
            ?.map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    // Parse images / anhTinOGhep
    final rawImages = (data['images'] ?? data['anhTinOGhep'] ?? data['anhPhong']) as List<dynamic>?;
    final parsedImages = rawImages
            ?.map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    final rawCaptions = (data['imageCaptions'] ?? data['ghiChuAnh']) as List<dynamic>?;
    final parsedCaptions = rawCaptions
            ?.map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    return RoommatePostModel(
      id: id,
      authorId: data['authorId'] ?? data['nguoiDangId'] ?? '',
      authorName: data['authorName'] ?? data['hoTen'] ?? data['tenNguoiDang'] ?? 'Thành viên HomeShare',
      authorAge: (data['authorAge'] ?? data['tuoi']) is num ? (data['authorAge'] ?? data['tuoi']).toInt() : 20,
      authorGender: data['authorGender'] ?? data['gioiTinh'] ?? 'Nam',
      authorOccupation: data['authorOccupation'] ?? data['ngheNghiep'] ?? 'Sinh viên',
      authorAvatar: data['authorAvatar'] ?? data['anhDaiDien'] ?? '',
      title: data['title'] ?? data['tieuDe'] ?? '',
      description: data['description'] ?? data['noiDung'] ?? data['moTa'] ?? '',
      postType: loaiTinVal.toString(),
      propertyType: data['propertyType'] ?? data['loaiNhaO'] ?? data['loaiHinh'] ?? (hasRoomVal ? 'Căn hộ chung cư' : 'Phòng trọ sinh viên'),
      pricePerPerson: ((data['pricePerPerson'] ?? data['giaMoiNguoi']) as num?)?.toDouble() ?? 0.0,
      budgetMin: ((data['budgetMin'] ?? data['nganSachTu']) as num?)?.toDouble() ?? 1000000,
      budgetMax: ((data['budgetMax'] ?? data['nganSachDen']) as num?)?.toDouble() ?? 2500000,
      address: data['address'] ?? data['diaChi'] ?? '',
      latitude: data['latitude'] is num ? (data['latitude'] as num).toDouble() : double.tryParse('${data['latitude'] ?? ''}'),
      longitude: data['longitude'] is num ? (data['longitude'] as num).toDouble() : double.tryParse('${data['longitude'] ?? ''}'),
      district: data['district'] ?? data['quanHuyen'] ?? data['khuVuc'] ?? 'TP. Thủ Đức',
      targetGender: data['targetGender'] ?? data['gioiTinhMongMuon'] ?? 'Tất cả',
      habits: parsedHabits,
      images: parsedImages,
      imageCaptions: parsedCaptions,
      isVerified: data['isVerified'] ?? data['daXacThuc'] ?? true,
      matchRate: (data['matchRate'] ?? data['doTuongThich'] ?? 94) is num ? (data['matchRate'] ?? data['doTuongThich'] ?? 94).toInt() : 94,
      hasRoom: hasRoomVal,
      status: data['status'] ?? data['trangThai'] ?? 'dangMo',
      contactPhone: data['contactPhone'] ?? data['soDienThoai'] ?? data['sdtLienHe'] ?? '',
      roomId: (data['roomId'] ?? data['phongTroId'] ?? data['phong_tro_id'] ?? data['phongId'] ?? '').toString(),
      bookingId: (data['bookingId'] ?? data['donDatPhongId'] ?? '').toString(),
      deposit: ((data['deposit'] ?? data['tienCoc'] ?? data['depositAmount']) as num?)?.toDouble() ?? 0,
      moveInDate: (data['moveInDate'] is Timestamp)
          ? (data['moveInDate'] as Timestamp).toDate()
          : (data['ngayVao'] is Timestamp)
              ? (data['ngayVao'] as Timestamp).toDate()
              : null,
      extraFees: _readExtraFees(data['extraFees'] ?? data['phiPhatSinh']),
      area: ((data['area'] ?? data['dienTich'] ?? data['dienTichM2']) as num?)?.toDouble() ?? 0,
      capacity: ((data['capacity'] ?? data['sucChua']) as num?)?.toInt() ?? 0,
      amenities: () {
        final raw = data['amenities'] ?? data['tienIch'];
        if (raw is! List) return <String>[];
        return raw
            .map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
      }(),
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['ngayTao'] is Timestamp)
              ? (data['ngayTao'] as Timestamp).toDate()
              : DateTime.now(),
      updatedAt: (data['updatedAt'] is Timestamp)
          ? (data['updatedAt'] as Timestamp).toDate()
          : (data['ngayCapNhat'] is Timestamp)
              ? (data['ngayCapNhat'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorAge': authorAge,
      'authorGender': authorGender,
      'authorOccupation': authorOccupation,
      'authorAvatar': authorAvatar,
      'title': title,
      'description': description,
      'postType': postType,
      'propertyType': displayPropertyType,
      'pricePerPerson': pricePerPerson,
      'budgetMin': budgetMin,
      'budgetMax': budgetMax,
      'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'district': district,
      'targetGender': targetGender,
      'habits': habits,
      'isVerified': isVerified,
      'matchRate': matchRate,
      'hasRoom': hasRoom,
      'status': status,
      'contactPhone': contactPhone,
      if (roomId.isNotEmpty) 'roomId': roomId,
      if (bookingId.isNotEmpty) 'bookingId': bookingId,
      if (deposit > 0) 'deposit': deposit,
      if (moveInDate != null) 'moveInDate': Timestamp.fromDate(moveInDate!),
      if (extraFees.isNotEmpty)
        'extraFees': extraFees.map((fee) => fee.toMap()).toList(),
      if (area > 0) 'area': area,
      if (capacity > 0) 'capacity': capacity,
      if (amenities.isNotEmpty) 'amenities': amenities,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

List<RoommateExtraFee> _readExtraFees(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => RoommateExtraFee.fromMap(Map<String, dynamic>.from(item)))
      .where((fee) => fee.name.isNotEmpty && fee.amount > 0)
      .toList();
}
