import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/host/notifications/filters/host_notification_filter.dart';
import 'package:home_share/features/host/notifications/models/host_notification_model.dart';
import 'package:home_share/features/host/notifications/notification_types.dart';

HostNotificationModel notification({
  required String id,
  required DateTime createdAt,
  String bookingId = '',
  String bookingCode = '',
  String title = '',
  String message = '',
  String renterName = '',
  bool isRead = false,
}) {
  return HostNotificationModel(
    id: id,
    receiverId: 'host-1',
    type: HostNotificationType.pendingAction,
    title: title,
    message: message,
    bookingId: bookingId,
    bookingCode: bookingCode,
    renterName: renterName,
    isRead: isRead,
    createdAt: createdAt,
  );
}

void main() {
  group('lọc thông báo chủ trọ', () {
    test('tìm kiếm không dấu trên mã booking, khách thuê và nội dung', () {
      final items = [
        notification(
          id: '1',
          createdAt: DateTime(2026, 11, 16),
          bookingCode: 'DP_NT968',
          renterName: 'Nguyễn Văn An',
          message: 'Khách đã chuyển khoản tiền cọc',
        ),
        notification(
          id: '2',
          createdAt: DateTime(2026, 11, 15),
          bookingCode: 'BKDP_20',
          renterName: 'Lê Bình',
        ),
      ];

      expect(
        applyHostNotificationFilters(
          notifications: items,
          query: 'nt968',
        ).map((item) => item.id),
        ['1'],
      );
      expect(
        applyHostNotificationFilters(
          notifications: items,
          query: 'nguyen van',
        ).map((item) => item.id),
        ['1'],
      );
      expect(
        applyHostNotificationFilters(
          notifications: items,
          query: 'chuyen khoan',
        ).map((item) => item.id),
        ['1'],
      );
    });

    test('khoảng ngày bao gồm trọn ngày bắt đầu và kết thúc', () {
      final items = [
        notification(id: 'before', createdAt: DateTime(2026, 11, 9, 23, 59)),
        notification(id: 'start', createdAt: DateTime(2026, 11, 10)),
        notification(id: 'end', createdAt: DateTime(2026, 11, 12, 23, 59)),
        notification(id: 'after', createdAt: DateTime(2026, 11, 13)),
      ];

      final result = applyHostNotificationFilters(
        notifications: items,
        filter: HostNotificationFilter(
          startDate: DateTime(2026, 11, 10),
          endDate: DateTime(2026, 11, 12),
        ),
      );

      expect(result.map((item) => item.id), ['end', 'start']);
    });

    test('lọc chưa đọc và sắp xếp cũ nhất trước', () {
      final items = [
        notification(
          id: 'new-read',
          createdAt: DateTime(2026, 11, 16),
          isRead: true,
        ),
        notification(id: 'new-unread', createdAt: DateTime(2026, 11, 15)),
        notification(id: 'old-unread', createdAt: DateTime(2026, 11, 10)),
      ];

      final result = applyHostNotificationFilters(
        notifications: items,
        filter: const HostNotificationFilter(
          readFilter: HostNotificationReadFilter.unread,
          sortOrder: HostNotificationSortOrder.oldest,
        ),
      );

      expect(result.map((item) => item.id), ['old-unread', 'new-unread']);
    });
  });
}
