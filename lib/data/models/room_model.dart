import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../../core/utils/vietnam_address_parser.dart';

/// Model Phòng trọ & Bài đăng chuẩn hóa theo Database homeShare
/// Bảng: Nhà trọ, Phòng, ẢnhPhong, Tiện ích, Bài đăng
class RoomModel {
  // Chủ trọ - Liên kết phòng với nhà - Luồng đi: Phòng tạo từ khu quản
  // lý lưu propertyId và roomCode; dữ liệu cũ vẫn đọc được khi thiếu trường.
  final String propertyId;
  final String roomCode;
  final String status;
  // Chủ trọ - Chi tiết quản lý phòng - Luồng đi: Đọc phí dịch vụ và
  // khách thuê/hợp đồng nếu có; thiếu dữ liệu không tạo thông tin minh họa.
  final double? electricityRate, waterRate, serviceFee;
  final String tenantName, tenantPhone, tenantAvatar, contractId;
  final DateTime? contractStart, contractEnd, updatedAt;
  final bool hasRentDebt;
  final String id; // phongId / baiDangId
  final String title; // tieuDe / tieuDePhong
  final String description; // moTa / noiDung
  final double price; // giaThueThang / giaThue / gia (VNĐ / tháng)
  final double deposit; // tienCoc
  // Chủ trọ - Tỷ lệ cọc - Luồng đi: Lưu mức 10–100% đã chọn;
  // phòng cũ thiếu tỷ lệ được đối chiếu với số cọc khi mở chỉnh sửa.
  final int? depositPercentage;
  final String address; // diaChi
  final String district; // quanHuyen / khuVuc (diaDiemId)
  final String city; // thanhPho
  final double area; // dienTichM2 / dienTich
  final double? minArea, maxArea;
  String get areaLabel =>
      minArea != null && maxArea != null && minArea != maxArea
      ? '$minArea–$maxArea m²'
      : '${minArea ?? area} m²';
  final String
  roomType; // loaiPhong (studio, gác lửng, phòng đơn, chung cư mini)
  final List<String>
  amenities; // tienIch (wifi, máy lạnh, tủ lạnh, máy giặt, gác lửng, ban công, bảo vệ)
  final List<String> images; // anhPhong / duongDan
  final String hostId; // chuNhaId / nguoiDangId
  final String hostName; // tenChuNha
  final String hostPhone; // soDienThoai / soDienThoaiLienHe
  final String hostAvatar; // anhDaiDien
  final double rating; // soSao / soSaoTrungBinh
  final int reviewCount; // soLuotDanhGia
  final bool isAvailable; // trangThai (conPhong, dangMo)
  final int capacity; // sucChua
  final int floor; // tang
  final DateTime createdAt; // ngayTao / ngayDang

  // Vietnamese DrawIO Alias Getters
  String get phongId => id;
  String get tieuDe => title;
  String get moTa => description;
  double get giaThueThang => price;
  double get gia => price;
  double get tienCoc => deposit;
  String get diaChi => address;
  String get quanHuyen => district;
  String get thanhPho => city;
  double get dienTichM2 => area;
  String get loaiPhong => roomType;
  List<String> get tienIch => amenities;
  List<String> get anhPhong => images;
  String get chuNhaId => hostId;
  String get tenChuNha => hostName;
  String get soDienThoai => hostPhone;
  String get anhDaiDien => hostAvatar;
  double get soSaoTrungBinh => rating;
  int get sucChua => capacity;
  int get tang => floor;
  DateTime get ngayTao => createdAt;
  String get maPhong {
    final clean = roomCode.trim().toUpperCase();
    if (clean.isNotEmpty && clean != 'P001') {
      return clean;
    }
    if (id.isNotEmpty && id != 'P001') {
      return id.trim().toUpperCase();
    }
    if (clean.isNotEmpty && clean != 'P001') {
      return clean;
    }
    if (id.startsWith('sample_room_')) {
      final num = id.replaceAll('sample_room_', '');
      return 'P${num.padLeft(3, '0')}';
    }
    final match = RegExp(r'P\d{3,}', caseSensitive: false).firstMatch(id);
    if (match != null && match.group(0)!.toUpperCase() != 'P001') {
      return match.group(0)!.toUpperCase();
    }
    final titleMatch = RegExp(
      r'P\d{3,}|\b\d{3}\b',
      caseSensitive: false,
    ).firstMatch(title);
    if (titleMatch != null) {
      final val = titleMatch.group(0)!.toUpperCase();
      final formatted = val.startsWith('P') ? val : 'P$val';
      if (formatted != 'P001') return formatted;
    }
    return id.isNotEmpty ? id.trim().toUpperCase() : '';
  }

