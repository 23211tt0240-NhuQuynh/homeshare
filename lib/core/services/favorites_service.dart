import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/room_model.dart';
import '../../data/models/roommate_post_model.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'room_service.dart';
import 'roommate_service.dart';

class FavoritesState {
  final Set<String> favoriteRoomIds;
  final Set<String> favoritePostIds;
  final Map<String, RoomModel> roomsCache;
  final Map<String, RoommatePostModel> postsCache;
  final bool isLoading;

  const FavoritesState({
    this.favoriteRoomIds = const {},
    this.favoritePostIds = const {},
    this.roomsCache = const {},
    this.postsCache = const {},
    this.isLoading = false,
  });

  FavoritesState copyWith({
    Set<String>? favoriteRoomIds,
    Set<String>? favoritePostIds,
    Map<String, RoomModel>? roomsCache,
    Map<String, RoommatePostModel>? postsCache,
    bool? isLoading,
  }) {
    return FavoritesState(
      favoriteRoomIds: favoriteRoomIds ?? this.favoriteRoomIds,
      favoritePostIds: favoritePostIds ?? this.favoritePostIds,
      roomsCache: roomsCache ?? this.roomsCache,
      postsCache: postsCache ?? this.postsCache,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  List<RoomModel> get favoriteRooms {
    final list = <RoomModel>[];
    for (final id in favoriteRoomIds) {
      if (roomsCache.containsKey(id)) {
        list.add(roomsCache[id]!);
      }
    }
    return list;
  }

  List<RoommatePostModel> get favoritePosts {
    final list = <RoommatePostModel>[];
    for (final id in favoritePostIds) {
      if (postsCache.containsKey(id)) {
        list.add(postsCache[id]!);
      }
    }
    return list;
  }
}

class FavoritesNotifier extends Notifier<FavoritesState> {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static const _spKeyRoomIds = 'homeshare_favorite_room_ids';
  static const _spKeyPostIds = 'homeshare_favorite_post_ids';
  static const _spKeyRoomsCache = 'homeshare_favorite_rooms_cache';
  static const _spKeyPostsCache = 'homeshare_favorite_posts_cache';

  @override
  FavoritesState build() {
    Future.microtask(_loadFavorites);
    return const FavoritesState();
  }

  Future<void> _loadFavorites() async {
    state = state.copyWith(isLoading: true);
    try {
      final sp = await SharedPreferences.getInstance();
      final roomIds = (sp.getStringList(_spKeyRoomIds) ?? []).toSet();
      final postIds = (sp.getStringList(_spKeyPostIds) ?? []).toSet();

      final roomsCache = <String, RoomModel>{};
      final postsCache = <String, RoommatePostModel>{};

      // Tải cache phòng từ SharedPreferences
      final rawRoomsJson = sp.getString(_spKeyRoomsCache);
      if (rawRoomsJson != null && rawRoomsJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawRoomsJson) as Map<String, dynamic>;
          decoded.forEach((key, value) {
            if (value is Map<String, dynamic>) {
              roomsCache[key] = RoomModel.fromMap(value, key);
            }
          });
        } catch (e) {
          debugPrint('Error parsing cached favorite rooms: $e');
        }
      }

      // Tải cache bài đăng ở ghép từ SharedPreferences
      final rawPostsJson = sp.getString(_spKeyPostsCache);
      if (rawPostsJson != null && rawPostsJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawPostsJson) as Map<String, dynamic>;
          decoded.forEach((key, value) {
            if (value is Map<String, dynamic>) {
              postsCache[key] = RoommatePostModel.fromMap(value, key);
            }
          });
        } catch (e) {
          debugPrint('Error parsing cached favorite posts: $e');
        }
      }

      // Cập nhật state ngay lập tức từ bộ nhớ cục bộ để UI phản hồi tức thì
      state = state.copyWith(
        favoriteRoomIds: roomIds,
        favoritePostIds: postIds,
        roomsCache: roomsCache,
        postsCache: postsCache,
        isLoading: false,
      );

