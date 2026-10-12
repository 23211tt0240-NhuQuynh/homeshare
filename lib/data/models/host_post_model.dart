import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/auth/providers/user_provider.dart';
import 'room_model.dart';

/// Model Bài đăng Chủ trọ chuẩn hóa theo SDS & Database.docx:
/// Bài đăng ├── phongId ├── chuNhaId ├── diaDiemId ├── loaiThue_id └── trangThai_id
class HostPostModel {
  final String id;
  final String phongId;
  final String chuNhaId;
  final String diaDiemId;
  final String loaiThueId;
  final String trangThaiId;
  final String tieuDe;
  final String moTa;
  final double giaThue;
  final int phanTramTienCoc;
  final double tienCoc;
  final String soDienThoaiLienHe;
  final DateTime ngayDang;
  final String authorName;
  final String authorAvatar;
  final String address;
  final List<String> images;
  final List<String> amenities;
  final String mucDichHopTac;
  final int interestedCount;
  final int responseCount;
  final bool isVerified;
  final bool isVip;
  final double roomArea;
  final String roomType;
  final String propertyName;
  final String city;
  final String district;
  final bool isUserInterested;
  final RoomModel? joinedRoom;
  final UserProfile? joinedHost;

  const HostPostModel({
    required this.id,
    this.phongId = '',
    this.chuNhaId = '',
    this.diaDiemId = '',
    this.loaiThueId = 'thang',
    this.trangThaiId = 'dangHienThi',
    required this.tieuDe,
    required this.moTa,
    required this.giaThue,
    this.phanTramTienCoc = 20,
    this.tienCoc = 0.0,
    this.soDienThoaiLienHe = '',
    required this.ngayDang,
    this.authorName = '',
    this.authorAvatar = '',
    this.address = '',
    this.images = const [],
    this.amenities = const [],
    this.mucDichHopTac = 'Chia sẻ khách thuê & Hợp tác quản lý',
    this.interestedCount = 0,
    this.responseCount = 0,
    this.isVerified = false,
    this.isVip = false,
    this.roomArea = 0.0,
    this.roomType = 'Phòng trọ',
    this.propertyName = '',
    this.city = '',
    this.district = '',
    this.isUserInterested = false,
    this.joinedRoom,
    this.joinedHost,
  });

  bool get isActive =>
      trangThaiId != 'daAn' &&
      trangThaiId != 'deleted' &&
      trangThaiId != 'closed' &&
      trangThaiId != 'hidden';

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
    // Tự động nhận diện và làm sạch tất cả trường ảnh từ Firestore
    final imagesList = _parseImagesList(data);
    final amenitiesList = _parseStringList(
      data['amenities'] ?? data['tienIch'] ?? data['danhSachTienIch'],
    );

