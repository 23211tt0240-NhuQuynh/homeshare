import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:home_share/core/theme/app_theme.dart';
import 'package:home_share/core/services/roommate_service.dart';
import 'package:home_share/data/models/roommate_post_model.dart';
import 'package:home_share/features/auth/providers/auth_provider.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/renter/screens/roommate_community_screen.dart';

RoommatePostModel _post(int i, {required bool hasRoom}) {
  return RoommatePostModel(
    id: 'p$i-${hasRoom ? 'has' : 'need'}',
    authorId: 'u$i',
    authorName: 'Bạn $i',
    authorAge: 22,
    authorGender: i.isEven ? 'Nữ' : 'Nam',
    authorOccupation: 'Sinh viên',
    authorAvatar: '',
    title: 'Tìm bạn ghép phòng số $i gần trung tâm',
    description: 'Mô tả bài đăng',
    pricePerPerson: 1800000,
    budgetMin: 1500000,
    budgetMax: 2000000,
    address: '123 Đường Test, Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh',
    district: 'Quận 1',
    targetGender: 'Tất cả',
    habits: const ['Thích nấu ăn', 'Không hút thuốc'],
    images: const [
      'https://example.com/room.jpg',
      'data:image/png;base64,AAAA',
    ],
    imageCaptions: const ['Phòng ngủ máy lạnh', 'Bếp chung rộng'],
    hasRoom: hasRoom,
    isVerified: true,
    contactPhone: '0900000000',
    createdAt: DateTime.now().subtract(Duration(hours: i + 1)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('kéo hết tab ở ghép không vỡ layout', (tester) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    final posts = [
      for (var i = 0; i < 6; i++) _post(i, hasRoom: true),
      for (var i = 0; i < 4; i++) _post(i + 6, hasRoom: false),
    ];

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith((ref) => null),
          userProfileProvider.overrideWith((ref) => Stream<UserProfile?>.value(null)),
          roommatePostsStreamProvider.overrideWith(
            (ref, filters) => Stream.value(
              posts.where((post) => post.hasRoom == (filters.hasRoom != false)).toList(),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: IndexedStack(
              index: 0,
              children: [RoommateCommunityScreen()],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    FlutterError.onError = previous;
    for (final error in errors) {
      if (error.exceptionAsString().contains('HTTP request failed')) continue;
      // ignore: avoid_print
      print('LAYOUT ERROR:\n${error.toString()}');
    }

    final list = find.byType(SingleChildScrollView);
    expect(list, findsOneWidget, reason: errors.join('\n----\n'));

    for (var i = 0; i < 15; i++) {
      await tester.drag(list, const Offset(0, -700));
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Chưa tìm được bạn ghép'), findsOneWidget);
    final layoutErrors = errors
        .where((error) => !error.exceptionAsString().contains('HTTP request failed'))
        .map((error) => error.exceptionAsString())
        .toList();
    expect(layoutErrors, isEmpty, reason: layoutErrors.join('\n----\n'));
  });
}
