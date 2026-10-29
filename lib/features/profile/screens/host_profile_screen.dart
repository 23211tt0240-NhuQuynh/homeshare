import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/vietnam_banks.dart';
import '../../../core/services/user_profile_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../renter/screens/report_host_screen.dart';
import '../widgets/host_reviews_section.dart';
import '../widgets/user_avatar.dart';
import 'cccd_verification_screen.dart';

/// Hồ sơ chủ trọ tách riêng khỏi hồ sơ người thuê.
/// Giữ: uy tín / đánh giá, báo cáo, thông tin cơ bản & liên hệ, tài khoản ngân hàng.
class HostProfileScreen extends ConsumerStatefulWidget {
  final String? userId;

  const HostProfileScreen({super.key, this.userId});

  @override
  ConsumerState<HostProfileScreen> createState() => _HostProfileScreenState();
}

class _HostProfileScreenState extends ConsumerState<HostProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _nameController = TextEditingController();
  final _yearController = TextEditingController();
  final _phoneController = TextEditingController();
  final _hometownController = TextEditingController();
  final _emailController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _picker = ImagePicker();

  String _avatarUrl = '';
  String _gender = '';
  String? _genderError;
  bool _verified = false;
  bool _hydrated = false;
  bool _bankLoaded = false;
  bool _bankLoadFailed = false;
  String _bankName = '';
  bool _saving = false;
  bool _viewOnly = false;
  bool _editing = false;
  bool _loadingUser = false;

  bool get _locked => _viewOnly || !_editing;
  int _reputationScore = 100;
  String? _loadError;
  Uint8List? _pickedAvatar;
  DateTime? _birthDate;

  @override
  void initState() {
    super.initState();
    final requested = widget.userId?.trim() ?? '';
    if (requested.isEmpty) return;
    _loadingUser = true;
    Future.microtask(() => _loadViewedUser(requested));
  }

  Future<void> _loadViewedUser(String requested) async {
    final mine = ref.read(userProfileProvider).value;
    if (mine != null && mine.uid == requested) {
      if (mounted) setState(() => _loadingUser = false);
      return;
    }
    try {
      final profile = await ref.read(userProfileServiceProvider).loadUser(requested);
      if (!mounted) return;
      setState(() {
        _loadingUser = false;
        _viewOnly = profile != null;
        _loadError = profile == null ? 'Không tìm thấy hồ sơ chủ trọ.' : null;
        if (profile != null) {
          _hydrated = true;
          _hydrate(profile);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingUser = false;
        _loadError = 'Không tải được hồ sơ chủ trọ.';
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    _yearController.dispose();
    _phoneController.dispose();
    _hometownController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  String get _hostProfileId {
    final requested = widget.userId?.trim() ?? '';
    if (requested.isNotEmpty) return requested;
    return ref.read(userProfileProvider).value?.uid ?? '';
  }

  void _startEditing() {
    setState(() => _editing = true);
  }

  void _cancelEditing() {
    final profile = ref.read(userProfileProvider).value;
    if (profile != null) {
      _hydrate(profile);
      _loadBankAccount(profile.uid);
    }
    setState(() {
      _editing = false;
      _pickedAvatar = null;
      _genderError = null;
    });
  }

  void _openHostReport() {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để báo cáo.')),
      );
      return;
    }
    if (user.uid == _hostProfileId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn không thể báo cáo chính mình.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportHostScreen(
          hostId: _hostProfileId,
          hostName: _nameController.text.trim(),
        ),
      ),
    );
  }

  void _hydrate(UserProfile profile) {
    _nameController.text = profile.displayName;
    _phoneController.text = _normalizePhone(profile.phoneNumber);
    _hometownController.text = profile.hometown;
    _emailController.text = profile.email;
    _avatarUrl = profile.avatarUrl;
    _gender = _normalizeGender(profile.gender);
    _verified = profile.isCccdVerified;
    _reputationScore = profile.reputationScore;
    _birthDate = profile.birthDate;
    if (profile.birthDate != null) {
      _yearController.text = profile.birthDate!.year.toString();
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
      final hadBirthday =
          now.month > birth.month || (now.month == birth.month && now.day >= birth.day);
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
    issues.addAll(_bankIssues());
    return issues;
  }

  List<String> _bankIssues() {
    if (_bankLoadFailed) return const [];
    final number = _accountNumberController.text.trim();
    final holder = _accountHolderController.text.trim();
    final bank = _bankName.trim();
    if (number.isEmpty && holder.isEmpty && bank.isEmpty) return const [];
    final issues = <String>[];
    if (!RegExp(r'^\d{6,19}$').hasMatch(number)) {
      issues.add('Số tài khoản gồm từ 6 đến 19 chữ số.');
    }
    if (holder.length < 2 || !RegExp(r'\p{L}', unicode: true).hasMatch(holder)) {
      issues.add('Nhập tên chủ tài khoản.');
    }
    if (bank.isEmpty) {
      issues.add('Chọn ngân hàng.');
    }
    return issues;
  }

  Future<void> _loadBankAccount(String uid) async {
    try {
      final account = await ref.read(userProfileServiceProvider).loadBankAccount(uid);
      if (!mounted) return;
      setState(() {
        _accountNumberController.text = account.accountNumber;
        _accountHolderController.text = account.accountHolder;
        _bankName = account.bankName;
        _bankLoaded = true;
        _bankLoadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bankLoaded = true;
        _bankLoadFailed = true;
      });
    }
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

    if (!_bankLoaded) return;
    setState(() => _saving = true);
    try {
      await ref.read(userProfileServiceProvider).saveHostProfile(
            uid: profile.uid,
            displayName: _nameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            gender: _gender,
            hometown: _hometownController.text.trim(),
            birthDate: _birthDateFromYear(),
            avatarBytes: _pickedAvatar,
            accountNumber: _accountNumberController.text.trim(),
            accountHolder: _accountHolderController.text.trim(),
            bankName: _bankName.trim(),
            updateBankAccount: !_bankLoadFailed,
          );
      if (!mounted) return;
      await _showResult(
        title: 'Đã lưu hồ sơ chủ trọ',
        message: _bankLoadFailed
            ? 'Thông tin cơ bản đã được cập nhật. Tài khoản ngân hàng chưa được đổi.'
            : 'Thông tin cơ bản, liên hệ và tài khoản ngân hàng đã được cập nhật.',
        success: true,
      );
      if (mounted) setState(() => _editing = false);
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
    final requested = widget.userId?.trim() ?? '';
    final viewingOther = requested.isNotEmpty && requested != profile?.uid;
    if (profile != null && !viewingOther) {
      _verified = profile.isCccdVerified;
      _reputationScore = profile.reputationScore;
      if (!_hydrated) {
        _hydrated = true;
        _hydrate(profile);
        _loadBankAccount(profile.uid);
      }
    }

    final waiting = _loadingUser || (profileAsync.isLoading && profile == null && !_viewOnly);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hồ sơ chủ trọ'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          if (!_viewOnly && !_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Chỉnh sửa hồ sơ',
              onPressed: _startEditing,
            ),
        ],
      ),
      body: waiting
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(child: Text(_loadError!))
              : profile == null && !_viewOnly
              ? const Center(child: Text('Không tìm thấy tài khoản.'))
              : Column(
                  children: [
                    Expanded(
                      child: Form(
                        key: _formKey,
                        autovalidateMode:
                            _locked ? AutovalidateMode.disabled : AutovalidateMode.onUserInteraction,
                        child: ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 18),
                            HostReviewsSection(
                              hostId: _hostProfileId,
                              hostName: _nameController.text.trim(),
                              reputationScore: _reputationScore,
                              showReviewButton: _viewOnly,
                            ),
                            if (_viewOnly) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _openHostReport,
                                icon: const Icon(Icons.flag_outlined, size: 18, color: Color(0xFFDC2626)),
                                label: const Text(
                                  'Báo cáo chủ trọ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44),
                                  side: BorderSide(color: AppColors.danger.withValues(alpha: 0.45)),
                                  backgroundColor: AppColors.dangerContainer,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            _buildSection(
                              icon: Icons.badge_outlined,
                              title: 'Thông tin cơ bản & Liên hệ',
                              subtitle: _locked ? '' : 'Thông tin chủ trọ dùng khi liên hệ và nhận thanh toán',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _textField(
                                    controller: _nameController,
                                    label: 'Họ và tên *',
                                    hint: 'Họ và tên trên tài khoản',
                                    readOnly: _locked,
                                    validator: _locked
                                        ? null
                                        : (val) {
                                            final name = val?.trim() ?? '';
                                            if (name.length < 2) return 'Họ và tên cần ít nhất 2 ký tự';
                                            if (!RegExp(r'\p{L}', unicode: true).hasMatch(name)) {
                                              return 'Họ và tên cần có chữ cái';
                                            }
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
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    readOnly: _locked,
                                    validator: _locked
                                        ? null
                                        : (val) {
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
                                    readOnly: _locked,
                                    validator: _locked
                                        ? null
                                        : (val) => (val?.trim().length ?? 0) < 2
                                            ? 'Nhập quê quán / tỉnh thành'
                                            : null,
                                  ),
                                ],
                              ),
                            ),
                            if (!_viewOnly) ...[
                              const SizedBox(height: 14),
                              _buildBankSection(),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (!_viewOnly && _editing) _buildFooter(),
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
            if (!_locked)
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
        if (!_locked) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _pickAvatar,
            child: const Text('Đổi ảnh đại diện', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ] else
          const SizedBox(height: 8),
        Text(
          _nameController.text.trim().isEmpty ? 'Chưa cập nhật tên' : _nameController.text.trim(),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: AppColors.textDark, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _viewOnly || _verified
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
        color: AppColors.surface,
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
                child: Text(
                  title,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark),
                ),
              ),
            ],
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.35)),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _profileLine(String label, String raw) {
    final value = raw.trim();
    final empty = value.isEmpty;
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(
              empty ? 'Chưa cập nhật' : value,
              style: TextStyle(
                fontSize: 15.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: empty ? AppColors.textMuted : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankSection() {
    return _buildSection(
      icon: Icons.account_balance_outlined,
      title: 'Tài khoản ngân hàng',
      subtitle: 'Dùng khi nhận tiền giải ngân. Chưa có thì để trống.',
      child: !_bankLoaded
          ? const LinearProgressIndicator(minHeight: 2)
          : Column(
              children: [
                if (_bankLoadFailed)
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Không tải được tài khoản ngân hàng. Lần lưu này không đổi thông tin ngân hàng.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.danger, height: 1.35),
                    ),
                  ),
                _textField(
                  controller: _accountNumberController,
                  label: 'Số tài khoản',
                  hint: 'Nhập số tài khoản',
                  readOnly: _bankLoadFailed,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(19),
                  ],
                  validator: _bankLoadFailed
                      ? null
                      : (val) {
                          final number = val?.trim() ?? '';
                          if (_bankFieldsEmpty(number: number)) return null;
                          if (!RegExp(r'^\d{6,19}$').hasMatch(number)) return 'Gồm từ 6 đến 19 chữ số';
                          return null;
                        },
                ),
                const SizedBox(height: 12),
                _textField(
                  controller: _accountHolderController,
                  label: 'Chủ tài khoản',
                  hint: 'Tên chủ tài khoản',
                  readOnly: _bankLoadFailed,
                  inputFormatters: [LengthLimitingTextInputFormatter(70)],
                  validator: _bankLoadFailed
                      ? null
                      : (val) {
                          final holder = val?.trim() ?? '';
                          if (_bankFieldsEmpty(holder: holder)) return null;
                          if (holder.length < 2 || !RegExp(r'\p{L}', unicode: true).hasMatch(holder)) {
                            return 'Nhập tên chủ tài khoản';
                          }
                          return null;
                        },
                ),
                const SizedBox(height: 12),
                _bankDropdown(),
              ],
            ),
    );
  }

  bool _bankFieldsEmpty({String? number, String? holder, String? bank}) {
    final accountNumber = number ?? _accountNumberController.text.trim();
    final accountHolder = holder ?? _accountHolderController.text.trim();
    final bankName = bank ?? _bankName.trim();
    return accountNumber.isEmpty && accountHolder.isEmpty && bankName.isEmpty;
  }

  Widget _bankDropdown() {
    final selected = _bankName.trim();
    final choices = selected.isNotEmpty && !vietnamBanks.contains(selected)
        ? [selected, ...vietnamBanks]
        : vietnamBanks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ngân hàng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: const ValueKey('host-bank-account-name'),
          isExpanded: true,
          initialValue: selected.isEmpty ? null : selected,
          menuMaxHeight: 280,
          items: [
            for (final name in choices)
              DropdownMenuItem(
                value: name,
                child: Text(name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _bankLoadFailed ? null : (value) => setState(() => _bankName = value ?? ''),
          decoration: _decoration('Chọn ngân hàng'),
          validator: _bankLoadFailed
              ? null
              : (val) {
                  final bank = (val ?? '').trim();
                  if (_bankFieldsEmpty(bank: bank)) return null;
                  if (bank.isEmpty) return 'Chọn ngân hàng';
                  return null;
                },
        ),
      ],
    );
  }

  Widget _yearField() {
    final age = _age();
    if (_locked) {
      final year = _yearController.text.trim();
      final shown = year.isEmpty ? '' : (age == null ? year : '$year · $age tuổi');
      return _profileLine('Năm sinh', shown);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Năm sinh / Tuổi *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _yearController,
          readOnly: _locked,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          onChanged: (_) => setState(() {}),
          decoration: _decoration('Năm sinh').copyWith(
            suffixText: age == null ? null : '$age tuổi',
          ),
          validator: _locked
              ? null
              : (val) {
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
    if (_locked) return _profileLine('Giới tính', _gender);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Giới tính *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
          Text(_genderError!, style: TextStyle(color: AppColors.danger, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _genderChip(String label) {
    final selected = _gender == label;
    return InkWell(
      onTap: _locked
          ? null
          : () => setState(() {
                _gender = label;
                _genderError = null;
              }),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
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
    if (_locked) {
      return _profileLine(label.replaceAll(' *', ''), controller?.text ?? '');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
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
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary, width: 1.4)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.danger)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.danger, width: 1.4)),
      errorMaxLines: 2,
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : _cancelEditing,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Hủy bỏ', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _saving || !_bankLoaded ? null : _save,
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
