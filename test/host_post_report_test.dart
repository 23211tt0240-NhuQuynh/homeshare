import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/utils/host_post_report_policy.dart';
import 'package:home_share/core/utils/id_generator.dart';
import 'package:home_share/features/auth/providers/auth_provider.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import 'package:home_share/features/renter/widgets/report_host_post_dialog.dart';

void main() {
  group('HostPostReportPolicy', () {
    test('phải đăng nhập, có bài đăng và không tự báo cáo', () {
      expect(
        HostPostReportPolicy.canReport(
          reporterId: '',
          hostId: 'host1',
          postId: 'post1',
        ),
        isFalse,
      );
      expect(
        HostPostReportPolicy.canReport(
          reporterId: 'host1',
          hostId: 'host1',
          postId: 'post1',
        ),
        isFalse,
      );
      expect(
        HostPostReportPolicy.canReport(
          reporterId: 'renter1',
          hostId: 'host1',
          postId: '',
        ),
        isFalse,
      );
      expect(
        HostPostReportPolicy.canReport(
          reporterId: 'renter1',
          hostId: 'host1',
          postId: 'post1',
        ),
        isTrue,
      );
    });

    test('phải chọn ít nhất một lý do', () {
      expect(
        HostPostReportPolicy.validate(
          reporterId: 'renter1',
          hostId: 'host1',
          postId: 'post1',
          selectedReasons: const [],
          otherText: '',
        ),
        'Vui lòng chọn ít nhất một lý do.',
      );
    });

    test('chọn nhiều chip có sẵn thì không cần khung khác', () {
      expect(
        HostPostReportPolicy.validate(
          reporterId: 'renter1',
          hostId: 'host1',
          postId: 'post1',
          selectedReasons: HostPostReportPolicy.reasons.take(2),
          otherText: '',
        ),
        isNull,
      );
    });

    test('vấn đề khác bắt buộc nhập text', () {
      expect(
        HostPostReportPolicy.validate(
          reporterId: 'renter1',
          hostId: 'host1',
          postId: 'post1',
          selectedReasons: const [HostPostReportPolicy.otherReason],
          otherText: '',
        ),
        'Vui lòng nhập vấn đề khác.',
      );
      expect(
        HostPostReportPolicy.validate(
          reporterId: 'renter1',
          hostId: 'host1',
          postId: 'post1',
          selectedReasons: [
            HostPostReportPolicy.reasons.first,
            HostPostReportPolicy.otherReason,
          ],
          otherText: 'Giá trên bài khác giá khi hỏi',
        ),
        isNull,
      );
    });

    test('mã báo cáo bài đăng bắt đầu bằng BCB_', () {
      expect(IdGenerator.postReport(), startsWith('BCB_'));
    });
  });

  group('ReportHostPostDialog', () {
    testWidgets('chọn Vấn đề khác mới hiện khung text, chọn được nhiều chip', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserProvider.overrideWith((ref) => null),
            userProfileProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ReportHostPostDialog(
                postId: 'post1',
                postTitle: 'Phòng test',
                hostId: 'host1',
                hostName: 'Cô Lan',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Báo cáo'), findsOneWidget);
      expect(find.text('Tìm hỗ trợ hoặc báo cáo bài đăng'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text('Lừa đảo'));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);

      await tester.ensureVisible(find.text('Vấn đề khác'));
      await tester.tap(find.text('Vấn đề khác'));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Tiếp'), findsOneWidget);
    });
  });
}
