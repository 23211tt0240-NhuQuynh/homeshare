import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/data/models/resident_model.dart';
import 'package:home_share/core/services/resident_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('Resident moved_out & past homes logic test', () {
    test('ResidentModel parses moved_out and daRoi correctly', () {
      final data = {
        'id': 'checkin_DP_20261101_WNmRHUHbTmdjPHga347a_NT968_tX2g6Pdk05MA44YkREEU5s74zTn1',
        'roomId': 'MMF2U5DNW5VT',
        'userId': 'tX2g6Pdk05MA44YkREEU5s74zTn1',
        'status': 'moved_out',
        'statusId': 'daRoi',
        'fullName': 'vanthe',
        'phone': '0938912833',
        'formId': 'chinh',
        'periodId': 'checkin_DP_20261101_WNmRHUHbTmdjPHga347a_NT968',
        'moveInDate': Timestamp.fromDate(DateTime(2026, 11, 1, 22, 46, 32)),
        'moveOutDate': Timestamp.fromDate(DateTime(2026, 11, 3, 16, 25, 32)),
      };

      final resident = ResidentModel.fromMap(data, data['id'] as String);

      expect(resident.statusId, equals('daRoi'));
      expect(resident.isMovedOut, isTrue);
      expect(resident.isActive, isFalse);
      expect(ResidentService.isActive(resident), isFalse);
    });

    test('Resident with status moved_out even if statusId is empty is detected as moved out', () {
      final data = {
        'id': 'test_resident_1',
        'roomId': 'MMF2U5DNW5VT',
        'userId': 'user123',
        'status': 'moved_out',
        'fullName': 'Test User',
        'moveInDate': Timestamp.fromDate(DateTime(2026, 11, 1)),
        'moveOutDate': Timestamp.fromDate(DateTime(2026, 11, 3)),
      };

      final resident = ResidentModel.fromMap(data, 'test_resident_1');

      expect(resident.statusId, equals('daRoi'));
      expect(resident.isMovedOut, isTrue);
      expect(resident.isActive, isFalse);
      expect(ResidentService.isActive(resident), isFalse);
    });
  });
}