  String get soPhong => maPhong;
  String get maNhaTro => propertyId;

  bool get isApproved {
    final s = status.toLowerCase().trim();
    return s == 'active' ||
        s == 'approved' ||
        s == 'danghien' ||
        s == 'danghienthi' ||
        s == 'available' ||
        s == 'conphong' ||
        s == 'dangmo';
  }

  bool get isPending {
    final s = status.toLowerCase().trim();
    return s == 'pending' || s == 'choduyet' || s == 'cho_duyet';
  }

  bool get isDeleted {
    final s = status.toLowerCase().trim();
    return s == 'deleted' || s == 'daxoa' || s == 'da_xoa' || s == 'đã xóa';
  }

  bool get isHiddenOrRejected {
    final s = status.toLowerCase().trim();
    return s == 'rejected' ||
        s == 'tuchoi' ||
        s == 'tu_choi' ||
        s == 'hidden' ||
        s == 'daan' ||
        s == 'da_an' ||
        s == 'an' ||
        s == 'ẩn' ||
        s == 'bị ẩn' ||
        s == 'bi_an' ||
        s == 'go' ||
        s == 'gỡ' ||
        s == 'bị gỡ' ||
        s == 'bi_go' ||
        s == 'closed' ||
        s == 'dong' ||
        s == 'đóng' ||
        s == 'khoa' ||
        s == 'khóa' ||
        isDeleted ||
        s == 'unavailable';
  }

  /// Kiểm tra xem bài đăng có phải bài mẫu hardcode (sample) không
  bool get isSampleOrHardcode {
    if (id.toLowerCase().startsWith('sample')) return true;
    if (roomCode.toLowerCase().startsWith('sample')) return true;
    final hId = hostId.toLowerCase().trim();
    if (hId == 'host_chu_ba_101' ||
        hId == 'host_minh_gv' ||
        hId == 'host_linhtrung_99' ||
        hId == 'host_saigon_luxury' ||
        hId.startsWith('host_sample')) {
      return true;
    }
    final t = title.toLowerCase().trim();
    if (t == 'phòng trọ máy lạnh gần đh nông lâm' ||
        t == 'studio ban công thoáng mát nguyễn văn lượng' ||
        t == 'phòng trọ duplex cao cấp d2 hutech' ||
        t == 'căn hộ dịch vụ 1pn mai chí thọ có hồ bơi') {
      return true;
    }
    return false;
  }

  /// Chỉ các bài ĐANG HIỂN THỊ (đã duyệt, còn mở, không bị ẩn/gỡ/từ chối/chờ duyệt, không phải bài mẫu hardcode)
  bool get isDisplayable {
    return isApproved &&
        !isPending &&
        !isHiddenOrRejected &&
        isAvailable &&
        !isSampleOrHardcode;
  }

  String get statusDisplayLabel {
    if (isPending) return 'Chờ duyệt';
    if (isHiddenOrRejected) return 'Đã ẩn';
    final s = status.toLowerCase().trim();
    if (s == 'occupied' || s == 'dathue') return 'Đã thuê';
    return 'Đã duyệt';
  }

  RoomModel({
    required this.id,
    this.propertyId = '',
    this.roomCode = '',
    String? status,
    this.electricityRate,
    this.waterRate,
    this.serviceFee,
    this.tenantName = '',
    this.tenantPhone = '',
    this.tenantAvatar = '',
    this.contractId = '',
    this.contractStart,
    this.contractEnd,
    this.updatedAt,
    this.hasRentDebt = false,
    required this.title,
    required this.description,
    required this.price,
    required this.deposit,
    this.depositPercentage,
    required this.address,
    required this.district,
    this.city = 'TP. Hồ Chí Minh',
    required this.area,
    this.minArea,
    this.maxArea,
    required this.roomType,
    required this.amenities,
    required this.images,
    required this.hostId,
    required this.hostName,
    required this.hostPhone,
    this.hostAvatar = '',
    this.rating = 5.0,
    this.reviewCount = 0,
    this.isAvailable = true,
    this.capacity = 2,
    this.floor = 1,
    required this.createdAt,
  }) : status = status ?? (isAvailable ? 'available' : 'unavailable');

