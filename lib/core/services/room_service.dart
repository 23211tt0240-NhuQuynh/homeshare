import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/firestore_collections.dart';
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
  final String sortBy; // 'newest', 'price_asc', 'price_desc', 'rating'

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
          sortBy == other.sortBy;

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
  );
}

class RoomService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// `posts` là nguồn dữ liệu công khai duy nhất của Dashboard người thuê.
  ///
  /// `rooms` chỉ là bản sao thông tin phòng để quản lý/đặt phòng. Nếu tiếp tục
  /// ghép bản sao đó vào feed, một bài đã xóa khỏi `posts` có thể xuất hiện lại
  /// vì document `rooms` cũ vẫn còn trạng thái active/available.
  @visibleForTesting
  static List<RoomModel> mergeDashboardListings({
    required Iterable<RoomModel> roomMirrors,
    required Iterable<RoomModel> posts,
  }) {
    // Cố ý không đưa roomMirrors vào kết quả. Tham số này giúp kiểm thử và ghi
    // rõ ranh giới giữa dữ liệu quản lý phòng với dữ liệu bài đăng công khai.
    final listingsById = <String, RoomModel>{};
    for (final post in posts) {
      if (post.isDisplayable) listingsById[post.id] = post;
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
      FirestoreCollections.hostRooms,
      FirestoreCollections.rooms,
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
          addressText.isEmpty ||
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
  }) {
    late StreamController<List<RoomModel>> controller;
    StreamSubscription? postsSub;
    List<RoomModel> latestPosts = [];

    List<RoomModel> filterAndSort(List<RoomModel> rawList) {
      // Chỉ giữ lại những bài đang hiển thị hợp lệ (đã duyệt, còn mở, không bị ẩn/gỡ, không phải bài mẫu hardcode)
      var list = rawList.where((r) => r.isDisplayable).toList();

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

      // 8. Sắp xếp kết quả
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
        roomMirrors: const <RoomModel>[],
        posts: latestPosts,
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
      },
      onCancel: () async {
        await postsSub?.cancel();
      },
    );

    return controller.stream;
  }

  // Lấy chi tiết 1 phòng
  Future<RoomModel?> getRoomById(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty || cleanId.toLowerCase().startsWith('sample')) {
      return null;
    }
    try {
      final doc = await _firestore.collection('rooms').doc(cleanId).get();
      if (doc.exists) {
        final room = RoomModel.fromFirestore(doc);
        if (room.isDisplayable) return room;
      }
      final postDoc = await _firestore.collection('posts').doc(cleanId).get();
      if (postDoc.exists) {
        final post = RoomModel.fromFirestore(postDoc);
        if (post.isDisplayable) return post;
      }
    } catch (e) {
      debugPrint('Error getting room from firestore $id: $e');
    }
    return null;
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
      );
    });
