import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../data/models/room_model.dart';

// Chủ trọ - Dữ liệu cơ sở - Luồng đi: Đọc properties theo tài khoản,
// quy mô dự kiến tách biệt với các phòng thực đã tạo trong host_rooms.
class HostProperty {
  const HostProperty({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.ward,
    this.district = '',
    required this.hostId,
    required this.plannedRooms,
    this.floors = 1,
    this.minRent = 0,
    this.maxRent = 0,
    this.images = const [],
    this.createdAt,
  });
  final String id, name, address, city, district, ward, hostId;
  final int plannedRooms, floors;
  final double minRent, maxRent;
  final List<String> images;
  final DateTime? createdAt;
  String get fullAddress =>
      [address, ward, district, city].where((v) => v.isNotEmpty).join(', ');

  // Chủ trọ - Đọc cơ sở Firestore - Luồng đi: Chuyển tài liệu properties / bat_dong_san
  // thành dữ liệu giao diện; trường chưa có dùng giá trị mặc định.
  factory HostProperty.fromMap(String id, Map<String, dynamic> data) {
    final rawWard =
        (data['ward'] ??
                data[BatDongSanSqlFields.phuongXa] ??
                data['phuongXa'] ??
                '')
            as String;
    const separator = ' — ';
    final legacyParts = rawWard.split(separator);
    final ward = legacyParts.length > 1 ? legacyParts.first : rawWard;
    final storedDistrict =
        (data['district'] ??
                data[BatDongSanSqlFields.quanHuyen] ??
                data['quanHuyen'] ??
                '')
            as String;
    final district = storedDistrict.isNotEmpty
        ? storedDistrict
        : (legacyParts.length > 1
              ? legacyParts.sublist(1).join(separator)
              : '');
    return HostProperty(
      id: id,
      name:
          (data['name'] ??
                  data[BatDongSanSqlFields.tenToaNha] ??
                  data['ten'] ??
                  '')
              as String,
      address:
          (data['address'] ??
                  data[BatDongSanSqlFields.diaChiChiTiet] ??
                  data['diaChi'] ??
                  '')
              as String,
      city:
          (data['city'] ??
                  data[BatDongSanSqlFields.tinhThanh] ??
                  data['thanhPho'] ??
                  '')
              as String,
      district: district,
      ward: ward,
      hostId:
          (data['hostId'] ??
                  data[BatDongSanSqlFields.chuTroId] ??
                  data['chuNhaId'] ??
                  '')
              as String,
      plannedRooms: (data['plannedRooms'] as num?)?.toInt() ?? 0,
      floors: ((data['floors'] ?? data['soTang']) as num?)?.toInt() ?? 1,
      minRent: (data['minRent'] as num?)?.toDouble() ?? 0,
      maxRent: (data['maxRent'] as num?)?.toDouble() ?? 0,
      images: List<String>.from(
        data['images'] as List? ??
            data['anhPhong'] as List? ??
            data['anh'] as List? ??
            data['photos'] as List? ??
            data['anhBatDongSan'] as List? ??
            [],
      ),
      createdAt: (data['createdAt'] is Timestamp)
          ? (data['createdAt'] as Timestamp).toDate()
          : (data[BatDongSanSqlFields.ngayTao] is Timestamp)
          ? (data[BatDongSanSqlFields.ngayTao] as Timestamp).toDate()
          : null,
    );
  }

  /// Chủ trọ - Ghi cơ sở lên Firestore - Luồng đi: Lưu địa chỉ hai cấp bằng
  /// city và ward; không ghi district, kể cả khi model đọc từ bản ghi cũ.
  Map<String, dynamic> toFirestore() => {
    'id': id,
    'hostId': hostId,
    'name': name,
    'address': address,
    'city': city,
    'ward': ward,
    'description': name,
    'plannedRooms': plannedRooms,
    'floors': floors,
    'minRent': minRent,
    'maxRent': maxRent,
    'images': images,
    'status': 'active',
    'createdAt': FieldValue.serverTimestamp(),
  };

