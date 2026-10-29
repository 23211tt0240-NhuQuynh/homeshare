import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/chat/services/roommate_invitation_eligibility_service.dart';
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
    test('chỉ nhận các trạng thái booking đã có quyền sử dụng phòng', () {
      for (final status in [
        'approved',
        'deposit_paid',
        'completed',
        'active',
        'rented',
        'dangO',
        'daCoc',
        'daDuyet',
      ]) {
        expect(
          RoommateInvitationPolicy.isActiveBookingStatus(status),
          isTrue,
          reason: status,
        );
      }

      for (final status in [
        '',
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

  test('đơn dangO lấy được phòng từ chính booking khi rooms/posts thiếu', () {
    final room = roomFromActiveBooking({
      'status': 'dangO',
      'renterId': 'tX2g6Pdk05MA44YkREEU5s74zTn1',
      'hostId': '2WRf5Owyi0ale2BGxzACLC1KfOz1',
      'hostName': 'Trần Trà Quốc Mẫn',
      'roomId': '0lV2xMQBgSWFEE6aBTN6',
      'roomTitle': 'Toan',
      'rentalPrice': 500000000,
      'roomAddress': '',
    }, 'DP_20261025_0lV2xMQBgSWFEE6aBTN6_NT968');
    expect(room, isNotNull);
    expect(room!.id, '0lV2xMQBgSWFEE6aBTN6');
    expect(room.hostId, '2WRf5Owyi0ale2BGxzACLC1KfOz1');
    expect(room.title, 'Toan');
    expect(room.price, 500000000);
  });

  test('chấp nhận lời mời dùng hostId đã gắn lúc gửi khi rooms thiếu', () {
    final room = roomFromInvitationPayload(
      roomId: '0lV2xMQBgSWFEE6aBTN6',
      hostId: '2WRf5Owyi0ale2BGxzACLC1KfOz1',
      roomTitle: 'Toan',
      roomCode: 'PWFFQHMBU783',
      hostName: 'Trần Trà Quốc Mẫn',
    );
    expect(room, isNotNull);
    expect(room!.hostId, '2WRf5Owyi0ale2BGxzACLC1KfOz1');
    expect(room.title, 'Toan');
  });
}
