import '../../../core/services/resident_service.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/constants/vietnam_locations.dart';
import '../../../core/services/image_storage_service.dart';
import '../../../core/utils/room_identity.dart';
import '../../../core/utils/room_deposit.dart';
import '../../../data/models/room_model.dart';
import '../data/host_property.dart';

// Chủ trọ - Phiên Firebase - Luồng đi: Chỉ đọc dữ liệu khi Firebase đã
// khởi tạo và đã đăng nhập; chế độ preview không tự tạo tài khoản giả.
final hostSessionProvider = StreamProvider<String?>((ref) {
  if (Firebase.apps.isEmpty) return Stream.value(null);
  return FirebaseAuth.instance.authStateChanges().map((user) => user?.uid);
});
final hostRepositoryProvider = Provider<HostRepository>(
  (ref) => HostRepository(),
);
final hostPropertiesProvider = StreamProvider<List<HostProperty>>((ref) {
  final uid = ref.watch(hostSessionProvider).value;
  if (uid == null) return Stream.value([]);
  return ref.watch(hostRepositoryProvider).watchProperties(uid);
});
final hostRoomsProvider = StreamProvider<List<RoomModel>>((ref) {
  final uid = ref.watch(hostSessionProvider).value;
  if (uid == null) return Stream.value([]);
  return ref.watch(hostRepositoryProvider).watchRooms(uid);
});

// Chủ trọ - Ảnh đã chọn - Luồng đi: Giữ byte ảnh trong form để xem
// trước và tải bằng putData trên Chrome, Android và iOS.
class HostUpload {
  const HostUpload(this.bytes, this.contentType);
  final Uint8List bytes;
  final String contentType;
}

// Chủ trọ - Kho dữ liệu quản lý - Luồng đi: Lưu nhà vào properties,
// phòng vào host_rooms và ảnh vào đường dẫn riêng theo UID chủ trọ.
// Bài đăng công khai lưu riêng trong posts và tham chiếu roomId.
class HostRepository {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;

