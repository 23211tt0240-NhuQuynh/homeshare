import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
<<<<<<< HEAD
import '../../../core/services/auth_service.dart';
import '../../../core/theme/phong_sang_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_form_card.dart';
import 'forgot_password_screen.dart';
=======
import '../providers/auth_provider.dart';
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? initialEmail;
  const LoginScreen({super.key, this.initialEmail});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
<<<<<<< HEAD
  static const _gmailSuffix = '@gmail.com';

=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
<<<<<<< HEAD
  String? _lockNotice;
=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    _emailController = TextEditingController(text: _gmailLocalPart(widget.initialEmail ?? ''));
    final pending = AuthService.pendingLockNotice;
    if (pending != null) {
      _lockNotice = pending;
      AuthService.pendingLockNotice = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showLockDialog());
    }
=======
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
<<<<<<< HEAD
        email: _fullGmail(_emailController.text),
=======
        email: _emailController.text,
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
        password: _passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng nhập thành công!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
<<<<<<< HEAD
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
=======
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

<<<<<<< HEAD
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

=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
<<<<<<< HEAD
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
                          hint: 'an.nguyen',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          suffixIcon: const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Text(
                              _gmailSuffix,
                              style: TextStyle(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          validator: _validateGmailLocal,
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
                                  builder: (_) => ForgotPasswordScreen(initialEmail: _fullGmail(_emailController.text)),
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
=======
                  // App Brand Logo with Emerald Accent
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.home_work_rounded,
                        size: 44,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'HomeShare',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Đăng nhập để tìm phòng & kết nối ở ghép',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Email Input
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'vidu@email.com',
                      prefixIcon: Icon(Icons.email_outlined, color: AppColors.textMuted),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng nhập email';
                      }
                      if (!val.contains('@') || !val.contains('.')) {
                        return 'Email không hợp lệ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Input
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textMuted,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
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
                  const SizedBox(height: 12),

                  // Quên mật khẩu
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text(
                        'Quên mật khẩu?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Login Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Đăng Nhập',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Điều hướng sang Đăng ký
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Chưa có tài khoản? ',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
<<<<<<< HEAD
                              _emailController.text = _gmailLocalPart(registeredEmail);
=======
                              _emailController.text = registeredEmail;
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                              _passwordController.clear();
                            });
                          }
                        },
<<<<<<< HEAD
                        child: Text(
                          'Đăng ký ngay',
                          style: PhongSangText.label(color: PhongSangColors.accent, fontSize: 16),
=======
                        child: const Text(
                          'Đăng ký ngay',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
<<<<<<< HEAD

  String _gmailLocalPart(String raw) {
    var value = raw.trim();
    if (value.toLowerCase().endsWith(_gmailSuffix)) {
      value = value.substring(0, value.length - _gmailSuffix.length).trim();
    }
    return value;
  }

  String _fullGmail(String raw) => '${_gmailLocalPart(raw)}$_gmailSuffix';

  String? _validateGmailLocal(String? val) {
    final local = _gmailLocalPart(val ?? '');
    if (local.isEmpty) return 'Vui lòng nhập email';
    if (!RegExp(r'^[A-Za-z0-9._+-]+$').hasMatch(local)) {
      return 'Chỉ nhập phần tên trước @gmail.com';
    }
    return null;
  }
=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
}
