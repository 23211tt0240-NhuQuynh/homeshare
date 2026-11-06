import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/host/notifications/models/host_notification_model.dart';
import 'package:home_share/features/host/notifications/notification_types.dart';

void main() {
  test(
    'Admin disbursement notification is parsed for the host payment tab',
    () {
      final notification = HostNotificationModel.fromMap({
        'receiverId': 'host-1',
        'senderId': 'admin',
        'notificationType': 'paymentCompleted',
        'actionType': 'disbursement',
        'paymentId': 'settlement-1',
        'title': 'Admin đã giải ngân',
        'message': 'Admin đã giải ngân 950.000 đ cho chủ trọ.',
        'amount': 950000,
        'statusId': 'disbursed',
        'isRead': false,
      }, 'notification-1');

      expect(notification.receiverId, 'host-1');
      expect(notification.type, HostNotificationType.paymentCompleted);
      expect(notification.isDisbursementNotification, isTrue);
      expect(notification.amount, 950000);
    },
  );
}
