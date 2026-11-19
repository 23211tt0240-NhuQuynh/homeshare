import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/host/notifications/notification_types.dart';
import 'package:home_share/features/host/notifications/providers/host_notification_provider.dart';
import 'package:home_share/features/host/notifications/screens/host_notifications_screen.dart';

void main() {
  testWidgets('nút bộ lọc mở bảng lọc theo ngày', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hostNotificationCountsProvider.overrideWith(
            (ref) => Stream.value(<HostNotificationType, int>{}),
          ),
          hostNotificationsProvider.overrideWith(
            (ref, type) => Stream.value([]),
          ),
        ],
        child: const MaterialApp(home: HostNotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('host_notification_filter_button')));
    await tester.pumpAndSettle();

    expect(find.text('Bộ lọc thông báo'), findsOneWidget);
    expect(find.text('Khoảng ngày tạo thông báo'), findsOneWidget);
    expect(find.text('Áp dụng'), findsOneWidget);
  });
}
