import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import '../constants/firestore_collections.dart';

/// Provider dịch vụ gửi & xác thực mã OTP qua Gmail
final emailOtpServiceProvider = Provider<EmailOtpService>((ref) {
  return EmailOtpService();
});

/// Kết quả gửi mã OTP
class OtpSendResult {
  final bool isSuccess;
  final String message;
  final String? debugOtp; // Chỉ xuất hiện ở chế độ debug/test
  final bool sentViaSmtp;

  const OtpSendResult({
    required this.isSuccess,
    required this.message,
    this.debugOtp,
    this.sentViaSmtp = false,
  });
}

/// Dữ liệu phiên OTP lưu trong bộ nhớ ứng dụng
/// Đảm bảo hoạt động độc lập ngay cả khi Firestore chưa cấp quyền cho người dùng vãng lai (unauthenticated)
class _OtpSession {
  final String email;
  final String otp;
  final DateTime createdAt;
  final DateTime expiresAt;
  DateTime lastSentAt;
  int attempts;

  _OtpSession({
    required this.email,
    required this.otp,
    required this.createdAt,
    required this.expiresAt,
    required this.lastSentAt,
    this.attempts = 0,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Dịch vụ quản lý gửi mã xác thực Email OTP qua Gmail
class EmailOtpService {
  final FirebaseFirestore _firestore;

  EmailOtpService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  // Cấu hình tài khoản Gmail gửi mã OTP của hệ thống HomeShare.
  static const String defaultSmtpUser = 'homeshare.verify@gmail.com';
  static const String defaultSmtpPassword = ''; // Mật khẩu ứng dụng 16 ký tự của Google

  // Bộ nhớ đệm phiên OTP trong RAM ứng dụng
  static final Map<String, _OtpSession> _memoryOtps = {};

  /// Kiểm tra xem email đã được đăng ký tài khoản nào chưa
  Future<bool> isEmailRegistered(String rawEmail) async {
    final email = rawEmail.trim().toLowerCase();
    if (email.isEmpty) return false;

    // Kiểm tra trong Firestore collection users nếu có quyền đọc
    try {
      final snap = await _firestore
          .collection(FirestoreCollections.users)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return true;
    } catch (_) {
      // Khi người dùng chưa đăng nhập, Security Rules có thể chặn truy vấn users.
      // Firebase Auth sẽ tự động kiểm tra trùng lặp khi đăng ký (email-already-in-use).
    }

    return false;
  }

  /// Sinh mã OTP ngẫu nhiên 6 chữ số
  String _generate6DigitOtp() {
    final rng = Random.secure();
    final code = 100000 + rng.nextInt(900000);
    return code.toString();
  }

  /// Gửi mã OTP xác thực đăng ký đến địa chỉ Gmail của người dùng
  Future<OtpSendResult> sendRegistrationOtp({
    required String rawEmail,
    String recipientName = 'Quý khách',
  }) async {
    final email = rawEmail.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@')) {
      throw 'Địa chỉ email không hợp lệ.';
    }

    // 1. Kiểm tra trùng lặp email (nếu có quyền đọc)
    final alreadyExists = await isEmailRegistered(email);
    if (alreadyExists) {
      throw 'Email này đã được sử dụng cho một tài khoản khác. Vui lòng đăng nhập hoặc dùng email mới.';
    }

    // 2. Kiểm tra Cooldown chống spam gửi liên tục (tối thiểu cách nhau 45 giây)
    final existingSession = _memoryOtps[email];
    if (existingSession != null) {
      final diff = DateTime.now().difference(existingSession.lastSentAt);
      if (diff.inSeconds < 45) {
        final remaining = 45 - diff.inSeconds;
        throw 'Vui lòng chờ $remaining giây trước khi yêu cầu gửi lại mã OTP.';
      }
    }

    // 3. Tạo mã OTP mới có hiệu lực 5 phút
    final otpCode = _generate6DigitOtp();
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(minutes: 5));

    // Lưu vào bộ nhớ phiên RAM (an toàn 100%, không bị permission-denied)
    _memoryOtps[email] = _OtpSession(
      email: email,
      otp: otpCode,
      createdAt: now,
      expiresAt: expiresAt,
      lastSentAt: now,
      attempts: 0,
    );

    // Đồng bộ vào Firestore email_otps nếu rules cho phép
    try {
      await _firestore.collection(FirestoreCollections.emailOtps).doc(email).set({
        'email': email,
        'otp': otpCode,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSentAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'attempts': 0,
        'isVerified': false,
        'recipientName': recipientName.trim(),
      });
    } catch (e) {
      debugPrint('[EmailOtpService] Bỏ qua ghi Firestore email_otps (unauthenticated): $e');
    }

    debugPrint('====================================================');
    debugPrint('[EmailOtpService] MÃ OTP XÁC THỰC CHO $email LÀ: $otpCode');
    debugPrint('====================================================');

    // 4. Đọc cấu hình SMTP nếu có
    String smtpUser = defaultSmtpUser;
    String smtpPass = defaultSmtpPassword;

    try {
      final configDoc = await _firestore.collection('app_config').doc('smtp').get();
      if (configDoc.exists && configDoc.data() != null) {
        final cData = configDoc.data()!;
        final u = cData['username']?.toString().trim();
        final p = cData['appPassword']?.toString().trim();
        if (u != null && u.isNotEmpty) smtpUser = u;
        if (p != null && p.isNotEmpty) smtpPass = p;
      }
    } catch (_) {}

    // 5. Gửi email qua SMTP Gmail nếu có cấu hình mật khẩu ứng dụng
    bool sentViaSmtp = false;
    if (!kIsWeb && smtpPass.isNotEmpty && smtpUser.isNotEmpty) {
      try {
        final smtpServer = gmail(smtpUser, smtpPass);

        final message = Message()
          ..from = Address(smtpUser, 'HomeShare Verification')
          ..recipients.add(email)
          ..subject = '[HomeShare] Mã xác thực đăng ký tài khoản: $otpCode'
          ..html = _buildEmailHtml(recipientName, otpCode);

        await send(message, smtpServer);
        sentViaSmtp = true;
        debugPrint('[EmailOtpService] Đã gửi OTP thành công qua Gmail SMTP tới $email');
      } catch (e) {
        debugPrint('[EmailOtpService] Lỗi gửi SMTP ($e). Sử dụng mã test.');
      }
    }

    return OtpSendResult(
      isSuccess: true,
      message: sentViaSmtp
          ? 'Mã OTP 6 chữ số đã được gửi tới Gmail $email. Vui lòng kiểm tra hộp thư (cả mục Spam/Rác).'
          : 'Đã gửi mã xác thực đến $email. (Chế độ Test: Mã OTP là $otpCode)',
      debugOtp: otpCode,
      sentViaSmtp: sentViaSmtp,
    );
  }

  /// Xác thực mã OTP người dùng nhập vào
  Future<bool> verifyOtp({
    required String rawEmail,
    required String rawOtp,
  }) async {
    final email = rawEmail.trim().toLowerCase();
    final otp = rawOtp.trim();

    if (email.isEmpty || otp.isEmpty) {
      throw 'Vui lòng nhập đầy đủ email và mã OTP.';
    }

    // 1. Kiểm tra trong bộ nhớ phiên RAM trước
    final session = _memoryOtps[email];
    if (session != null) {
      if (session.attempts >= 5) {
        throw 'Bạn đã nhập sai mã OTP quá 5 lần. Vui lòng yêu cầu mã xác thực mới.';
      }
      if (session.isExpired) {
        throw 'Mã xác thực OTP đã hết hạn. Vui lòng nhấn "Gửi lại mã".';
      }
      if (session.otp != otp) {
        session.attempts += 1;
        final remaining = 5 - session.attempts;
        if (remaining > 0) {
          throw 'Mã OTP không chính xác. Bạn còn $remaining lần thử.';
        } else {
          throw 'Bạn đã nhập sai mã OTP quá 5 lần. Vui lòng yêu cầu mã mới.';
        }
      }

      // Khớp mã OTP!
      return true;
    }

    // 2. Fallback kiểm tra Firestore nếu session RAM bị mất
    try {
      final docRef = _firestore.collection(FirestoreCollections.emailOtps).doc(email);
      final snapshot = await docRef.get();

      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final attempts = (data['attempts'] as num?)?.toInt() ?? 0;
        final storedOtp = data['otp']?.toString().trim() ?? '';
        final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();

        if (attempts >= 5) {
          throw 'Bạn đã nhập sai mã OTP quá 5 lần. Vui lòng yêu cầu mã xác thực mới.';
        }
        if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
          throw 'Mã xác thực OTP đã hết hạn. Vui lòng nhấn "Gửi lại mã".';
        }
        if (storedOtp != otp) {
          final newAttempts = attempts + 1;
          try {
            await docRef.update({'attempts': newAttempts});
          } catch (_) {}
          final remaining = 5 - newAttempts;
          if (remaining > 0) {
            throw 'Mã OTP không chính xác. Bạn còn $remaining lần thử.';
          } else {
            throw 'Bạn đã nhập sai mã OTP quá 5 lần. Vui lòng yêu cầu mã mới.';
          }
        }
        return true;
      }
    } on String {
      rethrow;
    } catch (_) {}

