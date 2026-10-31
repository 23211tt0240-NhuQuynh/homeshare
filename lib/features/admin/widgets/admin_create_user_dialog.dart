import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Hộp thoại Admin tạo người dùng mới trực tiếp vào hệ thống.
class AdminCreateUserDialog extends StatefulWidget {
  const AdminCreateUserDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AdminCreateUserDialog(),
    );
  }

  @override
  State<AdminCreateUserDialog> createState() => _AdminCreateUserDialogState();
}

class _AdminCreateUserDialogState extends State<AdminCreateUserDialog> {
  static const _primary = Color(0xFF398FC0);
  static const _textDark = Color(0xFF101828);
  static const _textGrey = Color(0xFF667085);
  static const _red = Color(0xFFD92D20);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController(text: '123456');

  String _role = 'renter';
  int _initialRepScore = 100;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final name = _nameCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final password = _passwordCtrl.text.trim();

      final db = FirebaseFirestore.instance;
      // Sinh ID người dùng mới
      final userRef = db.collection('users').doc();
      final userId = userRef.id;

      final userData = {
        'id': userId,
        'uid': userId,
        'fullName': name,
        'displayName': name,
        'name': name,
        'email': email,
        'phoneNumber': phone,
        'phone': phone,
        'role': _role,
        'isBanned': false,
        'reputationScore': _initialRepScore,
        'diemUyTin': _initialRepScore,
        'warningCount': 0,
        'avatarUrl': '',
        'initialPassword': password,
        'createdBy': 'Admin',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await userRef.set(userData);

      // Ghi audit log
      await db.collection('audit_logs').add({
        'action': 'Tạo người dùng mới',
        'actor': 'Admin',
        'category': 'nguoiDung',
        'details': 'Admin tạo tài khoản "$name" ($email, vai trò: $_role)',
        'target': 'User $userId',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF12B76A),
          content: Text('Đã tạo thành công tài khoản cho $name!'),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _red,
          content: Text('Lỗi tạo người dùng: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF8FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.person_add_rounded, color: _primary, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thêm người dùng mới',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark),
                          ),
                          Text(
                            'Tạo tài khoản quản trị trực tiếp trên hệ thống',
                            style: TextStyle(fontSize: 11.5, color: _textGrey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: _textGrey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Họ và tên
                const Text('HỌ VÀ TÊN (*)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textGrey)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: _inputDeco('Ví dụ: Nguyễn Văn An', Icons.badge_outlined),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập họ tên' : null,
                ),
                const SizedBox(height: 12),

                // Email
                const Text('ĐỊA CHỈ EMAIL (*)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textGrey)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 13),
                  decoration: _inputDeco('Ví dụ: user@gmail.com', Icons.email_outlined),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Vui lòng nhập email';
                    if (!val.contains('@')) return 'Email không hợp lệ';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Số điện thoại
                const Text('SỐ ĐIỆN THOẠI (*)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textGrey)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 13),
                  decoration: _inputDeco('Ví dụ: 0912345678', Icons.phone_outlined),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập SĐT' : null,
                ),
                const SizedBox(height: 12),

                // Vai trò
                const Text('VAI TRÒ TÀI KHOẢN (*)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textGrey)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Người thuê')),
                        selected: _role == 'renter',
                        selectedColor: _primary.withValues(alpha: 0.15),
                        onSelected: (_) => setState(() => _role = 'renter'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Chủ trọ')),
                        selected: _role == 'host',
                        selectedColor: const Color(0xFF027A48).withValues(alpha: 0.15),
                        onSelected: (_) => setState(() => _role = 'host'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Admin')),
                        selected: _role == 'admin',
                        selectedColor: _red.withValues(alpha: 0.15),
                        onSelected: (_) => setState(() => _role = 'admin'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Mật khẩu khởi tạo
                const Text('MẬT KHẨU BAN ĐẦU', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textGrey)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _passwordCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: _inputDeco('Mật khẩu khởi tạo', Icons.lock_outline),
                ),
                const SizedBox(height: 12),

                // Điểm uy tín khởi tạo
                Row(
                  children: [
                    const Text('Điểm uy tín ban đầu:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('$_initialRepScore/100 đ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF027A48))),
                  ],
                ),
                Slider(
                  value: _initialRepScore.toDouble(),
                  min: 50,
                  max: 100,
                  divisions: 10,
                  label: '$_initialRepScore đ',
                  activeColor: _primary,
                  onChanged: (val) => setState(() => _initialRepScore = val.toInt()),
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Huỷ'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Tạo tài khoản'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF98A2B3)),
      prefixIcon: Icon(icon, size: 18, color: _textGrey),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    );
  }
}

