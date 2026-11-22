import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/phong_sang_theme.dart';
import '../providers/auth_provider.dart';
import '../services/email_verification_policy.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  int _resendSeconds = 60;
  bool _isChecking = false;
  bool _isResending = false;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCountdown();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isChecking) {
      _checkVerification(showPendingMessage: false);
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    setStateIfMounted(() => _resendSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  void setStateIfMounted(VoidCallback callback) {
    if (mounted) setState(callback);
  }

  Future<void> _checkVerification({bool showPendingMessage = true}) async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    try {
      final verified = await ref
          .read(authServiceProvider)
          .refreshEmailVerificationStatus();
      if (!mounted) return;
      if (verified) {
        await _completeRegistration();
      } else if (showPendingMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Firebase chưa ghi nhận xác thực. Hãy bấm link trong Gmail rồi thử lại.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _completeRegistration() async {
    if (_isCompleting || !mounted) return;
    _isCompleting = true;

    final successDialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          icon: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 54,
          ),
          title: const Text('Đăng ký thành công', textAlign: TextAlign.center),
          content: Text(
            'Tài khoản ${EmailVerificationPolicy.maskEmail(widget.email)} đã được xác thực. Đang chuyển đến màn hình đăng nhập...',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    await successDialog;

    if (!mounted) return;
    try {
      final authService = ref.read(authServiceProvider);
      await authService.activateVerifiedEmail();
      AuthService.pendingLoginEmail = widget.email.trim().toLowerCase();
      await authService.signOut();
    } catch (e) {
      _isCompleting = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _resendEmail() async {
    if (_resendSeconds > 0 || _isResending) return;
    setState(() => _isResending = true);
    try {
      await ref.read(authServiceProvider).sendEmailVerification();
      if (!mounted) return;
      _startCountdown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã gửi lại link xác thực. Hãy kiểm tra cả thư mục Spam.',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _openGmail() async {
    final opened = await launchUrl(
      Uri.parse('https://mail.google.com/mail/u/0/#inbox'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được Gmail trên thiết bị này.')),
      );
    }
  }

  Future<void> _changeAccount() async {
    await ref.read(authServiceProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x140F172A),
                      blurRadius: 28,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: const Icon(
                          Icons.mark_email_unread_rounded,
                          color: AppColors.primary,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Xác thực tài khoản',
                      textAlign: TextAlign.center,
                      style: PhongSangText.screenTitle.copyWith(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'HomeShare đã gửi link xác thực đến',
                      textAlign: TextAlign.center,
                      style: PhongSangText.body.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      EmailVerificationPolicy.maskEmail(widget.email),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Text(
                        'Bấm link trong email, quay lại ứng dụng rồi chọn “Tôi đã xác thực”. Nếu chưa thấy thư, hãy kiểm tra Spam.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF92400E),
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _isChecking ? null : _checkVerification,
                      icon: _isChecking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified_rounded),
                      label: const Text('Tôi đã xác thực'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _openGmail,
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Mở Gmail'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _resendSeconds == 0 && !_isResending
                          ? _resendEmail
                          : null,
                      child: Text(
                        _isResending
                            ? 'Đang gửi lại...'
                            : _resendSeconds > 0
                            ? 'Gửi lại sau $_resendSeconds giây'
                            : 'Gửi lại email xác thực',
                      ),
                    ),
                    TextButton(
                      onPressed: _changeAccount,
                      child: const Text('Đổi tài khoản / sửa Gmail'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
