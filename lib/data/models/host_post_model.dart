import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_collections.dart';
import '../../features/auth/providers/user_provider.dart';
import 'room_model.dart';

/// Trạng thái chuẩn của bài đăng: pending, active, rejected (đã loại bỏ hidden)
abstract final class PostStatus {
  static const pending = 'pending';
  static const active = 'active';
  static const rejected = 'rejected';
  static const occupied = 'occupied';
  @Deprecated('Bài đăng không còn dùng hidden, chỉ còn pending, active, rejected, occupied')
  static const hidden = 'hidden';

  static const validStatuses = {pending, active, rejected, occupied};

  static String normalize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return pending;
    final s = raw.toLowerCase().trim();
    if (s == 'active' || s == 'approved' || s == 'daduyet' || s == 'da_duyet' || s == 'danghienthi' || s == 'published') {
      return active;
    }
    if (s == 'occupied' || s == 'dathue' || s == 'da_thue' || s == 'dango' || s == 'dang_o' || s == 'đã có người' || s == 'đang ở') {
      return occupied;
    }
    if (s == 'rejected' || s == 'tuchoi' || s == 'tu_choi' || s == 'bituchoi') {
      return rejected;
    }
    if (s == 'pending' || s == 'choduyet' || s == 'cho_duyet') {
      return pending;
    }
    return pending;
  }
}

/// Model Bài đăng Chủ trọ chuẩn hóa theo Database.docx & quy ước schema:
/// - Code sử dụng biến tiếng Anh chuẩn (roomId, hostId, rentalPrice, depositAmount, ...)
/// - Khi ghi Firestore: chỉ trả về các field trong [PostFields] bằng [toFirestore()]
/// - Cung cấp alias tiếng Việt (phongId, chuNhaId, giaThue, ...) để tương thích giao diện
class HostPostModel {
  // Các trường cốt lõi trong Schema Firestore
  final String id; // postId / baiDangId
  final String roomId; // phongId [FK -> rooms]
  final String propertyId; // nhaTroId [FK -> properties]
  final String hostId; // chuNhaId [FK -> users]
  final String locationId; // diaDiemId [FK -> locations]
  final String rentalTypeId; // loaiThue_id
  final String title; // tieuDe
  final String description; // moTa
  final double rentalPrice; // giaThue
  final double depositAmount; // tienCoc
  final int depositPercentage; // phanTramTienCoc (10–20%)
  final List<String> amenities; // tienIch
  final List<String> images; // anhPhong
  final String address; // diaChi
  final String contactPhone; // soDienThoaiLienHe
  final DateTime createdAt; // ngayDang
  final String status; // trangThai: active, pending, rejected, hidden
  final String rejectReason; // lyDoTuChoi (từ Firestore khi admin từ chối)
  final DateTime? hostResubmittedAt; // thời gian chủ trọ gửi duyệt lại
  final DateTime? reviewedAt; // thời gian admin duyệt / từ chối
  final String reviewedBy; // adminId thực hiện duyệt

  // Các trường nghiệp vụ giao diện và ghép nối bộ nhớ (IN-MEMORY ONLY - KHÔNG LƯU FIRESTORE)
  final String authorName;
  final String authorAvatar;
  final String propertyName;
  final String city;
  final String district;
  final double roomArea;
  final String roomType;
  final String mucDichHopTac;
  final int interestedCount;
  final int responseCount;
  final bool isVerified;
  final bool isVip;
  final bool isUserInterested;
  final RoomModel? joinedRoom;
  final UserProfile? joinedHost;

