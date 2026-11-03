import '../../data/models/roommate_post_model.dart';

/// Sức chứa bài ở ghép tab "Đã có phòng": căn bài mới nhất, đủ người thì đóng tin.
abstract final class RoommateCapacityPolicy {
  static const closedStatus = 'daDong';
  static const openStatus = 'dangMo';

  static String normalizeStatus(String status) {
    return status.toLowerCase().trim().replaceAll(RegExp(r'[\s_-]+'), '');
  }

  static bool isOpenStatus(String status) {
    final normalized = normalizeStatus(status);
    return normalized != 'dadong' &&
        normalized != 'closed' &&
        normalized != 'hidden' &&
        normalized != 'inactive';
  }

  static bool isFull({
    required int occupantCount,
    required int capacity,
  }) {
    if (capacity <= 0 || occupantCount <= 0) return false;
    return occupantCount >= capacity;
  }

  static int resolveCapacity({
    int postCapacity = 0,
    int roomCapacity = 0,
  }) {
    if (postCapacity > 0) return postCapacity;
    if (roomCapacity > 0) return roomCapacity;
    return 0;
  }

  /// Bài tab "Đã có phòng" mới nhất — nếu đăng 2 tin liên tiếp thì lấy tin sau.
  static RoommatePostModel? latestHasRoomPost(Iterable<RoommatePostModel> posts) {
    final hasRoom = posts.where((post) => post.hasRoom).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (hasRoom.isEmpty) return null;
    return hasRoom.first;
  }

  static List<RoommatePostModel> openHasRoomPosts(
    Iterable<RoommatePostModel> posts,
  ) {
    return posts
        .where((post) => post.hasRoom && isOpenStatus(post.status))
        .toList();
  }
}
