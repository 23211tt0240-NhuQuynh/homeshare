import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/data/models/room_model.dart';
import 'package:home_share/features/chat/services/roommate_invitation_eligibility_service.dart';

void main() {
  group('RoommateInvitationEligibility Tests', () {
    test('canInvite is true when activeRooms is populated and blockReason is none', () {
      final room1 = RoomModel.fromMap({
        'hostId': 'host123',
        'title': 'Phòng trọ Bình Thạnh',
        'price': 3000000,
      }, 'room-1');

      final room2 = RoomModel.fromMap({
        'hostId': 'host456',
        'title': 'Căn hộ mini Cầu Giấy',
        'price': 4500000,
      }, 'room-2');

      final eligibility = RoommateInvitationEligibility(
        senderRole: 'renter',
        receiverRole: 'renter',
        activeRoom: room1,
        activeRooms: [room1, room2],
        blockReason: RoommateInvitationBlockReason.none,
      );

      expect(eligibility.canInvite, isTrue);
      expect(eligibility.activeRooms.length, equals(2));
      expect(eligibility.activeRoom?.id, equals('room-1'));
    });

    test('canInvite is false when blockReason is not none', () {
      final eligibility = RoommateInvitationEligibility(
        senderRole: 'renter',
        receiverRole: 'renter',
        activeRoom: null,
        activeRooms: const [],
        blockReason: RoommateInvitationBlockReason.noActiveRoom,
      );

      expect(eligibility.canInvite, isFalse);
    });

    test('roomFromActiveBooking extracts fields properly', () {
      final bookingData = {
        'hostId': 'host_abc',
        'hostName': 'Chủ trọ Nguyễn Văn A',
        'hostPhone': '0901234567',
        'roomTitle': 'Phòng 202 máy lạnh',
        'rentalPrice': 2500000,
        'depositAmount': 2500000,
        'roomAddress': '123 Đường Số 1, Gò Vấp',
        'roomCode': 'P202',
      };

      final room = roomFromActiveBooking(bookingData, 'booking_789');
      expect(room, isNotNull);
      expect(room!.id, equals('booking_789'));
      expect(room.hostId, equals('host_abc'));
      expect(room.hostName, equals('Chủ trọ Nguyễn Văn A'));
      expect(room.title, equals('Phòng 202 máy lạnh'));
      expect(room.price, equals(2500000));
      expect(room.roomCode, equals('P202'));
    });

    test('roomFromActiveBooking returns null when hostId is missing', () {
      final bookingData = {
        'roomTitle': 'Phòng không chủ',
        'rentalPrice': 2000000,
      };

      final room = roomFromActiveBooking(bookingData, 'booking_invalid');
      expect(room, isNull);
    });

    test('roomFromInvitationPayload constructs model correctly', () {
      final room = roomFromInvitationPayload(
        roomId: 'room_xyz',
        hostId: 'host_xyz',
        roomTitle: 'Phòng ban công thoáng mát',
        roomCode: 'P101',
        hostName: 'Chị Lan',
      );

      expect(room, isNotNull);
      expect(room!.id, equals('room_xyz'));
      expect(room.hostId, equals('host_xyz'));
      expect(room.title, equals('Phòng ban công thoáng mát'));
      expect(room.roomCode, equals('P101'));
    });

    test('roomFromInvitationPayload returns null when hostId is empty', () {
      final room = roomFromInvitationPayload(
        roomId: 'room_xyz',
        hostId: '   ',
      );

      expect(room, isNull);
    });
    test('canInvite is false when blockReason is roomFull', () {
      final room = RoomModel.fromMap({
        'hostId': 'host123',
        'title': 'Phòng trọ 3 người',
        'capacity': 3,
      }, 'room-full');

      final eligibility = RoommateInvitationEligibility(
        senderRole: 'renter',
        receiverRole: 'renter',
        activeRoom: room,
        activeRooms: [room],
        blockReason: RoommateInvitationBlockReason.roomFull,
        capacityChecks: const {
          'room-full': RoomCapacityCheckResult(
            roomId: 'room-full',
            capacity: 3,
            currentOccupants: 3,
            isFull: true,
            message: 'Phòng đã đủ số người ở tối đa (3/3 người).',
          ),
        },
      );

      expect(eligibility.canInvite, isFalse);
      expect(eligibility.blockReason, equals(RoommateInvitationBlockReason.roomFull));
      expect(eligibility.capacityChecks['room-full']?.isFull, isTrue);
      expect(eligibility.capacityChecks['room-full']?.remainingSlots, equals(0));
    });

    test('RoomCapacityCheckResult computes remainingSlots and isFull accurately', () {
      const availableCap = RoomCapacityCheckResult(
        roomId: 'room-1',
        capacity: 3,
        currentOccupants: 1,
        isFull: false,
        message: 'Phòng hiện có 1/3 người.',
      );

      expect(availableCap.isFull, isFalse);
      expect(availableCap.remainingSlots, equals(2));

      const fullCap = RoomCapacityCheckResult(
        roomId: 'room-2',
        capacity: 3,
        currentOccupants: 3,
        isFull: true,
        message: 'Phòng đã đủ 3/3 người.',
      );

      expect(fullCap.isFull, isTrue);
      expect(fullCap.remainingSlots, equals(0));
    });
  });
}

