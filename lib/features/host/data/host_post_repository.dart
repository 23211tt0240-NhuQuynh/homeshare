import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../../data/models/host_post_model.dart';
import '../../../data/models/room_model.dart';
import '../../auth/providers/user_provider.dart';
import '../../chat/screens/chat_detail_screen.dart';

/// Repository xử lý nghiệp vụ đọc Bài đăng Chủ trọ và nối quan hệ dữ liệu:
/// Bài đăng ├── phongId ├── chuNhaId ├── diaDiemId ├── loaiThue_id └── trangThai_id
class HostPostRepository {
  final FirebaseFirestore? firestore;

  HostPostRepository({this.firestore});

  FirebaseFirestore? get _db {
    if (firestore != null) return firestore;
    if (Firebase.apps.isNotEmpty) return FirebaseFirestore.instance;
    return null;
  }

  // Bộ nhớ đệm tạm thời để tối ưu hoá hiệu năng join
  final Map<String, RoomModel> _roomCache = {};
  final Map<String, List<String>> _propertyImagesCache = {};
  final Map<String, UserProfile> _hostCache = {};
  final Map<String, Map<String, String>> _locationCache = {};

  /// 1. Stream bài đăng realtime từ collection 'posts', loại trừ chủ trọ hiện tại
  Stream<List<HostPostModel>> watchActivePosts({
    String? excludeHostId,
    String? currentUserId,
  }) {
    final db = _db;
    if (db == null) {
      return Stream.value(const []);
    }

    // Lắng nghe realtime từ collection 'posts' và bổ sung tiện ích từ phòng nếu tài liệu bài đăng chưa lưu sẵn
    return db.collection('posts').snapshots().asyncMap((snapshot) async {
      final posts = <HostPostModel>[];

      for (final doc in snapshot.docs) {
        try {
          final post = HostPostModel.fromFirestore(
            doc,
            currentUserId: currentUserId ?? '',
          );

          // Chỉ lấy bài đang hoạt động và không phải của chủ trọ hiện tại
          if (!post.isActive) continue;
          if (excludeHostId != null &&
              excludeHostId.isNotEmpty &&
              post.chuNhaId == excludeHostId) {
            continue;
          }

          posts.add(post);
        } catch (e) {
          debugPrint('Lỗi parse HostPostModel ${doc.id}: $e');
        }
      }

      // Đảm bảo bài đăng có đầy đủ ảnh và tiện ích (phục vụ hiển thị và bộ lọc)
      final enrichedPosts = <HostPostModel>[];
      for (final post in posts) {
        var enriched = post;

        // Trích xuất mã phòng từ tiêu đề (ví dụ: 'Phòng A102 • Nhà trọ i tê' -> 'A102')
        String extractedRoomCode = '';
        final roomCodeMatch = RegExp(
          r'(?:phòng|phong|room)\s*([a-zA-Z0-9_\-]+)',
          caseSensitive: false,
        ).firstMatch(post.tieuDe);
        if (roomCodeMatch != null) {
          extractedRoomCode = roomCodeMatch.group(1)!.trim();
        } else if (post.tieuDe.contains('•')) {
          final firstPart = post.tieuDe.split('•').first;
          extractedRoomCode = firstPart
              .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '')
              .trim();
        }

        // Trích xuất tên cơ sở / nhà trọ (ví dụ: 'Nhà trọ i tê')
        String extractedPropName = post.propertyName;
        if (extractedPropName.isEmpty && post.tieuDe.contains('•')) {
          extractedPropName = post.tieuDe.split('•').last.trim();
        }

        // 1. Tự động liên kết dữ liệu từ phòng nếu bài đăng thiếu ảnh hoặc tiện ích
        if (enriched.images.isEmpty ||
            enriched.amenities.isEmpty ||
            enriched.joinedRoom == null) {
          final room = await getRoom(
            post.phongId,
            roomCode: extractedRoomCode,
            hostId: post.chuNhaId,
            propertyName: extractedPropName,
          );
          if (room != null) {
            enriched = enriched.withRoom(room);
          }
        }

        // 2. Nếu bài đăng vẫn chưa có ảnh, truy vấn từ bảng AnhPhong / anhPhong
        if (enriched.images.isEmpty) {
          var anhPhongImages = <String>[];
          if (post.phongId.isNotEmpty) {
            anhPhongImages = await getImagesFromAnhPhong(post.phongId);
          }
          if (anhPhongImages.isEmpty && extractedRoomCode.isNotEmpty) {
            anhPhongImages = await getImagesFromAnhPhong(extractedRoomCode);
          }
          if (anhPhongImages.isNotEmpty) {
            enriched = enriched.copyWith(images: anhPhongImages);
          }
        }

        // 3. Nếu bài đăng vẫn chưa có ảnh, fallback lấy ảnh từ cơ sở liên kết (properties / host_properties)
        if (enriched.images.isEmpty) {
          final propImages = await findPropertyImagesForPost(
            enriched,
            extractedPropName: extractedPropName,
          );
          if (propImages.isNotEmpty) {
            enriched = enriched.copyWith(images: propImages);
            if (enriched.joinedRoom != null &&
                enriched.joinedRoom!.images.isEmpty) {
              enriched = enriched.copyWith(
                joinedRoom: enriched.joinedRoom!.copyWith(images: propImages),
              );
            }
          }
        }

        // 4. Tự động lấy tên & avatar chủ trọ từ collection users nếu bài đăng chưa có
        if ((enriched.authorAvatar.isEmpty || enriched.authorName.isEmpty) &&
            post.chuNhaId.isNotEmpty) {
          final host = await getHostProfile(post.chuNhaId);
          if (host != null) {
            enriched = enriched.withHost(host);
          }
        }

        enrichedPosts.add(enriched);
      }

      return enrichedPosts;
    });
  }

  /// 2. Đọc phòng liên quan theo phongId/roomCode từ host_rooms hoặc rooms
  Future<RoomModel?> getRoom(
    String roomId, {
    String? roomCode,
    String? hostId,
    String? propertyName,
  }) async {
    final db = _db;
    if (db == null) return null;
    final cacheKey = roomId.isNotEmpty ? roomId : (roomCode ?? '');
    if (cacheKey.isNotEmpty && _roomCache.containsKey(cacheKey)) {
      return _roomCache[cacheKey];
    }

    try {
      DocumentSnapshot? foundDoc;

      // 1. Thử đọc trực tiếp bằng doc ID nếu có
      if (roomId.isNotEmpty) {
        var doc = await db
            .collection(FirestoreCollections.hostRooms)
            .doc(roomId)
            .get();
        if (!doc.exists) {
          doc = await db
              .collection(FirestoreCollections.publicRooms)
              .doc(roomId)
              .get();
        }
        if (doc.exists && doc.data() != null) {
          foundDoc = doc;
        } else {
          // Thử tìm theo trường id / phongId / roomCode
          for (final col in [
            FirestoreCollections.hostRooms,
            FirestoreCollections.publicRooms,
            'phong',
            'Phong',
          ]) {
            for (final field in ['id', 'phongId', 'roomCode', 'maPhong']) {
              final snap = await db
                  .collection(col)
                  .where(field, isEqualTo: roomId)
                  .limit(1)
                  .get();
              if (snap.docs.isNotEmpty) {
                foundDoc = snap.docs.first;
                break;
              }
            }
            if (foundDoc != null) break;
          }
        }
      }

      // 2. Nếu chưa tìm thấy và có roomCode (ví dụ: 'A102' bóc từ tiêu đề)
      if (foundDoc == null && roomCode != null && roomCode.isNotEmpty) {
        for (final col in [
          FirestoreCollections.hostRooms,
          FirestoreCollections.publicRooms,
        ]) {
          // Khớp cả hostId và roomCode
          if (hostId != null && hostId.isNotEmpty) {
            final snap = await db
                .collection(col)
                .where('hostId', isEqualTo: hostId)
                .where('roomCode', isEqualTo: roomCode)
                .limit(1)
                .get();
            if (snap.docs.isNotEmpty) {
              foundDoc = snap.docs.first;
              break;
            }
          }

          // Khớp roomCode
          final snapCode = await db
              .collection(col)
              .where('roomCode', isEqualTo: roomCode)
              .limit(1)
              .get();
          if (snapCode.docs.isNotEmpty) {
            foundDoc = snapCode.docs.first;
            break;
          }
        }
      }

      if (foundDoc != null && foundDoc.data() != null) {
        var room = RoomModel.fromFirestore(foundDoc);

        // 3. Nếu phòng chưa có ảnh, tìm thêm từ collection AnhPhong
        if (room.images.isEmpty) {
          var anhPhongImages = await getImagesFromAnhPhong(room.id);
          if (anhPhongImages.isEmpty && room.roomCode.isNotEmpty) {
            anhPhongImages = await getImagesFromAnhPhong(room.roomCode);
          }
          if (anhPhongImages.isNotEmpty) {
            room = room.copyWith(images: anhPhongImages);
          }
        }

        // 4. Nếu phòng vẫn chưa có ảnh nhưng có propertyId, thừa hưởng ảnh từ cơ sở
        if (room.images.isEmpty && room.propertyId.isNotEmpty) {
          final propImages = await getPropertyImages(room.propertyId);
          if (propImages.isNotEmpty) {
            room = room.copyWith(images: propImages);
          }
        }

        if (cacheKey.isNotEmpty) {
          _roomCache[cacheKey] = room;
        }
        _roomCache[room.id] = room;
        return room;
      }
    } catch (e) {
      debugPrint('Lỗi đọc phòng $roomId (code: $roomCode): $e');
    }
    return null;
  }

  /// Đọc danh sách ảnh phòng thực tế từ collection 'AnhPhong' hoặc 'anhPhong' theo phongId hoặc roomCode
  Future<List<String>> getImagesFromAnhPhong(String roomId) async {
    final db = _db;
    if (roomId.isEmpty || db == null) return const [];
    try {
      final results = <String>[];
      for (final col in [
        'AnhPhong',
        'anhPhong',
        'RoomImages',
        'room_images',
        'anh_phong',
      ]) {
        for (final field in ['phongId', 'roomId', 'roomCode', 'maPhong']) {
          final snap = await db
              .collection(col)
              .where(field, isEqualTo: roomId)
              .get();
          for (final d in snap.docs) {
            final data = d.data();
            final rawUrl = (data['duongDan'] ??
                    data['url'] ??
                    data['image'] ??
                    data['hinhAnh'] ??
                    data['duong_dan'] ??
                    '')
                .toString();
            final clean = HostPostModel.cleanImageUrl(rawUrl);
            if (clean.isNotEmpty && !results.contains(clean)) {
              results.add(clean);
            }
          }
          if (results.isNotEmpty) break;
        }
      }
      return results;
    } catch (e) {
      debugPrint('Lỗi đọc AnhPhong cho phòng $roomId: $e');
      return const [];
    }
  }

  /// Đọc ảnh cơ sở/nhà trọ từ collection 'properties' hoặc 'host_properties'
  Future<List<String>> getPropertyImages(String propertyId) async {
    final db = _db;
    if (propertyId.isEmpty || db == null) return const [];
    if (_propertyImagesCache.containsKey(propertyId)) {
      return _propertyImagesCache[propertyId]!;
    }

    try {
      final results = <String>[];
      for (final col in [
        FirestoreCollections.hostProperties,
        'host_properties',
        'nhaTro',
        'NhaTro',
        'coSo',
      ]) {
        final doc = await db.collection(col).doc(propertyId).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final images = HostPostModel.parseImagesList(data);
          for (final img in images) {
            if (!results.contains(img)) results.add(img);
          }
          if (results.isNotEmpty) break;
        }
      }
      if (results.isNotEmpty) {
        _propertyImagesCache[propertyId] = results;
        return results;
      }
    } catch (e) {
      debugPrint('Lỗi đọc ảnh cơ sở $propertyId: $e');
    }
    return const [];
  }

  /// Tìm kiếm ảnh cơ sở / nhà trọ cho bài đăng qua nhiều tiêu chí liên kết:
  /// 1. joinedRoom.propertyId
  /// 2. post.diaDiemId (có thể lưu ID nhà trọ)
  /// 3. Tên nhà trọ (post.propertyName hoặc tách từ tiêu đề, ví dụ: 'Nhà trọ i tê')
  /// 4. ID chủ nhà (post.chuNhaId)
  Future<List<String>> findPropertyImagesForPost(
    HostPostModel post, {
    String? extractedPropName,
  }) async {
    final db = _db;
    if (db == null) return const [];

    // 1. Kiểm tra qua propertyId của phòng đã liên kết
    if (post.joinedRoom?.propertyId.isNotEmpty == true) {
      final imgs = await getPropertyImages(post.joinedRoom!.propertyId);
      if (imgs.isNotEmpty) return imgs;
    }

    // 2. Kiểm tra qua diaDiemId nếu nó trùng với ID cơ sở
    if (post.diaDiemId.isNotEmpty) {
      final imgs = await getPropertyImages(post.diaDiemId);
      if (imgs.isNotEmpty) return imgs;
    }

    // 3. Tìm theo tên cơ sở (ví dụ: 'Nhà trọ i tê' được bóc từ tiêu đề 'Phòng A102 • Nhà trọ i tê')
    final propName = (extractedPropName?.isNotEmpty == true
            ? extractedPropName!
            : post.propertyName)
        .trim();

    final collections = [
      FirestoreCollections.hostProperties,
      'host_properties',
      'nhaTro',
      'NhaTro',
      'coSo',
    ];

    if (propName.isNotEmpty) {
      for (final col in collections) {
        try {
          // Ưu tiên khớp cả tên cơ sở và chủ nhà
          if (post.chuNhaId.isNotEmpty) {
            final snapWithHost = await db
                .collection(col)
                .where('hostId', isEqualTo: post.chuNhaId)
                .where('name', isEqualTo: propName)
                .limit(1)
                .get();
            if (snapWithHost.docs.isNotEmpty) {
              final imgs = HostPostModel.parseImagesList(
                snapWithHost.docs.first.data(),
              );
              if (imgs.isNotEmpty) return imgs;
            }
          }

          // Khớp theo tên cơ sở
          for (final nameField in ['name', 'tenNha', 'tenCoSo', 'title']) {
            final snap = await db
                .collection(col)
                .where(nameField, isEqualTo: propName)
                .limit(1)
                .get();
            if (snap.docs.isNotEmpty) {
              final imgs = HostPostModel.parseImagesList(
                snap.docs.first.data(),
              );
              if (imgs.isNotEmpty) return imgs;
            }
          }
        } catch (_) {}
      }
    }

    // 4. Nếu vẫn chưa có, lấy ảnh cơ sở mà chủ trọ này sở hữu
    if (post.chuNhaId.isNotEmpty) {
      for (final col in collections) {
        try {
          final snap = await db
              .collection(col)
              .where('hostId', isEqualTo: post.chuNhaId)
              .limit(3)
              .get();
          for (final doc in snap.docs) {
            final imgs = HostPostModel.parseImagesList(doc.data());
            if (imgs.isNotEmpty) return imgs;
          }
        } catch (_) {}
      }
    }

    return const [];
  }

  /// 3. Đọc thông tin chủ trọ theo chuNhaId từ collection 'users'
  Future<UserProfile?> getHostProfile(String hostId) async {
    final db = _db;
    if (hostId.isEmpty || db == null) return null;
    if (_hostCache.containsKey(hostId)) return _hostCache[hostId];

    try {
      final doc = await db.collection('users').doc(hostId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final profile = UserProfile(
          uid: hostId,
          email: data['email'] ?? '',
          displayName: data['displayName'] ??
              data['hoTen'] ??
              data['name'] ??
              'Chủ trọ',
          phoneNumber: data['phoneNumber'] ??
              data['soDienThoai'] ??
              data['phone'] ??
              '',
          role: data['role'] ?? 'host',
          avatarUrl: data['avatarUrl'] ?? data['anhDaiDien'] ?? '',
          gender: data['gender'] ?? 'nam',
          address: data['address'] ?? data['diaChi'] ?? '',
          hometown: data['hometown'] ?? data['queQuan'] ?? '',
          reputationScore: (data['reputationScore'] ??
                  data['diemUyTin'] ??
                  100 as num)
              .toInt(),
          occupation: data['occupation'] ?? 'Chủ nhà trọ',
          hobbies: const [],
          isCccdVerified: data['isCccdVerified'] == true ||
              data['daXacThucCccd'] == true,
          cccdNumber: data['cccdNumber'] ?? '',
          cccdFullName: data['cccdFullName'] ?? '',
          cccdIssueDate: data['cccdIssueDate'] ?? '',
          cccdHometown: data['cccdHometown'] ?? '',
          cccdFrontImageUrl: data['cccdFrontImageUrl'] ?? '',
          cccdBackImageUrl: data['cccdBackImageUrl'] ?? '',
        );
        _hostCache[hostId] = profile;
        return profile;
      }
    } catch (e) {
      debugPrint('Lỗi đọc chủ trọ $hostId: $e');
    }
    return null;
  }

  /// 4. Đọc địa điểm theo diaDiemId
  Future<Map<String, String>?> getLocation(String diaDiemId) async {
    final db = _db;
    if (diaDiemId.isEmpty || db == null) return null;
    if (_locationCache.containsKey(diaDiemId)) return _locationCache[diaDiemId];

    try {
      final doc = await db.collection('locations').doc(diaDiemId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final result = {
          'city': (data['city'] ?? data['thanhPho'] ?? '').toString(),
          'district':
              (data['district'] ?? data['quanHuyen'] ?? diaDiemId).toString(),
        };
        _locationCache[diaDiemId] = result;
        return result;
      }
    } catch (e) {
      debugPrint('Lỗi đọc địa điểm $diaDiemId: $e');
    }

    // Nếu không tìm thấy document, sử dụng diaDiemId làm district
    final fallback = {'city': 'TP. Hồ Chí Minh', 'district': diaDiemId};
    _locationCache[diaDiemId] = fallback;
    return fallback;
  }

  /// 5. Đếm lượt quan tâm / phản hồi
  Future<Map<String, int>> getInteractions(String postId) async {
    final db = _db;
    if (postId.isEmpty || db == null) {
      return {'interestedCount': 0, 'responseCount': 0};
    }
    try {
      final doc = await db.collection('posts').doc(postId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final interested = (data['interestedCount'] ??
                (data['interestedUsers'] as List?)?.length ??
                0 as num)
            .toInt();
        final responses = (data['responseCount'] ?? 0 as num).toInt();
        return {'interestedCount': interested, 'responseCount': responses};
      }
    } catch (_) {}
    return {'interestedCount': 0, 'responseCount': 0};
  }

  /// 6. Gửi thao tác quan tâm (Like / Quan tâm)
  Future<bool> toggleInterest({
    required String postId,
    required String userId,
  }) async {
    final db = _db;
    if (postId.isEmpty || userId.isEmpty || db == null) return false;

    try {
      final postRef = db.collection('posts').doc(postId);
      final doc = await postRef.get();
      if (!doc.exists) return false;

      final data = doc.data() ?? {};
      final interestedUsers = List<String>.from(data['interestedUsers'] ?? []);

      final bool isCurrentlyInterested = interestedUsers.contains(userId);
      if (isCurrentlyInterested) {
        interestedUsers.remove(userId);
        await postRef.update({
          'interestedUsers': FieldValue.arrayRemove([userId]),
          'interestedCount': FieldValue.increment(-1),
        });
        return false;
      } else {
        interestedUsers.add(userId);
        await postRef.update({
          'interestedUsers': FieldValue.arrayUnion([userId]),
          'interestedCount': FieldValue.increment(1),
        });
        return true;
      }
    } catch (e) {
      debugPrint('Lỗi thao tác quan tâm: $e');
      return false;
    }
  }

  /// 7. Mở cuộc trò chuyện theo baiDangId
  void openChatWithHost(
    BuildContext context,
    HostPostModel post, {
    String? currentUserId,
    String? currentUserName,
  }) {
    final senderId = currentUserId ?? '';
    if (senderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để nhắn tin với chủ trọ khác'),
        ),
      );
      return;
    }

    if (senderId == post.chuNhaId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đây là bài đăng của chính bạn')),
      );
      return;
    }

    final roomToPin = post.joinedRoom ??
        RoomModel(
          id: post.phongId.isNotEmpty ? post.phongId : post.id,
          title: post.tieuDe,
          description: post.moTa,
          price: post.giaThue,
          deposit: post.tienCoc,
          address: post.address,
          district: post.district,
          city: post.city.isNotEmpty ? post.city : 'TP. Hồ Chí Minh',
          area: post.roomArea > 0 ? post.roomArea : 20.0,
          roomType: post.roomType,
          amenities: post.amenities,
          images: post.images,
          hostId: post.chuNhaId,
          hostName: post.authorName,
          hostPhone: post.soDienThoaiLienHe,
          hostAvatar: post.authorAvatar,
          createdAt: post.ngayDang,
        );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          receiverId: post.chuNhaId,
          receiverName:
              post.authorName.isNotEmpty ? post.authorName : 'Chủ trọ',
          receiverAvatar: post.authorAvatar,
          receiverPhone: post.soDienThoaiLienHe.isNotEmpty
              ? post.soDienThoaiLienHe
              : '0903888999',
          isLandlord: true,
          currentUserId: senderId,
          currentUserName: currentUserName?.isNotEmpty == true
              ? currentUserName!
              : 'Chủ trọ',
          pinnedRoom: roomToPin,
        ),
      ),
    );
  }
}

final hostPostRepositoryProvider = Provider<HostPostRepository>((ref) {
  return HostPostRepository();
});
