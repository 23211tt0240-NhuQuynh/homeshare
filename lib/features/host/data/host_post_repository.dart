import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../../data/models/host_post_model.dart';
import '../../../data/models/room_model.dart';
import '../../auth/providers/user_provider.dart';
import '../../chat/screens/chat_detail_screen.dart';
import 'host_property.dart';

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
  final Map<String, UserProfile> _hostCache = {};
  final Map<String, Map<String, String>> _locationCache = {};
  final Map<String, HostProperty> _propertyCache = {};

  /// 1. Stream bài đăng realtime từ collection 'bai_dang_cho_thue' hoặc 'posts', loại trừ chủ trọ hiện tại
  Stream<List<HostPostModel>> watchActivePosts({
    String? excludeHostId,
    String? currentUserId,
  }) {
    final db = _db;
    if (db == null) {
      return Stream.value(const []);
    }

    // Lắng nghe realtime từ collection 'posts' (fallback 'bai_dang_cho_thue' nếu còn tài liệu cũ)
    return db.collection(FirestoreCollections.posts).snapshots().asyncMap((snapshot) async {
      var docs = snapshot.docs;
      if (docs.isEmpty) {
        final fallbackSnap = await db.collection(FirestoreCollections.baiDangChoThue).get();
        docs = fallbackSnap.docs;
      }

      final posts = <HostPostModel>[];

      for (final doc in docs) {
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

      // Nối quan hệ dữ liệu qua các khóa ngoại tách bảng
      final enrichedPosts = <HostPostModel>[];
      for (final post in posts) {
        var enriched = post;
        RoomModel? room;
        if (post.phongId.isNotEmpty) {
          room = await getRoom(post.phongId);
          if (room != null) {
            enriched = enriched.withRoom(room);
          }
        }
        final hostIdToFetch = post.chuNhaId.isNotEmpty
            ? post.chuNhaId
            : (room?.hostId ?? '');
        if (hostIdToFetch.isNotEmpty) {
          final host = await getHostProfile(hostIdToFetch);
          if (host != null) {
            enriched = enriched.withHost(host);
          }
        }
        final propId = room?.propertyId ?? '';
        if (propId.isNotEmpty) {
          final prop = await getProperty(propId);
          if (prop != null) {
            enriched = enriched.copyWith(
              propertyName: prop.name,
              address: enriched.address.isNotEmpty ? enriched.address : prop.address,
              city: enriched.city.isNotEmpty ? enriched.city : prop.city,
              district: enriched.district.isNotEmpty ? enriched.district : prop.district,
            );
          }
        }
        if (post.diaDiemId.isNotEmpty && (enriched.city.isEmpty || enriched.district.isEmpty)) {
          final loc = await getLocation(post.diaDiemId);
          if (loc != null) {
            enriched = enriched.withLocation(
              resolvedCity: loc['city'],
              resolvedDistrict: loc['district'],
            );
          }
        }
        enrichedPosts.add(enriched);
      }

      return enrichedPosts;
    });
  }

  /// Đọc cơ sở theo propertyId từ collection 'properties' hoặc 'bat_dong_san'
  Future<HostProperty?> getProperty(String propertyId) async {
    final db = _db;
    if (propertyId.isEmpty || db == null) return null;
    if (_propertyCache.containsKey(propertyId)) return _propertyCache[propertyId];

    try {
      for (final col in [
        FirestoreCollections.hostProperties,
        FirestoreCollections.batDongSan,
      ]) {
        final doc = await db.collection(col).doc(propertyId).get();
        if (doc.exists && doc.data() != null) {
          final prop = HostProperty.fromMap(doc.id, doc.data()!);
          _propertyCache[propertyId] = prop;
          return prop;
        }
      }
    } catch (e) {
      debugPrint('Lỗi đọc cơ sở $propertyId: $e');
    }
    return null;
  }

  /// 2. Đọc phòng liên quan theo roomId từ host_rooms, public_rooms hoặc phong_tro
  /// và nạp ảnh từ room_images cùng tiện ích từ room_amenities
  Future<RoomModel?> getRoom(String roomId) async {
    final db = _db;
    if (roomId.isEmpty || db == null) return null;
    if (_roomCache.containsKey(roomId)) return _roomCache[roomId];

    try {
      DocumentSnapshot? doc;
      for (final col in [
        FirestoreCollections.hostRooms,
        FirestoreCollections.publicRooms,
        FirestoreCollections.phongTro,
      ]) {
        final d = await db.collection(col).doc(roomId).get();
        if (d.exists && d.data() != null) {
          doc = d;
          break;
        }
      }

      if (doc != null && doc.data() != null) {
        var room = RoomModel.fromFirestore(doc);

        // Nối ảnh từ bảng riêng room_images / hinh_anh_phong
        final roomImages = await getRoomImages(roomId);
        if (roomImages.isNotEmpty) {
          room = room.copyWith(images: roomImages);
        }

        // Nối tiện ích từ bảng riêng room_amenities / tien_ich_phong_tro
        final roomAmenities = await getRoomAmenities(roomId);
        if (roomAmenities.isNotEmpty) {
          room = room.copyWith(amenities: roomAmenities);
        }

        _roomCache[roomId] = room;
        return room;
      }
    } catch (e) {
      debugPrint('Lỗi đọc phòng $roomId: $e');
    }
    return null;
  }

  /// Đọc ảnh phòng từ sub-collection hinh_anh_phong hoặc root collection room_images
  Future<List<String>> getRoomImages(String roomId) async {
    final db = _db;
    if (roomId.isEmpty || db == null) return const [];
    try {
      final results = <String>[];
      // 1. Đọc từ Sub-collection chuẩn 1-N: phong_tro/{roomId}/hinh_anh_phong
      try {
        for (final roomCol in [
          FirestoreCollections.phongTro,
          FirestoreCollections.hostRooms,
          FirestoreCollections.publicRooms,
        ]) {
          final subSnap = await db
              .collection(roomCol)
              .doc(roomId)
              .collection(FirestoreCollections.hinhAnhPhong)
              .get();
          if (subSnap.docs.isNotEmpty) {
            final docs = subSnap.docs.toList()
              ..sort((a, b) {
                final oa = (a.data()['thu_tu'] ??
                        a.data()['sortOrder'] ??
                        a.data()['thuTu']) as num? ??
                    0;
                final ob = (b.data()['thu_tu'] ??
                        b.data()['sortOrder'] ??
                        b.data()['thuTu']) as num? ??
                    0;
                return oa.compareTo(ob);
              });
            for (final doc in docs) {
              final data = doc.data();
              final url = (data['url_anh'] ??
                      data['url'] ??
                      data['duongDan'] ??
                      data['image'] ??
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
      } catch (_) {}

      // 2. Fallback đọc từ root collection (nếu có)
      for (final col in [
        FirestoreCollections.roomImages,
        FirestoreCollections.hinhAnhPhong,
        FirestoreCollections.anhPhong,
      ]) {
        for (final field in ['roomId', 'phongId', 'phong_tro_id']) {
          final snap = await db
              .collection(col)
              .where(field, isEqualTo: roomId)
              .get();
          final docs = snap.docs.toList()
            ..sort((a, b) {
              final oa = (a.data()['sortOrder'] ?? a.data()['thu_tu'] ?? a.data()['thuTu']) as num? ?? 0;
              final ob = (b.data()['sortOrder'] ?? b.data()['thu_tu'] ?? b.data()['thuTu']) as num? ?? 0;
              return oa.compareTo(ob);
            });
          for (final doc in docs) {
            final data = doc.data();
            final url = (data['url'] ??
                    data['url_anh'] ??
                    data['duongDan'] ??
                    data['image'] ??
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
      return results;
    } catch (_) {
      return const [];
    }
  }

  /// Đọc tiện ích phòng từ bảng room_amenities
  Future<List<String>> getRoomAmenities(String roomId) async {
    final db = _db;
    if (roomId.isEmpty || db == null) return const [];
    try {
      final results = <String>[];
      for (final col in [
        FirestoreCollections.roomAmenities,
        FirestoreCollections.tienIchPhongTro,
        FirestoreCollections.tienIchPhong,
      ]) {
        for (final field in ['roomId', 'phongId', 'phong_tro_id']) {
          final snap = await db
              .collection(col)
              .where(field, isEqualTo: roomId)
              .get();
          for (final d in snap.docs) {
            final data = d.data();
            final name = (data['amenityName'] ??
                    data['name'] ??
                    data['ten_tien_ich'] ??
                    data['tenTienIch'] ??
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
      return results;
    } catch (_) {
      return const [];
    }
  }

  /// 3. Đọc thông tin chủ trọ theo chuNhaId từ collection 'nguoi_dung' hoặc 'users'
  Future<UserProfile?> getHostProfile(String hostId) async {
    final db = _db;
    if (hostId.isEmpty || db == null) return null;
    if (_hostCache.containsKey(hostId)) return _hostCache[hostId];

    try {
      DocumentSnapshot? doc;
      for (final col in [
        FirestoreCollections.nguoiDung,
        'users',
      ]) {
        final d = await db.collection(col).doc(hostId).get();
        if (d.exists && d.data() != null) {
          doc = d;
          break;
        }
      }

      if (doc != null && doc.data() != null) {
        final data = doc.data()! as Map<String, dynamic>;
        final profile = UserProfile(
          uid: hostId,
          email: data['email'] ?? '',
          displayName: data['ho_ten'] ??
              data['displayName'] ??
              data['hoTen'] ??
              data['name'] ??
              'Chủ trọ',
          phoneNumber: data['so_dien_thoai'] ??
              data['phoneNumber'] ??
              data['soDienThoai'] ??
              data['phone'] ??
              '',
          role: data['vai_tro'] ?? data['role'] ?? 'host',
          avatarUrl: data['avatarUrl'] ?? data['anhDaiDien'] ?? '',
          gender: data['gender'] ?? 'nam',
          address: data['address'] ?? data['diaChi'] ?? '',
          hometown: data['hometown'] ?? data['queQuan'] ?? '',
          reputationScore: (data['diem_uy_tin'] ??
                  data['reputationScore'] ??
                  data['diemUyTin'] ??
                  100 as num)
              .toInt(),
          occupation: data['occupation'] ?? 'Chủ nhà trọ',
          hobbies: const [],
          isCccdVerified: data['isCccdVerified'] == true ||
              data['daXacThucCccd'] == true,
          cccdNumber: data['so_cccd'] ?? data['cccdNumber'] ?? '',
          cccdFullName: data['ho_ten_cccd'] ?? data['cccdFullName'] ?? '',
          cccdIssueDate: data['cccdIssueDate'] ?? '',
          cccdHometown: data['cccdHometown'] ?? '',
          cccdFrontImageUrl: data['anh_mat_truoc'] ?? data['cccdFrontImageUrl'] ?? '',
          cccdBackImageUrl: data['anh_mat_sau'] ?? data['cccdBackImageUrl'] ?? '',
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
          'city': (data['city'] ?? data['province'] ?? data['thanhPho'] ?? '').toString(),
          'district':
              (data['district'] ?? data['quanHuyen'] ?? diaDiemId).toString(),
          'ward': (data['ward'] ?? data['phuongXa'] ?? '').toString(),
          'address': (data['address'] ?? data['diaChi'] ?? '').toString(),
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
