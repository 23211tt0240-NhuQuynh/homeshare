import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/user_profile_service.dart';
import '../../auth/providers/user_provider.dart';
import '../widgets/user_avatar.dart';
import 'cccd_verification_screen.dart';

/// Hồ sơ cá nhân của role người dùng.
/// Tên, ảnh, mã, điện thoại, email và trạng thái VNeID/CCCD lấy từ tài khoản.
/// Giới thiệu để trống cho người dùng tự viết. Sở thích mặc định không có.
class PersonalProfileScreen extends ConsumerStatefulWidget {
  const PersonalProfileScreen({super.key});

  @override
  ConsumerState<PersonalProfileScreen> createState() => _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends ConsumerState<PersonalProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _nameController = TextEditingController();
  final _yearController = TextEditingController();
  final _phoneController = TextEditingController();
  final _hometownController = TextEditingController();
  final _occupationController = TextEditingController();
  final _workplaceController = TextEditingController();
  final _bioController = TextEditingController();
  final _interestController = TextEditingController();
  final _picker = ImagePicker();

  final _emailController = TextEditingController();
  String _userCode = '';
  String _avatarUrl = '';
  String _role = 'renter';
  String _gender = '';
  String? _genderError;
  bool _verified = false;
  bool _hydrated = false;
  bool _loadingInterests = true;
  bool _saving = false;
  Uint8List? _pickedAvatar;
  DateTime? _birthDate;
  final List<String> _interests = [];

