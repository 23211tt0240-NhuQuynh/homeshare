import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/utils/roommate_capacity_policy.dart';
import 'package:home_share/data/models/roommate_post_model.dart';
import 'package:home_share/features/chat/services/roommate_invitation_policy.dart';

RoommatePostModel _post({
  required String id,
  required DateTime createdAt,
  int capacity = 2,
  bool hasRoom = true,
  String status = 'dangMo',
}) {
  return RoommatePostModel(
    id: id,
    authorId: 'author1',
    authorName: 'Toàn',
    authorAge: 22,
    authorGender: 'Nam',
    authorOccupation: 'Sinh viên',
    title: 'Tìm bạn ở ghép',
    description: 'Phòng đang ở',
    budgetMin: 1500000,
    budgetMax: 2000000,
    district: 'TP. Thủ Đức',
    targetGender: 'Nam',
    habits: const [],
    hasRoom: hasRoom,
    status: status,
    contactPhone: '0901000000',
    capacity: capacity,
    createdAt: createdAt,
  );
}

void main() {
  group('RoommateCapacityPolicy', () {
    test('sức chứa 2 và đã có 2 người thì đủ chỗ', () {
      expect(
        RoommateCapacityPolicy.isFull(occupantCount: 2, capacity: 2),
        isTrue,
      );
    });

    test('sức chứa 3 và mới có 2 người thì vẫn còn chỗ', () {
      expect(
        RoommateCapacityPolicy.isFull(occupantCount: 2, capacity: 3),
        isFalse,
      );
    });

    test('sức chứa 3 và đã có 3 người thì đủ chỗ', () {
      expect(
        RoommateCapacityPolicy.isFull(occupantCount: 3, capacity: 3),
        isTrue,
      );
    });

    test('thiếu sức chứa thì không đóng tin', () {
      expect(
        RoommateCapacityPolicy.isFull(occupantCount: 2, capacity: 0),
        isFalse,
      );
    });

    test('ưu tiên sức chứa trên bài đăng, không lấy phòng nếu bài đã có số', () {
      expect(
        RoommateCapacityPolicy.resolveCapacity(postCapacity: 3, roomCapacity: 2),
        3,
      );
      expect(
        RoommateCapacityPolicy.resolveCapacity(postCapacity: 0, roomCapacity: 2),
        2,
      );
    });

    test('đăng 2 bài liên tiếp thì lấy bài mới nhất', () {
      final latest = RoommateCapacityPolicy.latestHasRoomPost([
        _post(id: 'old', createdAt: DateTime(2026, 10, 1), capacity: 2),
        _post(id: 'new', createdAt: DateTime(2026, 10, 27), capacity: 3),
      ]);
      expect(latest?.id, 'new');
      expect(latest?.capacity, 3);
    });

    test('khi đủ chỗ thì đóng mọi tin đã có phòng còn mở', () {
      final open = RoommateCapacityPolicy.openHasRoomPosts([
        _post(id: 'open1', createdAt: DateTime(2026, 10, 1)),
        _post(
          id: 'closed',
          createdAt: DateTime(2026, 10, 2),
          status: 'daDong',
        ),
        _post(
          id: 'looking',
          createdAt: DateTime(2026, 10, 3),
          hasRoom: false,
        ),
      ]);
      expect(open.map((post) => post.id), ['open1']);
    });

    test('tin daDong bị coi là đã ẩn', () {
      expect(_post(id: 'a', createdAt: DateTime(2026, 10, 1)).isOpen, isTrue);
      expect(
        _post(
          id: 'b',
          createdAt: DateTime(2026, 10, 1),
          status: 'daDong',
        ).isClosed,
        isTrue,
      );
    });
  });

  test('lời mời chat bị chặn khi phòng đã đủ sức chứa', () {
    expect(
      RoommateInvitationPolicy.canInvite(
        senderRole: 'renter',
        receiverRole: 'renter',
        hasActiveRoom: true,
        roomHasFreeCapacity: false,
      ),
      isFalse,
    );
    expect(
      RoommateInvitationPolicy.canInvite(
        senderRole: 'renter',
        receiverRole: 'renter',
        hasActiveRoom: true,
        roomHasFreeCapacity: true,
      ),
      isTrue,
    );
  });
}