  // Chủ trọ - Theo dõi nhà và phòng - Luồng đi: Lọc hostId ở truy vấn;
  // sắp xếp tại ứng dụng để không yêu cầu composite index mới.
  Stream<List<HostProperty>> watchProperties(String uid) => _db
      .collection(FirestoreCollections.hostProperties)
      .where('hostId', isEqualTo: uid)
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs
            .where((doc) => doc.data()['status'] != 'deleted')
            .map((doc) => HostProperty.fromMap(doc.id, doc.data()))
            .toList();
        list.sort(
          (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
            a.createdAt ?? DateTime(1970),
          ),
        );
        return list;
      });

  // Tự động phân giải và đồng bộ dữ liệu con (1-N ảnh phòng và N-N tiện ích) vào document cha
  Future<List<RoomModel>> _resolveRoomChildData(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final rooms = <RoomModel>[];
    for (final doc in docs) {
      final data = doc.data();
      if (data['status'] == 'deleted') continue;
      var room = RoomModel.fromFirestore(doc);
      bool needsUpdate = false;
      final updateData = <String, dynamic>{};

      // 1-N: Lưu danh sách ảnh dưới dạng dữ liệu con (100% tiếng Anh: images)
      if (room.images.isEmpty) {
        final fallbackImages = await getRoomImagesFromAnhPhong(room.id);
        if (fallbackImages.isNotEmpty) {
          room = room.copyWith(images: fallbackImages);
          updateData['images'] = fallbackImages;
          needsUpdate = true;
        }
      }

      // N-N: Tách bảng riêng biệt - Lấy danh sách tiện ích từ bảng liên kết (100% tiếng Anh: amenities)
      if (room.amenities.isEmpty) {
        final fallbackAmenities = await getRoomAmenitiesFromTienIchPhong(
          room.id,
        );
        if (fallbackAmenities.isNotEmpty) {
          room = room.copyWith(amenities: fallbackAmenities);
          updateData['amenities'] = fallbackAmenities;
          needsUpdate = true;
        }
      }

      // Dọn sạch triệt để các trường tiếng Việt và trường trùng lặp trên document
      for (final legacyKey in [
        'anhPhong',
        'tienIch',
        'tieuDe',
        'gia',
        'giaThue',
        'giaThueThang',
        'tienCoc',
        'dienTich',
        'dienTichM2',
        'sucChua',
        'tang',
        'moTa',
        'noiDung',
        'anhBatDongSan',
        'phongId',
        'chuNhaId',
        'soDienThoai',
        'anhDaiDien',
        'property_id',
        'room_code',
        'rental_price',
        'deposit_amount',
        'created_at',
        'updated_at',
      ]) {
        if (data.containsKey(legacyKey)) {
          updateData[legacyKey] = FieldValue.delete();
          needsUpdate = true;
        }
      }

      if (needsUpdate) {
        try {
          await doc.reference.update(updateData);
        } catch (_) {}
      }

      rooms.add(room);
    }
    return Future.wait(rooms.map(ResidentService(_db).hydrateRoom));
  }

  Stream<List<RoomModel>> watchRooms(String uid) => _db
      .collection(FirestoreCollections.hostRooms)
      .where('hostId', isEqualTo: uid)
      .snapshots()
      .asyncMap((snapshot) => _resolveRoomChildData(snapshot.docs));
  String newPropertyId() =>
      _db.collection(FirestoreCollections.hostProperties).doc().id;

  // Chủ trọ - Kiểm tra phiên lưu - Luồng đi: Trước khi ghi nhà/phòng,
  // xác nhận UID hiện tại vẫn là người đã mở form và có vai trò chủ trọ.
  Future<void> _requireHost(String uid) async {
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('Phiên đăng nhập đã thay đổi. Vui lòng đăng nhập lại.');
    }
    final profile = await _db.collection('users').doc(uid).get();
    final data = profile.data();
    if ((data?['role'] ?? data?['vaiTro']) != 'host') {
      throw StateError('Bạn cần tài khoản Chủ trọ để tạo nhà/phòng.');
    }
  }

  // Chủ trọ - Tải ảnh thực - Luồng đi: Ưu tiên Firebase Storage; nếu
  // Storage lỗi (billing/rules/mạng) thì lưu Base64 vào Firestore như chat.
  Future<List<String>> _upload(
    List<HostUpload> images,
    String folder,
    int max,
  ) async {
    if (images.isEmpty || images.length > max) {
      throw StateError('Chọn từ 1 đến $max ảnh.');
    }
    final urls = <String>[];
    for (var i = 0; i < images.length; i++) {
      final image = images[i];
      if (!['image/jpeg', 'image/png'].contains(image.contentType) ||
          image.bytes.length > 5 * 1024 * 1024) {
        throw StateError('Mỗi ảnh phải là JPG/PNG và không quá 5 MB.');
      }
      if (image.bytes.isEmpty) {
        throw StateError('Ảnh đã chọn bị rỗng. Vui lòng chọn lại ảnh.');
      }
      final object = _storage.ref('$folder/$i');
      final task = object.putData(
        image.bytes,
        SettableMetadata(contentType: image.contentType),
      );
      try {
        final snapshot = await task.timeout(
          const Duration(seconds: 60),
          onTimeout: () async {
            await task.cancel();
            throw StateError('Tải ảnh quá lâu. Kiểm tra mạng và thử lưu lại.');
          },
        );
        final url = await snapshot.ref.getDownloadURL();
        if (!url.startsWith('https://')) {
          throw StateError('Không lấy được đường dẫn ảnh. Vui lòng thử lại.');
        }
        urls.add(url);
      } catch (error) {
        debugPrint(
          '[HostRepository] Storage upload lỗi ($error). Lưu ảnh Base64 vào Firestore.',
        );
        const maxBytes = 180 * 1024;
        var prepared = image.bytes;
        if (prepared.length > maxBytes) {
          prepared = await compute(compressJpegToLimit, (prepared, maxBytes));
        }
        urls.add('data:image/jpeg;base64,${base64Encode(prepared)}');
      }
    }
    return urls;
  }

  // Chủ trọ - Tạo cơ sở - Luồng đi: Kiểm tra cấp xã hiện hành, tải ảnh rồi
  // ghi địa chỉ hai cấp bằng ID giữ cố định khi thử lại. Form hiện gửi proof
  // bằng null; tham số giấy tờ chỉ giữ để tương thích lời gọi cũ.
  Future<String> createProperty(
    HostProperty property,
    List<HostUpload> images,
    HostUpload? proof,
  ) async {
    await _requireHost(property.hostId);
    if (!VietnamLocations.getWards(property.city).contains(property.ward)) {
      throw StateError('Vui lòng chọn phường/xã/đặc khu hiện hành.');
    }
    final document = _db
        .collection(FirestoreCollections.hostProperties)
        .doc(property.id);
    if ((await document.get()).exists) return property.id;
    final urls = await _upload(
      images,
      'host_media/${property.hostId}/properties/${property.id}',
      5,
    );
    String? proofPath;
    if (proof != null) {
      if (!['image/jpeg', 'image/png'].contains(proof.contentType) ||
          proof.bytes.length > 15 * 1024 * 1024) {
        throw StateError('Giấy tờ phải là JPG/PNG và không quá 15 MB.');
      }
      proofPath = 'host_private/${property.hostId}/${property.id}/proof';
      await _storage
          .ref(proofPath)
          .putData(
            proof.bytes,
            SettableMetadata(contentType: proof.contentType),
          );
    }
    await _db.runTransaction((transaction) async {
      final existing = await transaction.get(document);
      if (!existing.exists) {
        final propData = {
          ...property.toMap(),
          'images': urls,
          'roomCount': 0,
          'roomCodes': <String, String>{},
          'proofPath': ?proofPath,
        };
        transaction.set(document, propData);
      }
    });

    // Bảng ảnh trọ riêng biệt (property_images)
    for (var i = 0; i < urls.length; i++) {
      try {
        final imgDoc = _db
            .collection(FirestoreCollections.propertyImages)
            .doc();
        final imgData = {
          'id': imgDoc.id,
          'propertyId': property.id,
          'url': urls[i],
          'imageType': 'property',
          'createdAt': FieldValue.serverTimestamp(),
        };
        await imgDoc.set(imgData);
      } catch (_) {}
    }
    return property.id;
  }

  // Chủ trọ - Sửa cơ sở - Luồng đi: Giữ ID và ảnh cũ được chọn, tải ảnh
  // mới rồi cập nhật các trường quản lý; không cho giảm quy mô dưới số phòng.
  Future<void> updateProperty(
    HostProperty base,
    Map<String, dynamic> patch,
    List<String> keptImages,
    List<HostUpload> newImages,
    String operationId,
  ) async {
    await _requireHost(base.hostId);
    const allowed = {
      'name',
      'address',
      'city',
      'ward',
      'plannedRooms',
      'floors',
      'minRent',
      'maxRent',
    };
    if (patch.keys.any((key) => !allowed.contains(key))) {
      throw StateError('Thông tin cơ sở chỉnh sửa không hợp lệ.');
    }
    if (keptImages.length + newImages.length < 1 ||
        keptImages.length + newImages.length > 5 ||
        keptImages.any((url) => !base.images.contains(url))) {
      throw StateError('Giữ từ 1 đến 5 ảnh cơ sở hợp lệ.');
    }
    final name = (patch['name'] as String).trim();
    final address = (patch['address'] as String).trim();
    final ward = (patch['ward'] as String).trim();
    final plannedRooms = (patch['plannedRooms'] as num).toInt();
    final floors = (patch['floors'] as num).toInt();
    final minRent = (patch['minRent'] as num).toDouble();
    final maxRent = (patch['maxRent'] as num).toDouble();
    if (name.isEmpty ||
        address.isEmpty ||
        !VietnamLocations.getWards(patch['city'] as String).contains(ward) ||
        plannedRooms < 1 ||
        plannedRooms > 1000 ||
        floors < 1 ||
        floors > 100 ||
        minRent < 0 ||
        maxRent < minRent ||
        maxRent > 1000000000) {
      throw StateError('Kiểm tra tên, địa chỉ, quy mô và số tầng cơ sở.');
    }

    final activeRooms = await _db
        .collection(FirestoreCollections.hostRooms)
        .where('hostId', isEqualTo: base.hostId)
        .where('propertyId', isEqualTo: base.id)
        .get();
    final rooms = activeRooms.docs
        .map(RoomModel.fromFirestore)
        .where((room) => room.status != 'deleted')
        .toList();
    if (plannedRooms < rooms.length) {
      throw StateError(
        'Quy mô không thể nhỏ hơn ${rooms.length} phòng đã tạo.',
      );
    }
    final highestFloor = rooms.fold<int>(0, (value, room) {
      return room.floor > value ? room.floor : value;
    });
    if (floors < highestFloor) {
      throw StateError('Cơ sở đang có phòng ở tầng $highestFloor.');
    }

    final uploaded = newImages.isEmpty
        ? <String>[]
        : await _upload(
            newImages,
            'host_media/${base.hostId}/properties/${base.id}/edits/$operationId',
            5,
          );
    final images = [...keptImages, ...uploaded];
    final propertyRef = _db
        .collection(FirestoreCollections.hostProperties)
        .doc(base.id);
    await _db.runTransaction((transaction) async {
      final current = await transaction.get(propertyRef);
      final data = current.data();
      if (data == null || data['status'] == 'deleted') {
        throw StateError('Cơ sở không còn tồn tại.');
      }
      if (data['hostId'] != base.hostId) {
        throw StateError('Bạn không có quyền chỉnh sửa cơ sở này.');
      }
      if (data['lastEditOperation'] == operationId) return;
      final roomCount = (data['roomCount'] as num?)?.toInt() ?? 0;
      if (plannedRooms < roomCount) {
        throw StateError('Quy mô không thể nhỏ hơn $roomCount phòng đã tạo.');
      }
      transaction.update(propertyRef, {
        ...patch,
        'name': name,
        'address': address,
        // Chủ trọ - Bỏ cấp huyện - Luồng đi: Xóa cả trường district và các
        // tên trường cũ khi lưu chỉnh sửa, thay vì ghi lại chuỗi rỗng.
        'district': FieldValue.delete(),
        'quan_huyen': FieldValue.delete(),
        'quanHuyen': FieldValue.delete(),
        'ward': ward,
        'plannedRooms': plannedRooms,
        'floors': floors,
        'images': images,
        'lastEditOperation': operationId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Chủ trọ - Xóa cơ sở - Luồng đi: Chỉ xóa mềm cơ sở không còn phòng,
  // giữ tài liệu để lịch sử và dữ liệu liên quan không bị mất liên kết.
  Future<void> deleteProperty(HostProperty base) async {
    await _requireHost(base.hostId);
    final activeRooms = await _db
        .collection(FirestoreCollections.hostRooms)
        .where('hostId', isEqualTo: base.hostId)
        .where('propertyId', isEqualTo: base.id)
        .get();
    final activeCount = activeRooms.docs
        .where((doc) => doc.data()['status'] != 'deleted')
        .length;
    if (activeCount > 0) {
      throw StateError(
        'Cơ sở còn $activeCount phòng. Hãy xóa các phòng trước khi xóa cơ sở.',
      );
    }
    final propertyRef = _db
        .collection(FirestoreCollections.hostProperties)
        .doc(base.id);
    await _db.runTransaction((transaction) async {
      final current = await transaction.get(propertyRef);
      final data = current.data();
      if (data == null || data['status'] == 'deleted') return;
      if (data['hostId'] != base.hostId) {
        throw StateError('Bạn không có quyền xóa cơ sở này.');
      }
      final roomCount = (data['roomCount'] as num?)?.toInt() ?? 0;
      if (roomCount > 0) {
        throw StateError(
          'Cơ sở còn $roomCount phòng. Hãy xóa các phòng trước khi xóa cơ sở.',
        );
      }
      transaction.update(propertyRef, {
        'status': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Chủ trọ - Mã phòng duy nhất - Luồng đi: Cùng cơ sở và mã phòng
  // tạo cùng ID; transaction ngăn trùng mã cả khi hai thiết bị lưu cùng lúc.
  static String roomDocumentId(String propertyId, String code) =>
      '${propertyId}_${base64Url.encode(utf8.encode(code.trim().toUpperCase())).replaceAll('=', '')}';

  // Chủ trọ - Khóa mã phòng trong cơ sở - Luồng đi: Lưu bảng mã trên
  // properties để đổi số phòng vẫn giữ ID và liên kết đơn thuê cũ.
  static String _codeKey(String code) => base64Url
      .encode(utf8.encode(code.trim().toUpperCase()))
      .replaceAll('=', '');
  Map<String, dynamic> _codes(Map<String, dynamic> property) =>
      Map<String, dynamic>.from(property['roomCodes'] as Map? ?? {});
  void _checkRevision(Map<String, dynamic> current, RoomModel base) {
    final stamp = current['updatedAt'];
    final date = stamp is Timestamp ? stamp.toDate() : null;
    if (date != base.updatedAt) {
      throw StateError(
        'Phòng vừa được thay đổi trên thiết bị khác. Quay lại chi tiết rồi mở chỉnh sửa để tải dữ liệu mới.',
      );
    }
  }

  // Chủ trọ - Tạo phòng có mã duy nhất - Luồng đi: Giữ ID theo thao
  // tác khi thử lại; khóa mã và tăng số phòng cùng một transaction.
  Future<void> createRoom(
    RoomModel room,
    List<HostUpload> images,
    String operationId,
  ) async {
    await _requireHost(room.hostId);
    final propertyRef = _db
        .collection(FirestoreCollections.hostProperties)
        .doc(room.propertyId);
    // Chủ trọ - Một ID phòng - Luồng đi: Form cấp trước ID ngắn;
    // lưu đúng ID vào document và trường id, không ghép mã thao tác.
    if (room.depositPercentage != null &&
        (!roomDepositPercentages.contains(room.depositPercentage) ||
            room.deposit != roomDeposit(room.price, room.depositPercentage!))) {
      throw StateError('Tiền cọc phải khớp tỷ lệ đã chọn và giá thuê.');
    }
    if (!isShortRoomId(room.id)) {
      throw StateError('ID phòng không hợp lệ. Vui lòng mở lại form.');
    }
    final roomRef = _db.collection(FirestoreCollections.hostRooms).doc(room.id);
    bool matchesCreation(Map<String, dynamic>? data) =>
        data != null &&
        data['id'] == room.id &&
        data['hostId'] == room.hostId &&
        data['propertyId'] == room.propertyId &&
        data['title'] == room.title.trim() &&
        data['floor'] == room.floor &&
        data['price'] == room.price &&
        data['deposit'] == room.deposit &&
        data['status'] != 'deleted';
    final existing = await roomRef.get();
    if (existing.exists) {
      if (matchesCreation(existing.data())) return;
      throw StateError(
        'ID phòng đã tồn tại. Vui lòng mở lại form để lấy mã mới.',
      );
    }
    if (room.title.trim().isEmpty || room.title.trim().length > 100) {
      throw StateError('Nhập tên phòng từ 1 đến 100 ký tự.');
    }
    final urls = await _upload(
      images,
      'host_media/${room.hostId}/host_rooms/${roomRef.id}/$operationId',
      8,
    );
    await _db.runTransaction((transaction) async {
      final property = await transaction.get(propertyRef);
      final current = await transaction.get(roomRef);
      if (current.exists) {
        if (matchesCreation(current.data())) return;
        throw StateError('Trùng ID phòng.');
      }
      final data = property.data();
      if (data == null ||
          data['status'] == 'deleted' ||
          data['hostId'] != room.hostId) {
        throw StateError('Cơ sở không thuộc tài khoản này.');
      }
      if (room.floor < 1 || room.floor > (data['floors'] as num)) {
        throw StateError('Tầng phòng vượt quá số tầng của cơ sở.');
      }
      final count = (data['roomCount'] as num?)?.toInt() ?? 0;
      if (count >= (data['plannedRooms'] as num).toInt()) {
        throw StateError('Đã đạt tổng số phòng của cơ sở.');
      }
      final resolvedCode = roomRef.id;
      final roomData = {
        'id': roomRef.id,
        'propertyId': room.propertyId,
        'roomCode': resolvedCode,
        'title': room.title.trim().isNotEmpty
            ? room.title.trim()
            : 'Phòng $resolvedCode',
        'description': room.description,
        'price': room.price,
        'deposit': room.deposit,
        if (room.depositPercentage != null)
          'depositPercentage': room.depositPercentage,
        'address': room.address,
        'district': room.district,
        'city': room.city,
        'area': room.area,
        'capacity': room.capacity,
        'floor': room.floor,
        'roomType': room.roomType,
        'electricityRate': room.electricityRate ?? 0.0,
        'waterRate': room.waterRate ?? 0.0,
        'serviceFee': room.serviceFee ?? 0.0,
        'hostId': room.hostId,
        'hostName': room.hostName,
        'hostPhone': room.hostPhone,
        'isAvailable': true,
        'status': 'available',
        // 1-N: Lưu ảnh phòng dưới dạng dữ liệu con (Array trong document cha - 100% tiếng Anh)
        'images': urls,
        // N-N: Mảng tiện ích trong document cha (100% tiếng Anh)
        'amenities': room.amenities,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      transaction.set(roomRef, roomData);

      transaction.update(propertyRef, {'roomCount': count + 1});
    });

    // Bảng ảnh phòng riêng biệt (room_images - tiếng Anh chuẩn)
    for (var i = 0; i < urls.length; i++) {
      try {
        final imgDoc = _db.collection(FirestoreCollections.roomImages).doc();
        final imgData = {
          'id': imgDoc.id,
          'roomId': roomRef.id,
          'url': urls[i],
          'isCover': i == 0,
          'sortOrder': i,
          'createdAt': FieldValue.serverTimestamp(),
        };
        await imgDoc.set(imgData);
      } catch (_) {}
    }

    // Bảng liên kết tiện ích phòng riêng biệt (room_amenities - tiếng Anh chuẩn)
    for (final amName in room.amenities) {
      final name = amName.trim();
      if (name.isEmpty) continue;
      try {
        final linkDoc = _db
            .collection(FirestoreCollections.roomAmenities)
            .doc();
        final linkData = {
          'id': linkDoc.id,
          'roomId': roomRef.id,
          'amenityId': name,
          'amenityName': name,
          'createdAt': FieldValue.serverTimestamp(),
        };
        await linkDoc.set(linkData);
      } catch (_) {}
    }
  }

  // Chủ trọ - Lưu chỉnh sửa phòng - Luồng đi: Upload ảnh mới, kiểm
  // tra phiên/bản sửa, giữ ID và chỉ cập nhật thông tin phòng được phép.
  Future<void> updateRoom(
    RoomModel base,
    Map<String, dynamic> patch,
    List<String> keptImages,
    List<HostUpload> newImages,
    String operationId,
  ) async {
    await _requireHost(base.hostId);
    const allowed = {
      'title',
      'roomCode',
      'floor',
      'area',
      'minArea',
      'maxArea',
      'capacity',
      'price',
      'deposit',
      'depositPercentage',
      'electricityRate',
      'waterRate',
      'serviceFee',
      'amenities',
      'description',
    };
    if (patch.keys.any((key) => !allowed.contains(key))) {
      throw StateError('Thông tin chỉnh sửa không hợp lệ.');
    }
    if (keptImages.length + newImages.length < 1 ||
        keptImages.length + newImages.length > 8 ||
        keptImages.any((url) => !base.images.contains(url))) {
      throw StateError('Giữ từ 1 đến 8 ảnh phòng hợp lệ.');
    }
    // Chủ trọ - Sửa tên phòng - Luồng đi: ID lấy từ document gốc,
    // chỉ lưu tên người dùng nhập; không có mã phòng thứ hai trong payload.
    final title = (patch['title'] as String? ?? base.title).trim();
    if (title.isEmpty || title.length > 100) {
      throw StateError('Nhập tên phòng từ 1 đến 100 ký tự.');
    }
    // Chủ trọ - Kiểm tra cọc trước lưu - Luồng đi: Tỷ lệ 10–100%,
    // số tiền phải khớp giá thuê tháng; không chấp nhận khoản tự sửa.
    if (patch['depositPercentage'] != null &&
        (patch['depositPercentage'] is! int ||
            !roomDepositPercentages.contains(patch['depositPercentage']) ||
            patch['deposit'] !=
                roomDeposit(
                  patch['price'] as num,
                  patch['depositPercentage'] as int,
                ))) {
      throw StateError('Tiền cọc phải khớp tỷ lệ đã chọn và giá thuê.');
    }
    for (final key in [
      'price',
      'deposit',
      'area',
      'electricityRate',
      'waterRate',
      'serviceFee',
    ]) {
      final value = patch[key] as num?;
      if (value != null &&
          (!value.isFinite || value < 0 || value > 1000000000)) {
        throw StateError('Giá thuê và phí phòng không hợp lệ.');
      }
    }
    if ((patch['price'] as num) <= 0 ||
        (patch['deposit'] as num) < 0 ||
        (patch['area'] as num) <= 0 ||
        patch['capacity'] is! int ||
        (patch['capacity'] as int) < 1) {
      throw StateError('Kiểm tra mã, diện tích, sức chứa và giá thuê.');
    }
    final roomRef = _db.collection(FirestoreCollections.hostRooms).doc(base.id);
    final propertyRef = _db
        .collection(FirestoreCollections.hostProperties)
        .doc(base.propertyId);
    final uploaded = newImages.isEmpty
        ? <String>[]
        : await _upload(
            newImages,
            'host_media/${base.hostId}/host_rooms/${base.id}/edits/$operationId',
            8,
          );
    final images = [...keptImages, ...uploaded];
    await _db.runTransaction((transaction) async {
      final current = await transaction.get(roomRef);
      final property = await transaction.get(propertyRef);
      final data = current.data();
      final parent = property.data();
      if (data == null || data['status'] == 'deleted') {
        throw StateError('Phòng không còn tồn tại.');
      }
      if (data['hostId'] != base.hostId ||
          data['propertyId'] != base.propertyId ||
          parent?['hostId'] != base.hostId) {
        throw StateError('Bạn không có quyền chỉnh sửa phòng này.');
      }
      if (data['lastEditOperation'] == operationId) return;
      _checkRevision(data, base);
      if ((patch['floor'] as num) < 1 ||
          (patch['floor'] as num) > (parent!['floors'] as num)) {
        throw StateError('Tầng phòng vượt quá số tầng của cơ sở.');
      }
      transaction.update(roomRef, {
        ...patch,
        'id': base.id,
        'roomCode': data['roomCode'] ?? base.id,
        'title': title,
        'price': patch['price'],
        'deposit': patch['deposit'],
        'area': patch['area'],
        'minArea': FieldValue.delete(),
        'maxArea': FieldValue.delete(),
        'capacity': patch['capacity'],
        'floor': patch['floor'],
        'amenities': patch['amenities'],
        'description': patch['description'],
        'images': images,
        // Xóa hoàn toàn các trường tiếng Việt thừa/trùng lặp
        'maPhong': FieldValue.delete(),
        'maphong': FieldValue.delete(),
        'trangThai': FieldValue.delete(),
        'trangthai': FieldValue.delete(),
        'tieuDe': FieldValue.delete(),
        'gia': FieldValue.delete(),
        'giaThue': FieldValue.delete(),
        'giaThueThang': FieldValue.delete(),
        'tienCoc': FieldValue.delete(),
        'dienTich': FieldValue.delete(),
        'dienTichM2': FieldValue.delete(),
        'sucChua': FieldValue.delete(),
        'tang': FieldValue.delete(),
        'tienIch': FieldValue.delete(),
        'moTa': FieldValue.delete(),
        'noiDung': FieldValue.delete(),
        'anhPhong': FieldValue.delete(),
        'lastEditOperation': operationId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // Cập nhật bảng ảnh phòng riêng biệt (room_images - tiếng Anh chuẩn)
    for (int i = 0; i < images.length; i++) {
      final imgUrl = images[i];
      final imgDocId = '${base.id}_img_$i';
      await _db.collection(FirestoreCollections.roomImages).doc(imgDocId).set({
        'id': imgDocId,
        'roomId': base.id,
        'url': imgUrl,
        'isCover': i == 0,
        'sortOrder': i,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // Cập nhật bảng tiện ích phòng riêng biệt (room_amenities - tiếng Anh chuẩn)
    final rawAmenities = patch['amenities'];
    if (rawAmenities is Iterable) {
      for (final am in rawAmenities) {
        final amName = am.toString().trim();
        if (amName.isEmpty) continue;
        final amDocId = '${base.id}_${amName.replaceAll(RegExp(r'\s+'), '_')}';
        await _db
            .collection(FirestoreCollections.roomAmenities)
            .doc(amDocId)
            .set({
              'id': amDocId,
              'roomId': base.id,
              'amenityId': amDocId,
              'amenityName': amName,
              'createdAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
    }
  }

  // Chủ trọ - Xóa phòng khỏi quản lý - Luồng đi: Sau xác nhận, đánh
  // dấu deleted và giảm số phòng; giữ bản ghi/ảnh để đơn thuê cũ còn liên kết.
  Future<void> deleteRoom(RoomModel base) async {
    await _requireHost(base.hostId);
    final roomRef = _db.collection(FirestoreCollections.hostRooms).doc(base.id);
    final propertyRef = _db
        .collection(FirestoreCollections.hostProperties)
        .doc(base.propertyId);
    // Một số dữ liệu cũ dùng tên khóa roomId/phongId khác nhau. Thu thập toàn
    // bộ bài liên kết để thao tác xóa phòng không để lại bài active mồ côi.
    final linkedPostRefs = <String, DocumentReference<Map<String, dynamic>>>{};
    for (final field in const ['roomId', 'room_id', 'phongId']) {
      final posts = await _db
          .collection(FirestoreCollections.posts)
          .where(field, isEqualTo: base.id)
          .get();
      for (final post in posts.docs) {
        linkedPostRefs[post.reference.path] = post.reference;
      }
    }

    await _db.runTransaction((transaction) async {
      final current = await transaction.get(roomRef);
      final property = await transaction.get(propertyRef);
      final data = current.data();
      final parent = property.data();
      if (data == null) return;
      if (data['hostId'] != base.hostId || parent?['hostId'] != base.hostId) {
        throw StateError('Bạn không có quyền xóa phòng này.');
      }

      final alreadyDeleted = data['status'] == 'deleted';
      final deletedPayload = {
        'status': 'deleted',
        'isAvailable': false,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      for (final postRef in linkedPostRefs.values) {
        transaction.update(postRef, deletedPayload);
      }
      if (alreadyDeleted) return;

      _checkRevision(data, base);
      if (data['status'] == 'occupied' ||
          data['status'] == 'reserved' ||
          (data['contractId'] as String? ?? '').isNotEmpty) {
        throw StateError(
          'Phòng còn khách thuê hoặc hợp đồng. Hãy kết thúc hợp đồng trước khi xóa.',
        );
      }
      final codes = _codes(parent!);
      final key = _codeKey(data['roomCode'] as String? ?? '');
      if (codes[key] == base.id) codes.remove(key);
      final count = (parent['roomCount'] as num?)?.toInt() ?? 0;
      transaction.update(roomRef, deletedPayload);
      transaction.update(propertyRef, {
        'roomCount': count > 0 ? count - 1 : 0,
        'roomCodes': codes,
      });
    });
  }

  // Chủ trọ - Theo dõi danh sách phòng theo cơ sở
  Stream<List<RoomModel>> watchRoomsByProperty(String uid, String propertyId) =>
      _db
          .collection(FirestoreCollections.hostRooms)
          .where('hostId', isEqualTo: uid)
          .where('propertyId', isEqualTo: propertyId)
          .snapshots()
          .asyncMap((snapshot) => _resolveRoomChildData(snapshot.docs));

  // Chủ trọ - Lấy danh sách tiện ích thực tế từ bảng tien_ich_phong_tro / TienIch_Phong / room_amenities của phòng
  Future<List<String>> getRoomAmenitiesFromTienIchPhong(String roomId) async {
    if (roomId.isEmpty) return const [];
    try {
      final results = <String>[];
      final targetIds = <String>{
        roomId,
        if (roomId.contains('_') && roomId.lastIndexOf('_') > 0)
          roomId.substring(0, roomId.lastIndexOf('_')),
      };
      for (final col in [
        FirestoreCollections.roomAmenities,
        FirestoreCollections.tienIchPhongTro,
        FirestoreCollections.tienIchPhong,
        'room_amenities',
        'tien_ich_phong_tro',
      ]) {
        for (final field in ['roomId', 'phong_tro_id', 'phongId']) {
          for (final tid in targetIds) {
            final snap = await _db
                .collection(col)
                .where(field, isEqualTo: tid)
                .get();
            for (final d in snap.docs) {
              final data = d.data();
              final name =
                  (data['amenityName'] ??
                          data['ten_tien_ich'] ??
                          data['tenTienIch'] ??
                          data['name'] ??
                          '')
                      .toString()
                      .trim();
              if (name.isNotEmpty && !results.contains(name)) {
                results.add(name);
              }
            }
            if (results.isNotEmpty) return results;
          }
        }
      }
      return results;
    } catch (_) {
      return const [];
    }
  }

  // Chủ trọ - Lấy danh sách ảnh thực tế từ bảng hinh_anh_phong / AnhPhong / room_images của phòng
  Future<List<String>> getRoomImagesFromAnhPhong(String roomId) async {
    if (roomId.isEmpty) return const [];
    try {
      final results = <String>[];
      final targetIds = <String>{
        roomId,
        if (roomId.contains('_') && roomId.lastIndexOf('_') > 0)
          roomId.substring(0, roomId.lastIndexOf('_')),
      };
      for (final col in [
        FirestoreCollections.roomImages,
        FirestoreCollections.hinhAnhPhong,
        FirestoreCollections.anhPhong,
        'roomImages',
        'AnhPhong',
        'hinh_anh_phong',
      ]) {
        for (final field in ['roomId', 'phong_tro_id', 'phongId']) {
          for (final tid in targetIds) {
            final snap = await _db
                .collection(col)
                .where(field, isEqualTo: tid)
                .get();
            final docs = snap.docs.toList()
              ..sort((a, b) {
                final oa =
                    (a.data()['sortOrder'] ??
                            a.data()['thu_tu'] ??
                            a.data()['thuTu'])
                        as num? ??
                    0;
                final ob =
                    (b.data()['sortOrder'] ??
                            b.data()['thu_tu'] ??
                            b.data()['thuTu'])
                        as num? ??
                    0;
                return oa.compareTo(ob);
              });
            for (final doc in docs) {
              final data = doc.data();
              final url =
                  (data['url'] ??
                          data['url_anh'] ??
                          data['duongDan'] ??
                          data['image'] ??
                          data['imageUrl'] ??
                          data['link'] ??
                          '')
                      .toString()
                      .trim();
              if (url.isNotEmpty && !results.contains(url)) {
                results.add(url);
              }
            }
            if (results.isNotEmpty) return results;
          }
        }
      }

      // Kiểm tra sub-collections: host_rooms/{roomId}/room_images, rooms/{roomId}/room_images
      if (results.isEmpty) {
        for (final parentCol in [FirestoreCollections.hostRooms]) {
          for (final tid in targetIds) {
            for (final subCol in [
              FirestoreCollections.roomImages,
              FirestoreCollections.hinhAnhPhong,
              'room_images',
              'images',
            ]) {
              try {
                final subSnap = await _db
                    .collection(parentCol)
                    .doc(tid)
                    .collection(subCol)
                    .get();
                for (final d in subSnap.docs) {
                  final data = d.data();
                  final url =
                      (data['url'] ??
                              data['url_anh'] ??
                              data['duongDan'] ??
                              data['image'] ??
                              data['imageUrl'] ??
                              '')
                          .toString()
                          .trim();
                  if (url.isNotEmpty && !results.contains(url)) {
                    results.add(url);
                  }
                }
                if (results.isNotEmpty) return results;
              } catch (_) {}
            }
          }
        }
      }

      // Kiểm tra trực tiếp document phòng nếu chưa có
      if (results.isEmpty) {
        for (final col in [FirestoreCollections.hostRooms]) {
          for (final tid in targetIds) {
            final doc = await _db.collection(col).doc(tid).get();
            if (doc.exists && doc.data() != null) {
              final data = doc.data()!;
              final raw =
                  data['images'] ??
                  data['anhPhong'] ??
                  data['roomImages'] ??
                  data['imageUrls'] ??
                  data['photos'] ??
                  data['photoUrls'] ??
                  data['hinhAnh'] ??
                  data['anh_phong'];
              if (raw is List) {
                for (final item in raw) {
                  final u = item.toString().trim();
                  if (u.isNotEmpty && !results.contains(u)) results.add(u);
                }
              } else if (raw is String && raw.trim().isNotEmpty) {
                results.add(raw.trim());
              }
              if (results.isNotEmpty) break;
            }
          }
        }
      }

      return results;
    } catch (_) {
      return const [];
    }
  }

  // Chủ trọ - Đăng bài trong posts; giữ nguyên dữ liệu phòng và dữ liệu con.
  Future<String> createPostWithAmenities({
    required RoomModel room,
    required List<HostUpload> images,
    required String operationId,
    required Set<String> selectedAmenities,
    required List<String> customAmenities,
    required Map<String, String> catalogAmenitiesMap,
    required String chuNhaId,
    required String diaDiemId,
    required String loaiThueId,
    required String status,
    required String tieuDe,
    required String moTa,
    required double giaThue,
    int phanTramTienCoc = 20,
    double? tienCoc,
    required String soDienThoaiLienHe,
    required String authorName,
    required String authorAvatar,
    String? nhaTroId,
    String? phongId,
  }) async {
    await _requireHost(chuNhaId);
    final calculatedDeposit = tienCoc ?? (giaThue * phanTramTienCoc / 100);
    final targetRoomId = phongId ?? (room.id.isNotEmpty ? room.id : '');

    // Bài đăng chỉ tham chiếu phòng đã tồn tại, không tạo hoặc sửa phòng.
    if (targetRoomId.isEmpty) {
      throw StateError('Vui lòng chọn phòng đã tạo trước khi đăng bài.');
    }
    final sourceRoom = await _db
        .collection(FirestoreCollections.hostRooms)
        .doc(targetRoomId)
        .get();
    final sourceData = sourceRoom.data();
    if (sourceData == null ||
        sourceData['hostId'] != chuNhaId ||
        sourceData['propertyId'] != (nhaTroId ?? room.propertyId) ||
        sourceData['status'] == 'deleted') {
      throw StateError('Phòng không tồn tại hoặc không thuộc cơ sở của bạn.');
    }

    if (!RoomModel.fromFirestore(sourceRoom).canBeListed) {
      throw StateError('Phòng đã được đặt cọc hoặc không còn trống.');
    }

    final finalUrls = <String>[...room.images];
    if (images.isNotEmpty) {
      final uploadRoomId = targetRoomId.isNotEmpty
          ? targetRoomId
          : DateTime.now().millisecondsSinceEpoch.toString();
      final uploaded = await _upload(
        images,
        'host_media/$chuNhaId/posts/$operationId/$uploadRoomId',
        10,
      );
      finalUrls.addAll(uploaded);
    }

    final batch = _db.batch();

    // 1. Lưu danh mục tiện ích vào collection amenities
    for (final name in selectedAmenities) {
      final key = name.trim().toLowerCase();
      if (catalogAmenitiesMap.containsKey(key)) {
        continue;
      } else {
        final amRef = _db.collection(FirestoreCollections.amenities).doc();
        final amData = {
          'id': amRef.id,
          'name': name,
          'icon': '',
          'source': 'host_custom',
          'createdAt': FieldValue.serverTimestamp(),
        };
        batch.set(amRef, amData);
      }
    }

    // 4. Lưu bài đăng vào collection posts (100% tiếng Anh, không lặp key)
    final postRef = _db.collection(FirestoreCollections.posts).doc();
    final postPayload = {
      'id': postRef.id,
      // Chủ trọ - Giữ liên kết cơ sở của phòng có sẵn trên bài đăng.
      'propertyId': sourceData['propertyId'] ?? room.propertyId,
      'roomId': targetRoomId,
      'roomCode': sourceData['roomCode'] ?? targetRoomId,
      'hostId': chuNhaId,
      'title': tieuDe,
      'description': moTa,
      'rentalPrice': giaThue,
      'depositAmount': calculatedDeposit,
      'depositPercentage': phanTramTienCoc,
      'images': finalUrls,
      'amenities': selectedAmenities.toList(),
      'status': status.isNotEmpty ? status : 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    };
    await batch.commit();
    // Recheck after uploads; touching the room serializes against deposit approval.
    await _db.runTransaction((transaction) async {
      final latestRoom = await transaction.get(sourceRoom.reference);
      if (!latestRoom.exists ||
          !RoomModel.fromFirestore(latestRoom).canBeListed) {
        throw StateError('Phòng đã được đặt cọc hoặc không còn trống.');
      }
      transaction.update(sourceRoom.reference, {
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(postRef, postPayload);
    });
    return postRef.id;
  }
}

final hostRoomsByPropertyProvider =
    StreamProvider.family<List<RoomModel>, String>((ref, propertyId) {
      final uid = ref.watch(hostSessionProvider).value;
      if (uid == null || propertyId.isEmpty) return Stream.value(const []);
      return ref
          .watch(hostRepositoryProvider)
          .watchRoomsByProperty(uid, propertyId);
    });

// Chủ trọ - Thông báo lỗi Firebase - Luồng đi: Hiển thị nguyên nhân
// lưu/tải thất bại bằng tiếng Việt để người dùng có thể sửa và thử lại.
String hostErrorMessage(Object error) {
  // Một số lỗi callback transaction trên web được bọc lại thành chuỗi.
  if (error.toString().contains('Trùng ID phòng.')) {
    return 'Trùng ID phòng.';
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
      case 'unauthorized':
        return 'Chưa có quyền truy cập. Kiểm tra tài khoản Chủ trọ và Firebase Rules.';
      case 'unauthenticated':
        return 'Vui lòng đăng nhập lại để lưu nhà/phòng.';
      case 'unavailable':
      case 'network-request-failed':
      case 'retry-limit-exceeded':
        return 'Không kết nối được Firebase. Kiểm tra mạng rồi thử lại.';
      case 'bucket-not-found':
      case 'object-not-found':
        return 'Chưa truy cập được Storage. Kiểm tra bucket trong Firebase Console.';
      default:
        return 'Firebase báo lỗi ${error.code}. Vui lòng kiểm tra cấu hình rồi thử lại.';
    }
  }
  return error is StateError
      ? error.message.toString()
      : 'Không thể hoàn tất thao tác. Vui lòng thử lại.';
}
