import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/phong_sang_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_form_card.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import '../../renter/screens/renter_main_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? initialEmail;
  const LoginScreen({super.key, this.initialEmail});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _lockNotice;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    final pending = AuthService.pendingLockNotice;
    if (pending != null) {
      _lockNotice = pending;
      AuthService.pendingLockNotice = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showLockDialog());
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithEmail(
        email: _resolveEmail(_emailController.text),
        password: _passwordController.text,
      );

      // Đảm bảo khi đăng nhập, màn hình đầu tiên của người thuê LUÔN LUÔN là Dashboard (index 0)
      ref.read(renterBottomNavIndexProvider.notifier).setIndex(0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng nhập thành công!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      if (message == AuthService.lockedAccountMessage) {
        AuthService.pendingLockNotice = null;
        setState(() => _lockNotice = message);
        await _showLockDialog();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showLockDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.lock_outline, color: AppColors.danger, size: 32),
        title: const Text('Tài khoản đã bị khóa'),
        content: const Text(AuthService.lockedAccountMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: PhongSangColors.accentSoft,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.home_work_rounded,
                        size: 40,
                        color: PhongSangColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'HomeShare',
                    textAlign: TextAlign.center,
                    style: PhongSangText.screenTitle.copyWith(fontSize: 32),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Đăng nhập để tìm phòng và kết nối ở ghép',
                    textAlign: TextAlign.center,
                    style: PhongSangText.body.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 28),
                  AuthFormCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'vidu@gmail.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          suffixIcon: _emailController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18, color: PhongSangColors.muted),
                                  onPressed: () => setState(() => _emailController.clear()),
                                )
                              : null,
                          validator: _validateEmail,
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _passwordController,
                          label: 'Mật khẩu',
                          hint: 'Nhập mật khẩu',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: PhongSangColors.muted,
                              size: 22,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Vui lòng nhập mật khẩu';
                            }
                            if (val.length < 6) {
                              return 'Mật khẩu tối thiểu 6 ký tự';
                            }
                            return null;
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ForgotPasswordScreen(initialEmail: _resolveEmail(_emailController.text)),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: PhongSangColors.accent,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                            ),
                            child: Text(
                              'Quên mật khẩu?',
                              style: PhongSangText.label(color: PhongSangColors.accent, fontSize: 15),
                            ),
                          ),
                        ),
                        if (_lockNotice != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.dangerContainer,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.danger),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lock_outline, color: AppColors.danger),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _lockNotice!,
                                    style: const TextStyle(
                                      color: AppColors.danger,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PhongSangColors.accent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                  )
                                : Text('Đăng nhập', style: PhongSangText.button.copyWith(fontSize: 17)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Chưa có tài khoản? ', style: PhongSangText.body.copyWith(fontSize: 16)),
                      GestureDetector(
                        onTap: () async {
                          final registeredEmail = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          );
                          if (registeredEmail != null && registeredEmail.isNotEmpty && mounted) {
                            setState(() {
                              _emailController.text = registeredEmail;
                              _passwordController.clear();
                            });
                          }
                        },
                        child: Text(
                          'Đăng ký ngay',
                          style: PhongSangText.label(color: PhongSangColors.accent, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _resolveEmail(String raw) {
    final value = raw.trim();
    if (!value.contains('@') && value.isNotEmpty) {
      return '$value@gmail.com';
    }
    return value;
  }

  String? _validateEmail(String? val) {
    final text = (val ?? '').trim();
    if (text.isEmpty) return 'Vui lòng nhập email';
    if (text.contains('@')) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(text)) {
        return 'Email không hợp lệ (Ví dụ: vidu@gmail.com)';
      }
    } else {
      if (!RegExp(r'^[A-Za-z0-9._+-]+$').hasMatch(text)) {
        return 'Email chứa ký tự không hợp lệ';
      }
    }
    return null;
  }
}
