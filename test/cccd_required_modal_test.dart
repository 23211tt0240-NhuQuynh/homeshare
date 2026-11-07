import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/profile/widgets/cccd_required_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CccdRequiredDialog UI & Flow Tests', () {
    testWidgets('Hiển thị cảnh báo dí dỏm chuẩn cho Renter khi chưa xác thực CCCD', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CccdRequiredDialog(
              isHost: false,
              actionName: 'đặt phòng',
            ),
          ),
        ),
      );

      // Kiểm tra tiêu đề dí dỏm cho Renter
      expect(find.text('Ối kìa! Chưa có vé thông hành sao? 😱'), findsOneWidget);

      // Kiểm tra nội dung cảnh báo dí dỏm
      expect(
        find.textContaining('bảo mật level max'),
        findsOneWidget,
      );

      // Kiểm tra nút xác thực ngay và nút để sau
      expect(find.byKey(const ValueKey('cccd_verify_now_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('cccd_verify_later_button')), findsOneWidget);
    });

    testWidgets('Hiển thị cảnh báo dí dỏm cho Host khi tạo cơ sở', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CccdRequiredDialog(
              isHost: true,
              actionName: 'tạo cơ sở',
            ),
          ),
        ),
      );

      // Tiêu đề Host
      expect(find.text('Ủa ủa! Khoan đã chủ trọ ơi! 😱'), findsOneWidget);

      // Nội dung tạo cơ sở
      expect(
        find.textContaining('ông trùm bất động sản'),
        findsOneWidget,
      );
    });

    testWidgets('Hiển thị cảnh báo dí dỏm cho Host khi tạo phòng', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CccdRequiredDialog(
              isHost: true,
              actionName: 'tạo phòng',
            ),
          ),
        ),
      );

      expect(
        find.textContaining('lên sóng'),
        findsOneWidget,
      );
    });

    testWidgets('Hiển thị cảnh báo dí dỏm cho Host khi đăng bài', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CccdRequiredDialog(
              isHost: true,
              actionName: 'đăng bài',
            ),
          ),
        ),
      );

      expect(
        find.textContaining('duyệt vèo vèo'),
        findsOneWidget,
      );
    });

    testWidgets('Bấm "Để tôi làm sau nhé" đóng dialog với kết quả false', (tester) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await showCccdRequiredModal(ctx, isHost: false);
                },
                child: const Text('Mở Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Mở Modal'));
      await tester.pumpAndSettle();

      expect(find.byType(CccdRequiredDialog), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('cccd_verify_later_button')));
      await tester.pumpAndSettle();

      expect(find.byType(CccdRequiredDialog), findsNothing);
      expect(result, isFalse);
    });
  });
}