    DateTime postDate = DateTime.now();
    final rawDate = data['ngayDang'] ?? data['createdAt'] ?? data['ngayTao'];
    if (rawDate is Timestamp) {
      postDate = rawDate.toDate();
    } else if (rawDate is DateTime) {
      postDate = rawDate;
    } else if (rawDate is String) {
      postDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    final double price = (data['giaThue'] ??
            data['price'] ??
            data['gia'] ??
            data['giaThueThang'] ??
            0.0 as num)
        .toDouble();
    final double deposit = (data['tienCoc'] ??
            data['deposit'] ??
            (price *
                ((data['phanTramTienCoc'] as num?)?.toInt() ?? 20) /
                100))
        .toDouble();

    final interestedList = data['interestedUsers'];
    final bool isUserInterested =
        currentUserId.isNotEmpty &&
        interestedList is List &&
        interestedList.contains(currentUserId);

    final int interestedCount = (data['interestedCount'] ??
            data['soNguoiQuanTam'] ??
            data['luotQuanTam'] ??
            (interestedList is List ? interestedList.length : 0) as num?)
        ?.toInt() ??
        0;

    final int responseCount = (data['responseCount'] ??
            data['soPhanHoi'] ??
            data['repliesCount'] ??
            0 as num?)
        ?.toInt() ??
        0;

    final rawAvatar = (data['authorAvatar'] ??
            data['hostAvatar'] ??
            data['avatarUrl'] ??
            data['avatar'] ??
            data['anhDaiDien'] ??
            data['hinhDaiDien'] ??
            '')
        .toString()
        .trim();

    final rawTitle = (data['tieuDe'] ?? data['title'] ?? '').toString().trim();
    var propName = (data['propertyName'] ??
            data['tenNhaTro'] ??
            data['tenCoSo'] ??
            data['coSoName'] ??
            data['property_name'] ??
            '')
        .toString()
        .trim();
    if (propName.isEmpty && rawTitle.contains('•')) {
      final parts = rawTitle.split('•');
      if (parts.length > 1) {
        propName = parts.last.trim();
      }
    }

    final resolvedPhongId = (data['phongId'] ??
            data['roomId'] ??
            data['phong_id'] ??
            data['room_id'] ??
            data['idPhong'] ??
            data['maPhong'] ??
            data['roomCode'] ??
            '')
        .toString()
        .trim();

    final resolvedDiaDiemId = (data['diaDiemId'] ??
            data['locationId'] ??
            data['propertyId'] ??
            data['nhaTroId'] ??
            data['coSoId'] ??
            '')
        .toString()
        .trim();

    return HostPostModel(
      id: id,
      phongId: resolvedPhongId,
      chuNhaId:
          (data['chuNhaId'] ?? data['hostId'] ?? data['userId'] ?? '')
              .toString()
              .trim(),
      diaDiemId: resolvedDiaDiemId,
      loaiThueId: (data['loaiThue_id'] ?? data['loaiThueId'] ?? 'thang')
          .toString()
          .trim(),
      trangThaiId:
          (data['trangThai_id'] ??
                  data['trangThaiId'] ??
                  data['status'] ??
                  'dangHienThi')
              .toString()
              .trim(),
      tieuDe: rawTitle,
      moTa: (data['moTa'] ?? data['description'] ?? '').toString().trim(),
      giaThue: price,
      phanTramTienCoc:
          (data['phanTramTienCoc'] as num?)?.toInt() ??
          (price > 0 && deposit > 0
              ? ((deposit / price) * 100).round()
              : 20),
      tienCoc: deposit,
      soDienThoaiLienHe: (data['soDienThoaiLienHe'] ??
              data['hostPhone'] ??
              data['phone'] ??
              '')
          .toString()
          .trim(),
      ngayDang: postDate,
      authorName: (data['authorName'] ?? data['hostName'] ?? '')
          .toString()
          .trim(),
      authorAvatar: cleanImageUrl(rawAvatar),
      address: (data['address'] ?? data['diaChi'] ?? '').toString().trim(),
      images: imagesList,
      amenities: amenitiesList,
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
      roomArea:
          (data['roomArea'] ?? data['dienTich'] ?? data['area'] ?? 0.0 as num)
              .toDouble(),
      roomType: (data['roomType'] ?? data['loaiPhong'] ?? 'Phòng trọ')
          .toString()
          .trim(),
      propertyName: propName,
      city: (data['city'] ?? data['thanhPho'] ?? '').toString().trim(),
      district: (data['district'] ?? data['quanHuyen'] ?? '')
          .toString()
          .trim(),
      isUserInterested: isUserInterested,
    );
  }

  /// Chuẩn hóa đường dẫn ảnh từ Firestore:
  /// - Tự động bóc tách chuỗi map dạng `{duongDan: https://...}` hoặc `{"url": "https://..."}`.
  /// - Loại bỏ dấu ngoặc kép thừa hoặc khoảng trắng.
  /// - Hỗ trợ cả URL Cloudinary/Firebase Storage, HTTP/HTTPS và Base64 Data URI.
  static String cleanImageUrl(dynamic raw) {
    if (raw == null) return '';
    var s = raw.toString().trim();
    if (s.isEmpty) return '';

    // 1. Nếu chuỗi chứa URL HTTP/HTTPS ở bất kỳ vị trí nào, bóc tách chính xác URL
    final urlMatch = RegExp(r"""https?://[^\s,;"'\]\}\)\>]+""").firstMatch(s);
    if (urlMatch != null) {
      return urlMatch.group(0)!.trim();
    }

    // 2. Nếu là Base64 Data URI
    if (s.startsWith('data:image')) {
      return s;
    }

    // 3. Xử lý chuỗi map bị lưu dạng string: ví dụ {duongDan: https://...} hoặc {"url": "https://..."}
    if (s.startsWith('{') && s.endsWith('}')) {
      final match = RegExp(
        r'''["']?(?:duongDan|url|image|photo|duong_dan|hinhAnh|path)["']?\s*:\s*([^,}]+)''',
        caseSensitive: false,
      ).firstMatch(s);
      if (match != null) {
        s = match.group(1)!.trim().replaceAll('"', '').replaceAll("'", "");
      }
    }

    // 4. Loại bỏ dấu nháy bọc ngoài nếu có
    if ((s.startsWith('"') && s.endsWith('"')) ||
        (s.startsWith("'") && s.endsWith("'"))) {
      s = s.substring(1, s.length - 1).trim();
    }

    return s;
  }

