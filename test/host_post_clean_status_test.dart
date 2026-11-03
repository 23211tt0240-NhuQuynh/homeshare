import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/data/models/host_post_model.dart';

void main() {
  group('HostPostModel Status Clean Tests', () {
    test('PostStatus canonical values must be exactly: pending, active, rejected, hidden', () {
      expect(PostStatus.pending, 'pending');
      expect(PostStatus.active, 'active');
      expect(PostStatus.rejected, 'rejected');
      expect(PostStatus.hidden, 'hidden');
      expect(PostStatus.validStatuses, containsAll(['pending', 'active', 'rejected', 'hidden']));
      expect(PostStatus.validStatuses.length, 4);
    });

    test('PostStatus.normalize maps canonical and legacy values accurately', () {
      // Pending
      expect(PostStatus.normalize('pending'), 'pending');
      expect(PostStatus.normalize('choduyet'), 'pending');
      expect(PostStatus.normalize('cho_duyet'), 'pending');
      expect(PostStatus.normalize(''), 'pending');
      expect(PostStatus.normalize(null), 'pending');

      // Active
      expect(PostStatus.normalize('active'), 'active');
      expect(PostStatus.normalize('approved'), 'active');
      expect(PostStatus.normalize('daduyet'), 'active');
      expect(PostStatus.normalize('da_duyet'), 'active');
      expect(PostStatus.normalize('danghienthi'), 'active');
      expect(PostStatus.normalize('published'), 'active');

      // Rejected
      expect(PostStatus.normalize('rejected'), 'rejected');
      expect(PostStatus.normalize('tuchoi'), 'rejected');
      expect(PostStatus.normalize('tu_choi'), 'rejected');
      expect(PostStatus.normalize('bituchoi'), 'rejected');

      // Hidden
      expect(PostStatus.normalize('hidden'), 'hidden');
      expect(PostStatus.normalize('daan'), 'hidden');
      expect(PostStatus.normalize('da_an'), 'hidden');
      expect(PostStatus.normalize('an'), 'hidden');
      expect(PostStatus.normalize('taman'), 'hidden');
      expect(PostStatus.normalize('tam_an'), 'hidden');
    });

    test('HostPostModel constructor and toFirestore must only write status', () {
      for (final canonical in ['pending', 'active', 'rejected', 'hidden']) {
        final post = HostPostModel(
          id: 'post_$canonical',
          roomId: 'room_123',
          status: canonical,
          title: 'Phòng trọ tiện nghi',
        );

        // Verification of getters
        expect(post.status, canonical);
        expect(post.statusId, canonical);
        expect(post.trangThaiId, canonical);
        expect(post.trangThai, canonical);

        if (canonical == 'pending') expect(post.isPending, isTrue);
        if (canonical == 'active') {
          expect(post.isActive, isTrue);
          expect(post.isApprovedOrActive, isTrue);
        }
        if (canonical == 'rejected') expect(post.isRejected, isTrue);
        if (canonical == 'hidden') expect(post.isHidden, isTrue);

        // Verify toFirestore only writes status
        final firestoreMap = post.toFirestore();
        expect(firestoreMap.containsKey('status'), isTrue);
        expect(firestoreMap['status'], canonical);
        expect(firestoreMap.containsKey('statusId'), isFalse);
        expect(firestoreMap.containsKey('trang_thai'), isFalse);
        expect(firestoreMap.containsKey('trangThai'), isFalse);
        expect(firestoreMap.containsKey('trangThai_id'), isFalse);
      }
    });

    test('HostPostModel fromMap reads from status or legacy fallbacks and normalizes to standard 4 statuses', () {
      // Legacy document with approved -> normalized to active
      final docApproved = {
        'id': 'post_approved',
        'roomId': 'room_1',
        'status': 'approved',
        'statusId': 'approved',
        'trang_thai': 'approved',
      };
      final postActive = HostPostModel.fromMap(docApproved, 'post_approved');
      expect(postActive.status, 'active');
      expect(postActive.isActive, isTrue);
      expect(postActive.toFirestore()['status'], 'active');
      expect(postActive.toFirestore().containsKey('statusId'), isFalse);

      // Legacy document with hidden
      final docHidden = {
        'id': 'post_hidden',
        'roomId': 'room_2',
        'status': 'hidden',
        'statusId': 'hidden',
        'trang_thai': 'hidden',
      };
      final postHidden = HostPostModel.fromMap(docHidden, 'post_hidden');
      expect(postHidden.status, 'hidden');
      expect(postHidden.isHidden, isTrue);
      expect(postHidden.toFirestore()['status'], 'hidden');
      expect(postHidden.toFirestore().containsKey('statusId'), isFalse);
      expect(postHidden.toFirestore().containsKey('trang_thai'), isFalse);

      // Legacy document with rejected
      final docRejected = {
        'id': 'post_rejected',
        'roomId': 'room_3',
        'trang_thai': 'tuchoi',
      };
      final postRejected = HostPostModel.fromMap(docRejected, 'post_rejected');
      expect(postRejected.status, 'rejected');
      expect(postRejected.isRejected, isTrue);
      expect(postRejected.toFirestore()['status'], 'rejected');
    });
  });
}
