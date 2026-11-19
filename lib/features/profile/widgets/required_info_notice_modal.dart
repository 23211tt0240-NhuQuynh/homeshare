import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/vietnam_banks.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../core/services/user_uniqueness_service.dart';
import '../../auth/providers/user_provider.dart';

/// Hộp thoại/BottomSheet nhắc nhở và yêu cầu người dùng cập nhật đầy đủ Số điện thoại & STK ngân hàng
/// ngay sau khi đăng nhập (tương tự như màn hình/modal xác thực CCCD).
/// Bao gồm kiểm tra tính độc nhất (không trùng với tài khoản khác).
class RequiredInfoNoticeModal extends ConsumerStatefulWidget {
  final UserProfile profile;
  final BankAccount? initialBankAccount;
  final VoidCallback? onCompleted;

  const RequiredInfoNoticeModal({
    super.key,
    required this.profile,
    this.initialBankAccount,
    this.onCompleted,
  });

  /// Hiển thị Modal bắt buộc cập nhật SĐT và STK ngân hàng
  static Future<bool?> show(
    BuildContext context, {
    required UserProfile profile,
    BankAccount? initialBankAccount,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // Bắt buộc người dùng không được bỏ sót
      builder: (ctx) => RequiredInfoNoticeModal(
        profile: profile,
        initialBankAccount: initialBankAccount,
      ),
    );
  }

  @override
  ConsumerState<RequiredInfoNoticeModal> createState() =>
      _RequiredInfoNoticeModalState();
}

class _RequiredInfoNoticeModalState extends ConsumerState<RequiredInfoNoticeModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _accountHolderController;
  String _selectedBank = '';
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.profile.phoneNumber);
    _accountNumberController = TextEditingController(
      text: widget.initialBankAccount?.accountNumber ?? '',
    );
    _accountHolderController = TextEditingController(
      text: widget.initialBankAccount?.accountHolder.isNotEmpty == true
          ? widget.initialBankAccount!.accountHolder
          : widget.profile.displayName,
    );
    _selectedBank = widget.initialBankAccount?.bankName ?? '';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBank.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng chọn ngân hàng';
      });
      return;
    }

    final phone = _phoneController.text.trim();
    final accountNumber = _accountNumberController.text.trim();
    final accountHolder = _accountHolderController.text.trim();
    final bankName = _selectedBank.trim();

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final uniquenessService = UserUniquenessService();

      // 1. Kiểm tra tính độc nhất của Số điện thoại
      final phoneError = await uniquenessService.checkPhoneNumberUnique(
        phone,
        excludeUid: widget.profile.uid,
      );
      if (phoneError != null) {
        throw phoneError;
      }

      // 2. Kiểm tra tính độc nhất của Số tài khoản ngân hàng
      final bankError = await uniquenessService.checkBankAccountUnique(
        accountNumber,
        excludeUid: widget.profile.uid,
      );
      if (bankError != null) {
        throw bankError;
      }

      // 3. Chỉ lưu SĐT và STK, không thay đổi các phần hồ sơ khác.
      await ref.read(userProfileServiceProvider).saveRequiredAccountInfo(
            uid: widget.profile.uid,
            phoneNumber: phone,
            accountNumber: accountNumber,
            accountHolder: accountHolder,
            bankName: bankName,
          );

      ref.invalidate(userProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật SĐT và STK ngân hàng thành công!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
        widget.onCompleted?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        elevation: 16,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mascot / Icon cảnh báo thông tin
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      size: 36,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tiêu đề
                const Text(
                  'Yêu Cầu Cập Nhật Thông Tin',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),

                // Mô tả dí dỏm và rõ ràng
                const Text(
                  'Để đảm bảo an toàn giao dịch, chuyển cọc và hỗ trợ liên hệ tức thì, vui lòng hoàn tất Số điện thoại và STK ngân hàng chính chủ của bạn (mỗi tài khoản là độc nhất).',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),

                // Banner an toàn & độc nhất
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 18, color: Color(0xFF16A34A)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'SĐT, STK và CCCD được kiểm tra và liên kết riêng với từng tài khoản.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 1. Số điện thoại
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Số điện thoại *',
                    hintText: 'Ví dụ: 0912345678',
                    prefixIcon: const Icon(Icons.phone_iphone_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Vui lòng nhập số điện thoại';
                    }
                    final clean = UserUniquenessService.normalizePhone(val);
                    final phoneRegex = RegExp(r'^0\d{9}$');
                    if (!phoneRegex.hasMatch(clean)) {
                      return 'SĐT phải gồm 10 chữ số (bắt đầu bằng số 0)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 2. Ngân hàng
                DropdownButtonFormField<String>(
                  initialValue: _selectedBank.isNotEmpty && vietnamBanks.contains(_selectedBank)
                      ? _selectedBank
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Ngân hàng nhận tiền / hoàn cọc *',
                    hintText: 'Chọn ngân hàng',
                    prefixIcon: const Icon(Icons.account_balance_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: vietnamBanks
                      .map(
                        (bank) => DropdownMenuItem<String>(
                          value: bank,
                          child: Text(bank, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedBank = val ?? '';
                      _errorMessage = null;
                    });
                  },
                ),
                const SizedBox(height: 14),

                // 3. Số tài khoản ngân hàng
                TextFormField(
                  controller: _accountNumberController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Số tài khoản ngân hàng (STK) *',
                    hintText: 'Nhập số tài khoản',
                    prefixIcon: const Icon(Icons.credit_card_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Vui lòng nhập số tài khoản ngân hàng';
                    }
                    final clean = UserUniquenessService.normalizeBankAccount(val);
                    if (!RegExp(r'^\d{6,19}$').hasMatch(clean)) {
                      return 'STK phải gồm từ 6 đến 19 chữ số';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 4. Chủ tài khoản
                TextFormField(
                  controller: _accountHolderController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Tên chủ tài khoản (viết hoa không dấu) *',
                    hintText: 'Ví dụ: NGUYEN VAN AN',
                    prefixIcon: const Icon(Icons.person_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Vui lòng nhập tên chủ tài khoản';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Nút Xác nhận cập nhật
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF155EEF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Lưu & Tiếp tục',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
