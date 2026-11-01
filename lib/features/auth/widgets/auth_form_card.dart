import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/phong_sang_theme.dart';

/// Card bọc cụm ô nhập trên màn đăng nhập và đăng ký. Màu theo theme hiện tại.
class AuthFormCard extends StatelessWidget {
  final Widget child;

  const AuthFormCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withValues(alpha: 0.06),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Ô nhập cao, nền xám nhạt, dễ chạm trên điện thoại.
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AppColors.border),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: PhongSangText.label(color: AppColors.textDark, fontSize: 15),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: PhongSangText.search.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textDark,
          ),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: PhongSangText.search.copyWith(
              fontSize: 15,
              color: AppColors.textMuted,
            ),
            prefixIcon: Icon(icon, size: 22, color: AppColors.textMuted),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 50,
              minHeight: 58,
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.surfaceVariant,
            isDense: false,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 17,
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: BorderSide(
                color: AppColors.primary,
                width: 1.6,
              ),
            ),
            errorBorder: border.copyWith(
              borderSide: BorderSide(color: AppColors.danger),
            ),
            focusedErrorBorder: border.copyWith(
              borderSide: BorderSide(
                color: AppColors.danger,
                width: 1.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
