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
    this.city = 'TP. Hồ Chí Minh',
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream danh sách phòng theo bộ lọc chi tiết (gộp từ publicRooms và posts để hiển thị đầy đủ bài đăng trên trang chủ)
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
    List<RoomModel> publicRooms = [];
    List<RoomModel> postRooms = [];
    StreamSubscription? subPublic;
    StreamSubscription? subPosts;

    void updateAndEmit() {
      if (controller.isClosed) return;

      final map = <String, RoomModel>{};
      for (final r in publicRooms) {
        if (r.id.isNotEmpty) {
          map[r.id] = r;
        }
      }

      for (final r in postRooms) {
        final key = r.id.isNotEmpty ? r.id : r.phongId;
        if (key.isNotEmpty && !map.containsKey(key)) {
          final alreadyExists = map.values.any(
            (existing) =>
                (r.phongId.isNotEmpty && existing.id == r.phongId) ||
                (existing.roomCode.isNotEmpty &&
                    r.roomCode.isNotEmpty &&
                    existing.roomCode == r.roomCode &&
                    existing.hostId == r.hostId),
          );
          if (!alreadyExists) {
            map[key] = r;
          }
        }
      }

      final filtered = _filterAndSortRooms(
        map.values.toList(),
        city: city,
        district: district,
        rentalType: rentalType,
        minPrice: minPrice,
        maxPrice: maxPrice,
        minArea: minArea,
        maxArea: maxArea,
        amenities: amenities,
        roomType: roomType,
        searchQuery: searchQuery,
        sortBy: sortBy,
      );

      controller.add(filtered);
    }

    controller = StreamController<List<RoomModel>>.broadcast(
      onListen: () {
        subPublic = _firestore
            .collection(FirestoreCollections.publicRooms)
            .snapshots()
            .listen(
              (snapshot) {
                publicRooms = snapshot.docs
                    .map((doc) {
                      try {
                        if (doc.data()['status'] == 'deleted') return null;
                        return RoomModel.fromFirestore(doc);
                      } catch (e) {
                        debugPrint('Error parsing room doc ${doc.id}: $e');
                        return null;
                      }
                    })
                    .whereType<RoomModel>()
                    .toList();
                updateAndEmit();
              },
              onError: (err) {
                if (!controller.isClosed) controller.addError(err);
              },
            );

        subPosts = _firestore
            .collection('posts')
            .snapshots()
            .listen(
              (snapshot) {
                postRooms = snapshot.docs
                    .map((doc) {
                      try {
                        final data = doc.data();
                        final st = data['status'] ?? data['trangThai_id'] ?? '';
                        if (st == 'deleted' ||
                            st == 'daAn' ||
                            st == 'closed' ||
                            st == 'hidden') {
                          return null;
                        }
                        return RoomModel.fromFirestore(doc);
                      } catch (e) {
                        debugPrint('Error parsing post doc ${doc.id}: $e');
                        return null;
                      }
                    })
                    .whereType<RoomModel>()
                    .toList();
                updateAndEmit();
              },
              onError: (_) {
                // posts stream error không làm ảnh hưởng publicRooms
              },
            );
      },
      onCancel: () {
        subPublic?.cancel();
        subPosts?.cancel();
      },
    );

    return controller.stream;
  }

  List<RoomModel> _filterAndSortRooms(
    List<RoomModel> rawList, {
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
    var list = List<RoomModel>.from(rawList);

    // 1. Lọc theo Thành phố
    if (city != null &&
        city.isNotEmpty &&
        city != 'Tất cả' &&
        city != 'Chọn Tỉnh/Thành phố') {
      final cleanCity = city
          .toLowerCase()
          .replaceFirst('tp. ', '')
          .replaceFirst('thành phố ', '')
          .replaceFirst('tỉnh ', '')
          .trim();
      list = list
          .where(
            (r) =>
                r.city.toLowerCase().contains(city.toLowerCase()) ||
                r.city.toLowerCase().contains(cleanCity) ||
                r.address.toLowerCase().contains(city.toLowerCase()) ||
                r.address.toLowerCase().contains(cleanCity),
          )
          .toList();
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

    // 6. Lọc theo tiện ích được chọn
    if (amenities != null && amenities.isNotEmpty) {
      list = list.where((r) {
        for (final a in amenities) {
          final key = a.toLowerCase();
          final hasMatch = r.amenities.any(
            (item) =>
                item.toLowerCase().contains(key) ||
                key.contains(item.toLowerCase()),
          );
          final hasMatchDesc =
              r.description.toLowerCase().contains(key) ||
              r.title.toLowerCase().contains(key);
          if (!hasMatch && !hasMatchDesc) {
            return false;
          }
        }
        return true;
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

  // Lấy chi tiết 1 phòng (tìm trong publicRooms, nếu không có fallback sang posts và host_rooms)
  Future<RoomModel?> getRoomById(String id) async {
    final doc = await _firestore
        .collection(FirestoreCollections.publicRooms)
        .doc(id)
        .get();
    if (doc.exists && doc.data()?['status'] != 'deleted') {
      return RoomModel.fromFirestore(doc);
    }

    // Fallback sang posts
    final postDoc = await _firestore.collection('posts').doc(id).get();
    if (postDoc.exists &&
        postDoc.data()?['status'] != 'deleted' &&
        postDoc.data()?['trangThai_id'] != 'daAn') {
      return RoomModel.fromFirestore(postDoc);
    }

    // Fallback sang host_rooms
    final hostDoc = await _firestore
        .collection(FirestoreCollections.hostRooms)
        .doc(id)
        .get();
    if (hostDoc.exists && hostDoc.data()?['status'] != 'deleted') {
      return RoomModel.fromFirestore(hostDoc);
    }

    return null;
  }

  // Tự động nạp dữ liệu mẫu chất lượng cao vào Firestore nếu database trống
  Future<void> seedInitialRoomsIfEmpty() async {
    final snapshot = await _firestore
        .collection(FirestoreCollections.publicRooms)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) return; // Đã có dữ liệu

    final sampleRooms = [
      RoomModel(
        id: '',
        title: 'Phòng trọ máy lạnh gần ĐH Nông Lâm',
        description:
            'Phòng mới xây gác đúc, máy lạnh Inverter, chỗ để xe miễn phí, an ninh 24/7, giờ giấc tự do.',
        price: 3200000,
        deposit: 3200000,
        address: 'Đ. Số 8, P. Linh Trung',
        district: 'TP. Thủ Đức',
        area: 25.0,
        roomType: 'Phòng trọ',
        amenities: [
          'Máy lạnh',
          'Có gác lửng',
          'Chỗ để xe miễn phí',
          'Giờ giấc tự do',
          'Wifi tốc độ cao',
        ],
        images: [
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?auto=format&fit=crop&w=800&q=80',
        ],
        hostId: 'host_chu_ba_101',
        hostName: 'Chú Ba Linh Trung',
        hostPhone: '0908123456',
        rating: 4.8,
        reviewCount: 15,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      RoomModel(
        id: '',
        title: 'Studio ban công thoáng mát Nguyễn Văn Lượng',
        description:
            'Căn hộ Studio full nội thất cao cấp phong cách Bắc Âu, có ban công view đẹp, thang máy, máy giặt riêng.',
        price: 4500000,
        deposit: 4500000,
        address: 'Nguyễn Văn Lượng, P.3',
        district: 'Gò Vấp',
        area: 30.0,
        roomType: 'Căn hộ mini',
        amenities: [
          'Máy lạnh',
          'Ban công / Cửa sổ lớn',
          'Tủ lạnh & Máy giặt',
          'Wifi tốc độ cao',
          'Không chung chủ',
        ],
        images: [
          'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?auto=format&fit=crop&w=800&q=80',
        ],
        hostId: 'host_minh_gv',
        hostName: 'Anh Minh Gò Vấp',
        hostPhone: '0938112233',
        rating: 4.9,
        reviewCount: 22,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      RoomModel(
        id: '',
        title: 'Phòng trọ duplex cao cấp D2 Hutech',
        description:
            'Phòng gác đúc cao 2m2, khóa vân tay thẻ từ ra vào, kệ bếp rộng rãi, vệ sinh riêng khép kín, gần trạm xe buýt và chợ.',
        price: 3800000,
        deposit: 3800000,
        address: 'Đường D2 (Nguyễn Gia Trí), P. 25',
        district: 'Bình Thạnh',
        area: 22.0,
        roomType: 'Phòng trọ',
        amenities: [
          'Máy lạnh',
          'Có gác lửng',
          'Chỗ để xe miễn phí',
          'Không chung chủ',
          'Gần trường ĐH / Bến xe',
        ],
        images: [
          'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2?auto=format&fit=crop&w=800&q=80',
        ],
        hostId: 'host_linhtrung_99',
        hostName: 'Cô Lan Bình Thạnh',
        hostPhone: '0912345678',
        rating: 4.7,
        reviewCount: 18,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      RoomModel(
        id: '',
        title: 'Căn hộ dịch vụ 1PN Mai Chí Thọ có hồ bơi',
        description:
            'Căn hộ dịch vụ hạng sang có ban công rộng, đầy đủ tiện ích hồ bơi tràn bờ, phòng gym, bảo vệ 24/7.',
        price: 6500000,
        deposit: 6500000,
        address: 'Số 10 Mai Chí Thọ, P. An Phú',
        district: 'TP. Thủ Đức',
        area: 45.0,
        roomType: 'Chung cư',
        amenities: [
          'Máy lạnh',
          'Tủ lạnh & Máy giặt',
          'Ban công / Cửa sổ lớn',
          'Chỗ để xe miễn phí',
          'Giờ giấc tự do',
        ],
        images: [
          'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?auto=format&fit=crop&w=800&q=80',
        ],
        hostId: 'host_saigon_luxury',
        hostName: 'Homes Luxury Co.',
        hostPhone: '0988776655',
        rating: 5.0,
        reviewCount: 30,
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
    ];

    final batch = _firestore.batch();
    for (var r in sampleRooms) {
      final docRef = _firestore
          .collection(FirestoreCollections.publicRooms)
          .doc();
      batch.set(docRef, r.toMap());
    }
    await batch.commit();
  }
}

final roomServiceProvider = Provider<RoomService>((ref) => RoomService());

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
