import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/firestore_collections.dart';
import '../utils/vietnam_address_parser.dart';
import '../../data/models/room_model.dart';

class RoomFilterParams {
  final String city;
  final String district;
  final String rentalType; // 'all', 'single' (Ở 1 mình), 'shared' (Ở ghép)
  final double? minPrice;
  final double? maxPrice;
  final double? minArea;
  final double? maxArea;
  final List<String> amenities;
  final String roomType;
  final String searchQuery;
  final String sortBy; // 'newest', 'price_asc', 'price_desc', 'rating', 'distance'
  final String hostQuery; // Tên, SĐT hoặc Host ID chủ trọ
  final double? userLat;
  final double? userLng;
  final double? maxDistanceKm; // Bán kính km tối đa
  final bool includeUnpostedRooms; // Hiển thị cả phòng chưa đăng bài

  const RoomFilterParams({
    this.city = 'Tất cả',
    this.district = 'Tất cả',
    this.rentalType = 'all',
    this.minPrice,
    this.maxPrice,
    this.minArea,
    this.maxArea,
    this.amenities = const [],
    this.roomType = 'Tất cả',
    this.searchQuery = '',
    this.sortBy = 'newest',
    this.hostQuery = '',
    this.userLat,
    this.userLng,
    this.maxDistanceKm,
    this.includeUnpostedRooms = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomFilterParams &&
          city == other.city &&
          district == other.district &&
          rentalType == other.rentalType &&
          minPrice == other.minPrice &&
          maxPrice == other.maxPrice &&
          minArea == other.minArea &&
          maxArea == other.maxArea &&
          listEquals(amenities, other.amenities) &&
          roomType == other.roomType &&
          searchQuery == other.searchQuery &&
          sortBy == other.sortBy &&
          hostQuery == other.hostQuery &&
          userLat == other.userLat &&
          userLng == other.userLng &&
          maxDistanceKm == other.maxDistanceKm &&
          includeUnpostedRooms == other.includeUnpostedRooms;

  @override
  int get hashCode => Object.hash(
    city,
    district,
    rentalType,
    minPrice,
    maxPrice,
    minArea,
    maxArea,
    Object.hashAll(amenities),
    roomType,
    searchQuery,
    sortBy,
    hostQuery,
    userLat,
    userLng,
    maxDistanceKm,
    includeUnpostedRooms,
  );
}

class RoomService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// `posts` là nguồn dữ liệu công khai tiêu chuẩn của Dashboard người thuê.
  /// Khi [includeUnpostedRooms] = true, hỗ trợ tìm kiếm và hiển thị thêm cả các
  /// phòng trống từ kho phòng của chủ trọ (`host_rooms`/`rooms`) chưa tạo bài đăng công khai.
  @visibleForTesting
  static List<RoomModel> mergeDashboardListings({
    required Iterable<RoomModel> roomMirrors,
    required Iterable<RoomModel> posts,
    bool includeUnpostedRooms = false,
  }) {
    final listingsById = <String, RoomModel>{};
    for (final post in posts) {
      if (post.isDisplayable) listingsById[post.id] = post;
    }

    if (includeUnpostedRooms) {
      final postedRoomIds = <String>{};
      for (final post in listingsById.values) {
        if (post.id.isNotEmpty) postedRoomIds.add(post.id);
        if (post.phongId.isNotEmpty) postedRoomIds.add(post.phongId);
        if (post.roomCode.isNotEmpty) postedRoomIds.add(post.roomCode);
      }

      for (final mirror in roomMirrors) {
        if (mirror.isDeleted) continue;
        final alreadyPosted = postedRoomIds.contains(mirror.id) ||
            postedRoomIds.contains(mirror.phongId) ||
            (mirror.roomCode.isNotEmpty && postedRoomIds.contains(mirror.roomCode));
        if (!alreadyPosted && mirror.isAvailable) {
          listingsById[mirror.id] = mirror.copyWith(isUnposted: true);
        }
      }
    }

    return listingsById.values.toList();
  }

  String _readReference(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  Future<Map<String, dynamic>?> _readDocument(
    Iterable<String> collections,
    String id,
  ) async {
    if (id.trim().isEmpty) return null;
    for (final collection in collections.toSet()) {
      try {
        final doc = await _firestore.collection(collection).doc(id).get();
        final data = doc.data();
        if (doc.exists && data != null) {
          return {...data, 'id': doc.id};
        }
      } catch (error) {
        debugPrint('Không thể đọc $collection/$id: $error');
      }
    }
    return null;
  }

  Future<RoomModel?> _readReferencedRoom(String roomId) async {
    if (roomId.trim().isEmpty) return null;
    final collections = <String>{
      FirestoreCollections.rooms,
      FirestoreCollections.hostRooms,
      FirestoreCollections.phongTro,
    };

    final directData = await _readDocument(collections, roomId);
    if (directData != null) return RoomModel.fromMap(directData, roomId);

    for (final collection in collections) {
      for (final field in const [
        'roomId',
        'room_id',
        'phongId',
        'phong_tro_id',
      ]) {
        try {
          final result = await _firestore
              .collection(collection)
              .where(field, isEqualTo: roomId)
              .limit(1)
              .get();
          if (result.docs.isNotEmpty) {
            final doc = result.docs.first;
            return RoomModel.fromMap(doc.data(), doc.id);
          }
        } catch (error) {
          debugPrint('Không thể tìm phòng $roomId theo $field: $error');
        }
      }
    }
    return null;
  }

  Future<RoomModel> _enrichPostDocument(
    DocumentSnapshot<Map<String, dynamic>> document, {
    RoomModel? referencedRoom,
  }) async {
    final data = document.data() ?? const <String, dynamic>{};
    final post = RoomModel.fromMap(data, document.id);

    try {
      final roomId = _readReference(data, const [
        'roomId',
        'room_id',
        'phongId',
        'phong_tro_id',
      ]);
      final room = referencedRoom ?? await _readReferencedRoom(roomId);
      final hostId = post.hostId.trim().isNotEmpty
          ? post.hostId.trim()
          : (room?.hostId.trim() ?? '');
      final propertyId = post.propertyId.trim().isNotEmpty
          ? post.propertyId.trim()
          : (room?.propertyId.trim() ?? '');
      final locationId = _readReference(data, const [
        'locationId',
        'location_id',
        'diaDiemId',
        'dia_diem_id',
      ]);

      final results = await Future.wait<Map<String, dynamic>?>([
        _readDocument(const [
          FirestoreCollections.users,
          FirestoreCollections.nguoiDung,
        ], hostId),
        _readDocument(const [
          FirestoreCollections.properties,
          FirestoreCollections.batDongSan,
        ], propertyId),
        _readDocument(const [FirestoreCollections.locations], locationId),
      ]);
      final hostData = results[0];
      var propertyData = results[1];
      final locationData = results[2];

      if (propertyData == null && hostId.isNotEmpty && propertyId.isNotEmpty) {
        try {
          final nested = await _firestore
              .collection(FirestoreCollections.users)
              .doc(hostId)
              .collection(FirestoreCollections.properties)
              .doc(propertyId)
              .get();
          if (nested.exists && nested.data() != null) {
            propertyData = {...nested.data()!, 'id': nested.id};
          }
        } catch (error) {
          debugPrint('Không thể đọc nhà trọ $propertyId của $hostId: $error');
        }
      }

      return post.enrichWithRelatedData(
        room: room,
        propertyData: propertyData,
        hostData: hostData,
        locationData: locationData,
      );
    } catch (error, stackTrace) {
      debugPrint('Không thể nối dữ liệu bài đăng ${document.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
      return post;
    }
  }

  Future<RoomModel?> _readListingDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    try {
      // 1. Bỏ tất cả các bài mẫu hardcode (sample_room_...)
      if (document.id.toLowerCase().startsWith('sample')) return null;

      final listing = RoomModel.fromFirestore(document);
      // 2. Lọc CHỈ HIỂN THỊ những bài đang hoạt động (đã duyệt, còn mở):
      // Các bài bị gỡ, bị ẩn, từ chối hoặc chờ duyệt, bài hardcode thì lọc KHÔNG hiển thị.
      if (!listing.isDisplayable) {
        return null;
      }

      // Bài cũ có thể vẫn active trong `posts` dù phòng quản lý đã bị xóa mềm.
      // Kiểm tra phòng gốc để không làm sống lại bài đăng mồ côi trên Dashboard.
      final roomId = _readReference(document.data() ?? const {}, const [
        'roomId',
        'room_id',
        'phongId',
        'phong_tro_id',
      ]);
      final referencedRoom = await _readReferencedRoom(roomId);
      if (referencedRoom?.isDeleted == true) return null;

      final addressText = listing.address
          .replaceAll(RegExp(r'[,\s]'), '')
          .trim();
      final normalizedHost = listing.hostName.trim().toLowerCase();
      final needsRelatedData =
          listing.images.isEmpty ||
          listing.amenities.isEmpty ||
          addressText.isEmpty ||
          VietnamAddressParser.isCityOrProvinceOnly(listing.address) ||
          normalizedHost.isEmpty ||
          normalizedHost == 'chủ nhà' ||
          normalizedHost == 'chủ trọ';
      if (needsRelatedData) {
        final enriched = await _enrichPostDocument(
          document,
          referencedRoom: referencedRoom,
        );
        if (!enriched.isDisplayable) return null;
        return enriched;
      }
      return listing;
    } catch (error, stackTrace) {
      debugPrint('Không thể đọc phòng/bài đăng ${document.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  /// Theo dõi trực tiếp một bài đăng trong collection `posts`.
  ///
  /// Màn chi tiết dùng stream này để luôn phản ánh dữ liệu mới nhất trên
  /// Firestore thay vì tiếp tục hiển thị snapshot được truyền từ danh sách.
  Stream<RoomModel?> watchPostById(String postOrRoomId) {
    if (postOrRoomId.trim().isEmpty) return Stream.value(null);

    late StreamController<RoomModel?> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? directSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? roomIdSub;

    void startRoomIdFallback() {
      if (roomIdSub != null) return;
      roomIdSub = _firestore
          .collection(FirestoreCollections.posts)
          .where(PostFields.roomId, isEqualTo: postOrRoomId)
          .limit(1)
          .snapshots()
          .listen((snapshot) async {
            if (controller.isClosed) return;
            if (snapshot.docs.isEmpty) {
              controller.add(null);
              return;
            }
            final post = await _readListingDocument(snapshot.docs.first);
            if (!controller.isClosed) controller.add(post);
          }, onError: controller.addError);
    }

    controller = StreamController<RoomModel?>(
      onListen: () {
        directSub = _firestore
            .collection(FirestoreCollections.posts)
            .doc(postOrRoomId)
            .snapshots()
            .listen((doc) async {
              if (doc.exists) {
                await roomIdSub?.cancel();
                roomIdSub = null;
                if (!controller.isClosed) {
                  final post = await _readListingDocument(doc);
                  if (!controller.isClosed) controller.add(post);
                }
                return;
              }
              startRoomIdFallback();
            }, onError: controller.addError);
      },
      onCancel: () async {
        await directSub?.cancel();
        await roomIdSub?.cancel();
      },
    );
    return controller.stream;
  }

  // Stream bài đăng công khai realtime. Collection `rooms` không phải nguồn
  // feed vì nó có thể còn bản sao cũ sau khi bài đăng bị xóa.
  Stream<List<RoomModel>> getRoomsStream({
    String? city,
    String? district,
    String? rentalType,
    double? minPrice,
    double? maxPrice,
    double? minArea,
    double? maxArea,
    List<String>? amenities,
    String? roomType,
    String? searchQuery,
    String? sortBy,
    String? hostQuery,
    double? userLat,
    double? userLng,
    double? maxDistanceKm,
    bool includeUnpostedRooms = false,
  }) {
    late StreamController<List<RoomModel>> controller;
    StreamSubscription? postsSub;
    StreamSubscription? hostRoomsSub;
    List<RoomModel> latestPosts = [];
    List<RoomModel> latestRoomMirrors = [];

    List<RoomModel> filterAndSort(List<RoomModel> rawList) {
      // Chỉ giữ lại những bài đang hiển thị hợp lệ hoặc phòng chưa đăng bài được phép hiển thị
      var list = rawList.where((r) => r.isDisplayable || (r.isUnposted && r.isAvailable && !r.isDeleted)).toList();

      // 1. Lọc theo Thành phố
      if (city != null &&
          city.isNotEmpty &&
          city != 'Tất cả' &&
          city != 'Toàn quốc' &&
          city != 'Chọn Tỉnh/Thành phố') {
        final cleanCity = city
            .toLowerCase()
            .replaceFirst('tp. ', '')
            .replaceFirst('thành phố ', '')
            .replaceFirst('tỉnh ', '')
            .trim();
        list = list.where((r) {
          if (r.city.isEmpty) return true;
          return r.city.toLowerCase().contains(city.toLowerCase()) ||
              r.city.toLowerCase().contains(cleanCity) ||
              r.address.toLowerCase().contains(city.toLowerCase()) ||
              r.address.toLowerCase().contains(cleanCity);
        }).toList();
      }

      // 2. Lọc theo Phường/Xã hoặc Quận/Huyện
      if (district != null &&
          district.isNotEmpty &&
          district != 'Tất cả' &&
          district != 'Chọn Phường / Xã') {
        final cleanDistrict = district.toLowerCase();
        final rawBaseName = district.split('(').first.trim().toLowerCase();
        final shortWardName = rawBaseName.replaceFirst('phường ', 'p. ').trim();
        list = list.where((r) {
          final rDist = r.district.toLowerCase();
          final rAddr = r.address.toLowerCase();

          return rDist.contains(cleanDistrict) ||
              rAddr.contains(cleanDistrict) ||
              rDist.contains(rawBaseName) ||
              rAddr.contains(rawBaseName) ||
              rAddr.contains(shortWardName);
        }).toList();
      }

      // 3. Lọc theo loại phòng / hình thức thuê
      if (roomType != null && roomType.isNotEmpty && roomType != 'Tất cả') {
        list = list
            .where(
              (r) => r.roomType.toLowerCase().contains(roomType.toLowerCase()),
            )
            .toList();
      }

      // 4. Lọc theo khoảng giá
      if (minPrice != null && minPrice > 0) {
        list = list.where((r) => r.price >= minPrice).toList();
      }
      if (maxPrice != null && maxPrice > 0 && maxPrice < 20000000) {
        list = list.where((r) => r.price <= maxPrice).toList();
      }

      // 5. Lọc theo diện tích
      if (minArea != null && minArea > 0) {
        list = list.where((r) => r.area >= minArea).toList();
      }
      if (maxArea != null && maxArea > 0 && maxArea < 200) {
        list = list.where((r) => r.area <= maxArea).toList();
      }

      // 6. Lọc theo tiện ích được chọn (khớp ít nhất 1 tiện ích)
      if (amenities != null && amenities.isNotEmpty) {
        list = list.where((r) {
          return amenities.any((a) {
            final key = a.toLowerCase().trim();
            final hasMatch = r.amenities.any(
              (item) =>
                  item.toLowerCase().contains(key) ||
                  key.contains(item.toLowerCase()),
            );
            final hasMatchDesc =
                r.description.toLowerCase().contains(key) ||
                r.title.toLowerCase().contains(key);
            return hasMatch || hasMatchDesc;
          });
        }).toList();
      }

      // 7. Lọc theo từ khóa tìm kiếm
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        list = list
            .where(
              (r) =>
                  r.title.toLowerCase().contains(q) ||
                  r.address.toLowerCase().contains(q) ||
                  r.district.toLowerCase().contains(q) ||
                  r.description.toLowerCase().contains(q),
            )
            .toList();
      }

      // 8. Lọc theo thông tin chủ trọ (Tên, SĐT, hoặc Host ID)
      if (hostQuery != null && hostQuery.trim().isNotEmpty) {
        final hq = hostQuery.toLowerCase().trim();
        final cleanHq = hq.replaceAll(RegExp(r'\s+'), '');
        list = list.where((r) {
          final hName = r.hostName.toLowerCase();
          final hPhone = r.hostPhone.toLowerCase().replaceAll(RegExp(r'\s+'), '');
          final hId = r.hostId.toLowerCase();
          return hName.contains(hq) ||
              hPhone.contains(cleanHq) ||
              hId.contains(hq);
        }).toList();
      }

      // 9. Lọc theo khoảng cách tối đa (so với vị trí người dùng)
      if (userLat != null && userLng != null && maxDistanceKm != null && maxDistanceKm > 0) {
        list = list.where((r) {
          final dist = r.distanceTo(userLat, userLng);
          if (dist == null) return false;
          return dist <= maxDistanceKm;
        }).toList();
      }

      // 10. Sắp xếp kết quả
      switch (sortBy) {
        case 'price_asc':
          list.sort((a, b) => a.price.compareTo(b.price));
          break;
        case 'price_desc':
          list.sort((a, b) => b.price.compareTo(a.price));
          break;
        case 'rating':
          list.sort((a, b) => b.rating.compareTo(a.rating));
          break;
        case 'distance':
          if (userLat != null && userLng != null) {
            list.sort((a, b) {
              final distA = a.distanceTo(userLat, userLng) ?? double.infinity;
              final distB = b.distanceTo(userLat, userLng) ?? double.infinity;
              return distA.compareTo(distB);
            });
          }
          break;
        case 'newest':
        default:
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
      }

      return list;
    }

    void emitMerged() {
      if (controller.isClosed) return;
      final publicListings = mergeDashboardListings(
        roomMirrors: latestRoomMirrors,
        posts: latestPosts,
        includeUnpostedRooms: includeUnpostedRooms,
      );
      final merged = filterAndSort(publicListings);
      controller.add(merged);
    }

    controller = StreamController<List<RoomModel>>(
      onListen: () {
        postsSub = _firestore
            .collection('posts')
            .snapshots()
            .listen(
              (snapshot) async {
                final posts = await Future.wait(
                  snapshot.docs.map(_readListingDocument),
                );
                if (controller.isClosed) return;
                latestPosts = posts.whereType<RoomModel>().toList();
                emitMerged();
              },
              onError: (err) {
                debugPrint('Firestore posts stream error: $err');
                emitMerged();
              },
            );

        if (includeUnpostedRooms) {
          hostRoomsSub = _firestore
              .collection(FirestoreCollections.hostRooms)
              .snapshots()
              .listen(
                (snapshot) {
                  if (controller.isClosed) return;
                  latestRoomMirrors = snapshot.docs
                      .where((d) => !d.id.toLowerCase().startsWith('sample'))
                      .map((d) => RoomModel.fromFirestore(d))
                      .where((r) => r.isAvailable && !r.isDeleted)
                      .toList();
                  emitMerged();
                },
                onError: (err) {
                  debugPrint('Firestore hostRooms stream error: $err');
                  emitMerged();
                },
              );
        }
      },
      onCancel: () async {
        await postsSub?.cancel();
        await hostRoomsSub?.cancel();
      },
    );

    return controller.stream;
  }

  // Lấy chi tiết 1 phòng
  Future<RoomModel?> getRoomById(String id) async {
    final room = await getRoomRecordById(id);
    if (room == null || !room.isDisplayable) return null;
    return room;
  }

  /// Đọc phòng đang thuê kể cả khi đã occupied, không lọc bài đang hiển thị.
  Future<RoomModel?> getRoomRecordById(String id) {
    return resolveRentedRoom(roomId: id);
  }

  /// Ghép phòng công khai `rooms` + bài `posts` (+ `host_rooms` nếu đọc được).
  /// Khách thuê thường không đọc được `host_rooms`; `posts` không lưu area/phí.
  Future<RoomModel?> resolveRentedRoom({
    String roomId = '',
    String hostId = '',
    String roomCode = '',
    String title = '',
    double price = 0,
  }) async {
    final candidateIds = <String>{
      if (roomId.trim().isNotEmpty &&
          !roomId.trim().toLowerCase().startsWith('sample'))
        roomId.trim(),
    };
    final maps = <Map<String, dynamic>>[];
    final seenDocs = <String>{};

    Future<void> absorbMap(Map<String, dynamic>? data, String sourceId) async {
      if (data == null || data.isEmpty) return;
      final key = '$sourceId/${data['id'] ?? ''}';
      if (!seenDocs.add(key)) return;
      maps.add({...data, '_source': sourceId});
      for (final linked in [
        _readReference(data, const [
          'roomId',
          'room_id',
          'phongId',
          'phong_tro_id',
        ]),
        _readReference(data, const ['id']),
        _readReference(data, const ['roomCode', 'maPhong']),
      ]) {
        if (linked.isNotEmpty &&
            !linked.toLowerCase().startsWith('sample')) {
          candidateIds.add(linked);
        }
      }
    }

    Future<void> absorbDoc(String collection, String id) async {
      if (id.isEmpty) return;
      final cacheKey = '$collection/$id';
      if (!seenDocs.add('try:$cacheKey')) return;
      final data = await _readDocument([collection], id);
      await absorbMap(data, collection);
    }

    Future<void> absorbQuery(
      String collection,
      String field,
      String value,
    ) async {
      if (value.trim().isEmpty) return;
      try {
        final snap = await _firestore
            .collection(collection)
            .where(field, isEqualTo: value.trim())
            .limit(10)
            .get();
        for (final doc in snap.docs) {
          await absorbMap({...doc.data(), 'id': doc.id}, collection);
        }
      } catch (error) {
        debugPrint('Không thể truy vấn $collection.$field=$value: $error');
      }
    }

    final triedIds = <String>{};
    while (true) {
      final pending = candidateIds.where((id) => triedIds.add(id)).toList();
      if (pending.isEmpty) break;
      for (final id in pending) {
        await absorbDoc(FirestoreCollections.rooms, id);
        await absorbDoc(FirestoreCollections.posts, id);
        await absorbDoc(FirestoreCollections.hostRooms, id);
        await absorbDoc(FirestoreCollections.phongTro, id);
        for (final field in const [
          'roomId',
          'room_id',
          'phongId',
          'phong_tro_id',
        ]) {
          await absorbQuery(FirestoreCollections.posts, field, id);
          await absorbQuery(FirestoreCollections.rooms, field, id);
        }
      }
    }
    if (roomCode.trim().isNotEmpty) {
      await absorbQuery(FirestoreCollections.rooms, 'roomCode', roomCode);
      await absorbQuery(FirestoreCollections.posts, 'roomCode', roomCode);
      await absorbQuery(FirestoreCollections.hostRooms, 'roomCode', roomCode);
    }
    if (hostId.trim().isNotEmpty) {
      await absorbQuery(FirestoreCollections.rooms, 'hostId', hostId);
      await absorbQuery(FirestoreCollections.rooms, 'chuNhaId', hostId);
      await absorbQuery(FirestoreCollections.posts, 'hostId', hostId);
      await absorbQuery(FirestoreCollections.posts, 'chuNhaId', hostId);
    }

    if (maps.isEmpty) return null;

    int score(Map<String, dynamic> data) {
      var value = 0;
      final dataPrice = _readNumber(data, const [
            'price',
            'giaThue',
            'rentalPrice',
            'gia',
          ]) ??
          0;
      final dataCode = _readReference(data, const ['roomCode', 'maPhong']);
      final dataTitle = _readReference(data, const ['title', 'tieuDe']);
      if ((_readArea(data) ?? 0) > 0) value += 30;
      if ((_readElectricity(data) ?? 0) > 0) value += 20;
      if ((_readWater(data) ?? 0) > 0) value += 10;
      if ((_readServiceFee(data) ?? 0) > 0) value += 10;
      if (_readAmenityList(data).isNotEmpty) value += 15;
      if (price > 0 && dataPrice > 0 && (dataPrice - price).abs() < 1) {
        value += 40;
      }
      if (roomCode.trim().isNotEmpty &&
          dataCode.toLowerCase() == roomCode.trim().toLowerCase()) {
        value += 35;
      }
      if (title.trim().isNotEmpty &&
          dataTitle.isNotEmpty &&
          (dataTitle.toLowerCase().contains(title.trim().toLowerCase()) ||
              title.trim().toLowerCase().contains(dataTitle.toLowerCase()))) {
        value += 15;
      }
      return value;
    }

    Map<String, dynamic>? bestOf(Iterable<Map<String, dynamic>> items) {
      Map<String, dynamic>? best;
      var bestScore = -1;
      for (final item in items) {
        final value = score(item);
        if (best == null || value >= bestScore) {
          best = item;
          bestScore = value;
        }
      }
      return best;
    }

    final bestPost = bestOf(
      maps.where(
        (item) =>
            item['_source'] == FirestoreCollections.posts ||
            item['_source'] == FirestoreCollections.baiDangChoThue,
      ),
    );
    final bestRoom = bestOf(
      maps.where(
        (item) =>
            item['_source'] == FirestoreCollections.rooms ||
            item['_source'] == FirestoreCollections.hostRooms ||
            item['_source'] == FirestoreCollections.phongTro,
      ),
    );
    final merged = <String, dynamic>{};
    void absorb(Map<String, dynamic>? data) {
      if (data == null) return;
      data.forEach((key, value) {
        if (key == '_source') return;
        if (value == null) return;
        if (value is String && value.trim().isEmpty) return;
        if (value is List && value.isEmpty) return;
        if (value is num && value == 0 && merged[key] != null) return;
        merged[key] = value;
      });
    }

    absorb(bestPost);
    absorb(bestRoom);
    if (maps.isEmpty && merged.isEmpty) return null;

    final bestId = _firstNonEmpty([
      _readReference(bestRoom ?? const {}, const ['id', 'roomId', 'phongId']),
      _readReference(bestPost ?? const {}, const ['roomId', 'phongId']),
      _readReference(merged, const ['roomId', 'phongId', 'id']),
      roomId,
    ]);
    if (bestId.isEmpty) return null;
    var room = RoomModel.fromMap(merged, bestId);
    if (room.isSampleOrHardcode) return null;
    return _withHostListingDetails(room);
  }

  Future<RoomModel> _withHostListingDetails(RoomModel room) async {
    try {
      final postData = await _readHostPostData(room);
      final linkedRoomId = _firstNonEmpty([
        _readReference(postData ?? const {}, const [
          'roomId',
          'room_id',
          'phongId',
          'phong_tro_id',
        ]),
        room.id,
      ]);
      final hostRoomData = await _readDocument(const [
        FirestoreCollections.rooms,
        FirestoreCollections.hostRooms,
        FirestoreCollections.phongTro,
      ], linkedRoomId);
      final publicRoomData = linkedRoomId == room.id
          ? null
          : await _readDocument(const [
              FirestoreCollections.rooms,
              FirestoreCollections.hostRooms,
            ], room.id);

      final propertyId = _firstNonEmpty([
        room.propertyId,
        _readReference(postData ?? const {}, const [
          'propertyId',
          'property_id',
          'nhaTroId',
          'maNhaTro',
        ]),
        _readReference(hostRoomData ?? const {}, const [
          'propertyId',
          'property_id',
          'nhaTroId',
        ]),
      ]);
      final hostId = _firstNonEmpty([
        room.hostId,
        _readReference(postData ?? const {}, const ['hostId', 'chuNhaId']),
        _readReference(hostRoomData ?? const {}, const ['hostId', 'chuNhaId']),
      ]);
      var propertyData = await _readDocument(const [
        FirestoreCollections.properties,
        FirestoreCollections.batDongSan,
      ], propertyId);
      if (propertyData == null && hostId.isNotEmpty && propertyId.isNotEmpty) {
        try {
          final nested = await _firestore
              .collection(FirestoreCollections.users)
              .doc(hostId)
              .collection(FirestoreCollections.properties)
              .doc(propertyId)
              .get();
          if (nested.exists && nested.data() != null) {
            propertyData = {...nested.data()!, 'id': nested.id};
          }
        } catch (error) {
          debugPrint('Không thể đọc nhà trọ $propertyId của $hostId: $error');
        }
      }

      final sources = <Map<String, dynamic>?>[
        postData,
        hostRoomData,
        publicRoomData,
        propertyData,
      ];
      final area = _firstPositive(sources.map(_readArea));
      final electricity = _firstPositive(sources.map(_readElectricity));
      final water = _firstPositive(sources.map(_readWater));
      final service = _firstPositive(sources.map(_readServiceFee));
      final capacity = _firstPositive(sources.map(_readCapacity))?.toInt();
      final amenities = _uniqueNames([
        ..._readAmenityList(postData),
        ..._readAmenityList(hostRoomData),
        ..._readAmenityList(publicRoomData),
        ...await _loadAmenityNames(linkedRoomId),
        ...await _loadAmenityNames(room.id),
        ...room.amenities,
      ]);

      final bestAddress = VietnamAddressParser.pickBest([
        _joinStoredAddress(postData),
        _joinStoredAddress(propertyData),
        _joinStoredAddress(hostRoomData),
        VietnamAddressParser.composeParts(
          street: room.address,
          district: room.district,
          city: room.city,
        ),
      ]);
      final district = _firstNonEmpty([
        _readReference(postData ?? const {}, const ['district', 'quanHuyen']),
        _readReference(hostRoomData ?? const {}, const ['district', 'quanHuyen']),
        _readReference(propertyData ?? const {}, const ['district', 'quanHuyen']),
        room.district,
      ]);
      final city = _firstNonEmpty([
        _readReference(postData ?? const {}, const ['city', 'thanhPho', 'province']),
        _readReference(hostRoomData ?? const {}, const ['city', 'thanhPho']),
        _readReference(propertyData ?? const {}, const ['city', 'thanhPho', 'tinh_thanh']),
        room.city,
      ]);

      return room.copyWith(
        address: bestAddress.isNotEmpty ? bestAddress : room.address,
        district: district.isNotEmpty ? district : room.district,
        city: city.isNotEmpty ? city : room.city,
        area: area ?? (room.area > 0 ? room.area : 0),
        capacity: capacity ?? room.capacity,
        amenities: amenities.isNotEmpty ? amenities : room.amenities,
        electricityRate: electricity ?? room.electricityRate,
        waterRate: water ?? room.waterRate,
        serviceFee: service ?? room.serviceFee,
      );
    } catch (error) {
      debugPrint('Không thể ghép dữ liệu bài đăng chủ nhà ${room.id}: $error');
      return room;
    }
  }

  Future<Map<String, dynamic>?> _readHostPostData(RoomModel room) async {
    final direct = await _readDocument(const [
      FirestoreCollections.posts,
      FirestoreCollections.baiDangChoThue,
    ], room.id);
    if (direct != null) return direct;

    for (final field in const ['roomId', 'room_id', 'phongId', 'phong_tro_id']) {
      try {
        final result = await _firestore
            .collection(FirestoreCollections.posts)
            .where(field, isEqualTo: room.id)
            .limit(1)
            .get();
        if (result.docs.isNotEmpty) {
          final doc = result.docs.first;
          return {...doc.data(), 'id': doc.id};
        }
      } catch (error) {
        debugPrint('Không thể tìm bài đăng chủ nhà theo $field=${room.id}: $error');
      }
    }
    return null;
  }

  String _joinStoredAddress(Map<String, dynamic>? data) {
    if (data == null) return '';
    return VietnamAddressParser.composeParts(
      street: _readReference(data, const [
        'address',
        'diaChi',
        'dia_chi_chi_tiet',
      ]),
      ward: _readReference(data, const ['ward', 'phuongXa', 'phuong_xa']),
      district: _readReference(data, const [
        'district',
        'quanHuyen',
        'quan_huyen',
      ]),
      city: _readReference(data, const [
        'city',
        'province',
        'thanhPho',
        'tinh_thanh',
      ]),
    );
  }

  String _firstNonEmpty(Iterable<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  double? _firstPositive(Iterable<double?> values) {
    for (final value in values) {
      if (value != null && value > 0) return value;
    }
    return null;
  }

  double? _readNumber(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final key in keys) {
      final parsed = _parsePositive(data[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  double? _parsePositive(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) {
      final value = raw.toDouble();
      return value > 0 ? value : null;
    }
    if (raw is String) {
      final text = raw
          .trim()
          .replaceAll(' ', '')
          .replaceAll('đ', '')
          .replaceAll('₫', '')
          .replaceAll(',', '');
      if (text.isEmpty) return null;
      final parsed = double.tryParse(text);
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }

  double? _readArea(Map<String, dynamic>? data) => _readNumber(data, const [
        'area',
        'roomArea',
        'dienTich',
        'dienTichM2',
        'dien_tich',
        'minArea',
      ]);

  double? _readElectricity(Map<String, dynamic>? data) =>
      _readNumber(data, const [
        'electricityRate',
        'electricity_rate',
        'giaDien',
        'gia_dien',
        'tienDien',
      ]);

  double? _readWater(Map<String, dynamic>? data) => _readNumber(data, const [
        'waterRate',
        'water_rate',
        'giaNuoc',
        'gia_nuoc',
        'tienNuoc',
      ]);

  double? _readServiceFee(Map<String, dynamic>? data) =>
      _readNumber(data, const [
        'serviceFee',
        'service_fee',
        'wifiRate',
        'wifi_rate',
        'giaWifi',
        'gia_wifi',
        'phiDichVu',
      ]);

  double? _readCapacity(Map<String, dynamic>? data) =>
      _readNumber(data, const ['capacity', 'sucChua', 'suc_chua']);

  List<String> _readAmenityList(Map<String, dynamic>? data) {
    if (data == null) return const [];
    final raw =
        data['amenities'] ??
        data['tienIch'] ??
        data['danhSachTienIch'] ??
        data['tien_ich'] ??
        data['roomAmenities'];
    if (raw is String) {
      return raw
          .split(RegExp(r'[,;|]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (raw is! List) return const [];
    final names = <String>[];
    for (final item in raw) {
      if (item is String && item.trim().isNotEmpty) {
        names.add(item.trim());
      } else if (item is Map) {
        final name = (item['amenityName'] ??
                item['tenTienIch'] ??
                item['ten_tien_ich'] ??
                item['name'] ??
                item['ten'] ??
                '')
            .toString()
            .trim();
        if (name.isNotEmpty) names.add(name);
      }
    }
    return names;
  }

  List<String> _uniqueNames(Iterable<String> names) {
    final seen = <String>{};
    final result = <String>[];
    for (final name in names) {
      final clean = name.trim();
      if (clean.isEmpty) continue;
      if (seen.add(clean.toLowerCase())) result.add(clean);
    }
    return result;
  }

  Future<List<String>> _loadAmenityNames(String roomId) async {
    if (roomId.trim().isEmpty) return const [];
    final targetIds = <String>{
      roomId.trim(),
      if (roomId.contains('_') && roomId.lastIndexOf('_') > 0)
        roomId.substring(0, roomId.lastIndexOf('_')),
    };
    final names = <String>[];
    final pendingCatalogIds = <String>{};
    for (final col in [
      FirestoreCollections.roomAmenities,
      FirestoreCollections.tienIchPhongTro,
      FirestoreCollections.tienIchPhong,
      'room_amenities',
      'tien_ich_phong_tro',
    ]) {
      for (final field in const ['roomId', 'phongId', 'phong_tro_id']) {
        for (final targetId in targetIds) {
          try {
            final snap = await _firestore
                .collection(col)
                .where(field, isEqualTo: targetId)
                .get();
            for (final doc in snap.docs) {
              final data = doc.data();
              final name = (data['amenityName'] ??
                      data['name'] ??
                      data['ten_tien_ich'] ??
                      data['tenTienIch'] ??
                      '')
                  .toString()
                  .trim();
              if (name.isNotEmpty) {
                names.add(name);
                continue;
              }
              final amenityId = (data['amenityId'] ??
                      data['tienIchId'] ??
                      data['tien_ich_id'] ??
                      '')
                  .toString()
                  .trim();
              if (amenityId.isNotEmpty) pendingCatalogIds.add(amenityId);
            }
          } catch (error) {
            debugPrint('Không thể đọc tiện ích $col.$field=$targetId: $error');
          }
        }
      }
    }
    for (final amenityId in pendingCatalogIds) {
      final catalog = await _readDocument(const [
        FirestoreCollections.amenities,
        FirestoreCollections.danhMucTienIch,
      ], amenityId);
      final name = _readReference(catalog ?? const {}, const [
        'name',
        'amenityName',
        'tenTienIch',
        'ten_tien_ich',
      ]);
      if (name.isNotEmpty) names.add(name);
    }
    return _uniqueNames(names);
  }

  // Đã gỡ bỏ toàn bộ bài mẫu hardcode
  static List<RoomModel> getSampleRooms() {
    return const <RoomModel>[];
  }

  // Không nạp dữ liệu mẫu
  Future<void> seedInitialRoomsIfEmpty() async {
    return;
  }
}

final roomServiceProvider = Provider<RoomService>((ref) => RoomService());

final roomPostDetailProvider = StreamProvider.autoDispose
    .family<RoomModel?, String>((ref, postId) {
      return ref.watch(roomServiceProvider).watchPostById(postId);
    });

final roomsStreamProvider = StreamProvider.autoDispose
    .family<List<RoomModel>, RoomFilterParams>((ref, filters) {
      final service = ref.watch(roomServiceProvider);
      return service.getRoomsStream(
        city: filters.city,
        district: filters.district,
        rentalType: filters.rentalType,
        minPrice: filters.minPrice,
        maxPrice: filters.maxPrice,
        minArea: filters.minArea,
        maxArea: filters.maxArea,
        amenities: filters.amenities,
        roomType: filters.roomType,
        searchQuery: filters.searchQuery,
        sortBy: filters.sortBy,
        hostQuery: filters.hostQuery,
        userLat: filters.userLat,
        userLng: filters.userLng,
        maxDistanceKm: filters.maxDistanceKm,
        includeUnpostedRooms: filters.includeUnpostedRooms,
      );
    });
