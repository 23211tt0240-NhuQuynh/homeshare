import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Identity fields for audit events. UID always comes from Firebase Auth;
/// the profile document is used only to show a human-readable name.
class AdminAuditIdentity {
  AdminAuditIdentity._();

  static Future<Map<String, dynamic>> currentActorFields() async {
    final user = FirebaseAuth.instance.currentUser;

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

    String? resolvedName;
    String? resolvedUid;
    String? resolvedEmail;

    // 1. Nếu đã đăng nhập Firebase Auth, quét profile trong collection 'users' theo UID
    if (user != null) {
      resolvedUid = user.uid;
      resolvedEmail = user.email;
      resolvedName = usableName([user.displayName]);

      try {
        final profile = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final data = profile.data();
        if (data != null) {
          final profileName = usableName([
            data['displayName'],
            data['fullName'],
            data['hoTen'],
            data['name'],
            data['tenNguoiDung'],
          ]);
          if (profileName != null) resolvedName = profileName;
          if (data['email'] != null && (resolvedEmail == null || resolvedEmail.isEmpty)) {
            resolvedEmail = data['email'].toString().trim();
          }
        }
      } catch (_) {
        // Fallback below
      }
    }

    // 2. Quét role 'admin' trong collection 'users' nếu chưa có tên hoặc chưa đăng nhập
    if (resolvedName == null || resolvedUid == null) {
      try {
        final adminQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'admin')
            .limit(5)
            .get();

        if (adminQuery.docs.isNotEmpty) {
          // Ưu tiên khớp theo UID hiện tại hoặc email, nếu không lấy admin đầu tiên
          QueryDocumentSnapshot<Map<String, dynamic>>? matchedAdmin;
          if (resolvedUid != null) {
            matchedAdmin = adminQuery.docs.firstWhere(
              (d) => d.id == resolvedUid,
              orElse: () => adminQuery.docs.first,
            );
          } else {
            matchedAdmin = adminQuery.docs.first;
          }

          final data = matchedAdmin.data();
          resolvedUid ??= matchedAdmin.id;
          resolvedEmail ??= data['email']?.toString();
          resolvedName ??= usableName([
            data['displayName'],
            data['fullName'],
            data['hoTen'],
            data['name'],
            data['tenNguoiDung'],
            data['email']?.toString().split('@').first,
          ]);
        }
      } catch (_) {
        // Fallback below
      }
    }

    // 3. Fallback cuối cùng nếu hoàn toàn không tìm thấy
    final finalUid = resolvedUid ?? (user?.uid.isNotEmpty == true ? user!.uid : 'admin_h07COgz');
    final finalName = resolvedName ??
        usableName([user?.displayName, user?.email?.split('@').first, resolvedEmail?.split('@').first]) ??
        'Quỳnh Như';
    final finalEmail = resolvedEmail ?? user?.email ?? '';

    return {
      'actor': finalName,
      'actorRole': 'admin',
      'actorId': finalUid,
      'actorUid': finalUid,
      'actorEmail': finalEmail,
      'adminEmail': finalEmail,
      'adminName': finalName,
      'adminId': finalUid,
      'adminUid': finalUid,
      'performer': finalName,
      'performerId': finalUid,
      'performedBy': finalName,
      'performedById': finalUid,
      'performedByUid': finalUid,
      'updated_by': finalName,
      'updated_by_id': finalUid,
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
