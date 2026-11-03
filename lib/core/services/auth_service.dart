import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/auth/providers/user_provider.dart';
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
        final snap = await _firestore.collection('users').doc(user.uid).get();
        if (_isAccountLocked(snap.data())) {
          pendingLockNotice = lockedAccountMessage;
          await signOut();
          throw lockedAccountMessage;
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

  bool _isAccountLocked(Map<String, dynamic>? data) {
    if (data == null) return false;
    final raw = data['statusId'];
    final statusId = raw is num ? raw.toInt() : int.tryParse('$raw');
    return statusId == statusLockedId;
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
        final userCode = UserProfile.generateUserCode(seed: user.uid);

        // Lưu thông tin người dùng vào Firestore collection 'users'
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'userCode': userCode,
          'email': email.trim(),
          'displayName': displayName.trim(),
          'phoneNumber': phoneNumber ?? '',
          'role': role,
          'reputationScore': 100,
          'createdAt': FieldValue.serverTimestamp(),
        });
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

  // Đăng xuất. Xóa fcmToken trước để máy này không còn nhận chuông của tài khoản vừa thoát.
  Future<void> signOut() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        await PushNotificationService.unbindUser(uid);
      } catch (_) {}
      await _firestore.collection('users').doc(uid).set({
        'fcmToken': FieldValue.delete(),
      }, SetOptions(merge: true));
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