      // Đồng bộ từ Firestore nếu đã đăng nhập
      final user = ref.read(currentUserProvider);
      if (user != null) {
        try {
          final doc = await _firestore.collection('users').doc(user.uid).get();
          if (doc.exists) {
            final data = doc.data() ?? {};
            final cloudRoomIds = List<String>.from(data['favoriteRoomIds'] ?? []);
            final cloudPostIds = List<String>.from(data['favoritePostIds'] ?? []);

            roomIds.addAll(cloudRoomIds);
            postIds.addAll(cloudPostIds);

            await sp.setStringList(_spKeyRoomIds, roomIds.toList());
            await sp.setStringList(_spKeyPostIds, postIds.toList());

            state = state.copyWith(
              favoriteRoomIds: Set.from(roomIds),
              favoritePostIds: Set.from(postIds),
            );
          }
        } catch (e) {
          debugPrint('Sync favorites from Firestore offline fallback: $e');
        }
      }

      // Nạp đầy đủ thông tin chi tiết các phòng còn thiếu trong cache
      await _hydrateMissingRooms(roomIds);
      // Nạp đầy đủ thông tin chi tiết các bài đăng ở ghép còn thiếu trong cache
      await _hydrateMissingPosts(postIds);
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _hydrateMissingRooms(Set<String> roomIds) async {
    final updatedRooms = Map<String, RoomModel>.from(state.roomsCache);
    bool hasNew = false;
    final roomService = ref.read(roomServiceProvider);
    for (final id in roomIds) {
      if (id.toLowerCase().startsWith('sample')) continue;
      if (!updatedRooms.containsKey(id)) {
        // Tìm trong Firestore
        try {
          final room = await roomService.getRoomById(id);
          if (room != null && room.isDisplayable) {
            updatedRooms[id] = room;
            hasNew = true;
          }
        } catch (e) {
          debugPrint('Error fetching room $id: $e');
        }
      }
    }

    if (hasNew) {
      state = state.copyWith(roomsCache: updatedRooms);
      _persistRoomsCache(updatedRooms);
    }
  }

  Future<void> _hydrateMissingPosts(Set<String> postIds) async {
    final updatedPosts = Map<String, RoommatePostModel>.from(state.postsCache);
    bool hasNew = false;
    final demoPosts = RoommateService.getDemoRoommatePosts();

    for (final id in postIds) {
      if (!updatedPosts.containsKey(id)) {
        // Tìm trong demo posts
        final demoMatch = demoPosts.where((p) => p.id == id);
        if (demoMatch.isNotEmpty) {
          updatedPosts[id] = demoMatch.first;
          hasNew = true;
          continue;
        }

        // Tìm trong Firestore
        try {
          final doc = await _firestore.collection('roommate_posts').doc(id).get();
          if (doc.exists) {
            updatedPosts[id] = RoommatePostModel.fromFirestore(doc);
            hasNew = true;
          }
        } catch (e) {
          debugPrint('Error fetching post $id: $e');
        }
      }
    }

    if (hasNew) {
      state = state.copyWith(postsCache: updatedPosts);
      _persistPostsCache(updatedPosts);
    }
  }

  /// Toggle yêu thích phòng trọ
  /// Trả về `true` nếu vừa thêm vào yêu thích, `false` nếu vừa bỏ lưu.
  Future<bool> toggleFavoriteRoom(RoomModel room) async {
    final currentIds = Set<String>.from(state.favoriteRoomIds);
    final currentCache = Map<String, RoomModel>.from(state.roomsCache);
    final isAlreadyFav = currentIds.contains(room.id);
    final user = ref.read(currentUserProvider);

    if (isAlreadyFav) {
      currentIds.remove(room.id);
    } else {
      currentIds.add(room.id);
      currentCache[room.id] = room;
    }

    // Cập nhật State ngay tức thì
    state = state.copyWith(
      favoriteRoomIds: currentIds,
      roomsCache: currentCache,
    );

    // Lưu vào SharedPreferences
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_spKeyRoomIds, currentIds.toList());
    if (!isAlreadyFav) {
      _persistRoomsCache(currentCache);
    }

