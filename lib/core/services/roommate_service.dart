import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/roommate_post_model.dart';
<<<<<<< HEAD
import '../../features/auth/providers/auth_provider.dart';
import '../constants/vietnam_locations.dart';
import 'user_profile_service.dart';

class RoommateFilterParams {
  final String province;
  final String district;
  final String ward;
  final String targetGender;
  final bool? hasRoom; // null: Tất cả, true: Đã có phòng sẵn, false: Chưa có phòng
  final String occupation; // 'Tất cả', hoặc một nghề khi chỉ chọn một mục
  final List<String> occupations;
=======

class RoommateFilterParams {
  final String district;
  final String targetGender;
  final bool? hasRoom; // null: Tất cả, true: Đã có phòng sẵn, false: Chưa có phòng
  final String occupation; // 'Tất cả', 'Sinh viên', 'Đã đi làm', 'Freelancer'
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
  final double? budgetMin;
  final double? budgetMax;
  final List<String> habits;
  final int minMatchRate;
  final String searchQuery;

  const RoommateFilterParams({
<<<<<<< HEAD
    this.province = 'Tất cả',
    this.district = 'Tất cả',
    this.ward = 'Tất cả',
    this.targetGender = 'Tất cả',
    this.hasRoom,
    this.occupation = 'Tất cả',
    this.occupations = const [],
=======
    this.district = 'Tất cả',
    this.targetGender = 'Tất cả',
    this.hasRoom,
    this.occupation = 'Tất cả',
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
    this.budgetMin,
    this.budgetMax,
    this.habits = const [],
    this.minMatchRate = 0,
    this.searchQuery = '',
  });

