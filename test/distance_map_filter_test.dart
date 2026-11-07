import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/services/roommate_service.dart';
import 'package:home_share/data/models/roommate_post_model.dart';
import 'package:home_share/features/renter/screens/map_location_picker_screen.dart';

void main() {
  group('RoommatePostModel distanceTo Tests', () {
    test('Calculates accurate Haversine distance with explicit coordinates', () {
      // Bến Thành, Q.1: (10.7725, 106.6980)
      // Landmark 81, Bình Thạnh: (10.7950, 106.7219)
      final post = RoommatePostModel(
        id: 'post_1',
        authorId: 'user_1',
        authorName: 'Nguyễn Văn A',
        authorAge: 22,
        authorGender: 'Nam',
        authorOccupation: 'Sinh viên',
        authorAvatar: '',
        title: 'Tìm bạn ở ghép Landmark 81',
        description: 'Phòng sạch sẽ',
        budgetMin: 3000000,
        budgetMax: 5000000,
        address: 'Landmark 81, Bình Thạnh',
        district: 'Bình Thạnh',
        latitude: 10.7950,
        longitude: 106.7219,
        targetGender: 'Tất cả',
        habits: const ['Sạch sẽ', 'Không hút thuốc'],
        hasRoom: true,
        contactPhone: '0901234567',
        createdAt: DateTime.now(),
      );

      final distance = post.distanceTo(10.7725, 106.6980);
      expect(distance, isNotNull);
      // Khoảng cách xấp xỉ ~3.6 - 3.8 km
      expect(distance!, greaterThan(3.0));
      expect(distance, lessThan(4.5));
    });

    test('Falls back to address bias when coordinates are missing', () {
      final post = RoommatePostModel(
        id: 'post_2',
        authorId: 'user_2',
        authorName: 'Trần Thị B',
        authorAge: 21,
        authorGender: 'Nữ',
        authorOccupation: 'Sinh viên',
        authorAvatar: '',
        title: 'Tìm bạn nữ ở ghép Thủ Đức',
        description: 'Gần ĐH Quốc Gia',
        budgetMin: 2000000,
        budgetMax: 3000000,
        address: 'Phường Linh Trung',
        district: 'Thủ Đức',
        latitude: null,
        longitude: null,
        targetGender: 'Nữ',
        habits: const ['Yên tĩnh'],
        hasRoom: true,
        contactPhone: '0907654321',
        createdAt: DateTime.now(),
      );

      // Điểm mốc Q.1 (10.7769, 106.7009)
      final distance = post.distanceTo(10.7769, 106.7009);
      expect(distance, isNotNull);
      // Khoảng cách từ Q.1 đến Linh Trung Thủ Đức ~12 - 16 km
      expect(distance!, greaterThan(10.0));
      expect(distance, lessThan(20.0));
    });

    test('Returns null when user coordinates are null', () {
      final post = RoommatePostModel(
        id: 'post_3',
        authorId: 'user_3',
        authorName: 'Lê C',
        authorAge: 25,
        authorGender: 'Nam',
        authorOccupation: 'Lập trình viên',
        authorAvatar: '',
        title: 'Tìm bạn ở ghép',
        description: 'Mô tả',
        budgetMin: 3000000,
        budgetMax: 4000000,
        address: 'Quận 1',
        district: 'Quận 1',
        latitude: 10.7769,
        longitude: 106.7009,
        targetGender: 'Nam',
        habits: const [],
        hasRoom: true,
        contactPhone: '0912345678',
        createdAt: DateTime.now(),
      );

      expect(post.distanceTo(null, 106.7009), isNull);
      expect(post.distanceTo(10.7769, null), isNull);
    });
  });

  group('RoommateFilterParams Distance Tests', () {
    test('Equality and hashcode include distance parameters', () {
      const params1 = RoommateFilterParams(
        userLat: 10.7769,
        userLng: 106.7009,
        maxDistanceKm: 5.0,
        sortBy: 'distance',
      );
      const params2 = RoommateFilterParams(
        userLat: 10.7769,
        userLng: 106.7009,
        maxDistanceKm: 5.0,
        sortBy: 'distance',
      );
      const params3 = RoommateFilterParams(
        userLat: 10.7769,
        userLng: 106.7009,
        maxDistanceKm: 10.0,
        sortBy: 'distance',
      );

      expect(params1, equals(params2));
      expect(params1.hashCode, equals(params2.hashCode));
      expect(params1, isNot(equals(params3)));
    });

    test('copyWith updates and clears distance parameters', () {
      const initial = RoommateFilterParams(
        userLat: 10.7769,
        userLng: 106.7009,
        maxDistanceKm: 5.0,
      );

      final updated = initial.copyWith(
        maxDistanceKm: 15.0,
        sortBy: 'distance',
      );
      expect(updated.maxDistanceKm, equals(15.0));
      expect(updated.sortBy, equals('distance'));
      expect(updated.userLat, equals(10.7769));

      final cleared = updated.copyWith(clearDistance: true);
      expect(cleared.maxDistanceKm, isNull);
      expect(cleared.userLat, equals(10.7769));
    });
  });

  group('MapPickedLocation Tests', () {
    test('Holds coordinates, address, and provides LatLng', () {
      const loc = MapPickedLocation(
        latitude: 10.7769,
        longitude: 106.7009,
        address: 'Bến Thành, Quận 1',
      );

      expect(loc.latitude, equals(10.7769));
      expect(loc.longitude, equals(106.7009));
      expect(loc.address, equals('Bến Thành, Quận 1'));
      expect(loc.latLng.latitude, equals(10.7769));
      expect(loc.latLng.longitude, equals(106.7009));
      expect(loc.toString(), contains('Bến Thành, Quận 1'));
    });
  });

  group('MapLocationPickerScreen Widget Tests', () {
    testWidgets('Renders map picker UI with search field, chips and confirm button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MapLocationPickerScreen(
            initialLat: 10.7769,
            initialLng: 106.7009,
            initialLabel: 'Quận 1 (Trung tâm TP.HCM)',
          ),
        ),
      );

      // Verify app bar title
      expect(find.text('Chọn địa điểm trên bản đồ'), findsOneWidget);

      // Verify search text field
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Tìm địa điểm, đường phố, trường học...'), findsOneWidget);

      // Verify action button in app bar
      expect(find.text('Chọn điểm'), findsOneWidget);

      // Verify bottom confirm button
      expect(find.text('Xác nhận điểm mốc này'), findsOneWidget);

      // Verify GPS float button
      expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);
    });
  });
}