  @override
  void dispose() {
    _scrollController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    _yearController.dispose();
    _phoneController.dispose();
    _hometownController.dispose();
    _occupationController.dispose();
    _workplaceController.dispose();
    _bioController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  void _hydrate(UserProfile profile) {
    _nameController.text = profile.displayName;
    _phoneController.text = _normalizePhone(profile.phoneNumber);
    _hometownController.text = profile.hometown;
    _occupationController.text = profile.occupation;
    _workplaceController.text = profile.workplace;
    _bioController.text = profile.bio;
    _emailController.text = profile.email;
    _userCode = profile.userCode;
    _avatarUrl = profile.avatarUrl;
    _role = profile.role.isEmpty ? 'renter' : profile.role;
    _gender = _normalizeGender(profile.gender);
    _verified = profile.isCccdVerified;
    _birthDate = profile.birthDate;
    if (profile.birthDate != null) {
      _yearController.text = profile.birthDate!.year.toString();
    }
  }

  Future<void> _loadInterests(UserProfile profile) async {
    try {
      final names = await ref.read(userProfileServiceProvider).loadInterestNames(profile.uid);
      if (!mounted) return;
      setState(() {
        _interests
          ..clear()
          ..addAll(names.isNotEmpty ? names : profile.hobbies);
        _loadingInterests = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _interests
          ..clear()
          ..addAll(profile.hobbies);
        _loadingInterests = false;
      });
    }
  }

  String _normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('84') && digits.length == 11) {
      digits = '0${digits.substring(2)}';
    }
    return digits;
  }

  String _normalizeGender(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'nu' || value == 'nữ' || value == 'female') return 'Nữ';
    if (value == 'nam' || value == 'male') return 'Nam';
    if (value == 'khac' || value == 'khác' || value == 'other') return 'Khác';
    return '';
  }

  int? _age() {
    final year = int.tryParse(_yearController.text.trim());
    if (year == null) return null;
    final now = DateTime.now();
    var age = now.year - year;
    final birth = _birthDate;
    if (birth != null && birth.year == year) {
      final hadBirthday = now.month > birth.month || (now.month == birth.month && now.day >= birth.day);
      if (!hadBirthday) age -= 1;
    }
    return age < 0 ? null : age;
  }

  DateTime? _birthDateFromYear() {
    final year = int.tryParse(_yearController.text.trim());
    if (year == null) return null;
    final previous = _birthDate;
    if (previous != null) {
      return DateTime(year, previous.month, previous.day);
    }
    return DateTime(year, 1, 1);
  }

  Future<void> _pickAvatar() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1024);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _pickedAvatar = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không chọn được ảnh: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _addInterest() {
    final name = _interestController.text.trim();
    if (name.isEmpty) {
      _showResult(title: 'Chưa thêm sở thích', message: 'Nhập tên sở thích rồi bấm dấu +.', success: false);
      return;
    }
    if (name.length < 2 || name.length > 40) {
      _showResult(title: 'Sở thích chưa hợp lệ', message: 'Mỗi sở thích dài từ 2 đến 40 ký tự.', success: false);
      return;
    }
    if (_interests.length >= 12) {
      _showResult(title: 'Đã đủ sở thích', message: 'Chỉ lưu tối đa 12 sở thích.', success: false);
      return;
    }
    if (_interests.any((e) => e.toLowerCase() == name.toLowerCase())) {
      _interestController.clear();
      _showResult(title: 'Sở thích đã có', message: '"$name" đã nằm trong danh sách.', success: false);
      return;
    }
    setState(() {
      _interests.add(name);
      _interestController.clear();
    });
  }

  List<String> _collectIssues() {
    final issues = <String>[];
    final name = _nameController.text.trim();
    if (name.length < 2) {
      issues.add('Họ và tên cần ít nhất 2 ký tự.');
    } else if (!RegExp(r'\p{L}', unicode: true).hasMatch(name)) {
      issues.add('Họ và tên cần có chữ cái.');
    }

    final year = int.tryParse(_yearController.text.trim());
    final nowYear = DateTime.now().year;
    if (year == null) {
      issues.add('Nhập năm sinh.');
    } else if (year < nowYear - 100 || year > nowYear - 16) {
      issues.add('Năm sinh phải từ ${nowYear - 100} đến ${nowYear - 16} (đủ 16 tuổi).');
    }

    if (_gender.isEmpty) {
      issues.add('Chọn giới tính: Nữ, Nam hoặc Khác.');
    }

    if (!RegExp(r'^0\d{9}$').hasMatch(_phoneController.text.trim())) {
      issues.add('Số điện thoại phải gồm đúng 10 số và bắt đầu bằng 0.');
    }
    if (_hometownController.text.trim().length < 2) {
      issues.add('Nhập quê quán / tỉnh thành.');
    }
    if (_occupationController.text.trim().length < 2) {
      issues.add('Nhập nghề nghiệp / vị trí.');
    }
    if (_workplaceController.text.trim().length > 80) {
      issues.add('Nơi làm việc tối đa 80 ký tự.');
    }
    if (_bioController.text.trim().length > 500) {
      issues.add('Giới thiệu tối đa 500 ký tự.');
    }
    return issues;
  }

  Future<void> _showResult({
    required String title,
    required String message,
    required bool success,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(success ? 'Đóng' : 'Đã hiểu'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final issues = _collectIssues();
    final formOk = _formKey.currentState?.validate() ?? false;
    setState(() => _genderError = _gender.isEmpty ? 'Vui lòng chọn giới tính' : null);
    if (!formOk || issues.isNotEmpty) {
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
      if (!mounted) return;
      await _showResult(
        title: 'Chưa lưu được',
        message: issues.isEmpty ? 'Một số ô chưa đúng. Kiểm tra dòng chữ đỏ dưới mỗi ô.' : issues.join('\n'),
        success: false,
      );
      return;
    }

    final profile = ref.read(userProfileProvider).value;
    if (profile == null) {
      await _showResult(title: 'Chưa lưu được', message: 'Bạn cần đăng nhập để lưu hồ sơ.', success: false);
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(userProfileServiceProvider).saveProfile(
            uid: profile.uid,
            displayName: _nameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            gender: _gender,
            hometown: _hometownController.text.trim(),
            occupation: _occupationController.text.trim(),
            workplace: _workplaceController.text.trim(),
            bio: _bioController.text.trim(),
            interestNames: List<String>.from(_interests),
            role: _role,
            birthDate: _birthDateFromYear(),
            avatarBytes: _pickedAvatar,
          );
      if (!mounted) return;
      await _showResult(
        title: 'Đã lưu hồ sơ',
        message: 'Thông tin cá nhân và sở thích đã được cập nhật.',
        success: true,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      await _showResult(
        title: 'Lưu không thành công',
        message: e.toString().replaceFirst('Exception: ', ''),
        success: false,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value;
    if (profile != null) {
      _verified = profile.isCccdVerified;
      if (!_hydrated) {
        _hydrated = true;
        _hydrate(profile);
        _loadInterests(profile);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: profileAsync.isLoading && profile == null
          ? const Center(child: CircularProgressIndicator())
          : profile == null
              ? const Center(child: Text('Không tìm thấy tài khoản.'))
              : Column(
                  children: [
                    Expanded(
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 18),
                            _buildSection(
                              icon: Icons.badge_outlined,
                              title: 'Thông tin cơ bản & Liên hệ',
                              subtitle: 'Thông tin dùng để xác minh danh tính và hồ sơ ở ghép',
                              child: Column(
                                children: [
                                  _textField(
                                    controller: _nameController,
                                    label: 'Họ và tên *',
                                    hint: 'Họ và tên trên tài khoản',
                                    validator: (val) {
                                      final name = val?.trim() ?? '';
                                      if (name.length < 2) return 'Họ và tên cần ít nhất 2 ký tự';
                                      if (!RegExp(r'\p{L}', unicode: true).hasMatch(name)) return 'Họ và tên cần có chữ cái';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _yearField(),
                                  const SizedBox(height: 12),
                                  _genderField(),
                                  const SizedBox(height: 12),
                                  _textField(
                                    controller: _phoneController,
                                    label: 'Số điện thoại *',
                                    hint: '10 số, bắt đầu bằng 0',
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                                    validator: (val) {
                                      if (!RegExp(r'^0\d{9}$').hasMatch(val?.trim() ?? '')) {
                                        return 'Số điện thoại phải gồm đúng 10 số và bắt đầu bằng 0';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _textField(
                                    controller: _emailController,
                                    label: 'Email',
                                    hint: 'Email tài khoản',
                                    readOnly: true,
                                  ),
                                  const SizedBox(height: 12),
                                  _textField(
                                    controller: _hometownController,
                                    label: 'Quê quán / Tỉnh thành *',
                                    hint: 'Nhập quê quán',
                                    validator: (val) => (val?.trim().length ?? 0) < 2 ? 'Nhập quê quán / tỉnh thành' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildSection(
                              icon: Icons.work_outline,
                              title: 'Nghề nghiệp & Đơn vị công tác',
                              subtitle: 'Giúp bạn cùng phòng hiểu về lịch trình công việc và thời gian biểu của bạn',
                              child: Column(
                                children: [
                                  _textField(
                                    controller: _occupationController,
                                    label: 'Nghề nghiệp / Vị trí *',
                                    hint: 'Ví dụ: Sinh viên, Kỹ sư',
                                    validator: (val) => (val?.trim().length ?? 0) < 2 ? 'Nhập nghề nghiệp / vị trí' : null,
                                  ),
                                  const SizedBox(height: 12),
                                  _textField(
                                    controller: _workplaceController,
                                    label: 'Nơi làm việc / Công ty',
                                    hint: 'Trường hoặc nơi làm việc',
                                    validator: (val) => (val?.trim().length ?? 0) > 80 ? 'Tối đa 80 ký tự' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildIntroSection(),
                          ],
                        ),
                      ),
                    ),
                    _buildFooter(),
                  ],
                ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            UserAvatar(
              name: _nameController.text,
              imageUrl: _avatarUrl,
              localBytes: _pickedAvatar,
              radius: 48,
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Material(
                color: AppColors.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _pickAvatar,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.photo_camera_outlined, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _pickAvatar,
          child: const Text('Đổi ảnh đại diện', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        Text(
          'ID #$_userCode',
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _verified
              ? null
              : () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CccdVerificationScreen()));
                },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _verified ? AppColors.successContainer : AppColors.warningContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _verified ? Icons.verified_rounded : Icons.info_outline,
                  size: 16,
                  color: _verified ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 6),
                Text(
                  _verified ? 'Đã xác thực VNeID / CCCD' : 'Chưa xác thực VNeID / CCCD',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _verified ? AppColors.success : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.35)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildIntroSection() {
    final length = _bioController.text.characters.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notes_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Giới thiệu & Sở thích', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text('Đoạn giới thiệu ngắn', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              Text('$length/500', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _bioController,
            maxLines: 4,
            maxLength: 500,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => const SizedBox.shrink(),
            onChanged: (_) => setState(() {}),
            decoration: _decoration('Viết vài dòng về bạn'),
          ),
          const SizedBox(height: 8),
          const Text('Sở thích', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (_loadingInterests)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (_interests.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Chưa có sở thích nào. Hãy thêm sở thích của bạn.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final interest in _interests)
                    InputChip(
                      label: Text(interest),
                      onDeleted: () => setState(() => _interests.remove(interest)),
                      backgroundColor: AppColors.primaryContainer,
                      deleteIconColor: AppColors.primary,
                      labelStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _interestController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addInterest(),
                  decoration: _decoration('Nhập sở thích, thói quen mới...'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addInterest,
                style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                icon: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _yearField() {
    final age = _age();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Năm sinh / Tuổi *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _yearController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          onChanged: (_) => setState(() {}),
          decoration: _decoration('Năm sinh').copyWith(
            suffixText: age == null ? null : '$age tuổi',
          ),
          validator: (val) {
            final year = int.tryParse(val?.trim() ?? '');
            final now = DateTime.now().year;
            if (year == null) return 'Nhập năm sinh';
            if (year < now - 100 || year > now - 16) {
              return 'Năm sinh từ ${now - 100} đến ${now - 16} (đủ 16 tuổi)';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _genderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Giới tính *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final option in const ['Nữ', 'Nam', 'Khác']) ...[
              Expanded(child: _genderChip(option)),
              if (option != 'Khác') const SizedBox(width: 8),
            ],
          ],
        ),
        if (_genderError != null) ...[
          const SizedBox(height: 6),
          Text(_genderError!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _genderChip(String label) {
    final selected = _gender == label;
    return InkWell(
      onTap: () => setState(() {
        _gender = label;
        _genderError = null;
      }),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  Widget _textField({
    TextEditingController? controller,
    required String label,
    required String hint,
    bool readOnly = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          decoration: _decoration(hint),
        ),
      ],
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.4)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.danger)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.danger, width: 1.4)),
      errorMaxLines: 2,
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Hủy bỏ', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          SizedBox(width: 8),
                          Text('Đang lưu...', style: TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      )
                    : const Text('Lưu thay đổi', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
