import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/auth/providers/user_provider.dart';
import '../utils/host_reputation.dart';
import 'host_index_service.dart';
import 'push_notification_service.dart';

class AuthService {
  static const lockedAccountMessage =
      'Tài khoản của bạn đã bị khóa. Hãy liên hệ admin để được mở lại.';

  /// Giữ cảnh báo khi màn đăng nhập được dựng lại sau khi đăng xuất tài khoản khóa.
  static String? pendingLockNotice;

  static const int statusLockedId = 2;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream theo dõi trạng thái đăng nhập
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Lấy user hiện tại
  User? get currentUser => _auth.currentUser;

  // Đăng nhập bằng Email & Mật khẩu
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      final user = credential.user;
      if (user != null) {
        final profileRef = _firestore.collection('users').doc(user.uid);
        final snap = await profileRef.get();
        final profile = snap.data();
        if (_isAccountLocked(profile)) {
          final until = _suspensionDate(profile?['suspendedUntil']);
          pendingLockNotice = until == null
              ? lockedAccountMessage
              : 'Tài khoản tạm khóa đến ${until.toLocal()}.';
          await signOut();
          throw lockedAccountMessage;
        }
        if (_isSuspensionExpired(profile)) {
          await profileRef.set({
            'isBanned': false,
            'statusId': profile?['statusIdBeforeSuspension'] ?? 1,
            'banReason':
                (profile?['banReasonBeforeSuspension'] as String?)
                        ?.isNotEmpty ==
                    true
                ? profile!['banReasonBeforeSuspension']
                : FieldValue.delete(),
            'statusIdBeforeSuspension': FieldValue.delete(),
            'banReasonBeforeSuspension': FieldValue.delete(),
            'suspendedUntil': FieldValue.delete(),
            'suspensionType': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e == lockedAccountMessage) rethrow;
      throw 'Đã có lỗi xảy ra: $e';
    }
  }

  DateTime? _suspensionDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool _isSuspensionExpired(Map<String, dynamic>? data) {
    if (data == null ||
        data['accountDeleted'] == true ||
        data['suspensionType'] == null) {
      return false;
    }
    final until = _suspensionDate(data['suspendedUntil']);
    return until != null && !until.isAfter(DateTime.now());
  }

  bool _isAccountLocked(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['accountDeleted'] == true) return true;
    if (_isSuspensionExpired(data)) return false;
    final raw = data['statusId'];
    final statusId = raw is num ? raw.toInt() : int.tryParse('$raw');
    return data['isBanned'] == true || statusId == statusLockedId;
  }

  // Đăng ký tài khoản mới bằng Email & Mật khẩu
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    String? phoneNumber,
    String role = 'renter', // 'renter' (người thuê) hoặc 'host' (chủ trọ)
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(displayName);

        // Sinh mã người dùng 5 ký tự (3 số đầu + 2 chữ sau)
        final userCode = UserProfile.generateUserCode(seed: user.uid, role: role);

        // Lưu thông tin người dùng vào Firestore collection 'users'
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'userCode': userCode,
          'email': email.trim(),
          'displayName': displayName.trim(),
          'phoneNumber': phoneNumber ?? '',
          'role': role,
          'reputationScore': 100,
          'isEmailVerified': true,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Chủ trọ: cấp hostIndex cố định ngay khi đăng ký.
        if (HostReputation.isHostRole(role)) {
          await HostIndexService(firestore: _firestore).ensureHostIndex(user.uid);
        }
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Đã có lỗi xảy ra: $e';
    }
  }

  /// Gửi link đổi mật khẩu vào email. Người dùng đặt mật khẩu mới trên trang Firebase,
  /// mật khẩu đó có hiệu lực ngay khi đăng nhập lại trên app.
  Future<void> sendPasswordResetEmail(String email) async {
    final trimmed = email.trim();
    try {
      await _auth.setLanguageCode('vi');
      await _auth.sendPasswordResetEmail(email: trimmed);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Đã có lỗi xảy ra: $e';
    }
  }

  // Đăng xuất. Gỡ token của thiết bị hiện tại qua PushNotificationService.
  // Không xóa vô điều kiện fcmToken để bảo toàn cho các thiết bị khác đang đăng nhập.
  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        await PushNotificationService.unbindUser(uid);
      } catch (_) {}
    }
    await _auth.signOut();
  }

  // Xử lý thông báo lỗi tiếng Việt dễ hiểu
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Không tìm thấy tài khoản với email này.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Mật khẩu hoặc thông tin đăng nhập không chính xác.';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng cho tài khoản khác.';
      case 'invalid-email':
        return 'Định dạng email không hợp lệ.';
      case 'weak-password':
        return 'Mật khẩu quá yếu (tối thiểu 6 ký tự).';
      case 'user-disabled':
        return 'Tài khoản này đã bị khóa.';
      case 'too-many-requests':
        return 'Bạn gửi yêu cầu quá nhiều lần. Hãy thử lại sau ít phút.';
      case 'network-request-failed':
        return 'Không có mạng. Hãy kiểm tra kết nối rồi thử lại.';
      default:
        return e.message ?? 'Lỗi xác thực: ${e.code}';
    }
  }
}
