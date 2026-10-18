import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/auth/providers/user_provider.dart';
import 'user_profile_service.dart';

class AuthService {
  static const lockedAccountMessage =
      'Tài khoản của bạn đã bị khóa. Hãy liên hệ admin để được mở lại.';

  /// Giữ cảnh báo khi màn đăng nhập bị dựng lại sau khi đăng xuất tài khoản khóa.
  static String? pendingLockNotice;

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
        await _ensureUserDocument(user);
        final snap = await _firestore.collection('users').doc(user.uid).get();
        final raw = snap.data()?['statusId'];
        final statusId = raw is num ? raw.toInt() : int.tryParse('$raw');
        if (statusId == UserProfileService.statusLockedId) {
          pendingLockNotice = lockedAccountMessage;
          await _auth.signOut();
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

        final userCode = UserProfile.generateUserCode(seed: user.uid);
        await _firestore.collection('users').doc(user.uid).set(
          UserProfile.registrationData(
            uid: user.uid,
            email: email,
            displayName: displayName,
            phoneNumber: phoneNumber ?? '',
            role: role,
            userCode: userCode,
          ),
        );
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Đã có lỗi xảy ra: $e';
    }
  }

  /// Tài khoản chưa có document thì tạo bằng các trường tiếng Anh đã dùng trên users.
  Future<void> _ensureUserDocument(User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (snap.exists && snap.data() != null) return;
    final email = user.email ?? '';
    final displayName = (user.displayName ?? '').trim().isNotEmpty
        ? user.displayName!.trim()
        : email.split('@').first;
    await ref.set(
      UserProfile.registrationData(
        uid: user.uid,
        email: email,
        displayName: displayName,
        phoneNumber: '',
        role: 'renter',
        userCode: UserProfile.generateUserCode(seed: user.uid),
      ),
    );
  }

  // Đăng xuất
  Future<void> signOut() async {
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
      default:
        return e.message ?? 'Lỗi xác thực: ${e.code}';
    }
  }
}