  /// Trích xuất danh sách ảnh từ nhiều cấu trúc schema Firestore khác nhau:
  /// - Kiểm tra lần lượt các khóa: images, anhPhong, danhSachAnh, imageUrls, photos, ...
  /// - Hỗ trợ cả trường hợp lưu dưới dạng List hoặc chuỗi đơn hoặc Map con.
  static List<String> parseImagesList(Map<String, dynamic> data) =>
      _parseImagesList(data);

  static List<String> _parseImagesList(Map<String, dynamic> data) {
    final candidateKeys = [
      'images',
      'anhPhong',
      'danhSachAnh',
      'imageUrls',
      'photos',
      'hinhAnh',
      'danhSachHinhAnh',
      'hinhAnhList',
      'photo',
      'image',
      'duongDan',
      'url',
      'anh',
      'thumbnail',
      'nhaTroImages',
      'propertyImages',
      'anhCoSo',
      'hinhAnhCoSo',
      'hinhAnhNhaTro',
      'anhNhaTro',
      'coverImage',
      'hinhDaiDien',
      'hinh',
    ];

    final collected = <String>[];
    for (final key in candidateKeys) {
      if (data.containsKey(key) && data[key] != null) {
        final parsed = _parseStringList(data[key]);
        for (final item in parsed) {
          final clean = cleanImageUrl(item);
          if (clean.isNotEmpty && !collected.contains(clean)) {
            collected.add(clean);
          }
        }
      }
    }

    // Kiểm tra thêm các đối tượng con nếu có (ví dụ: data['property'] hoặc data['room'])
    for (final subKey in ['property', 'room', 'nhaTro', 'phong']) {
      final sub = data[subKey];
      if (sub is Map<String, dynamic>) {
        final subImages = _parseImagesList(sub);
        for (final img in subImages) {
          if (!collected.contains(img)) collected.add(img);
        }
      }
    }

    return collected;
  }

