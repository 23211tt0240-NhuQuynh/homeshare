import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/services/room_service.dart';
import 'package:home_share/data/models/room_model.dart';
import 'package:home_share/features/auth/providers/auth_provider.dart';
import 'package:home_share/features/renter/screens/room_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

RoomModel _room({
  required String title,
  required String description,
  required double price,
}) {
  return RoomModel(
    id: 'post-001',
    roomCode: 'P001',
    title: title,
    description: description,
    price: price,
    deposit: 1500000,
    address: '12 Nguyễn Văn Bảo, Gò Vấp',
    district: 'Gò Vấp',
    area: 28,
    roomType: 'Phòng trọ',
    amenities: const ['Máy lạnh', 'Wifi tốc độ cao'],
    images: const [],
    hostId: 'host-001',
    hostName: 'Cô Lan',
    hostPhone: '0909000000',
    createdAt: DateTime(2026, 10, 20),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'chi tiết hiển thị dữ liệu realtime từ document posts thay vì bản truyền từ danh sách',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final listSnapshot = _room(
        title: 'Tiêu đề cũ',
        description: 'Mô tả cũ',
        price: 1000000,
      );
      final firebasePost = _room(
        title: 'Phòng Firebase mới cập nhật',
        description: 'Dữ liệu lấy trực tiếp từ posts',
        price: 3500000,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWithValue(null),
            roomPostDetailProvider.overrideWith(
              (ref, postId) => Stream.value(firebasePost),
            ),
          ],
          child: MaterialApp(home: RoomDetailScreen(room: listSnapshot)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Phòng Firebase mới cập nhật'), findsOneWidget);
      expect(find.text('Dữ liệu lấy trực tiếp từ posts'), findsOneWidget);
      expect(find.text('Tiêu đề cũ'), findsNothing);
      expect(find.text('3.500.000 đ/tháng'), findsOneWidget);
    },
  );

  testWidgets('hiển thị thông báo khi bài đăng posts đã bị xóa', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final listSnapshot = _room(
      title: 'Bài đã xóa',
      description: 'Không được tiếp tục hiển thị dữ liệu cũ',
      price: 1000000,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(null),
          roomPostDetailProvider.overrideWith(
            (ref, postId) => Stream.value(null),
          ),
        ],
        child: MaterialApp(home: RoomDetailScreen(room: listSnapshot)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bài đăng không còn tồn tại'), findsOneWidget);
    expect(find.text('Bài đã xóa'), findsNothing);
  });
}