  factory RoomModel.fromFirestore(DocumentSnapshot doc) {
    return RoomModel.fromMap(doc.data() as Map<String, dynamic>? ?? {}, doc.id);
  }

  factory RoomModel.fromMap(Map<String, dynamic> data, String id) {
    return RoomModel(
      id: id,
      minArea: (data['minArea'] as num?)?.toDouble(),
      maxArea: (data['maxArea'] as num?)?.toDouble(),
      electricityRate: _readPositiveDouble(
        data['electricityRate'] ??
            data['electricity_rate'] ??
            data['giaDien'] ??
            data['gia_dien'],
      ),
      waterRate: _readPositiveDouble(
        data['waterRate'] ??
            data['water_rate'] ??
            data['giaNuoc'] ??
            data['gia_nuoc'],
      ),
      serviceFee: _readPositiveDouble(
        data['serviceFee'] ??
            data['service_fee'] ??
            data['wifiRate'] ??
            data['wifi_rate'] ??
            data['giaWifi'] ??
            data['gia_wifi'],
      ),
      tenantName: data['tenantName'] ?? '',
      tenantPhone: data['tenantPhone'] ?? '',
      tenantAvatar: data['tenantAvatar'] ?? '',
      contractId: data['contractId'] ?? '',
      contractStart: (data['contractStart'] as Timestamp?)?.toDate(),
      contractEnd: (data['contractEnd'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      hasRentDebt: data['hasRentDebt'] == true,
      propertyId:
          data['propertyId'] ??
          data['property_id'] ??
          data[PhongTroSqlFields.batDongSanId] ??
          data['bat_dong_san_id'] ??
          data['nhaTroId'] ??
          data['maNhaTro'] ??
          '',
      roomCode: () {
        final explicit =
            data['roomCode'] ??
            data['maPhong'] ??
            data[PhongTroSqlFields.maPhong] ??
            data['ma_phong'] ??
            data['soPhong'];
        if (explicit != null && explicit.toString().trim().isNotEmpty) {
          return explicit.toString().trim().toUpperCase();
        }
        if (id.startsWith('sample_room_')) {
          final num = id.replaceAll('sample_room_', '');
          return 'P${num.padLeft(3, '0')}';
        }
        final match = RegExp(r'P\d{3,}', caseSensitive: false).firstMatch(id);
        if (match != null) return match.group(0)!.toUpperCase();
        if (id.isNotEmpty) return id.trim().toUpperCase();
        return '';
      }(),
      status: () {
        final explicit =
            data['status'] ??
            data['statusId'] ??
            data['trangThai'] ??
            data['trangThai_id'];
        if (explicit != null && explicit.toString().trim().isNotEmpty) {
          return explicit.toString().trim();
        }
        return (data['isAvailable'] == false) ? 'unavailable' : 'available';
      }(),
      title: data['title'] ?? data['tieuDe'] ?? '',
      description: data['description'] ?? data['noiDung'] ?? data['moTa'] ?? '',
      price: () {
        final val =
            data['price'] ??
            data['gia'] ??
            data['giaThue'] ??
            data['rentalPrice'] ??
            data['giaThueThang'] ??
            data['gia_thue'];
        if (val is num) return val.toDouble();
        if (val is String && val.trim().isNotEmpty) {
          final cleaned = val.trim().replaceAll(',', '').replaceAll('.', '');
          return double.tryParse(cleaned) ?? 0.0;
        }
        return 0.0;
      }(),
      depositPercentage: (data['depositPercentage'] as num?)?.toInt(),
      deposit: () {
        final val =
            data['deposit'] ??
            data['tienCoc'] ??
            data['tien_coc'] ??
            data['depositAmount'] ??
            data['tienDatCoc'] ??
            data['datCoc'] ??
            data['tiencoc'];
        if (val is num) return val.toDouble();
        if (val is String && val.trim().isNotEmpty) {
          final cleaned = val.trim().replaceAll(',', '').replaceAll('.', '');
          final parsed = double.tryParse(cleaned);
          if (parsed != null) return parsed;
        }
        final percent = data['phanTramTienCoc'] ?? data['phan_tram_tien_coc'];
        if (percent is num && percent > 0) {
          final priceRaw =
              data['price'] ??
              data['gia'] ??
              data['giaThue'] ??
              data['giaThueThang'] ??
              data['gia_thue'];
          double? p;
          if (priceRaw is num) p = priceRaw.toDouble();
          if (priceRaw is String && priceRaw.trim().isNotEmpty) {
            p = double.tryParse(
              priceRaw.trim().replaceAll(',', '').replaceAll('.', ''),
            );
          }
          if (p != null && p > 0) return p * percent / 100;
        }
        return 0.0;
      }(),
      address:
          data['address'] ?? data['diaChi'] ?? data['dia_chi_chi_tiet'] ?? '',
      district:
          data['district'] ??
          data['quanHuyen'] ??
          data['khuVuc'] ??
          data['diaDiemId'] ??
          '',
      city: data['city'] ?? data['thanhPho'] ?? 'TP. Hồ Chí Minh',
      area: () {
        final val =
            data['area'] ??
            data['dienTich'] ??
            data['dienTichM2'] ??
            data['roomArea'] ??
            data['dien_tich'];
        if (val is num) return val.toDouble();
        if (val is String && val.trim().isNotEmpty) {
          final cleaned = val.trim().replaceAll(',', '.');
          final parsed = double.tryParse(cleaned);
          if (parsed != null) return parsed;
        }
        return 0.0;
      }(),
      roomType: data['roomType'] ?? data['loaiPhong'] ?? 'Phòng trọ',
      amenities: () {
        final raw =
            data['amenities'] ??
            data['tienIch'] ??
            data['danhSachTienIch'] ??
            data['tien_ich'] ??
            data['room_amenities'] ??
            data['roomAmenities'];
        if (raw is List) {
          final list = <String>[];
          for (final item in raw) {
            if (item is String && item.trim().isNotEmpty) {
              list.add(item.trim());
            } else if (item is Map) {
              final name =
                  (item['tenTienIch'] ??
                          item['amenityName'] ??
                          item['name'] ??
                          item['ten'] ??
                          '')
                      .toString()
                      .trim();
              if (name.isNotEmpty) list.add(name);
            }
          }
          return list;
        }
        if (raw is String && raw.trim().isNotEmpty) {
          return [raw.trim()];
        }
        return <String>[];
      }(),
      images: () {
        final raw =
            data['images'] ??
            data['anhPhong'] ??
            data['roomImages'] ??
            data['imageUrls'] ??
            data['photos'] ??
            data['photoUrls'] ??
            data['danhSachAnh'] ??
            data['hinhAnh'] ??
            data['anh_phong'] ??
            data['room_images'] ??
            data['anhList'];
        if (raw is List) {
          final list = <String>[];
          for (final item in raw) {
            if (item is String && item.trim().isNotEmpty) {
              var s = item.trim();
              if (s.startsWith('{') && s.endsWith('}')) {
                final match = RegExp(
                  r'(?:duongDan|url|image|imageUrl|url_anh):\s*([^,}]+)',
                ).firstMatch(s);
                if (match != null) {
                  s = match
                      .group(1)!
                      .trim()
                      .replaceAll('"', '')
                      .replaceAll("'", "");
                }
              }
              if (s.isNotEmpty) list.add(s);
            } else if (item is Map) {
              final url =
                  (item['url'] ??
                          item['url_anh'] ??
                          item['duongDan'] ??
                          item['image'] ??
                          item['imageUrl'] ??
                          item['duong_dan'] ??
                          '')
                      .toString()
                      .trim();
              if (url.isNotEmpty) list.add(url);
            }
          }
          return list;
        }
        if (raw is String && raw.trim().isNotEmpty) {
          return [raw.trim()];
        }
        final single =
            data['image'] ??
            data['imageUrl'] ??
            data['duongDan'] ??
            data['photoUrl'] ??
            data['anh'] ??
            data['hinhAnh'] ??
            data['url_anh'] ??
            data['url'];
        if (single is String && single.trim().isNotEmpty) {
          return [single.trim()];
        }
        return <String>[];
      }(),
      hostId:
          data['hostId'] ??
          data['host_id'] ??
          data['chuNhaId'] ??
          data['chu_tro_id'] ??
          data['userId'] ??
          data['nguoiDangId'] ??
          '',
      hostName:
          data['hostName'] ??
          data['host_name'] ??
          data['tenChuNha'] ??
          data['authorName'] ??
          'Chủ nhà',
      hostPhone:
          data['hostPhone'] ??
          data['host_phone'] ??
          data['soDienThoai'] ??
          data['so_dien_thoai'] ??
          data['soDienThoaiLienHe'] ??
          data['contactPhone'] ??
          '',
      hostAvatar:
          data['hostAvatar'] ??
          data['host_avatar'] ??
          data['avatarUrl'] ??
          data['anhDaiDien'] ??
          data['authorAvatar'] ??
          '',
      rating:
          ((data['rating'] ?? data['soSao'] ?? data['soSaoTrungBinh']) as num?)
              ?.toDouble() ??
          5.0,
      reviewCount:
          ((data['reviewCount'] ?? data['soLuotDanhGia']) as num?)?.toInt() ??
          0,
      isAvailable: () {
        if (data['isAvailable'] is bool) return data['isAvailable'] as bool;
        final raw =
            (data['status'] ??
                    data['statusId'] ??
                    data['trangThai'] ??
                    data['trangThai_id'])
                ?.toString()
                .toLowerCase()
                .trim();
        if (raw == 'rejected' ||
            raw == 'tuchoi' ||
            raw == 'hidden' ||
            raw == 'daan' ||
            raw == 'closed' ||
            raw == 'deleted' ||
            raw == 'daxoa' ||
            raw == 'unavailable') {
          return false;
        }
        return true;
      }(),
      capacity: ((data['capacity'] ?? data['sucChua']) as num?)?.toInt() ?? 2,
      floor: ((data['floor'] ?? data['tang']) as num?)?.toInt() ?? 1,
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['ngayTao'] is Timestamp)
          ? (data['ngayTao'] as Timestamp).toDate()
          : (data['ngayDang'] is Timestamp)
          ? (data['ngayDang'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Mapper chuẩn ghi Firestore theo Database.docx & ERD (100% tiếng Anh)
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'propertyId': propertyId,
      'roomCode': roomCode.isNotEmpty ? roomCode : maPhong,
      'hostId': hostId,
      'hostName': hostName,
      'hostPhone': hostPhone,
      'title': title,
      'description': description,
      'price': price,
      'deposit': deposit,
      if (depositPercentage != null) 'depositPercentage': depositPercentage,
      'area': area,
      'capacity': capacity,
      'floor': floor,
      'roomType': roomType,
      'status': status,
      'isAvailable': isAvailable,
      'amenities': amenities,
      'images': images,
      'address': address,
      'district': district,
      'city': city,
      if (electricityRate != null) 'electricityRate': electricityRate,
      if (waterRate != null) 'waterRate': waterRate,
      if (serviceFee != null) 'serviceFee': serviceFee,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  Map<String, dynamic> toMap() => toFirestore();

  /// Đường dẫn Sub-collection trên Firestore:
  /// Mối quan hệ 1-N giữa properties và rooms:
  /// Path: properties/{propertyId}/rooms
  static String subCollectionPath(String propertyId) =>
      HostFirestorePaths.rooms(propertyId);

  /// Đường dẫn Document trong Sub-collection:
  /// Path: properties/{propertyId}/rooms/{roomId}
  static String docPath(String propertyId, String roomId) =>
      HostFirestorePaths.roomDoc(propertyId, roomId);

  /// Đường dẫn lồng sâu từ Chủ trọ (1-N lồng):
  /// Path: users/{hostId}/properties/{propertyId}/rooms
  static String nestedSubCollectionPath(String hostId, String propertyId) =>
      HostFirestorePaths.nestedRooms(hostId, propertyId);

  /// CollectionReference cho Sub-collection rooms
  static CollectionReference<Map<String, dynamic>> subColRef(
    String propertyId, [
    FirebaseFirestore? firestore,
  ]) => (firestore ?? FirebaseFirestore.instance)
      .collection(FirestoreCollections.properties)
      .doc(propertyId)
      .collection(FirestoreCollections.rooms);

  /// Mapper chuẩn bảng phong_tro theo SQL_NHOM4_CHUYENDEDIDONG.sql (100% trường SQL)
  Map<String, dynamic> toPhongTroSql() => {
    PhongTroSqlFields.id: id,
    PhongTroSqlFields.batDongSanId: propertyId,
    PhongTroSqlFields.maPhong: roomCode,
    PhongTroSqlFields.dienTich: area,
    PhongTroSqlFields.giaThue: price,
    PhongTroSqlFields.tienCoc: deposit,
    PhongTroSqlFields.giaDien: electricityRate ?? 0.0,
    PhongTroSqlFields.giaNuoc: waterRate ?? 0.0,
    PhongTroSqlFields.giaWifi: serviceFee ?? 0.0,
    PhongTroSqlFields.trangThai: isAvailable ? 'TRONG' : 'DA_THUE',
    PhongTroSqlFields.ngayTao: Timestamp.fromDate(createdAt),
  };

  /// Factory đọc từ dữ liệu bảng phong_tro chuẩn SQL
  factory RoomModel.fromPhongTroSql(Map<String, dynamic> data, String id) {
    return RoomModel.fromMap(data, id);
  }

  /// Bổ sung các trường hiển thị còn thiếu của một bài đăng từ các tài liệu
  /// được tham chiếu bởi roomId, propertyId và hostId. Dữ liệu có sẵn trong
  /// `posts` luôn được ưu tiên, tránh ghi đè nội dung bài đăng.
  RoomModel enrichWithRelatedData({
    RoomModel? room,
    Map<String, dynamic>? propertyData,
    Map<String, dynamic>? hostData,
    Map<String, dynamic>? locationData,
  }) {
    String readString(Map<String, dynamic>? data, List<String> keys) {
      if (data == null) return '';
      for (final key in keys) {
        final value = data[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    String joinAddress(Map<String, dynamic>? data) {
      if (data == null) return '';
      final parts = <String>[
        readString(data, const ['address', 'diaChi', 'dia_chi_chi_tiet']),
        readString(data, const ['ward', 'phuongXa', 'phuong_xa']),
        readString(data, const ['district', 'quanHuyen', 'quan_huyen']),
        readString(data, const ['city', 'province', 'thanhPho', 'tinh_thanh']),
      ];
      return parts.where((part) => part.isNotEmpty).toSet().join(', ');
    }

    final currentName = hostName.trim();
    final normalizedName = currentName.toLowerCase();
    final shouldResolveHostName =
        currentName.isEmpty ||
        normalizedName == 'chủ nhà' ||
        normalizedName == 'chủ trọ';
    final relatedHostName = readString(hostData, const [
      'displayName',
      'ho_ten',
      'hoTen',
      'name',
      'cccdFullName',
      'ho_ten_cccd',
    ]);
    final roomAddress = room?.address.trim() ?? '';
    final propertyAddress = joinAddress(propertyData);
    final locationAddress = joinAddress(locationData);
    final resolvedAddress = VietnamAddressParser.pickBest([
      address.trim(),
      roomAddress,
      propertyAddress,
      locationAddress,
    ]);
    final resolvedHostId = hostId.trim().isNotEmpty
        ? hostId.trim()
        : (room?.hostId.trim() ?? '').isNotEmpty
        ? room!.hostId.trim()
        : readString(hostData, const [
            'userId',
            'uid',
            'id',
            'nguoiDungId',
            'nguoi_dung_id',
          ]);
    final resolvedPropertyId = propertyId.trim().isNotEmpty
        ? propertyId.trim()
        : (room?.propertyId.trim() ?? '');

    return copyWith(
      propertyId: resolvedPropertyId,
      area: (room?.area ?? 0) > 0 && area <= 0 ? room!.area : area,
      capacity: (room?.capacity ?? 0) > 0 && capacity <= 0
          ? room!.capacity
          : capacity,
      amenities: amenities.isNotEmpty
          ? amenities
          : (room?.amenities ?? amenities),
      electricityRate: electricityRate ?? room?.electricityRate,
      waterRate: waterRate ?? room?.waterRate,
      serviceFee: serviceFee ?? room?.serviceFee,
      address: resolvedAddress,
      district: district.trim().isNotEmpty
          ? district.trim()
          : (room?.district.trim() ?? '').isNotEmpty
          ? room!.district.trim()
          : readString(propertyData, const [
              'district',
              'quanHuyen',
              'quan_huyen',
            ]),
      city: city.trim().isNotEmpty
          ? city.trim()
          : (room?.city.trim() ?? '').isNotEmpty
          ? room!.city.trim()
          : readString(propertyData, const [
              'city',
              'province',
              'thanhPho',
              'tinh_thanh',
            ]),
      hostId: resolvedHostId,
      hostName: shouldResolveHostName && relatedHostName.isNotEmpty
          ? relatedHostName
          : currentName,
      hostPhone: hostPhone.trim().isNotEmpty
          ? hostPhone.trim()
          : readString(hostData, const [
              'phoneNumber',
              'so_dien_thoai',
              'soDienThoai',
              'phone',
            ]),
      hostAvatar: hostAvatar.trim().isNotEmpty
          ? hostAvatar.trim()
          : readString(hostData, const [
              'avatarUrl',
              'anhDaiDien',
              'anh_dai_dien',
            ]),
    );
  }

  RoomModel copyWith({
    String? id,
    String? propertyId,
    String? roomCode,
    String? title,
    String? description,
    double? price,
    double? deposit,
    int? depositPercentage,
    String? address,
    String? district,
    String? city,
    double? area,
    double? minArea,
    double? maxArea,
    String? roomType,
    List<String>? amenities,
    List<String>? images,
    String? hostId,
    String? hostName,
    String? hostPhone,
    String? hostAvatar,
    double? rating,
    int? reviewCount,
    bool? isAvailable,
    int? capacity,
    int? floor,
    DateTime? createdAt,
    String? status,
    String? tenantName,
    String? tenantPhone,
    String? tenantAvatar,
    String? contractId,
    DateTime? contractStart,
    DateTime? contractEnd,
    DateTime? updatedAt,
    bool? hasRentDebt,
    double? electricityRate,
    double? waterRate,
    double? serviceFee,
  }) {
    return RoomModel(
      id: id ?? this.id,
      propertyId: propertyId ?? this.propertyId,
      roomCode: roomCode ?? this.roomCode,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      deposit: deposit ?? this.deposit,
      depositPercentage: depositPercentage ?? this.depositPercentage,
      address: address ?? this.address,
      district: district ?? this.district,
      city: city ?? this.city,
      area: area ?? this.area,
      minArea: minArea ?? this.minArea,
      maxArea: maxArea ?? this.maxArea,
      roomType: roomType ?? this.roomType,
      amenities: amenities ?? this.amenities,
      images: images ?? this.images,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostPhone: hostPhone ?? this.hostPhone,
      hostAvatar: hostAvatar ?? this.hostAvatar,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isAvailable: isAvailable ?? this.isAvailable,
      capacity: capacity ?? this.capacity,
      floor: floor ?? this.floor,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      tenantName: tenantName ?? this.tenantName,
      tenantPhone: tenantPhone ?? this.tenantPhone,
      tenantAvatar: tenantAvatar ?? this.tenantAvatar,
      contractId: contractId ?? this.contractId,
      contractStart: contractStart ?? this.contractStart,
      contractEnd: contractEnd ?? this.contractEnd,
      updatedAt: updatedAt ?? this.updatedAt,
      hasRentDebt: hasRentDebt ?? this.hasRentDebt,
      electricityRate: electricityRate ?? this.electricityRate,
      waterRate: waterRate ?? this.waterRate,
      serviceFee: serviceFee ?? this.serviceFee,
    );
  }
}

double? _readPositiveDouble(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  if (raw is String) {
    final text = raw.trim().replaceAll(' ', '').replaceAll(',', '');
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }
  return null;
}
