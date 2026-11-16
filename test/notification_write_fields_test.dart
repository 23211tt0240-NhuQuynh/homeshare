import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/constants/firestore_collections.dart';
import 'package:home_share/core/utils/notification_write_utils.dart';

void main() {
  test('đánh dấu đã đọc xóa daDoc và ngayCapNhat legacy', () {
    final patch = notificationReadUpdate();

    expect(patch[NotificationFields.isRead], isTrue);
    expect(patch[NotificationFields.legacyIsRead], FieldValue.delete());
    expect(patch[NotificationFields.updatedAt], isA<FieldValue>());
    expect(patch[NotificationFields.legacyUpdatedAt], FieldValue.delete());
  });
}