  HostPostModel({
    required this.id,
    String? roomId,
    String? propertyId,
    String? hostId,
    String? locationId,
    String? rentalTypeId,
    String? statusId,
    String? title,
    String? description,
    double? rentalPrice,
    double? depositAmount,
    int? depositPercentage,
    this.amenities = const [],
    this.images = const [],
    this.address = '',
    String? contactPhone,
    DateTime? createdAt,
    String? status,
    String? rejectReason,
    this.hostResubmittedAt,
    this.reviewedAt,
    this.reviewedBy = '',
    // In-memory UI fields
    this.authorName = '',
    this.authorAvatar = '',
    this.propertyName = '',
    this.city = '',
    this.district = '',
    this.roomArea = 0.0,
    this.roomType = 'Phòng trọ',
    this.mucDichHopTac = 'Chia sẻ khách thuê & Hợp tác quản lý',
    this.interestedCount = 0,
    this.responseCount = 0,
    this.isVerified = false,
    this.isVip = false,
    this.isUserInterested = false,
    this.joinedRoom,
    this.joinedHost,
    // Vietnamese legacy named parameters
    String? phongId,
    String? nhaTroId,
    String? chuNhaId,
    String? diaDiemId,
    String? loaiThueId,
    String? trangThaiId,
    String? tieuDe,
    String? moTa,
    double? giaThue,
    double? tienCoc,
    int? phanTramTienCoc,
    String? soDienThoaiLienHe,
    DateTime? ngayDang,
    String? lyDoTuChoi,
  }) : roomId = roomId ?? phongId ?? '',
       propertyId = propertyId ?? nhaTroId ?? joinedRoom?.propertyId ?? '',
       hostId = hostId ?? chuNhaId ?? '',
       locationId = locationId ?? diaDiemId ?? '',
       rentalTypeId = rentalTypeId ?? loaiThueId ?? 'thang',
       status = PostStatus.normalize(
           (status != null && status.isNotEmpty)
               ? status
               : (statusId ?? trangThaiId ?? 'pending'),
       ),
       title = title ?? tieuDe ?? '',
       description = description ?? moTa ?? '',
       rentalPrice = rentalPrice ?? giaThue ?? 0.0,
       depositAmount = depositAmount ?? tienCoc ?? 0.0,
       depositPercentage = depositPercentage ?? phanTramTienCoc ?? 20,
       contactPhone = contactPhone ?? soDienThoaiLienHe ?? '',
       createdAt = createdAt ?? ngayDang ?? DateTime.now(),
       rejectReason = (rejectReason != null && rejectReason.isNotEmpty)
           ? rejectReason
           : (lyDoTuChoi ?? '');

  // Vietnamese Schema Aliases for backward compatibility in code
  String get phongId => roomId;
  String get nhaTroId => propertyId;
  String get chuNhaId => hostId;
  String get diaDiemId => locationId;
  String get loaiThueId => rentalTypeId;
  String get statusId => status;
  String get trangThaiId => status;
  String get tieuDe => title;
  String get moTa => description;
  double get giaThue => rentalPrice;
  double get tienCoc => depositAmount;
  int get phanTramTienCoc => depositPercentage;
  List<String> get tienIch => amenities;
  List<String> get anhPhong => images;
  String get diaChi => address;
  String get soDienThoaiLienHe => contactPhone;
  DateTime get ngayDang => createdAt;
  String get trangThai => status;
  String get lyDoTuChoi => rejectReason;

  bool get isRejected => PostStatus.normalize(status) == PostStatus.rejected;
  bool get isPending => PostStatus.normalize(status) == PostStatus.pending;
  bool get isActive => PostStatus.normalize(status) == PostStatus.active;
  bool get isOccupied => PostStatus.normalize(status) == PostStatus.occupied || (joinedRoom?.isOccupied == true);
  bool get isApprovedOrActive => isActive || isOccupied;
  @Deprecated('Bài đăng không còn trạng thái hidden, chỉ có pending, active, rejected')
  bool get isHidden => false;

  /// Bài đăng có thể chỉnh sửa: chỉ cho phép khi bị từ chối hoặc đang chờ duyệt,
  /// TUYỆT ĐỐI KHÔNG cho phép chỉnh sửa khi bài đã duyệt / đang hiển thị.
  bool get canEdit => isRejected || isPending;

  /// Phòng trọ gắn kèm đã được nối hoặc tạo đối tượng RoomModel an toàn từ bài đăng
  RoomModel get resolvedRoom => joinedRoom ?? RoomModel(
    id: roomId.isNotEmpty ? roomId : id,
    title: title,
    description: description,
    price: rentalPrice,
    deposit: depositAmount,
    depositPercentage: depositPercentage,
    address: address,
    district: district,
    city: city.isNotEmpty ? city : 'TP. Hồ Chí Minh',
    area: roomArea > 0 ? roomArea : 25.0,
    roomType: roomType.isNotEmpty ? roomType : 'Phòng trọ',
    amenities: amenities,
    images: images,
    hostId: hostId,
    hostName: authorName,
    hostPhone: contactPhone,
    hostAvatar: authorAvatar,
    createdAt: createdAt,
  );

  /// Đường dẫn Sub-collection trên Firestore theo quan hệ 1-N:
  /// Path: host_rooms/{roomId}/rental_posts
  static String subCollectionPath(String roomId) =>
      HostFirestorePaths.rentalPosts(roomId);