  // Chủ trọ - Ghi cơ sở
  Map<String, dynamic> toMap() => toFirestore();

  /// Đường dẫn Sub-collection trên Firestore theo SQL_NHOM4_CHUYENDEDIDONG.sql:
  /// Mối quan hệ 1-N giữa nguoi_dung và bat_dong_san:
  /// Path: users/{hostId}/properties
  static String subCollectionPath(String chuTroId) =>
      HostFirestorePaths.properties(chuTroId);

  /// Đường dẫn Document trong Sub-collection:
  /// Path: users/{hostId}/properties/{propertyId}
  static String docPath(String chuTroId, String propertyId) =>
      HostFirestorePaths.propertyDoc(chuTroId, propertyId);

  /// CollectionReference cho Sub-collection properties
  static CollectionReference<Map<String, dynamic>> subColRef(
    String chuTroId, [
    FirebaseFirestore? firestore,
  ]) => (firestore ?? FirebaseFirestore.instance)
      .collection(FirestoreCollections.users)
      .doc(chuTroId)
      .collection(FirestoreCollections.properties);

  /// Chủ trọ - Xuất cấu trúc SQL cũ - Luồng đi: Giữ cột quan_huyen để tương
  /// thích sơ đồ SQL; đường lưu Firestore hiện hành dùng toFirestore().
  Map<String, dynamic> toBatDongSanSql() => {
    BatDongSanSqlFields.id: id,
    BatDongSanSqlFields.chuTroId: hostId,
    BatDongSanSqlFields.tenToaNha: name,
    BatDongSanSqlFields.diaChiChiTiet: address,
    BatDongSanSqlFields.tinhThanh: city,
    BatDongSanSqlFields.quanHuyen: district,
    BatDongSanSqlFields.phuongXa: ward,
    BatDongSanSqlFields.moTa: name,
    BatDongSanSqlFields.ngayTao: FieldValue.serverTimestamp(),
  };

  /// Factory đọc từ dữ liệu bảng bat_dong_san chuẩn SQL
  factory HostProperty.fromBatDongSanSql(Map<String, dynamic> data, String id) {
    return HostProperty.fromMap(id, data);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HostProperty && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// Chủ trọ - Tổng hợp cơ sở - Luồng đi: Ghép properties với host_rooms theo
// propertyId; chỉ trạng thái occupied tính đang thuê, không tính đặt cọc.
class PropertySummary {
  PropertySummary(this.property, List<RoomModel> allRooms)
    : rooms = allRooms.where((room) => room.propertyId == property.id).toList();
  final HostProperty property;
  final List<RoomModel> rooms;
  // Chủ trọ - Khung giá thực tế - Luồng đi: Tính lại từ phòng còn tồn
  // tại mỗi lần stream thay đổi; chưa có phòng mới dùng giá dự kiến.
  List<double> get _prices => rooms
      .where((r) => r.status != 'deleted' && r.price.isFinite && r.price > 0)
      .map((r) => r.price)
      .toList();
  bool get hasActualRent => _prices.isNotEmpty;
  double get minRent => _prices.isEmpty
      ? property.minRent
      : _prices.reduce((a, b) => a < b ? a : b);
  double get maxRent => _prices.isEmpty
      ? property.maxRent
      : _prices.reduce((a, b) => a > b ? a : b);
  int get rented => rooms.where((r) => r.status == 'occupied').length;
  int get vacant => rooms.where((r) => r.status == 'available').length;
  int get other => rooms.length - rented - vacant;
  double get expectedRevenue => rooms
      .where((r) => r.status == 'occupied')
      .fold(0, (total, r) => total + r.price);
  int get occupancy =>
      rooms.isEmpty ? 0 : (rented * 100 / rooms.length).round();
}