  /// Phân tích dữ liệu danh sách chuỗi hoặc danh sách đối tượng map từ Firestore
  static List<String> _parseStringList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is List) {
      final list = <String>[];
      for (final item in raw) {
        if (item is String && item.trim().isNotEmpty) {
          final urlMatches =
              RegExp(r"""https?://[^\s,;"'\]\}\)\>]+""").allMatches(item);
          if (urlMatches.isNotEmpty) {
            for (final m in urlMatches) {
              final clean = m.group(0)!.trim();
              if (clean.isNotEmpty && !list.contains(clean)) list.add(clean);
            }
          } else {
            final cleaned = cleanImageUrl(item);
            if (cleaned.isNotEmpty && !list.contains(cleaned)) {
              list.add(cleaned);
            }
          }
        } else if (item is Map) {
          final s = cleanImageUrl(
            item['url'] ??
                item['duongDan'] ??
                item['image'] ??
                item['hinhAnh'] ??
                item['photo'] ??
                item['duong_dan'] ??
                item['path'] ??
                item['name'] ??
                item['ten'] ??
                item['amenityName'] ??
                item['tenTienIch'] ??
                '',
          );
          if (s.isNotEmpty && !list.contains(s)) list.add(s);
        }
      }
      return list;
    }
    if (raw is String && raw.trim().isNotEmpty) {
      final urlMatches =
          RegExp(r"""https?://[^\s,;"'\]\}\)\>]+""").allMatches(raw);
      if (urlMatches.isNotEmpty) {
        return urlMatches.map((m) => m.group(0)!.trim()).toSet().toList();
      }
      final cleaned = cleanImageUrl(raw);
      return cleaned.isNotEmpty ? [cleaned] : const [];
    }
    if (raw is Map) {
      final s = cleanImageUrl(
        raw['url'] ??
            raw['duongDan'] ??
            raw['image'] ??
            raw['hinhAnh'] ??
            raw['photo'] ??
            raw['duong_dan'] ??
            raw['path'] ??
            '',
      );
      if (s.isNotEmpty) return [s];
    }
    return const [];
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phongId': phongId,
      'chuNhaId': chuNhaId,
      'diaDiemId': diaDiemId,
      'loaiThue_id': loaiThueId,
      'trangThai_id': trangThaiId,
      'tieuDe': tieuDe,
      'moTa': moTa,
      'giaThue': giaThue,
      'phanTramTienCoc': phanTramTienCoc,
      'tienCoc': tienCoc,
      'soDienThoaiLienHe': soDienThoaiLienHe,
      'ngayDang': Timestamp.fromDate(ngayDang),
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'address': address,
      'images': images,
      'amenities': amenities,
      'mucDichHopTac': mucDichHopTac,
      'interestedCount': interestedCount,
      'responseCount': responseCount,
      'isVerified': isVerified,
      'isVip': isVip,
      'roomArea': roomArea,
      'roomType': roomType,
      'propertyName': propertyName,
      'city': city,
      'district': district,
    };
  }

  HostPostModel copyWith({
    String? id,
    String? phongId,
    String? chuNhaId,
    String? diaDiemId,
    String? loaiThueId,
    String? trangThaiId,
    String? tieuDe,
    String? moTa,
    double? giaThue,
    int? phanTramTienCoc,
    double? tienCoc,
    String? soDienThoaiLienHe,
    DateTime? ngayDang,
    String? authorName,
    String? authorAvatar,
    String? address,
    List<String>? images,
    List<String>? amenities,
    String? mucDichHopTac,
    int? interestedCount,
    int? responseCount,
    bool? isVerified,
    bool? isVip,
    double? roomArea,
    String? roomType,
    String? propertyName,
    String? city,
    String? district,
    bool? isUserInterested,
    RoomModel? joinedRoom,
    UserProfile? joinedHost,
  }) {
    return HostPostModel(
      id: id ?? this.id,
      phongId: phongId ?? this.phongId,
      chuNhaId: chuNhaId ?? this.chuNhaId,
      diaDiemId: diaDiemId ?? this.diaDiemId,
      loaiThueId: loaiThueId ?? this.loaiThueId,
      trangThaiId: trangThaiId ?? this.trangThaiId,
      tieuDe: tieuDe ?? this.tieuDe,
      moTa: moTa ?? this.moTa,
      giaThue: giaThue ?? this.giaThue,
      phanTramTienCoc: phanTramTienCoc ?? this.phanTramTienCoc,
      tienCoc: tienCoc ?? this.tienCoc,
      soDienThoaiLienHe: soDienThoaiLienHe ?? this.soDienThoaiLienHe,
      ngayDang: ngayDang ?? this.ngayDang,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      address: address ?? this.address,
      images: images ?? this.images,
      amenities: amenities ?? this.amenities,
      mucDichHopTac: mucDichHopTac ?? this.mucDichHopTac,
      interestedCount: interestedCount ?? this.interestedCount,
      responseCount: responseCount ?? this.responseCount,
      isVerified: isVerified ?? this.isVerified,
      isVip: isVip ?? this.isVip,
      roomArea: roomArea ?? this.roomArea,
      roomType: roomType ?? this.roomType,
      propertyName: propertyName ?? this.propertyName,
      city: city ?? this.city,
      district: district ?? this.district,
      isUserInterested: isUserInterested ?? this.isUserInterested,
      joinedRoom: joinedRoom ?? this.joinedRoom,
      joinedHost: joinedHost ?? this.joinedHost,
    );
  }

  /// Nối dữ liệu từ RoomModel
  HostPostModel withRoom(RoomModel room) {
    return copyWith(
      joinedRoom: room,
      roomArea: room.area > 0 ? room.area : (roomArea > 0 ? roomArea : 20.0),
      roomType: room.roomType.isNotEmpty ? room.roomType : roomType,
      propertyName:
          room.title.isNotEmpty ? room.title : propertyName,
      address: address.isNotEmpty ? address : room.address,
      city: city.isNotEmpty ? city : room.city,
      district: district.isNotEmpty ? district : room.district,
      images: images.isNotEmpty ? images : room.images,
      amenities: amenities.isNotEmpty ? amenities : room.amenities,
    );
  }

  /// Nối dữ liệu từ UserProfile của chủ trọ
  HostPostModel withHost(UserProfile host) {
    return copyWith(
      joinedHost: host,
      authorName: authorName.isNotEmpty ? authorName : host.displayName,
      authorAvatar: authorAvatar.isNotEmpty ? authorAvatar : host.avatarUrl,
      soDienThoaiLienHe: soDienThoaiLienHe.isNotEmpty
          ? soDienThoaiLienHe
          : host.phoneNumber,
      isVerified: host.isCccdVerified || isVerified,
      isVip: host.reputationScore >= 80 || host.isCccdVerified || isVip,
    );
  }

  /// Nối dữ liệu địa điểm
  HostPostModel withLocation({String? resolvedCity, String? resolvedDistrict}) {
    return copyWith(
      city: resolvedCity?.isNotEmpty == true ? resolvedCity : city,
      district:
          resolvedDistrict?.isNotEmpty == true ? resolvedDistrict : district,
    );
  }
}