  /// Đường dẫn Document trong Sub-collection:
  /// Path: host_rooms/{roomId}/rental_posts/{postId}
  static String docPath(String roomId, String postId) =>
      HostFirestorePaths.rentalPostDoc(roomId, postId);

  /// CollectionReference cho Sub-collection rental_posts
  static CollectionReference<Map<String, dynamic>> subColRef(
    String roomId, [
    FirebaseFirestore? firestore,
  ]) => (firestore ?? FirebaseFirestore.instance)
      .collection(FirestoreCollections.hostRooms)
      .doc(roomId)
      .collection(FirestoreCollections.rentalPosts);

  /// Mapper chuẩn theo bảng rental_posts (100% tiếng Anh)
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'roomId': roomId,
      'propertyId': propertyId,
      'hostId': hostId,
      'title': title,
      'description': description,
      'rentalPrice': rentalPrice,
      'depositAmount': depositAmount,
      'status': PostStatus.normalize(status),
      'images': images,
      'amenities': amenities,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Alias kiểm soát: Không tự gom toàn bộ biến object, ủy thác về [toFirestore]
  Map<String, dynamic> toMap() => toFirestore();

  factory HostPostModel.fromFirestore(
    DocumentSnapshot doc, {
    String currentUserId = '',
  }) {
    return HostPostModel.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      doc.id,
      currentUserId: currentUserId,
    );
  }

  factory HostPostModel.fromMap(
    Map<String, dynamic> data,
    String id, {
    String currentUserId = '',
  }) {
    final imagesList = _parseStringList(
      data[PostFields.images] ??
          data['images'] ??
          data['anhPhong'] ??
          data['danhSachAnh'] ??
          data['imageUrls'],
    );
    final amenitiesList = _parseStringList(
      data[PostFields.amenities] ??
          data['amenities'] ??
          data['tienIch'] ??
          data['danhSachTienIch'],
    );

    DateTime postDate = DateTime.now();
    final rawDate =
        data[PostFields.createdAt] ??
        data['createdAt'] ??
        data['ngayDang'] ??
        data['ngayTao'];
    if (rawDate is Timestamp) {
      postDate = rawDate.toDate();
    } else if (rawDate is DateTime) {
      postDate = rawDate;
    } else if (rawDate is String) {
      postDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    final double price =
        (data[PostFields.rentalPrice] ??
                data['rentalPrice'] ??
                data['giaThue'] ??
                data['price'] ??
                data['gia'] ??
                data['giaThueThang'] ??
                0.0 as num)
            .toDouble();

    final int depositPct =
        (data[PostFields.depositPercentage] ??
                data['depositPercentage'] ??
                data['phanTramTienCoc'] as num?)
            ?.toInt() ??
        20;

    final double deposit =
        (data[PostFields.depositAmount] ??
                data['depositAmount'] ??
                data['tienCoc'] ??
                data['deposit'] ??
                (price > 0 ? (price * depositPct / 100) : 0.0) as num)
            .toDouble();

    final interestedList = data['interestedUsers'];
    final bool isUserInterested =
        currentUserId.isNotEmpty &&
        interestedList is List &&
        interestedList.contains(currentUserId);

    final int interestedCount =
        (data['interestedCount'] ??
                data['soNguoiQuanTam'] ??
                data['luotQuanTam'] ??
                (interestedList is List ? interestedList.length : 0) as num?)
            ?.toInt() ??
        0;

    final int responseCount =
        (data['responseCount'] ??
                data['soPhanHoi'] ??
                data['repliesCount'] ??
                0 as num?)
            ?.toInt() ??
        0;

    final effectiveId = id.isNotEmpty
        ? id
        : (data[PostFields.postId] ?? data['postId'] ?? data['baiDangId'] ?? '')
              .toString()
              .trim();

    return HostPostModel(
      id: effectiveId,
      roomId:
          (data[BaiDangChoThueSqlFields.phongTroId] ??
                  data['phong_tro_id'] ??
                  data[PostFields.roomId] ??
                  data['roomId'] ??
                  data['phongId'] ??
                  '')
              .toString()
              .trim(),
      propertyId:
          (data['propertyId'] ??
                  data['nhaTroId'] ??
                  data['nha_tro_id'] ??
                  data['nhaId'] ??
                  '')
              .toString()
              .trim(),
      hostId:
          (data[BaiDangChoThueSqlFields.chuTroId] ??
                  data['chu_tro_id'] ??
                  data[PostFields.hostId] ??
                  data['hostId'] ??
                  data['chuNhaId'] ??
                  data['userId'] ??
                  '')
              .toString()
              .trim(),
      locationId:
          (data[PostFields.locationId] ??
                  data['locationId'] ??
                  data['diaDiemId'] ??
                  data['placeId'] ??
                  '')
              .toString()
              .trim(),
      rentalTypeId:
          (data[PostFields.rentalTypeId] ??
                  data['rentalTypeId'] ??
                  data['loaiThue_id'] ??
                  'thang')
              .toString()
              .trim(),
      title:
          (data[BaiDangChoThueSqlFields.tieuDe] ??
                  data['tieu_de'] ??
                  data[PostFields.title] ??
                  data['title'] ??
                  data['tieuDe'] ??
                  '')
              .toString()
              .trim(),
      description:
          (data[BaiDangChoThueSqlFields.noiDung] ??
                  data['noi_dung'] ??
                  data[PostFields.description] ??
                  data['description'] ??
                  data['moTa'] ??
                  '')
              .toString()
              .trim(),
      rentalPrice: price,
      depositAmount: deposit,
      depositPercentage: depositPct,
      amenities: amenitiesList,
      images: imagesList,
      address:
          (data[PostFields.address] ?? data['address'] ?? data['diaChi'] ?? '')
              .toString()
              .trim(),
      contactPhone:
          (data[PostFields.contactPhone] ??
                  data['contactPhone'] ??
                  data['soDienThoaiLienHe'] ??
                  data['phone'] ??
                  '')
              .toString()
              .trim(),
      createdAt: postDate,
      status: PostStatus.normalize(
        (data['status'] ??
                data[PostFields.status] ??
                data['statusId'] ??
                data[PostFields.statusId] ??
                data['trang_thai'] ??
                data['trangThai'] ??
                data['trangThai_id'] ??
                data[BaiDangChoThueSqlFields.trangThai] ??
                'pending')
            .toString()
            .trim(),
      ),
      // In-memory UI/Join properties
      authorName: (data['authorName'] ?? data['hostName'] ?? '')
          .toString()
          .trim(),
      authorAvatar: (data['authorAvatar'] ?? data['hostAvatar'] ?? '')
          .toString()
          .trim(),
      propertyName: (data['propertyName'] ?? data['tenNhaTro'] ?? '')
          .toString()
          .trim(),
      city: (data['city'] ?? data['thanhPho'] ?? '').toString().trim(),
      district: (data['district'] ?? data['quanHuyen'] ?? '').toString().trim(),
      roomArea:
          (data['roomArea'] ?? data['dienTich'] ?? data['area'] ?? 0.0 as num)
              .toDouble(),
      roomType: (data['roomType'] ?? data['loaiPhong'] ?? 'Phòng trọ')
          .toString()
          .trim(),
      mucDichHopTac:
          (data['mucDichHopTac'] ??
                  data['purpose'] ??
                  'Chia sẻ khách thuê & Hợp tác quản lý')
              .toString()
              .trim(),
      interestedCount: interestedCount,
      responseCount: responseCount,
      isVerified:
          data['isVerified'] == true ||
          data['xacThuc'] == true ||
          data['daXacThuc'] == true,
      isVip: data['isVip'] == true || data['vip'] == true,
      isUserInterested: isUserInterested,
      rejectReason: (data['rejectReason'] ??
              data['lyDoTuChoi'] ??
              data['reason'] ??
              data['ly_do_tu_choi'] ??
              '')
          .toString()
          .trim(),
      hostResubmittedAt: data['hostResubmittedAt'] is Timestamp
          ? (data['hostResubmittedAt'] as Timestamp).toDate()
          : (data['hostResubmittedAt'] is String
              ? DateTime.tryParse(data['hostResubmittedAt'])
              : null),
      reviewedAt: data['reviewedAt'] is Timestamp
          ? (data['reviewedAt'] as Timestamp).toDate()
          : (data['reviewedAt'] is String
              ? DateTime.tryParse(data['reviewedAt'])
              : null),
      reviewedBy: (data['reviewedBy'] ?? data['nguoiDuyet'] ?? '')
          .toString()
          .trim(),
    );
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      final list = <String>[];
      for (final item in raw) {
        if (item is String && item.trim().isNotEmpty) {
          list.add(item.trim());
        } else if (item is Map) {
          final s =
              (item['url'] ??
                      item['duongDan'] ??
                      item['name'] ??
                      item['ten'] ??
                      item['amenityName'] ??
                      '')
                  .toString()
                  .trim();
          if (s.isNotEmpty) list.add(s);
        }
      }
      return list;
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return [raw.trim()];
    }
    return const [];
  }

  HostPostModel copyWith({
    String? id,
    String? roomId,
    String? hostId,
    String? locationId,
    String? rentalTypeId,
    String? statusId,
    String? title,
    String? description,
    double? rentalPrice,
    double? depositAmount,
    int? depositPercentage,
    List<String>? amenities,
    List<String>? images,
    String? address,
    String? contactPhone,
    DateTime? createdAt,
    String? status,
    // UI/Join fields
    String? authorName,
    String? authorAvatar,
    String? propertyName,
    String? city,
    String? district,
    double? roomArea,
    String? roomType,
    String? mucDichHopTac,
    int? interestedCount,
    int? responseCount,
    bool? isVerified,
    bool? isVip,
    bool? isUserInterested,
    RoomModel? joinedRoom,
    UserProfile? joinedHost,
    String? rejectReason,
    DateTime? hostResubmittedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    // Vietnamese legacy named params
    String? phongId,
    String? chuNhaId,
    String? diaDiemId,
    String? loaiThueId,
    String? trangThaiId,
    String? tieuDe,
    String? moTa,
    double? giaThue,
    double? tienCoc,
    int? phanTramTienCoc,
    String? soDienThoaiLienHe,
    DateTime? ngayDang,
    String? lyDoTuChoi,
  }) {
    return HostPostModel(
      id: id ?? this.id,
      roomId: roomId ?? phongId ?? this.roomId,
      hostId: hostId ?? chuNhaId ?? this.hostId,
      locationId: locationId ?? diaDiemId ?? this.locationId,
      rentalTypeId: rentalTypeId ?? loaiThueId ?? this.rentalTypeId,
      status: status ?? statusId ?? trangThaiId ?? this.status,
      title: title ?? tieuDe ?? this.title,
      description: description ?? moTa ?? this.description,
      rentalPrice: rentalPrice ?? giaThue ?? this.rentalPrice,
      depositAmount: depositAmount ?? tienCoc ?? this.depositAmount,
      depositPercentage:
          depositPercentage ?? phanTramTienCoc ?? this.depositPercentage,
      amenities: amenities ?? this.amenities,
      images: images ?? this.images,
      address: address ?? this.address,
      contactPhone: contactPhone ?? soDienThoaiLienHe ?? this.contactPhone,
      createdAt: createdAt ?? ngayDang ?? this.createdAt,
      rejectReason: rejectReason ?? lyDoTuChoi ?? this.rejectReason,
      hostResubmittedAt: hostResubmittedAt ?? this.hostResubmittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      propertyName: propertyName ?? this.propertyName,
      city: city ?? this.city,
      district: district ?? this.district,
      roomArea: roomArea ?? this.roomArea,
      roomType: roomType ?? this.roomType,
      mucDichHopTac: mucDichHopTac ?? this.mucDichHopTac,
      interestedCount: interestedCount ?? this.interestedCount,
      responseCount: responseCount ?? this.responseCount,
      isVerified: isVerified ?? this.isVerified,
      isVip: isVip ?? this.isVip,
      isUserInterested: isUserInterested ?? this.isUserInterested,
      joinedRoom: joinedRoom ?? this.joinedRoom,
      joinedHost: joinedHost ?? this.joinedHost,
    );
  }

  /// Nối dữ liệu từ RoomModel (bộ nhớ tạm, không ghi vào posts document)
  HostPostModel withRoom(RoomModel room) {
    return copyWith(
      joinedRoom: room,
      roomArea: room.area > 0 ? room.area : (roomArea > 0 ? roomArea : 20.0),
      roomType: room.roomType.isNotEmpty ? room.roomType : roomType,
      propertyName: room.title.isNotEmpty ? room.title : propertyName,
      address: address.isNotEmpty ? address : room.address,
      city: city.isNotEmpty ? city : room.city,
      district: district.isNotEmpty ? district : room.district,
      rentalPrice: rentalPrice > 0 ? rentalPrice : room.price,
      depositAmount: depositAmount > 0 ? depositAmount : room.deposit,
      images: images.isNotEmpty ? images : room.images,
      amenities: amenities.isNotEmpty ? amenities : room.amenities,
    );
  }

  /// Nối dữ liệu từ UserProfile của chủ trọ (bộ nhớ tạm, không ghi vào posts document)
  HostPostModel withHost(UserProfile host) {
    return copyWith(
      joinedHost: host,
      authorName: authorName.isNotEmpty ? authorName : host.displayName,
      authorAvatar: authorAvatar.isNotEmpty ? authorAvatar : host.avatarUrl,
      contactPhone: contactPhone.isNotEmpty ? contactPhone : host.phoneNumber,
      isVerified: host.isCccdVerified || isVerified,
      isVip: host.reputationScore >= 80 || host.isCccdVerified || isVip,
    );
  }

  /// Nối dữ liệu địa điểm (bộ nhớ tạm)
  HostPostModel withLocation({String? resolvedCity, String? resolvedDistrict}) {
    return copyWith(
      city: resolvedCity?.isNotEmpty == true ? resolvedCity : city,
      district: resolvedDistrict?.isNotEmpty == true
          ? resolvedDistrict
          : district,
    );
  }

  /// Chuyển đổi sang RoomModel để mở trực tiếp màn hình chi tiết RoomDetailScreen
  RoomModel toRoomModel() {
    final effectiveRoomId = roomId.trim().isNotEmpty
        ? roomId.trim()
        : ((joinedRoom?.id.trim().isNotEmpty == true) ? joinedRoom!.id.trim() : id);
    final linkedCode = (joinedRoom?.roomCode ?? '').trim();
    return RoomModel(
      id: effectiveRoomId,
      propertyId: propertyId.isNotEmpty ? propertyId : (joinedRoom?.propertyId ?? ''),
      roomCode: linkedCode.isNotEmpty && !RoomModel.looksLikeOpaqueRoomId(linkedCode)
          ? linkedCode
          : '',
      // Ưu tiên occupancy thật từ phòng; post "active" không có nghĩa là còn trống.
      status: (joinedRoom != null && joinedRoom!.isRentedOrOccupied)
          ? (joinedRoom!.status.trim().isNotEmpty
              ? joinedRoom!.status
              : 'occupied')
          : (status.isNotEmpty ? status : statusId),
      title: title.isNotEmpty ? title : (joinedRoom?.title ?? ''),
      description: description.isNotEmpty ? description : (joinedRoom?.description ?? ''),
      price: rentalPrice > 0 ? rentalPrice : (joinedRoom?.price ?? 0.0),
      deposit: depositAmount > 0 ? depositAmount : (joinedRoom?.deposit ?? 0.0),
      depositPercentage: depositPercentage > 0 ? depositPercentage : joinedRoom?.depositPercentage,
      address: address.isNotEmpty ? address : (joinedRoom?.address ?? ''),
      district: district.isNotEmpty ? district : (joinedRoom?.district ?? ''),
      city: city.isNotEmpty ? city : (joinedRoom?.city ?? 'TP. Hồ Chí Minh'),
      area: roomArea > 0 ? roomArea : (joinedRoom?.area ?? 25.0),
      roomType: roomType.isNotEmpty ? roomType : (joinedRoom?.roomType ?? 'Phòng trọ'),
      amenities: amenities.isNotEmpty ? amenities : (joinedRoom?.amenities ?? const []),
      images: images.isNotEmpty ? images : (joinedRoom?.images ?? const []),
      hostId: hostId.isNotEmpty ? hostId : (joinedRoom?.hostId ?? ''),
      hostName: authorName.isNotEmpty ? authorName : (joinedRoom?.hostName ?? 'Chủ trọ'),
      hostPhone: contactPhone.isNotEmpty
          ? contactPhone
          : (joinedRoom?.hostPhone ?? ''),
      hostAvatar: authorAvatar.isNotEmpty ? authorAvatar : (joinedRoom?.hostAvatar ?? ''),
      rating: 5.0,
      reviewCount: 0,
      isAvailable: joinedRoom != null
          ? !joinedRoom!.isRentedOrOccupied && joinedRoom!.isAvailable
          : isActive,
      tenantName: joinedRoom?.tenantName ?? '',
      tenantPhone: joinedRoom?.tenantPhone ?? '',
      contractId: joinedRoom?.contractId ?? '',
      capacity: joinedRoom?.capacity ?? 2,
      floor: joinedRoom?.floor ?? 1,
      createdAt: createdAt,
      electricityRate: joinedRoom?.electricityRate,
      waterRate: joinedRoom?.waterRate,
      serviceFee: joinedRoom?.serviceFee,
    );
  }
}