  RoommateFilterParams copyWith({
<<<<<<< HEAD
    String? province,
    String? district,
    String? ward,
=======
    String? district,
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
    String? targetGender,
    bool? hasRoom,
    bool clearHasRoom = false,
    String? occupation,
<<<<<<< HEAD
    List<String>? occupations,
    double? budgetMin,
    double? budgetMax,
    bool clearBudget = false,
=======
    double? budgetMin,
    double? budgetMax,
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
    List<String>? habits,
    int? minMatchRate,
    String? searchQuery,
  }) {
    return RoommateFilterParams(
<<<<<<< HEAD
      province: province ?? this.province,
      district: district ?? this.district,
      ward: ward ?? this.ward,
      targetGender: targetGender ?? this.targetGender,
      hasRoom: clearHasRoom ? null : (hasRoom ?? this.hasRoom),
      occupation: occupation ?? this.occupation,
      occupations: occupations ?? this.occupations,
      budgetMin: clearBudget ? null : (budgetMin ?? this.budgetMin),
      budgetMax: clearBudget ? null : (budgetMax ?? this.budgetMax),
=======
      district: district ?? this.district,
      targetGender: targetGender ?? this.targetGender,
      hasRoom: clearHasRoom ? null : (hasRoom ?? this.hasRoom),
      occupation: occupation ?? this.occupation,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
      habits: habits ?? this.habits,
      minMatchRate: minMatchRate ?? this.minMatchRate,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoommateFilterParams &&
<<<<<<< HEAD
          province == other.province &&
          district == other.district &&
          ward == other.ward &&
          targetGender == other.targetGender &&
          hasRoom == other.hasRoom &&
          occupation == other.occupation &&
          listEquals(occupations, other.occupations) &&
=======
          district == other.district &&
          targetGender == other.targetGender &&
          hasRoom == other.hasRoom &&
          occupation == other.occupation &&
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
          budgetMin == other.budgetMin &&
          budgetMax == other.budgetMax &&
          listEquals(habits, other.habits) &&
          minMatchRate == other.minMatchRate &&
          searchQuery == other.searchQuery;

  @override
  int get hashCode => Object.hash(
<<<<<<< HEAD
        province,
        district,
        ward,
        targetGender,
        hasRoom,
        occupation,
        Object.hashAll(occupations),
=======
        district,
        targetGender,
        hasRoom,
        occupation,
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
        budgetMin,
        budgetMax,
        Object.hashAll(habits),
        minMatchRate,
        searchQuery,
      );
}

class RoommateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Danh sách bài đăng tạo mới trong bộ nhớ (đảm bảo luôn hiển thị ngay lập tức)
  static final List<RoommatePostModel> _localCreatedPosts = [];
<<<<<<< HEAD
  static bool _authorRepairStarted = false;
=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62

  // Stream bài đăng tìm ở ghép (an toàn bộ lọc, in-memory filter & sort)
  Stream<List<RoommatePostModel>> getRoommatePostsStream({
    String? district,
    String? targetGender,
<<<<<<< HEAD
    String? viewerId,
    RoommateFilterParams? filters,
  }) {
    final effectiveProvince = filters?.province ?? 'Tất cả';
    final effectiveDistrict = filters?.district ?? district;
    final effectiveWard = filters?.ward ?? 'Tất cả';
    final effectiveTargetGender = filters?.targetGender ?? targetGender;
    final hasRoom = filters?.hasRoom;
    final occupation = filters?.occupation;
    final occupations = filters?.occupations ?? const <String>[];
=======
    RoommateFilterParams? filters,
  }) {
    final effectiveDistrict = filters?.district ?? district;
    final effectiveTargetGender = filters?.targetGender ?? targetGender;
    final hasRoom = filters?.hasRoom;
    final occupation = filters?.occupation;
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
    final budgetMin = filters?.budgetMin;
    final budgetMax = filters?.budgetMax;
    final habits = filters?.habits ?? const [];
    final minMatchRate = filters?.minMatchRate ?? 0;
    final searchQuery = filters?.searchQuery.trim().toLowerCase() ?? '';
<<<<<<< HEAD
    _scheduleAuthorIdRepair();
=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62

    return _firestore.collection('roommate_posts').snapshots().handleError((err) {
      debugPrint('Firestore stream error, fallback to local: $err');
      return const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
<<<<<<< HEAD
    }).asyncMap((snapshot) async {
=======
    }).map((snapshot) {
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
      List<RoommatePostModel> list;
      if (snapshot.docs.isNotEmpty) {
        list = snapshot.docs.map((doc) {
          try {
            return RoommatePostModel.fromFirestore(doc);
          } catch (e) {
            debugPrint('Error parsing roommate post ${doc.id}: $e');
            return null;
          }
        }).whereType<RoommatePostModel>().toList();
      } else {
        list = [];
      }

      // Hợp nhất bài đăng tạo trong phiên (Local) và Cloud Firestore (Local ưu tiên trên đầu)
      final merged = <RoommatePostModel>[];
      for (final p in _localCreatedPosts) {
        merged.add(p);
      }
      for (final p in list) {
        if (!merged.any((item) => item.id == p.id)) {
          merged.add(p);
        }
      }

<<<<<<< HEAD
      // Bỏ các bài mẫu cũ. Bài thật, gồm bài mới nhất của Trần Thanh Anh Toàn, vẫn giữ.
      const obsoleteSampleIds = {'figma_post_1', 'figma_post_2', 'figma_post_3', 'figma_post_4'};
      merged.removeWhere((post) => obsoleteSampleIds.contains(post.id));
      for (final demo in getDemoRoommatePosts()) {
        if (!merged.any((post) => post.id == demo.id)) {
          merged.add(demo);
        }
      }

      final hydrated = await _withLiveAuthorAndImages(merged);

      final filtered = hydrated.where((post) {
=======
      final filtered = merged.where((post) {
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
        // 1. Tình trạng phòng (Đã có phòng / Chưa có phòng)
        if (hasRoom != null && post.hasRoom != hasRoom) {
          return false;
        }

        // 2. Tìm kiếm theo từ khóa (trường học, quận, tiêu đề, tên)
        if (searchQuery.isNotEmpty) {
          final matchTitle = post.title.toLowerCase().contains(searchQuery);
          final matchAddress = post.address.toLowerCase().contains(searchQuery);
          final matchDistrict = post.district.toLowerCase().contains(searchQuery);
          final matchAuthor = post.authorName.toLowerCase().contains(searchQuery);
          final matchOcc = post.authorOccupation.toLowerCase().contains(searchQuery);
          if (!matchTitle && !matchAddress && !matchDistrict && !matchAuthor && !matchOcc) {
            return false;
          }
        }

<<<<<<< HEAD
        // 3. Tỉnh, quận, rồi phường/xã nếu đã chọn
        if (effectiveProvince.isNotEmpty && effectiveProvince != 'Tất cả') {
          if (!_postMatchesProvince(post, effectiveProvince)) return false;
        }
        if (effectiveDistrict != null && effectiveDistrict.isNotEmpty && effectiveDistrict != 'Tất cả') {
          if (!_placeHit(post.district, effectiveDistrict) && !_placeHit(post.address, effectiveDistrict)) {
            return false;
          }
        }
        if (effectiveWard.isNotEmpty && effectiveWard != 'Tất cả') {
          if (!_placeHit(post.address, effectiveWard) && !_placeHit(post.district, effectiveWard)) {
=======
        // 3. Khu vực quận huyện
        if (effectiveDistrict != null && effectiveDistrict.isNotEmpty && effectiveDistrict != 'Tất cả') {
          if (!post.district.toLowerCase().contains(effectiveDistrict.toLowerCase()) &&
              !post.address.toLowerCase().contains(effectiveDistrict.toLowerCase())) {
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
            return false;
          }
        }

        // 4. Giới tính
        if (effectiveTargetGender != null && effectiveTargetGender.isNotEmpty && effectiveTargetGender != 'Tất cả') {
          if (effectiveTargetGender == 'LGBT+') {
            final isLgbt = post.targetGender.toLowerCase().contains('lgbt') ||
                post.habits.any((h) => h.toLowerCase().contains('lgbt'));
            if (!isLgbt && post.targetGender != 'Tất cả') return false;
          } else {
<<<<<<< HEAD
            final wanted = effectiveTargetGender.trim();
            final target = post.targetGender.trim();
            final author = post.authorGender.trim();
            final seeksWanted = target == 'Tất cả' || target == 'tatCa' || target == wanted;
            final authorIsWanted = author == wanted;
            if (!seeksWanted && !authorIsWanted) return false;
          }
        }

        // 5. Nghề nghiệp: khớp nếu nghề của người đăng chứa một mục đã chọn
        final selectedOccupations = <String>{
          ...occupations.where((item) => item.trim().isNotEmpty && item != 'Tất cả'),
          if (occupation != null && occupation.isNotEmpty && occupation != 'Tất cả') occupation,
        };
        if (selectedOccupations.isNotEmpty) {
          final authorJob = post.authorOccupation.toLowerCase();
          final matched = selectedOccupations.any((item) => authorJob.contains(item.toLowerCase()));
          if (!matched) return false;
=======
            if (post.targetGender != 'Tất cả' && post.targetGender != 'tatCa' && post.targetGender != effectiveTargetGender) {
              return false;
            }
          }
        }

        // 5. Nghề nghiệp
        if (occupation != null && occupation.isNotEmpty && occupation != 'Tất cả') {
          if (!post.authorOccupation.toLowerCase().contains(occupation.toLowerCase())) {
            return false;
          }
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
        }

        // 6. Ngân sách
        if (budgetMin != null && budgetMax != null) {
          final price = post.pricePerPerson > 0 ? post.pricePerPerson : post.budgetMax;
          if (price < budgetMin || price > budgetMax) {
            return false;
          }
        }

<<<<<<< HEAD
        // 7. Mỗi thói quen đã chọn phải có ý tương đương trên bài, không cần trùng từng chữ.
        if (habits.isNotEmpty && !habits.every((item) => _habitHit(item, post.habits))) {
=======
        // 7. Lối sống & Thói quen bắt buộc
        if (habits.isNotEmpty) {
          final matchedCount = habits.where((h) => post.habits.contains(h)).length;
          if (matchedCount == 0 && habits.length > 2) {
            return false;
          }
        }

        // 8. Tỷ lệ tương thích Match rate
        if (minMatchRate > 0 && post.matchRate < minMatchRate) {
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
          return false;
        }

        return true;
      }).toList();

<<<<<<< HEAD
      return _rankByViewerHobbies(filtered, viewerId: viewerId, minMatchRate: minMatchRate);
    });
  }

  /// Phần trăm sở thích của người xem xuất hiện trên bài. Null khi người xem chưa có sở thích.
  int? hobbyMatchPercent({
    required List<String> viewerHobbies,
    required List<String> candidateHabits,
  }) {
    final mine = <String>[];
    for (final raw in viewerHobbies) {
      final key = _habitKey(raw);
      if (key.isEmpty || mine.contains(key)) continue;
      mine.add(raw.trim());
    }
    if (mine.isEmpty) return null;
    var hit = 0;
    for (final hobby in mine) {
      if (_habitHit(hobby, candidateHabits)) hit++;
    }
    return ((hit / mine.length) * 100).round();
  }

  Future<List<RoommatePostModel>> _rankByViewerHobbies(
    List<RoommatePostModel> posts, {
    required String? viewerId,
    required int minMatchRate,
  }) async {
    final viewerHobbies = viewerId == null || viewerId.isEmpty
        ? const <String>[]
        : await _hobbyNamesOf(viewerId);
    if (viewerHobbies.isEmpty) {
      final plain = posts.map((post) => post.copyWith(matchRate: -1)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return plain;
    }

    final authorIds = posts.map((post) => post.authorId).where((id) => id.isNotEmpty).toSet();
    final authorHobbies = await _hobbyNamesByUser(authorIds);
    final ranked = <RoommatePostModel>[];
    for (final post in posts) {
      final candidate = <String>[
        ...post.habits,
        ...authorHobbies[post.authorId] ?? const <String>[],
      ];
      final percent = hobbyMatchPercent(viewerHobbies: viewerHobbies, candidateHabits: candidate) ?? 0;
      if (minMatchRate > 0 && percent < minMatchRate) continue;
      ranked.add(post.copyWith(matchRate: percent));
    }
    ranked.sort((a, b) {
      final byRate = b.matchRate.compareTo(a.matchRate);
      if (byRate != 0) return byRate;
      return b.createdAt.compareTo(a.createdAt);
    });
    return ranked;
  }

  Future<List<String>> _hobbyNamesOf(String uid) async {
    try {
      return UserProfileService().loadInterestNames(uid);
    } catch (e) {
      debugPrint('Đọc sở thích $uid: $e');
      return const [];
    }
  }

  Future<Map<String, List<String>>> _hobbyNamesByUser(Set<String> uids) async {
    final names = <String, List<String>>{};
    final ids = uids.toList();
    for (var i = 0; i < ids.length; i += 10) {
      final end = i + 10 > ids.length ? ids.length : i + 10;
      final chunk = ids.sublist(i, end);
      try {
        final links = await _firestore.collection('user_hobbies').where('nguoiDungId', whereIn: chunk).get();
        for (final doc in links.docs) {
          final uid = '${doc.data()['nguoiDungId'] ?? ''}';
          final hobbyId = '${doc.data()['soThichId'] ?? ''}';
          if (uid.isEmpty || hobbyId.isEmpty) continue;
          final hobby = await _firestore.collection('hobbies').doc(hobbyId).get();
          final name = hobby.data()?['tenSoThich']?.toString().trim() ?? '';
          if (name.isEmpty) continue;
          final list = names.putIfAbsent(uid, () => []);
          if (!list.any((item) => item.toLowerCase() == name.toLowerCase())) list.add(name);
        }
      } catch (e) {
        debugPrint('Đọc sở thích người đăng: $e');
      }
    }
    return names;
  }

  /// Avatar trên bài lấy ảnh hiện tại của người đăng.
  /// Ảnh bài của project kia nằm ở roommate_post_images, không nằm trên document bài.
  Future<List<RoommatePostModel>> _withLiveAuthorAndImages(List<RoommatePostModel> posts) async {
    final real = posts.where((post) => !post.id.startsWith('demo_') && !post.id.startsWith('figma_')).toList();
    if (real.isEmpty) return posts;

    final avatars = <String, String>{};
    for (final authorId in real.map((post) => post.authorId).where((id) => id.isNotEmpty).toSet()) {
      try {
        final doc = await _firestore.collection('users').doc(authorId).get();
        final data = doc.data();
        if (data == null) continue;
        final url = '${data['avatarUrl'] ?? data['anhDaiDien'] ?? ''}'.trim();
        if (url.isNotEmpty) avatars[authorId] = url;
      } catch (e) {
        debugPrint('Đọc avatar người đăng $authorId: $e');
      }
    }

    final imagesByPost = <String, List<String>>{};
    final needImages = real.where((post) => post.images.isEmpty).map((post) => post.id).toList();
    for (var start = 0; start < needImages.length; start += 10) {
      final end = start + 10 > needImages.length ? needImages.length : start + 10;
      final chunk = needImages.sublist(start, end);
      try {
        final snap = await _firestore.collection('roommate_post_images').where('postId', whereIn: chunk).get();
        final grouped = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
        for (final doc in snap.docs) {
          final postId = '${doc.data()['postId'] ?? ''}'.trim();
          if (postId.isEmpty) continue;
          grouped.putIfAbsent(postId, () => []).add(doc);
        }
        for (final entry in grouped.entries) {
          final docs = entry.value
            ..sort((a, b) {
              final left = a.data()['sortOrder'];
              final right = b.data()['sortOrder'];
              final leftOrder = left is num ? left.toInt() : 0;
              final rightOrder = right is num ? right.toInt() : 0;
              return leftOrder.compareTo(rightOrder);
            });
          imagesByPost[entry.key] = docs
              .map((doc) => '${doc.data()['imageUrl'] ?? doc.data()['duongDan'] ?? ''}'.trim())
              .where((url) => url.isNotEmpty)
              .toList();
        }
      } catch (e) {
        debugPrint('Đọc ảnh bài ở ghép: $e');
      }
    }

    return posts.map((post) {
      if (post.id.startsWith('demo_') || post.id.startsWith('figma_')) return post;
      final avatar = avatars[post.authorId];
      final linkedImages = imagesByPost[post.id];
      final images = post.images.isNotEmpty ? post.images : (linkedImages ?? post.images);
      final sameAvatar = avatar == null || avatar == post.authorAvatar;
      final sameImages = identical(images, post.images);
      if (sameAvatar && sameImages) return post;
      return post.copyWith(
        authorAvatar: avatar ?? post.authorAvatar,
        images: images,
        imageCaptions: post.imageCaptions.isNotEmpty || identical(images, post.images)
            ? post.imageCaptions
            : List<String>.filled(images.length, ''),
      );
    }).toList();
  }

=======
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return filtered;
    });
  }

>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
  // Đăng bài tìm ở ghép mới
  Future<RoommatePostModel> createPost(RoommatePostModel post) async {
    final newId = post.id.isNotEmpty ? post.id : 'rm_${DateTime.now().millisecondsSinceEpoch}';
    final savedPost = post.copyWith(id: newId);
    _localCreatedPosts.removeWhere((p) => p.id == newId);
    _localCreatedPosts.insert(0, savedPost);

    try {
      await _firestore.collection('roommate_posts').doc(newId).set(savedPost.toMap());
    } catch (e) {
      debugPrint('Firestore save roommate post offline fallback: $e');
    }
    return savedPost;
  }

<<<<<<< HEAD
  /// Sửa authorId giả trên tin ở ghép. Chỉ gán khi tên người đăng trùng đúng một document users.
  void _scheduleAuthorIdRepair() {
    if (_authorRepairStarted) return;
    _authorRepairStarted = true;
    repairRoommateAuthorIds();
  }

  Future<void> repairRoommateAuthorIds() async {
    try {
      final usersSnap = await _firestore.collection('users').get();
      final userIds = <String>{};
      final nameToIds = <String, Set<String>>{};
      for (final doc in usersSnap.docs) {
        userIds.add(doc.id);
        final data = doc.data();
        for (final key in ['displayName', 'hoTen', 'hoten']) {
          final name = _normName('${data[key] ?? ''}');
          if (name.isEmpty) continue;
          nameToIds.putIfAbsent(name, () => <String>{}).add(doc.id);
        }
      }

      final postsSnap = await _firestore.collection('roommate_posts').get();
      for (final doc in postsSnap.docs) {
        final data = doc.data();
        final authorId = '${data['authorId'] ?? data['nguoiDangId'] ?? ''}'.trim();
        if (authorId.isNotEmpty && userIds.contains(authorId)) continue;
        final name = _normName('${data['authorName'] ?? data['hoTen'] ?? data['tenNguoiDang'] ?? ''}');
        final matches = nameToIds[name];
        if (matches == null || matches.length != 1) continue;
        final uid = matches.first;
        await doc.reference.update({'authorId': uid, 'nguoiDangId': uid});
      }
    } catch (e) {
      debugPrint('repair roommate authorId: $e');
    }
  }

  String _normName(String raw) => raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Khớp thói quen khi bài ghi cách viết khác bộ lọc, ví dụ "Sạch sẽ ngăn nắp" với "Sạch sẽ, ngăn nắp cao".
  bool _habitHit(String selected, List<String> postHabits) {
    final needle = _habitKey(selected);
    if (needle.isEmpty) return true;
    for (final raw in postHabits) {
      final hay = _habitKey(raw);
      if (hay.isEmpty) continue;
      if (hay == needle || hay.contains(needle) || needle.contains(hay)) return true;
      if (_sameHabitFamily(needle, hay)) return true;
    }
    return false;
  }

  String _habitKey(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[,./()]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _sameHabitFamily(String a, String b) {
    const groups = <List<String>>[
      ['thuốc', 'hút thuốc'],
      ['sạch sẽ', 'ngăn nắp'],
      ['yên tĩnh'],
      ['giờ giấc tự do'],
    ];
    for (final group in groups) {
      if (group.any(a.contains) && group.any(b.contains)) return true;
    }
    return false;
  }

  /// Vài bài cố định để thử tìm kiếm. Hai bài ở TP.HCM mỗi phía, một bài tỉnh khác để không ra hết.
  static List<RoommatePostModel> getDemoRoommatePosts() {
    final now = DateTime.now();
    return [
      RoommatePostModel(
        id: 'demo_has_room_lan',
        authorId: 'demo_lan_anh',
        authorName: 'Lan Anh',
        authorAge: 21,
        authorGender: 'Nữ',
        authorOccupation: 'Sinh viên',
        title: 'Cần một bạn nữ ghép căn hộ Linh Trung',
        description: 'Đã thuê căn 2 phòng ngủ ở Linh Trung, còn một chỗ. Mình học buổi sáng, về sớm.',
=======
  // Danh sách bài đăng mẫu chuẩn 100% Figma HomeShare
  static List<RoommatePostModel> getFigmaSamplePosts() {
    return [
      RoommatePostModel(
        id: 'figma_post_1',
        authorId: 'user_minh_trang',
        authorName: 'Minh Trang',
        authorAge: 21,
        authorGender: 'Nữ',
        authorOccupation: 'SV Đại học Ngoại Thương CS2',
        authorAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
        title: 'Cần tìm 1 bạn nữ ở ghép căn hộ Sunview Town (Đã có phòng)',
        description: 'Căn hộ 2PN2WC tại chung cư Sunview Town, lầu 12 thoáng mát. Đã trang bị đầy đủ máy giặt, tủ lạnh, bếp từ, máy nước nóng. Tìm 1 bạn nữ gọn gàng, tính tình vui vẻ, hòa đồng cùng share phòng.',
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
        postType: 'timNguoiOGhep',
        pricePerPerson: 1800000,
        budgetMin: 1500000,
        budgetMax: 2000000,
<<<<<<< HEAD
        address: 'Số 20 Đường Số 1, Phường Linh Trung, Thành phố Thủ Đức, TP. Hồ Chí Minh',
        latitude: 10.8696,
        longitude: 106.7782,
        district: 'Thành phố Thủ Đức',
        targetGender: 'Nữ',
        habits: ['Sạch sẽ, ngăn nắp cao', 'Yên tĩnh sau 23h'],
        hasRoom: true,
        contactPhone: '0901000001',
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      RoommatePostModel(
        id: 'demo_has_room_khoa',
        authorId: 'demo_minh_khoa',
        authorName: 'Minh Khoa',
        authorAge: 24,
        authorGender: 'Nam',
        authorOccupation: 'Người đi làm',
        title: 'Ghép phòng Bình Thạnh, đã có nhà',
        description: 'Phòng đã thuê gần chợ Bà Chiểu, tìm một bạn nam đi làm giờ hành chính.',
        postType: 'timNguoiOGhep',
        pricePerPerson: 2800000,
        budgetMin: 2500000,
        budgetMax: 3000000,
        address: '88 Đường D2, Phường 25, Quận Bình Thạnh, TP. Hồ Chí Minh',
        latitude: 10.8036,
        longitude: 106.7302,
        district: 'Quận Bình Thạnh',
        targetGender: 'Nam',
        habits: ['Giờ giấc tự do', 'Có xe máy riêng'],
        hasRoom: true,
        contactPhone: '0901000002',
        createdAt: now.subtract(const Duration(hours: 8)),
      ),
      RoommatePostModel(
        id: 'demo_has_room_hamy',
        authorId: 'demo_ha_my',
        authorName: 'Hà My',
        authorAge: 22,
        authorGender: 'Nữ',
        authorOccupation: 'Sinh viên',
        title: 'Tìm bạn nữ ghép phòng Cầu Giấy',
        description: 'Phòng ở Cầu Giấy đã có, chỉ nhận bạn nữ.',
        postType: 'timNguoiOGhep',
        pricePerPerson: 2500000,
        budgetMin: 2000000,
        budgetMax: 3000000,
        address: '18 Trần Thái Tông, Phường Dịch Vọng, Cầu Giấy, Hà Nội',
        latitude: 21.0360,
        longitude: 105.7895,
        district: 'Cầu Giấy',
        targetGender: 'Nữ',
        habits: ['Chăm học/Làm việc'],
        hasRoom: true,
        contactPhone: '0901000003',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      RoommatePostModel(
        id: 'demo_need_room_phuong',
        authorId: 'demo_phuong_anh',
        authorName: 'Phương Anh',
        authorAge: 20,
        authorGender: 'Nữ',
        authorOccupation: 'Sinh viên',
        title: 'Tìm bạn nữ cùng thuê phòng Quận 7',
        description: 'Mình chưa có phòng, muốn kiếm một bạn nữ cùng xem phòng quanh Quận 7.',
        postType: 'dangTimPhong',
        pricePerPerson: 1600000,
        budgetMin: 1400000,
        budgetMax: 1800000,
        address: '88 Nguyễn Thị Thập, Phường Tân Phong, Quận 7, TP. Hồ Chí Minh',
        latitude: 10.7312,
        longitude: 106.7204,
        district: 'Quận 7',
        targetGender: 'Nữ',
        habits: ['Nấu ăn thường xuyên', 'Sạch sẽ, ngăn nắp cao'],
        hasRoom: false,
        contactPhone: '0901000004',
        createdAt: now.subtract(const Duration(hours: 6)),
      ),
      RoommatePostModel(
        id: 'demo_need_room_duc',
        authorId: 'demo_duc_anh',
        authorName: 'Đức Anh',
        authorAge: 25,
        authorGender: 'Nam',
        authorOccupation: 'Freelancer',
        title: 'Cần bạn nam cùng tìm phòng Gò Vấp',
        description: 'Làm việc ở nhà, chưa thuê phòng, muốn tìm một bạn nam cùng gu ở Gò Vấp.',
        postType: 'dangTimPhong',
        pricePerPerson: 2600000,
        budgetMin: 2400000,
        budgetMax: 2800000,
        address: '102 Quang Trung, Phường 16, Quận Gò Vấp, TP. Hồ Chí Minh',
        latitude: 10.8380,
        longitude: 106.6648,
        district: 'Quận Gò Vấp',
        targetGender: 'Nam',
        habits: ['Tuyệt đối không thuốc lá'],
        hasRoom: false,
        contactPhone: '0901000005',
        createdAt: now.subtract(const Duration(hours: 10)),
      ),
      RoommatePostModel(
        id: 'demo_need_room_viet',
        authorId: 'demo_quoc_viet',
        authorName: 'Quốc Việt',
        authorAge: 23,
        authorGender: 'Nam',
        authorOccupation: 'Người đi làm',
        title: 'Tìm bạn cùng thuê phòng Hải Châu',
        description: 'Mình ở Đà Nẵng, chưa có phòng, tìm một bạn nam cùng thuê.',
        postType: 'dangTimPhong',
        pricePerPerson: 1500000,
        budgetMin: 1200000,
        budgetMax: 1800000,
        address: '36 Bạch Đằng, Phường Hải Châu, Hải Châu, Đà Nẵng',
        latitude: 16.0715,
        longitude: 108.2238,
        district: 'Hải Châu',
        targetGender: 'Nam',
        habits: ['Giờ giấc tự do'],
        hasRoom: false,
        contactPhone: '0901000006',
        createdAt: now.subtract(const Duration(days: 3)),
=======
        address: 'Hiệp Bình Phước, TP. Thủ Đức (Gần cầu Bình Triệu)',
        district: 'TP. Thủ Đức',
        targetGender: 'Nữ',
        habits: ['Tuyệt đối không thuốc lá', 'Yên tĩnh sau 23h', 'Sạch sẽ, ngăn nắp cao', 'Thân thiện vui vẻ', 'Quy định dẫn bạn về phòng'],
        images: [
          'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=600',
          'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=600',
        ],
        imageCaptions: ['Phòng ngủ máy lạnh', 'Bếp chung rộng'],
        isVerified: true,
        matchRate: 94,
        hasRoom: true,
        contactPhone: '0981234567',
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      RoommatePostModel(
        id: 'figma_post_2',
        authorId: 'user_quoc_bao',
        authorName: 'Quốc Bảo',
        authorAge: 22,
        authorGender: 'Nam',
        authorOccupation: 'Kỹ sư phần mềm mới ra trường',
        authorAvatar: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=400',
        title: 'Cần tìm 1 bạn nam ghép phòng trọ D2 Bình Thạnh (Đã có phòng)',
        description: 'Phòng trọ rộng 28m2 gác lửng, giờ giấc tự do không chung chủ, có chỗ để xe an toàn. Cần 1 bạn nam làm việc văn phòng hoặc sinh viên năm cuối cùng chia tiền phòng.',
        postType: 'timNguoiOGhep',
        pricePerPerson: 2200000,
        budgetMin: 2000000,
        budgetMax: 2500000,
        address: 'Đường Nguyễn Gia Trí, P.25, Bình Thạnh',
        district: 'Bình Thạnh',
        targetGender: 'Nam',
        habits: ['Giờ giấc tự do 24/7', 'Có xe máy riêng', 'Thích thể thao', 'Không tụ tập ồn ào'],
        images: [
          'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=600',
        ],
        imageCaptions: ['Phòng trọ gác lửng'],
        isVerified: true,
        matchRate: 88,
        hasRoom: true,
        contactPhone: '0912987654',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      RoommatePostModel(
        id: 'figma_post_3',
        authorId: 'user_thuy_dung',
        authorName: 'Thùy Dung',
        authorAge: 20,
        authorGender: 'Nữ',
        authorOccupation: 'SV ĐH Sư Phạm Kỹ Thuật (HCMUT)',
        authorAvatar: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400',
        title: 'Muốn tìm 1 bạn nữ tính tình hòa đồng cùng tìm & thuê phòng quanh ĐH Sư...',
        description: 'Mình là sinh viên năm 2 ĐH Sư Phạm Kỹ Thuật, muốn tìm 1 bạn nữ cùng gu để cùng đi tìm và thuê phòng trọ bán kính 2km quanh ngã tư Thủ Đức. Ngân sách tầm 1.5 - 2 triệu/tháng.',
        postType: 'dangTimPhong',
        pricePerPerson: 1750000,
        budgetMin: 1500000,
        budgetMax: 2000000,
        address: 'Bán kính 2km quanh ngã tư Thủ Đức',
        district: 'TP. Thủ Đức',
        targetGender: 'Nữ',
        habits: ['Chăm học, ít ồn', 'Nấu ăn tại phòng', 'Dậy sớm (Trước 7h)', 'Sạch sẽ, ngăn nắp cao'],
        images: [],
        imageCaptions: [],
        isVerified: true,
        matchRate: 91,
        hasRoom: false,
        contactPhone: '0903456789',
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      RoommatePostModel(
        id: 'figma_post_4',
        authorId: 'user_huy_hoang',
        authorName: 'Huy Hoàng',
        authorAge: 23,
        authorGender: 'Nam',
        authorOccupation: 'Freelancer / WFH',
        authorAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400',
        title: 'Tìm bạn cùng thuê căn hộ dịch vụ Quận 1 hoặc Bình Thạnh',
        description: 'Làm việc tự do tại nhà, cần không gian làm việc yên tĩnh, có ban công thoáng mát và tôn trọng sự riêng tư của nhau.',
        postType: 'dangTimPhong',
        pricePerPerson: 3000000,
        budgetMin: 2500000,
        budgetMax: 3500000,
        address: 'Khu vực Đa Kao, Quận 1',
        district: 'Quận 1',
        targetGender: 'Nam',
        habits: ['Yên tĩnh sau 23h', 'Tuyệt đối không thuốc lá', 'Thú cưng (Chó/Mèo)', 'Không mở loa to'],
        images: [],
        imageCaptions: [],
        isVerified: true,
        matchRate: 85,
        hasRoom: false,
        contactPhone: '0938112233',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
      ),
    ];
  }

  // Vô hiệu hóa nạp bài đăng mẫu theo yêu cầu người dùng
  Future<void> seedInitialRoommatesIfEmpty() async {
    // Không nạp dữ liệu mẫu
  }

<<<<<<< HEAD
  // Bảo toàn bài đăng mẫu để người dùng luôn thấy bài đăng
  Future<void> deleteSampleRoommatePosts() async {
    // Không xóa bài mẫu để tránh màn hình trống
=======
  // Xóa toàn bộ bài đăng mẫu khỏi Cloud Firestore
  Future<void> deleteSampleRoommatePosts() async {
    try {
      final sampleAuthorIds = [
        'user_minh_trang',
        'user_quoc_bao',
        'user_thuy_dung',
        'user_huy_hoang',
      ];
      for (final authorId in sampleAuthorIds) {
        final snap = await _firestore
            .collection('roommate_posts')
            .where('authorId', isEqualTo: authorId)
            .get();
        for (final doc in snap.docs) {
          await doc.reference.delete();
        }
      }
    } catch (e) {
      debugPrint('Error deleting sample roommate posts: $e');
    }
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
  }
}

final roommateServiceProvider = Provider<RoommateService>((ref) => RoommateService());

<<<<<<< HEAD
/// Bài đăng thuộc tỉnh đã chọn khi địa chỉ hoặc quận trùng tỉnh, hoặc trùng một quận của tỉnh đó.
bool _postMatchesProvince(RoommatePostModel post, String province) {
  if (_placeHit(post.address, province) || _placeHit(post.district, province)) return true;
  for (final district in VietnamLocations.getAdministrativeDistricts(province)) {
    if (_placeHit(post.district, district) || _placeHit(post.address, district)) return true;
  }
  return false;
}

/// Khớp tên địa danh, kể cả khi một bên có tiền tố Quận/Phường. "Quận 1" không ăn "Quận 10".
bool _placeHit(String haystack, String needle) {
  final h = haystack.toLowerCase();
  final n = needle.toLowerCase().trim();
  if (n.length < 2 || h.isEmpty) return false;
  if (_boundedContains(h, n)) return true;
  final core = n
      .replaceAll('quận ', '')
      .replaceAll('huyện ', '')
      .replaceAll('thị xã ', '')
      .replaceAll('thành phố ', '')
      .replaceAll('tp. ', '')
      .replaceAll('phường ', '')
      .replaceAll('xã ', '')
      .trim();
  if (core.length < 2 || core == n) return false;
  return _boundedContains(h, core);
}

bool _boundedContains(String haystack, String needle) {
  var start = 0;
  while (true) {
    final index = haystack.indexOf(needle, start);
    if (index < 0) return false;
    final end = index + needle.length;
    final prevOk = index == 0 || !_isDigit(haystack[index - 1]);
    final nextOk = end >= haystack.length || !_isDigit(haystack[end]);
    if (prevOk && nextOk) return true;
    start = index + 1;
  }
}

bool _isDigit(String char) {
  final code = char.codeUnitAt(0);
  return code >= 48 && code <= 57;
}

=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
class RoommatePostsRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() => state++;
}

final roommatePostsRefreshTrigger = NotifierProvider<RoommatePostsRefreshNotifier, int>(RoommatePostsRefreshNotifier.new);

final roommatePostsStreamProvider = StreamProvider.autoDispose.family<List<RoommatePostModel>, RoommateFilterParams>((ref, filters) {
  ref.watch(roommatePostsRefreshTrigger);
  final service = ref.watch(roommateServiceProvider);
<<<<<<< HEAD
  final viewerId = ref.watch(currentUserProvider)?.uid;
  return service.getRoommatePostsStream(
    filters: filters,
    viewerId: viewerId,
=======
  return service.getRoommatePostsStream(
    filters: filters,
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
  );
});
