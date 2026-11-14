import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/email_otp_service.dart';

/// Bottom Sheet nhập mã OTP 6 số xác thực Email đăng ký HomeShare
class EmailOtpVerificationSheet extends ConsumerStatefulWidget {
  final String email;
  final String recipientName;
  final String? initialDebugOtp;

  const EmailOtpVerificationSheet({
    super.key,
    required this.email,
    required this.recipientName,
    this.initialDebugOtp,
  });

  /// Hàm tiện ích mở Bottom Sheet
  static Future<bool?> show(
    BuildContext context, {
    required String email,
    required String recipientName,
    String? initialDebugOtp,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EmailOtpVerificationSheet(
        email: email,
        recipientName: recipientName,
        initialDebugOtp: initialDebugOtp,
      ),
    );
  }

  @override
  ConsumerState<EmailOtpVerificationSheet> createState() =>
      _EmailOtpVerificationSheetState();
}

class _EmailOtpVerificationSheetState
    extends ConsumerState<EmailOtpVerificationSheet> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  Timer? _resendTimer;
  int _secondsRemaining = 60;
  bool _canResend = false;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _currentDebugOtp;

  @override
  void initState() {
    super.initState();
    _currentDebugOtp = widget.initialDebugOtp;
    _startTimer();

    // Tự động focus vào ô đầu tiên
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  void _startTimer() {
    _secondsRemaining = 60;
    _canResend = false;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        if (mounted) setState(() => _canResend = true);
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredOtp =>
      _controllers.map((c) => c.text.trim()).join();

  Future<void> _handleVerify() async {
    final otp = _enteredOtp;
    if (otp.length < 6) {
      setState(() => _errorMessage = 'Vui lòng nhập đủ 6 chữ số mã OTP.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final emailService = ref.read(emailOtpServiceProvider);
      await emailService.verifyOtp(
        rawEmail: widget.email,
        rawOtp: otp,
      );

      if (mounted) {
        Navigator.pop(context, true); // Trả về true báo hiệu xác thực thành công
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
        // Rung nhẹ và xóa mã nếu sai
        HapticFeedback.vibrate();
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _handleResend() async {
    if (!_canResend || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final emailService = ref.read(emailOtpServiceProvider);
      final result = await emailService.sendRegistrationOtp(
        rawEmail: widget.email,
        recipientName: widget.recipientName,
      );

      _currentDebugOtp = result.debugOtp;
      _startTimer();

      // Clear input
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: bottomInset > 0 ? bottomInset + 20 : 32,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thanh kéo trên đỉnh sheet
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header icon & tiêu đề
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.mark_email_read_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xác thực Gmail đăng ký',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Nhập mã 6 chữ số gửi đến hòm thư',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Địa chỉ email nhận mã
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.email_outlined, size: 18, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.email,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Hiển thị mã debug nếu đang ở chế độ test
          if (_currentDebugOtp != null && _currentDebugOtp!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFB45309)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Mã thử nghiệm nhanh: $_currentDebugOtp',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      for (int i = 0; i < 6 && i < _currentDebugOtp!.length; i++) {
                        _controllers[i].text = _currentDebugOtp![i];
                      }
                      setState(() {});
                      _handleVerify();
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'Tự điền',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 22),

          // 6 Ô NHẬP MÃ OTP
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              return SizedBox(
                width: 46,
                height: 54,
                child: TextField(
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(1),
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.zero,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _controllers[index].text.isNotEmpty
                            ? AppColors.primary
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  onChanged: (val) {
                    if (val.isNotEmpty && index < 5) {
                      _focusNodes[index + 1].requestFocus();
                    } else if (val.isEmpty && index > 0) {
                      _focusNodes[index - 1].requestFocus();
                    }
                    setState(() {});
                    // Tự động kiểm tra khi nhập đủ 6 số
                    if (_enteredOtp.length == 6) {
                      _handleVerify();
                    }
                  },
                ),
              );
            }),
          ),

          // Thông báo lỗi
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 20),

          // Nút đếm ngược & Gửi lại mã
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _canResend
                    ? 'Không nhận được mã? '
                    : 'Gửi lại mã sau $_secondsRemaining giây ',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              if (_canResend)
                InkWell(
                  onTap: _isResending ? null : _handleResend,
                  child: _isResending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Gửi lại ngay',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                ),
            ],
          ),

          const SizedBox(height: 22),

          // Nút Xác nhận & Hoàn tất
          ElevatedButton(
            onPressed: _isVerifying || _enteredOtp.length < 6
                ? null
                : _handleVerify,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
            ),
            child: _isVerifying
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Xác nhận & Hoàn tất đăng ký',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