    // Đồng bộ lên Firestore nếu đã đăng nhập
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'favoriteRoomIds': isAlreadyFav
              ? FieldValue.arrayRemove([room.id])
              : FieldValue.arrayUnion([room.id]),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Sync room favorite to firestore error: $e');
      }
    }

    return !isAlreadyFav;
  }

  /// Toggle yêu thích bài đăng ở ghép
  /// Trả về `true` nếu vừa thêm vào yêu thích, `false` nếu vừa bỏ lưu.
  Future<bool> toggleFavoritePost(RoommatePostModel post) async {
    final currentIds = Set<String>.from(state.favoritePostIds);
    final currentCache = Map<String, RoommatePostModel>.from(state.postsCache);
    final isAlreadyFav = currentIds.contains(post.id);
    final user = ref.read(currentUserProvider);

    if (isAlreadyFav) {
      currentIds.remove(post.id);
    } else {
      currentIds.add(post.id);
      currentCache[post.id] = post;
    }

    // Cập nhật State ngay tức thì
    state = state.copyWith(
      favoritePostIds: currentIds,
      postsCache: currentCache,
    );

    // Lưu vào SharedPreferences
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_spKeyPostIds, currentIds.toList());
    if (!isAlreadyFav) {
      _persistPostsCache(currentCache);
    }

    // Đồng bộ lên Firestore nếu đã đăng nhập
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'favoritePostIds': isAlreadyFav
              ? FieldValue.arrayRemove([post.id])
              : FieldValue.arrayUnion([post.id]),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Sync post favorite to firestore error: $e');
      }
    }

    return !isAlreadyFav;
  }

  bool isRoomFavorite(String roomId) => state.favoriteRoomIds.contains(roomId);

  bool isPostFavorite(String postId) => state.favoritePostIds.contains(postId);

  void _persistRoomsCache(Map<String, RoomModel> cache) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final mapToSave = <String, dynamic>{};
      cache.forEach((id, room) {
        mapToSave[id] = {
          'id': room.id,
          'title': room.title,
          'description': room.description,
          'price': room.price,
          'deposit': room.deposit,
          'address': room.address,
          'district': room.district,
          'city': room.city,
          'area': room.area,
          'roomType': room.roomType,
          'amenities': room.amenities,
          'images': room.images,
          'hostId': room.hostId,
          'hostName': room.hostName,
          'hostPhone': room.hostPhone,
          'hostAvatar': room.hostAvatar,
          'rating': room.rating,
          'reviewCount': room.reviewCount,
          'isAvailable': room.isAvailable,
          'capacity': room.capacity,
          'floor': room.floor,
          'createdAt': room.createdAt.toIso8601String(),
        };
      });
      await sp.setString(_spKeyRoomsCache, jsonEncode(mapToSave));
    } catch (e) {
      debugPrint('Error persisting favorite rooms cache: $e');
    }
  }

  void _persistPostsCache(Map<String, RoommatePostModel> cache) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final mapToSave = <String, dynamic>{};
      cache.forEach((id, post) {
        mapToSave[id] = {
          'id': post.id,
          'authorId': post.authorId,
          'authorName': post.authorName,
          'authorAge': post.authorAge,
          'authorGender': post.authorGender,
          'authorOccupation': post.authorOccupation,
          'authorAvatar': post.authorAvatar,
          'title': post.title,
          'description': post.description,
          'postType': post.postType,
          'propertyType': post.propertyType,
          'pricePerPerson': post.pricePerPerson,
          'budgetMin': post.budgetMin,
          'budgetMax': post.budgetMax,
          'address': post.address,
          'district': post.district,
          'targetGender': post.targetGender,
          'habits': post.habits,
          'images': post.images,
          'imageCaptions': post.imageCaptions,
          'isVerified': post.isVerified,
          'matchRate': post.matchRate,
          'hasRoom': post.hasRoom,
          'status': post.status,
          'contactPhone': post.contactPhone,
          'createdAt': post.createdAt.toIso8601String(),
        };
      });
      await sp.setString(_spKeyPostsCache, jsonEncode(mapToSave));
    } catch (e) {
      debugPrint('Error persisting favorite posts cache: $e');
    }
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, FavoritesState>(
  FavoritesNotifier.new,
);