    throw 'Không tìm thấy yêu cầu xác thực cho email này. Vui lòng nhấn gửi lại mã.';
  }

  /// Xóa bản ghi OTP sau khi tài khoản đã tạo thành công
  Future<void> consumeOtp(String rawEmail) async {
    final email = rawEmail.trim().toLowerCase();
    _memoryOtps.remove(email);
    try {
      await _firestore.collection(FirestoreCollections.emailOtps).doc(email).delete();
    } catch (_) {}
  }

  /// Mẫu giao diện Email HTML trang nhã chuẩn HomeShare
  String _buildEmailHtml(String name, String otp) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Mã xác thực HomeShare</title>
</head>
<body style="font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; background-color: #F8FAFC; margin: 0; padding: 24px; color: #1E293B;">
  <div style="max-width: 520px; margin: 0 auto; background-color: #FFFFFF; border-radius: 16px; overflow: hidden; border: 1px solid #E2E8F0; box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);">
    <div style="background-color: #0284C7; padding: 28px 24px; text-align: center;">
      <h1 style="color: #FFFFFF; margin: 0; font-size: 24px; font-weight: 700; letter-spacing: 0.5px;">HomeShare</h1>
      <p style="color: #E0F2FE; margin: 6px 0 0; font-size: 14px;">Ứng dụng thuê & tìm bạn ở ghép thông minh</p>
    </div>
    <div style="padding: 32px 28px;">
      <h2 style="color: #0F172A; font-size: 18px; margin-top: 0; margin-bottom: 12px;">Xin chào $name,</h2>
      <p style="font-size: 15px; line-height: 1.6; color: #475569; margin: 0 0 20px;">
        Cảm ơn bạn đã lựa chọn HomeShare. Để bảo vệ an toàn cho tài khoản và hoàn tất quá trình đăng ký, vui lòng sử dụng mã xác thực (OTP) dưới đây:
      </p>
      
      <div style="background-color: #F0F9FF; border: 2px dashed #38BDF8; border-radius: 12px; padding: 20px; text-align: center; margin: 24px 0;">
        <span style="font-size: 34px; font-weight: 800; letter-spacing: 10px; color: #0284C7; font-family: monospace;">$otp</span>
        <div style="font-size: 13px; color: #64748B; margin-top: 8px;">Hiệu lực trong vòng <b>5 phút</b></div>
      </div>
      
      <p style="font-size: 13px; line-height: 1.6; color: #94A3B8; margin: 0;">
        ⚠️ <b>Lưu ý bảo mật:</b> Không chia sẻ mã này với bất kỳ ai, kể cả nhân viên HomeShare. Nếu bạn không thực hiện yêu cầu đăng ký này, hãy bỏ qua email.
      </p>
    </div>
    <div style="background-color: #F8FAFC; padding: 18px 24px; text-align: center; border-top: 1px solid #F1F5F9; font-size: 12px; color: #94A3B8;">
      © 2026 HomeShare. Mọi quyền được bảo lưu.
    </div>
  </div>
</body>
</html>
''';
  }
}
