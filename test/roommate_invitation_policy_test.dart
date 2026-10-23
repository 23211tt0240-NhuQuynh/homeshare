import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/chat/services/roommate_invitation_policy.dart';

void main() {
  group('RoommateInvitationPolicy.canInvite', () {
    test('chỉ cho phép renter mời renter khi người gửi có phòng thật', () {
      expect(
        RoommateInvitationPolicy.canInvite(
          senderRole: 'renter',
          receiverRole: 'tenant',
          hasActiveRoom: true,
        ),
        isTrue,
      );
    });

    test('renter không có phòng không được gửi lời mời', () {
      expect(
        RoommateInvitationPolicy.canInvite(
          senderRole: 'renter',
          receiverRole: 'renter',
          hasActiveRoom: false,
        ),
        isFalse,
      );
    });

    test('host và host không được gửi lời mời', () {
      expect(
        RoommateInvitationPolicy.canInvite(
          senderRole: 'host',
          receiverRole: 'host',
          hasActiveRoom: true,
        ),
        isFalse,
      );
    });

    test('host và renter không được gửi lời mời theo cả hai chiều', () {
      expect(
        RoommateInvitationPolicy.canInvite(
          senderRole: 'host',
          receiverRole: 'renter',
          hasActiveRoom: true,
        ),
        isFalse,
      );
      expect(
        RoommateInvitationPolicy.canInvite(
          senderRole: 'renter',
          receiverRole: 'host',
          hasActiveRoom: true,
        ),
        isFalse,
      );
    });

    test('vai trò thiếu hoặc không hợp lệ luôn bị chặn', () {
      expect(
        RoommateInvitationPolicy.canInvite(
          senderRole: null,
          receiverRole: 'renter',
          hasActiveRoom: true,
        ),
        isFalse,
      );
      expect(
        RoommateInvitationPolicy.canInvite(
          senderRole: 'renter',
          receiverRole: 'unknown',
          hasActiveRoom: true,
        ),
        isFalse,
      );
    });
  });

  group('RoommateInvitationPolicy booking/resident', () {
    test('chỉ nhận các trạng thái booking thực tế đang ở trong trọ', () {
      for (final status in [
        'completed',
        'active',
        'rented',
        'dangO',
        'daNhanPhong',
      ]) {
        expect(
          RoommateInvitationPolicy.isActiveBookingStatus(status),
          isTrue,
          reason: status,
        );
      }

      for (final status in [
        '',
        'approved',
        'daDuyet',
        'deposit_paid',
        'daCoc',
        'choNhanPhong',
        'pending',
        'choDuyet',
        'cancelled',
        'daHuy',
        'rejected',
      ]) {
        expect(
          RoommateInvitationPolicy.isActiveBookingStatus(status),
          isFalse,
          reason: status,
        );
      }
    });

    test('cư dân chỉ hợp lệ khi còn đang ở', () {
      expect(RoommateInvitationPolicy.isActiveResidentStatus('dangO'), isTrue);
      expect(RoommateInvitationPolicy.isActiveResidentStatus('active'), isTrue);
      expect(RoommateInvitationPolicy.isActiveResidentStatus('DANG_O'), isTrue);
      expect(RoommateInvitationPolicy.isActiveResidentStatus('daRoi'), isFalse);
      expect(
        RoommateInvitationPolicy.isActiveResidentStatus('moved_out'),
        isFalse,
      );
    });
  });
}
