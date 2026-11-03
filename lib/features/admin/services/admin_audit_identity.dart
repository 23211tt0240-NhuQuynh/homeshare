import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Identity fields for audit events. UID always comes from Firebase Auth;
/// the profile document is used only to show a human-readable name.
class AdminAuditIdentity {
  AdminAuditIdentity._();

  static Future<Map<String, dynamic>> currentActorFields() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {
        'actor': 'Không xác định',
        'actorRole': 'unknown',
        'actorId': 'N/A',
        'actorUid': 'N/A',
        'adminName': 'Không xác định',
        'adminId': 'N/A',
        'adminUid': 'N/A',
        'performer': 'Không xác định',
        'performerId': 'N/A',
      };
    }

    String? usableName(Iterable<dynamic> values) {
      for (final value in values) {
        final candidate = (value ?? '').toString().trim();
        final normalized = candidate.toLowerCase();
        if (candidate.isNotEmpty &&
            !const {
              'admin',
              'không rõ',
              'không xác định',
              'người dùng homeshare',
              'unknown',
              'n/a',
              'system',
              'hệ thống',
              'hệ thống / admin',
              'homeshare system',
            }.contains(normalized)) {
          return candidate;
        }
      }
      return null;
    }

    var name = usableName([user.displayName]) ?? '';
    try {
      final profile = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = profile.data();
      final profileName = usableName([
        data?['displayName'],
        data?['hoTen'],
        data?['fullName'],
        data?['name'],
        data?['tenNguoiDung'],
      ]);
      if (profileName != null) name = profileName;
    } catch (_) {
      // Keep the Firebase Auth name/email fallback if profile reads are denied.
    }
    if (name.isEmpty) name = user.email?.trim() ?? '';
    if (name.isEmpty) name = 'Admin';

    return {
      'actor': name,
      'actorRole': 'admin',
      'actorId': user.uid,
      'actorUid': user.uid,
      'actorEmail': user.email ?? '',
      'adminEmail': user.email ?? '',
      'adminName': name,
      'adminId': user.uid,
      'adminUid': user.uid,
      'performer': name,
      'performerId': user.uid,
    };
  }

  static bool hasExplicitAdminRole(Map<String, dynamic> data) {
    final role = (data['actorRole'] ?? '').toString().trim().toLowerCase();
    return role == 'admin' || role == 'administrator';
  }

  static bool isKnownAdminAction(Map<String, dynamic> data) {
    if ((data['actorRole'] ?? '').toString().trim().isNotEmpty) return false;

    final category = (data['category'] ?? '').toString().toLowerCase().trim();
    final title = (data['title'] ?? data['action'] ?? '')
        .toString()
        .toLowerCase()
        .trim();
    final details = (data['details'] ?? data['subtitle'] ?? '')
        .toString()
        .toLowerCase()
        .trim();

    if (category == 'post') {
      return title.startsWith('duyệt tin đăng') ||
          title.startsWith('từ chối bài đăng');
    }

    return category == 'taichinh' &&
        title.startsWith('duyệt ') &&
        details.startsWith('admin đã xác nhận ');
  }

  static String? legacyActorUid(Map<String, dynamic> data) {
    for (final key in const [
      'actorUid',
      'actorId',
      'adminUid',
      'adminId',
      'performerId',
      'performedByUid',
      'performedById',
      'reviewedById',
      'updated_by_id',
      'updatedById',
      'updatedByUid',
      'createdById',
      'createdByUid',
      'userUid',
    ]) {
      final uid = (data[key] ?? '').toString().trim();
      if (uid.isNotEmpty &&
          !const {
            'system',
            'admin',
            'n/a',
            'unknown',
            'không xác định',
            'hệ thống',
            'hệ thống / admin',
          }.contains(uid.toLowerCase())) {
        return uid;
      }
    }
    return null;
  }
}
