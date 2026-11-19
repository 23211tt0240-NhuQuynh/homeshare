import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/auth/providers/user_provider.dart';
import '../../features/auth/services/email_verification_policy.dart';
import 'user_uniqueness_service.dart';
import '../utils/host_reputation.dart';
import 'host_index_service.dart';
import 'push_notification_service.dart';

class AuthService {
  static const lockedAccountMessage =
      'Tài khoản của bạn đã bị khóa. Hãy liên hệ admin để được mở lại.';

  /// Giữ cảnh báo khi màn đăng nhập được dựng lại sau khi đăng xuất tài khoản khóa.
  static String? pendingLockNotice;

  /// Gmail vừa đăng ký thành công để màn hình đăng nhập tự điền lại.
  static String? pendingLoginEmail;

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
        if (profile?['emailVerificationRequired'] == true) {
          await user.reload();
          if (_auth.currentUser?.emailVerified == true) {
            await activateVerifiedEmail();
          }
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
    final normalizedEmail = email.trim().toLowerCase();
    if (!EmailVerificationPolicy.isSupportedGmail(normalizedEmail)) {
      throw 'Vui lòng sử dụng địa chỉ Gmail hợp lệ (@gmail.com).';
    }
    if (!EmailVerificationPolicy.isSupportedRegistrationRole(role)) {
      throw 'Vai trò đăng ký không hợp lệ.';
    }
    try {
      late UserCredential credential;
      try {
        credential = await _auth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password.trim(),
        );
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use') rethrow;
        credential = await _resumePendingRegistration(
          email: normalizedEmail,
          password: password.trim(),
        );
      }

      final user = credential.user;
      if (user != null) {
        final normalizedPhone = UserUniquenessService.normalizePhone(
          phoneNumber ?? '',
        );
        await user.updateDisplayName(displayName);

        // Sinh mã người dùng 5 ký tự (3 số đầu + 2 chữ sau)
        final userCode = UserProfile.generateUserCode(
          seed: user.uid,
          role: role,
        );

        final profileRef = _firestore.collection('users').doc(user.uid);
        final profile = await profileRef.get();
        final pendingProfile = <String, dynamic>{
          'userCode': userCode,
          'displayName': displayName.trim(),
          'phoneNumber': normalizedPhone,
          'phoneNumberNormalized': normalizedPhone,
          'role': role,
          'isEmailVerified': false,
          'emailVerificationRequired': true,
        };
        if (profile.exists) {
          await profileRef.set({
            ...pendingProfile,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else {
          await profileRef.set({
            'uid': user.uid,
            'email': normalizedEmail,
            'reputationScore': 100,
            ...pendingProfile,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await sendEmailVerification();
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Đã có lỗi xảy ra: $e';
    }
  }

  Future<UserCredential> _resumePendingRegistration({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }

    await user.reload();
    final refreshedUser = _auth.currentUser;
    if (refreshedUser == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }

    final profile = await _firestore.collection('users').doc(user.uid).get();
    final canResume = EmailVerificationPolicy.canResumePendingRegistration(
      firebaseEmailVerified: refreshedUser.emailVerified,
      profileExists: profile.exists,
      profileRequiresVerification:
          profile.data()?['emailVerificationRequired'] == true,
    );
    if (!canResume) {
      await _auth.signOut();
      throw FirebaseAuthException(code: 'email-already-in-use');
    }

    return credential;
  }

  /// Gửi email bằng hạ tầng Firebase Auth; ứng dụng không giữ mật khẩu Gmail.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw 'Phiên đăng ký đã hết. Vui lòng đăng nhập lại.';
    if (user.emailVerified) return;

    try {
      await _auth.setLanguageCode('vi');
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Không thể gửi email xác thực: $e';
    }
  }

  /// Nạp lại trạng thái từ Firebase và chỉ kích hoạt hồ sơ khi link đã được bấm.
  Future<bool> refreshEmailVerificationStatus() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshedUser = _auth.currentUser;
    if (refreshedUser?.emailVerified != true) return false;
    // Làm mới ID token để Firestore Rules nhận claim email_verified mới nhất.
    await refreshedUser!.getIdToken(true);
    return true;
  }

  Future<void> activateVerifiedEmail() async {
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) return;

    final profileRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await profileRef.get();
    final data = snapshot.data();
    await profileRef.set({
      'isEmailVerified': true,
      'emailVerificationRequired': false,
      'emailVerifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (HostReputation.isHostRole(data?['role']?.toString() ?? '')) {
      await HostIndexService(firestore: _firestore).ensureHostIndex(user.uid);
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
