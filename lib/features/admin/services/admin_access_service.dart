import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_audit_identity.dart';

/// Manager identity is restricted to this Firebase Authentication account.
class AdminAccessService {
  AdminAccessService._();

  static const managerEmail = 'qnhu00181@gmail.com';
  static const accessCollection = 'admin_access';

  static User? get safeCurrentUser {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (_) {
      return null;
    }
  }

  static bool isManager([User? user]) {
    final targetUser = user ?? safeCurrentUser;
    return targetUser?.email?.trim().toLowerCase() == managerEmail;
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> accessStream(
    String uid,
  ) =>
      FirebaseFirestore.instance.collection(accessCollection).doc(uid).snapshots();

  static Future<void> setAdminAccess({
    required String uid,
    required String adminName,
    required bool enabled,
  }) async {
    if (!isManager(safeCurrentUser)) {
      throw StateError('Chỉ Manager được thay đổi quyền admin.');
    }
    final db = FirebaseFirestore.instance;
    final actor = await AdminAuditIdentity.currentActorFields();
    final batch = db.batch();
    batch.set(db.collection(accessCollection).doc(uid), {
      'uid': uid,
      'adminName': adminName,
      'enabled': enabled,
      'updatedByUid': actor['actorUid'],
      'updatedByEmail': safeCurrentUser?.email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(db.collection('audit_logs').doc(), {
      ...actor,
      'title': enabled ? 'Cấp quyền Admin' : 'Thu hồi quyền Admin',
      'subtitle':
          '${enabled ? 'Cho phép' : 'Từ chối'} tài khoản $adminName (UID: $uid) truy cập Admin Portal',
      'category': 'system',
      'target_type': 'admin',
      'targetUid': uid,
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}
