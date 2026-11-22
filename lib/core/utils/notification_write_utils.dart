import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/firestore_collections.dart';

Map<String, dynamic> notificationReadUpdate() {
  return {
    NotificationFields.isRead: true,
    NotificationFields.legacyIsRead: FieldValue.delete(),
    NotificationFields.updatedAt: FieldValue.serverTimestamp(),
    NotificationFields.legacyUpdatedAt: FieldValue.delete(),
  };
}
