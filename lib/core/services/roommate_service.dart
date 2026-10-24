import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/roommate_post_model.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../constants/vietnam_locations.dart';
import '../utils/vietnamese_utils.dart';
import 'image_storage_service.dart';
import 'user_profile_service.dart';

class RoommateFilterParams {
  final String province;
  final String district;
  final String ward;
  final String targetGender;
  final bool?
  hasRoom; // null: Tất cả, true: Đã có phòng sẵn, false: Chưa có phòng
  final String occupation; // 'Tất cả', hoặc một nghề khi chỉ chọn một mục
  final List<String> occupations;
  final double? budgetMin;
  final double? budgetMax;
  final List<String> habits;
  final int minMatchRate;
  final String searchQuery;

  const RoommateFilterParams({
    this.province = 'Tất cả',
    this.district = 'Tất cả',
    this.ward = 'Tất cả',
    this.targetGender = 'Tất cả',
    this.hasRoom,
    this.occupation = 'Tất cả',
    this.occupations = const [],
    this.budgetMin,
    this.budgetMax,
    this.habits = const [],
    this.minMatchRate = 0,
    this.searchQuery = '',
  });

  RoommateFilterParams copyWith({
    String? province,
    String? district,
    String? ward,
    String? targetGender,
    bool? hasRoom,
    bool clearHasRoom = false,
    String? occupation,
    List<String>? occupations,
    double? budgetMin,
    double? budgetMax,
    bool clearBudget = false,
    List<String>? habits,
    int? minMatchRate,
    String? searchQuery,
  }) {
    return RoommateFilterParams(
      province: province ?? this.province,
      district: district ?? this.district,
      ward: ward ?? this.ward,
      targetGender: targetGender ?? this.targetGender,
      hasRoom: clearHasRoom ? null : (hasRoom ?? this.hasRoom),
      occupation: occupation ?? this.occupation,
      occupations: occupations ?? this.occupations,
      budgetMin: clearBudget ? null : (budgetMin ?? this.budgetMin),
      budgetMax: clearBudget ? null : (budgetMax ?? this.budgetMax),
      habits: habits ?? this.habits,
      minMatchRate: minMatchRate ?? this.minMatchRate,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoommateFilterParams &&
          province == other.province &&
          district == other.district &&
          ward == other.ward &&
          targetGender == other.targetGender &&
          hasRoom == other.hasRoom &&
          occupation == other.occupation &&
          listEquals(occupations, other.occupations) &&
          budgetMin == other.budgetMin &&
          budgetMax == other.budgetMax &&
          listEquals(habits, other.habits) &&
          minMatchRate == other.minMatchRate &&
          searchQuery == other.searchQuery;

  @override
  int get hashCode => Object.hash(
    province,
    district,
    ward,
    targetGender,
    hasRoom,
    occupation,
    Object.hashAll(occupations),
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
  static bool _authorRepairStarted = false;

  // Stream bài đăng tìm ở ghép (an toàn bộ lọc, in-memory filter & sort)
  Stream<List<RoommatePostModel>> getRoommatePostsStream({
    String? district,
    String? targetGender,
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
    final budgetMin = filters?.budgetMin;
    final budgetMax = filters?.budgetMax;
    final habits = filters?.habits ?? const [];
    final minMatchRate = filters?.minMatchRate ?? 0;
    final searchQuery = filters?.searchQuery.trim().toLowerCase() ?? '';
    _scheduleAuthorIdRepair();

    return _firestore
        .collection('roommate_posts')
        .snapshots()
        .handleError((err) {
          debugPrint('Firestore stream error, fallback to local: $err');
          return const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        })
        .asyncMap((snapshot) async {
          List<RoommatePostModel> list;
          if (snapshot.docs.isNotEmpty) {
            list = snapshot.docs
                .map((doc) {
                  try {
                    return RoommatePostModel.fromFirestore(doc);
                  } catch (e) {
                    debugPrint('Error parsing roommate post ${doc.id}: $e');
                    return null;
                  }
                })
                .whereType<RoommatePostModel>()
                .toList();
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

          // Bỏ các bài mẫu cũ. Bài thật, gồm bài mới nhất của Trần Thanh Anh Toàn, vẫn giữ.
          const obsoleteSampleIds = {
            'figma_post_1',
            'figma_post_2',
            'figma_post_3',
            'figma_post_4',
            'demo_has_room_lan',
            'demo_has_room_khoa',
            'demo_has_room_hamy',
          };
          merged.removeWhere((post) => obsoleteSampleIds.contains(post.id));
          for (final demo in getDemoRoommatePosts()) {
            if (!merged.any((post) => post.id == demo.id)) {
              merged.add(demo);
            }
          }

          final hydrated = await _withLiveAuthorAndImages(merged);
          final mine = viewerId == null || viewerId.isEmpty
              ? const <RoommatePostModel>[]
              : hydrated.where((post) => post.authorId == viewerId).toList();

          final filtered = hydrated.where((post) {
            // 1. Tình trạng phòng (Đã có phòng / Chưa có phòng)
            if (hasRoom != null && post.hasRoom != hasRoom) {
              return false;
            }

            // 2. Tìm kiếm theo từ khóa (trường học, quận, tiêu đề, tên)
            if (searchQuery.isNotEmpty) {
              final matchTitle = post.title.toLowerCase().contains(searchQuery);
              final matchAddress = post.address.toLowerCase().contains(
                searchQuery,
              );
              final matchDistrict = post.district.toLowerCase().contains(
                searchQuery,
              );
              final matchAuthor = post.authorName.toLowerCase().contains(
                searchQuery,
              );
              final matchOcc = post.authorOccupation.toLowerCase().contains(
                searchQuery,
              );
              if (!matchTitle &&
                  !matchAddress &&
                  !matchDistrict &&
                  !matchAuthor &&
                  !matchOcc) {
                return false;
              }
            }

            // Người thuê - Lọc địa chỉ - Luồng đi: Lọc tỉnh/thành và cấp xã; district chỉ hỗ trợ lời gọi cũ.
            if (effectiveProvince.isNotEmpty && effectiveProvince != 'Tất cả') {
              if (!_postMatchesProvince(post, effectiveProvince)) return false;
            }
            if (effectiveDistrict != null &&
                effectiveDistrict.isNotEmpty &&
                effectiveDistrict != 'Tất cả') {
              if (!_placeHit(post.district, effectiveDistrict) &&
                  !_placeHit(post.address, effectiveDistrict)) {
                return false;
              }
            }
            if (effectiveWard.isNotEmpty && effectiveWard != 'Tất cả') {
              if (!_placeHit(post.address, effectiveWard) &&
                  !_placeHit(post.district, effectiveWard)) {
                return false;
              }
            }

            // 4. Giới tính
            if (effectiveTargetGender != null &&
                effectiveTargetGender.isNotEmpty &&
                effectiveTargetGender != 'Tất cả') {
              if (effectiveTargetGender == 'LGBT+') {
                final isLgbt =
                    post.targetGender.toLowerCase().contains('lgbt') ||
                    post.habits.any((h) => h.toLowerCase().contains('lgbt'));
                if (!isLgbt && post.targetGender != 'Tất cả') return false;
              } else {
                final wanted = effectiveTargetGender.trim();
                final target = post.targetGender.trim();
                final author = post.authorGender.trim();
                final seeksWanted =
                    target == 'Tất cả' || target == 'tatCa' || target == wanted;
                final authorIsWanted = author == wanted;
                if (!seeksWanted && !authorIsWanted) return false;
              }
            }

            // 5. Nghề nghiệp: khớp nếu nghề của người đăng chứa một mục đã chọn
            final selectedOccupations = <String>{
              ...occupations.where(
                (item) => item.trim().isNotEmpty && item != 'Tất cả',
              ),
              if (occupation != null &&
                  occupation.isNotEmpty &&
                  occupation != 'Tất cả')
                occupation,
            };
            if (selectedOccupations.isNotEmpty) {
              final authorJob = post.authorOccupation.toLowerCase();
              final matched = selectedOccupations.any(
                (item) => authorJob.contains(item.toLowerCase()),
              );
              if (!matched) return false;
            }

            // 6. Ngân sách
            if (budgetMin != null && budgetMax != null) {
              final price = post.pricePerPerson > 0
                  ? post.pricePerPerson
                  : post.budgetMax;
              if (price < budgetMin || price > budgetMax) {
                return false;
              }
            }

            // 7. Mỗi thói quen đã chọn phải có ý tương đương trên bài, không cần trùng từng chữ.
            if (habits.isNotEmpty &&
                !habits.every((item) => _habitHit(item, post.habits))) {
              return false;
            }

            return true;
          }).toList();

          return _rankByViewerHobbies(
            filtered,
            viewerId: viewerId,
            minMatchRate: minMatchRate,
            viewerHasRoom: mine.any((post) => post.hasRoom),
            viewerNeedsRoom: mine.any((post) => !post.hasRoom),
            viewerPostHabits: _uniqueHabits(mine),
          );
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

  /// Chỉ so sở thích khi một bên đã có phòng và bên kia đang tìm phòng.
  bool _isOppositeRoom({
    required RoommatePostModel post,
    required String? viewerId,
    required bool viewerHasRoom,
    required bool viewerNeedsRoom,
  }) {
    if (viewerId == null || viewerId.isEmpty || post.authorId == viewerId)
      return false;
    if (post.hasRoom && viewerNeedsRoom) return true;
    if (!post.hasRoom && viewerHasRoom) return true;
    return false;
  }

  List<String> _uniqueHabits(List<RoommatePostModel> posts) {
    final names = <String>[];
    for (final post in posts) {
      for (final habit in post.habits) {
        final name = habit.trim();
        if (name.isEmpty) continue;
        if (names.any((item) => item.toLowerCase() == name.toLowerCase()))
          continue;
        names.add(name);
      }
    }
    return names;
  }

  Future<List<RoommatePostModel>> _rankByViewerHobbies(
    List<RoommatePostModel> posts, {
    required String? viewerId,
    required int minMatchRate,
    required bool viewerHasRoom,
    required bool viewerNeedsRoom,
    required List<String> viewerPostHabits,
  }) async {
    final profileHobbies = viewerId == null || viewerId.isEmpty
        ? const <String>[]
        : await _hobbyNamesOf(viewerId);
    final viewerHobbies = profileHobbies.isNotEmpty
        ? profileHobbies
        : viewerPostHabits;
    if (viewerHobbies.isEmpty) {
      final plain = posts.map((post) => post.copyWith(matchRate: -1)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return plain;
    }

    final opposite = posts.where(
      (post) => _isOppositeRoom(
        post: post,
        viewerId: viewerId,
        viewerHasRoom: viewerHasRoom,
        viewerNeedsRoom: viewerNeedsRoom,
      ),
    );
    final authorIds = opposite
        .map((post) => post.authorId)
        .where((id) => id.isNotEmpty)
        .toSet();
    final authorHobbies = await _hobbyNamesByUser(authorIds);
    final ranked = <RoommatePostModel>[];
    for (final post in posts) {
      if (!_isOppositeRoom(
        post: post,
        viewerId: viewerId,
        viewerHasRoom: viewerHasRoom,
        viewerNeedsRoom: viewerNeedsRoom,
      )) {
        ranked.add(post.copyWith(matchRate: -1));
        continue;
      }
      final candidate = <String>[
        ...post.habits,
        ...authorHobbies[post.authorId] ?? const <String>[],
      ];
      final percent =
          hobbyMatchPercent(
            viewerHobbies: viewerHobbies,
            candidateHabits: candidate,
          ) ??
          0;
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
    try {
      return UserProfileService().loadInterestNamesForUsers(uids);
    } catch (e) {
      debugPrint('Đọc sở thích người đăng: $e');
      return {};
    }
  }

  /// Avatar trên bài lấy ảnh hiện tại của người đăng.
  /// Ảnh bài của project kia nằm ở roommate_post_images, không nằm trên document bài.
  Future<List<RoommatePostModel>> _withLiveAuthorAndImages(
    List<RoommatePostModel> posts,
  ) async {
    final real = posts
        .where(
          (post) =>
              !post.id.startsWith('demo_') && !post.id.startsWith('figma_'),
        )
        .toList();
    if (real.isEmpty) return posts;

    final avatars = <String, String>{};
    for (final authorId
        in real
            .map((post) => post.authorId)
            .where((id) => id.isNotEmpty)
            .toSet()) {
      try {
        final stored = await ImageStorageService().avatarDownloadUrl(authorId);
        if (stored != null) {
          avatars[authorId] = stored;
          continue;
        }
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
    final needImages = real
        .where((post) => post.images.isEmpty)
        .map((post) => post.id)
        .toList();
    for (var start = 0; start < needImages.length; start += 10) {
      final end = start + 10 > needImages.length
          ? needImages.length
          : start + 10;
      final chunk = needImages.sublist(start, end);
      try {
        final snap = await _firestore
            .collection('roommate_post_images')
            .where('postId', whereIn: chunk)
            .get();
        final grouped =
            <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
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
              .map(
                (doc) =>
                    '${doc.data()['imageUrl'] ?? doc.data()['duongDan'] ?? ''}'
                        .trim(),
              )
              .where((url) => url.isNotEmpty)
              .toList();
        }
      } catch (e) {
        debugPrint('Đọc ảnh bài ở ghép: $e');
      }
    }

    return posts.map((post) {
      if (post.id.startsWith('demo_') || post.id.startsWith('figma_'))
        return post;
      final avatar = avatars[post.authorId];
      final linkedImages = imagesByPost[post.id];
      final images = post.images.isNotEmpty
          ? post.images
          : (linkedImages ?? post.images);
      final sameAvatar = avatar == null || avatar == post.authorAvatar;
      final sameImages = identical(images, post.images);
      if (sameAvatar && sameImages) return post;
      return post.copyWith(
        authorAvatar: avatar ?? post.authorAvatar,
        images: images,
        imageCaptions:
            post.imageCaptions.isNotEmpty || identical(images, post.images)
            ? post.imageCaptions
            : List<String>.filled(images.length, ''),
      );
    }).toList();
  }

  /// Đọc một bài ở ghép theo id, kèm ảnh trong roommate_post_images nếu bài không lưu mảng ảnh.
  Future<RoommatePostModel?> loadPost(String postId) async {
    final id = postId.trim();
    if (id.isEmpty) return null;
    final doc = await _firestore.collection('roommate_posts').doc(id).get();
    if (!doc.exists) return null;
    final filled = await _withLiveAuthorAndImages([
      RoommatePostModel.fromFirestore(doc),
    ]);
    return filled.isEmpty ? null : filled.first;
  }

  // Đăng bài tìm ở ghép mới
  Future<RoommatePostModel> createPost(RoommatePostModel post) async {
    final newId = post.id.isNotEmpty
        ? post.id
        : 'rm_${DateTime.now().millisecondsSinceEpoch}';
    final savedPost = post.copyWith(id: newId);
    _localCreatedPosts.removeWhere((p) => p.id == newId);
    _localCreatedPosts.insert(0, savedPost);

    try {
      await _firestore
          .collection('roommate_posts')
          .doc(newId)
          .set(savedPost.toMap());
    } catch (e) {
      debugPrint('Firestore save roommate post offline fallback: $e');
    }
    return savedPost;
  }

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
        final authorId = '${data['authorId'] ?? data['nguoiDangId'] ?? ''}'
            .trim();
        if (authorId.isNotEmpty && userIds.contains(authorId)) continue;
        final name = _normName(
          '${data['authorName'] ?? data['hoTen'] ?? data['tenNguoiDang'] ?? ''}',
        );
        final matches = nameToIds[name];
        if (matches == null || matches.length != 1) continue;
        final uid = matches.first;
        await doc.reference.update({'authorId': uid, 'nguoiDangId': uid});
      }
    } catch (e) {
      debugPrint('repair roommate authorId: $e');
    }
  }

  String _normName(String raw) =>
      raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Khớp thói quen khi bài ghi cách viết khác bộ lọc, ví dụ "Sạch sẽ ngăn nắp" với "Sạch sẽ, ngăn nắp cao".
  bool _habitHit(String selected, List<String> postHabits) {
    final needle = _habitKey(selected);
    if (needle.isEmpty) return true;
    for (final raw in postHabits) {
      final hay = _habitKey(raw);
      if (hay.isEmpty) continue;
      if (hay == needle || hay.contains(needle) || needle.contains(hay))
        return true;
      if (_sameHabitFamily(needle, hay)) return true;
    }
    return false;
  }

  String _habitKey(String raw) {
    return normalizeVietnameseComparison(
      raw.replaceAll(RegExp(r'[,./()]'), ' '),
    );
  }

  bool _sameHabitFamily(String a, String b) {
    const groups = <List<String>>[
      ['thuốc', 'hút thuốc'],
      ['sạch sẽ', 'ngăn nắp'],
      ['yên tĩnh'],
      ['giờ giấc tự do'],
    ];
    for (final group in groups) {
      final keys = group.map(normalizeVietnameseComparison);
      if (keys.any((key) => a.contains(key)) &&
          keys.any((key) => b.contains(key)))
        return true;
    }
    return false;
  }

  /// Bài cố định chỉ còn ở tab cần tìm phòng. Tab đã có phòng lấy bài thật trên Firebase.
  static List<RoommatePostModel> getDemoRoommatePosts() {
    final now = DateTime.now();
    return [
      RoommatePostModel(
        id: 'demo_need_room_phuong',
        authorId: 'demo_phuong_anh',
        authorName: 'Phương Anh',
        authorAge: 20,
        authorGender: 'Nữ',
        authorOccupation: 'Sinh viên',
        title: 'Tìm bạn nữ cùng thuê phòng Quận 7',
        description:
            'Mình chưa có phòng, muốn kiếm một bạn nữ cùng xem phòng quanh Quận 7.',
        postType: 'dangTimPhong',
        pricePerPerson: 1600000,
        budgetMin: 1400000,
        budgetMax: 1800000,
        address:
            '88 Nguyễn Thị Thập, Phường Tân Phong, Quận 7, TP. Hồ Chí Minh',
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
        description:
            'Làm việc ở nhà, chưa thuê phòng, muốn tìm một bạn nam cùng gu ở Gò Vấp.',
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
        description:
            'Mình ở Đà Nẵng, chưa có phòng, tìm một bạn nam cùng thuê.',
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
      ),
    ];
  }

  // Vô hiệu hóa nạp bài đăng mẫu theo yêu cầu người dùng
  Future<void> seedInitialRoommatesIfEmpty() async {
    // Không nạp dữ liệu mẫu
  }

  // Bảo toàn bài đăng mẫu để người dùng luôn thấy bài đăng
  Future<void> deleteSampleRoommatePosts() async {
    // Không xóa bài mẫu để tránh màn hình trống
  }
}

final roommateServiceProvider = Provider<RoommateService>(
  (ref) => RoommateService(),
);

/// Người thuê - Đối chiếu tỉnh/thành - Luồng đi: Tìm tên tỉnh trong địa chỉ
/// hoặc trường khu vực; nếu chưa khớp thì đối chiếu các cấp xã thuộc tỉnh đó.
bool _postMatchesProvince(RoommatePostModel post, String province) {
  if (_placeHit(post.address, province) || _placeHit(post.district, province))
    return true;
  for (final district in VietnamLocations.getWards(province)) {
    if (_placeHit(post.district, district) || _placeHit(post.address, district))
      return true;
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

class RoommatePostsRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void trigger() => state++;
}

final roommatePostsRefreshTrigger =
    NotifierProvider<RoommatePostsRefreshNotifier, int>(
      RoommatePostsRefreshNotifier.new,
    );

final roommatePostsStreamProvider = StreamProvider.autoDispose
    .family<List<RoommatePostModel>, RoommateFilterParams>((ref, filters) {
      ref.watch(roommatePostsRefreshTrigger);
      final service = ref.watch(roommateServiceProvider);
      final viewerId = ref.watch(currentUserProvider)?.uid;
      return service.getRoommatePostsStream(
        filters: filters,
        viewerId: viewerId,
      );
    });
