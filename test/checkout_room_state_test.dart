import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/host/repositories/checkin_checkout_repository.dart';

void main() {
  group('checkout room state patches', () {
    test('phòng còn cư dân xóa isAvailable legacy và giữ occupied', () {
      final patch = checkoutOccupiedRoomPatch(
        tenantName: 'Người ở lại',
        tenantPhone: '0900000000',
      );

      expect(patch['status'], 'occupied');
      expect(patch['isAvailable'], isA<FieldValue>());
      expect(patch['tenantName'], 'Người ở lại');
    });

    test('người cuối checkout xóa isAvailable legacy và mở phòng bằng status', () {
      final patch = checkoutAvailableRoomPatch();

      expect(patch['status'], 'available');
      expect(patch['isAvailable'], isA<FieldValue>());
      expect(patch['bookingStatus'], 'available');
    });
  });
}
