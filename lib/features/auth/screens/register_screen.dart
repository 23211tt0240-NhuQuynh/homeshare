import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/phong_sang_theme.dart';
import '../providers/auth_provider.dart';
import '../services/email_verification_policy.dart';
import '../widgets/auth_form_card.dart';

/// Màn hình Đăng Ký Tài Khoản HomeShare (Hỗ trợ 2 Role: Người thuê & Chủ trọ)
/// Theo chuẩn Moodboard Phòng Sáng (phong_sang_theme.dart)
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Role người dùng: 'renter' (người thuê) hoặc 'host' (chủ trọ)
  String _selectedRole = 'renter';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng đồng ý với Điều khoản dịch vụ và Chính sách của HomeShare.',
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final targetEmail = _emailController.text.trim().toLowerCase();
    final targetName = _nameController.text.trim();
    final targetPassword = _passwordController.text.trim();
    final targetPhone = _phoneController.text.trim();

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signUpWithEmail(
        email: targetEmail,
        password: targetPassword,
        displayName: targetName,
        phoneNumber: targetPhone,
        role: _selectedRole,
      );

      if (!mounted) return;
      // RegisterScreen được push trên Navigator của AuthGate. Phải đóng route
      // này sau khi Firebase đăng nhập tài khoản chờ, nếu không nó sẽ che màn
      // hình xác thực email đang được AuthGate dựng ở phía dưới.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Tạo tài khoản',
          style: PhongSangText.roomName.copyWith(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 4,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textDark,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 12.0,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tạo không gian sống của riêng bạn',
                      style: PhongSangText.screenTitle.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Chọn vai trò để bắt đầu cùng HomeShare.',
                      style: PhongSangText.body.copyWith(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'BẠN THAM GIA VỚI VAI TRÒ NÀO?',
                      style: PhongSangText.label(
                        color: const Color(0xFF64748B),
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final renterCard = _buildRoleCard(
                          role: 'renter',
                          title: 'Người thuê',
                          subtitle: 'Tìm phòng, căn hộ & bạn ở ghép',
                          icon: Icons.person_search_rounded,
                        );
                        final hostCard = _buildRoleCard(
                          role: 'host',
                          title: 'Chủ trọ',
                          subtitle: 'Đăng tin phòng & tìm khách thuê',
                          icon: Icons.domain_rounded,
                        );
                        if (constraints.maxWidth < 380) {
                          return Column(
                            children: [
                              renterCard,
                              const SizedBox(height: 10),
                              hostCard,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: renterCard),
                            const SizedBox(width: 12),
                            Expanded(child: hostCard),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // 2. KHUNG ĐIỀN THÔNG TIN TÀI KHOẢN
                    AuthFormCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AuthTextField(
                            controller: _nameController,
                            label: 'Họ và tên *',
                            hint: 'Ví dụ: Nguyễn Văn An',
                            icon: Icons.person_outline_rounded,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Vui lòng nhập họ và tên';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Email
                          AuthTextField(
                            controller: _emailController,
                            label: 'Email *',
                            hint: 'an.nguyen@gmail.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 16),

                          // Số điện thoại
                          AuthTextField(
                            controller: _phoneController,
                            label: 'Số điện thoại *',
                            hint: '0901234567',
                            icon: Icons.phone_iphone_rounded,
                            keyboardType: TextInputType.phone,
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Vui lòng nhập số điện thoại';
                              }
                              final phoneRegex = RegExp(r'^0\d{9}$');
                              if (!phoneRegex.hasMatch(val.trim())) {
                                return 'Số điện thoại phải gồm 10 chữ số (bắt đầu bằng 0)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Mật khẩu
                          AuthTextField(
                            controller: _passwordController,
                            label: 'Mật khẩu *',
                            hint: 'Tối thiểu 6 ký tự',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
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
                          const SizedBox(height: 16),

                          // Xác nhận mật khẩu
                          AuthTextField(
                            controller: _confirmPasswordController,
                            label: 'Xác nhận mật khẩu *',
                            hint: 'Nhập lại mật khẩu vừa tạo',
                            icon: Icons.verified_user_outlined,
                            obscureText: _obscureConfirmPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              ),
                            ),
                            validator: (val) {
                              if (val != _passwordController.text) {
                                return 'Mật khẩu xác nhận không khớp';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          InkWell(
                            onTap: () =>
                                setState(() => _agreeToTerms = !_agreeToTerms),
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: Checkbox(
                                    value: _agreeToTerms,
                                    activeColor: AppColors.primary,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    onChanged: (val) => setState(
                                      () => _agreeToTerms = val ?? false,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Tôi đồng ý với Điều khoản dịch vụ và Chính sách quyền riêng tư của HomeShare.',
                                    style: PhongSangText.body.copyWith(
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 3. NÚT ĐĂNG KÝ
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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
                            : Text(
                                'Đăng ký tài khoản (${_selectedRole == 'host' ? 'Chủ trọ' : 'Người thuê'})',
                                style: PhongSangText.button.copyWith(
                                  fontSize: 17,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 4. QUAY VỀ ĐĂNG NHẬP
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Đã có tài khoản? ',
                          style: PhongSangText.body.copyWith(fontSize: 16),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            'Đăng nhập ngay',
                            style: PhongSangText.label(
                              color: PhongSangColors.accent,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? val) {
    final email = (val ?? '').trim().toLowerCase();
    if (email.isEmpty) return 'Vui lòng nhập email';
    if (!EmailVerificationPolicy.isSupportedGmail(email)) {
      return 'Vui lòng dùng địa chỉ Gmail hợp lệ (@gmail.com)';
    }
    return null;
  }

  // Thẻ lựa chọn Role trực quan (Người thuê / Chủ trọ)
  Widget _buildRoleCard({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;

    return InkWell(
      onTap: () => setState(() => _selectedRole = role),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryContainer.withValues(alpha: 0.3)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.priceSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: isSelected ? Colors.white : AppColors.textDark,
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13.5,
                color: isSelected ? AppColors.textDark : AppColors.textMuted,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
