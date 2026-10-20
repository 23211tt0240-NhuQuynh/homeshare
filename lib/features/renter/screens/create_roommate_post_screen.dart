import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/vietnam_locations.dart';
<<<<<<< HEAD
import '../../../core/services/image_storage_service.dart';
import '../../../core/services/roommate_service.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../data/models/roommate_post_model.dart';
=======
import '../../../data/models/roommate_post_model.dart';
import '../../../core/services/roommate_service.dart';
import '../../../core/services/image_storage_service.dart';
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import 'renter_main_screen.dart';

<<<<<<< HEAD
/// Màn hình Đăng Tin Tìm Ở Ghép chuẩn Figma 100%
/// Thiết kế Stepper 3 bước rõ ràng, sạch sẽ, không lỗi layout:
/// Bước 1: Thông tin người đăng (Hồ sơ cá nhân)
/// Bước 2: Thông tin phòng & Ngân sách (Địa điểm, Giá thuê, Tình trạng)
/// Bước 3: Lối sống, Thói quen & Hình ảnh phòng
=======
/// Màn hình Đăng Bài Tìm Ở Ghép chuẩn Figma 100%
/// - Nếu ĐÃ CÓ PHÒNG (Đã có nhà): Tiến trình 3 bước (1. Thông tin -> 2. Hình ảnh -> 3. Hoàn tất)
/// - Nếu CHƯA CÓ PHÒNG (Chưa có nhà): Tiến trình 2 bước (1. Thông tin -> 2. Hoàn tất, không cần ảnh)
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
class CreateRoommatePostScreen extends ConsumerStatefulWidget {
  const CreateRoommatePostScreen({super.key});

  @override
  ConsumerState<CreateRoommatePostScreen> createState() => _CreateRoommatePostScreenState();
}

class _CreateRoommatePostScreenState extends ConsumerState<CreateRoommatePostScreen> {
  final _formKey = GlobalKey<FormState>();
<<<<<<< HEAD
  int _currentStep = 0;

  // 1. Thông tin người đăng
  final _authorNameController = TextEditingController();
  final _authorAgeController = TextEditingController();
  final _authorOccupationController = TextEditingController();
  final _phoneController = TextEditingController();
  String _authorGender = 'Nữ';

  // 2. Thông tin bài đăng & phòng
  bool _hasRoom = true; // true: Đã có phòng, false: Chưa có phòng
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _addressController = TextEditingController();
  String _selectedProvince = 'TP. Hồ Chí Minh';
  String _selectedDistrict = 'TP. Thủ Đức';
  String _selectedWard = 'Linh Trung';
  String _selectedPropertyType = 'Căn hộ chung cư';
  String _targetGender = 'Nữ';

  // 3. Lối sống & Thói quen
  final List<String> _selectedHabits = [];
  final List<String> _customHabits = [];
  final TextEditingController _customHabitController = TextEditingController();
  final List<String> _selectedImages = [];
  final ImagePicker _imagePicker = ImagePicker();
  bool _isSubmitting = false;

  final List<String> _commonHabits = [
    'Yên tĩnh sau 23h',
    'Sạch sẽ, ngăn nắp cao',
    'Tuyệt đối không thuốc lá',
    'Giờ giấc tự do',
    'Có xe máy riêng',
    'Thích thể thao/Gym',
    'Không ồn ào/tụ tập',
    'Chăm học/Làm việc',
    'Nấu ăn thường xuyên',
  ];

  List<String> get _allHabits => [..._commonHabits, ..._customHabits];

  final List<String> _propertyTypes = [
    'Nhà trọ / Phòng trọ',
=======

  // Current Step: 0 = Thông tin, 1 = Hình ảnh (nếu có phòng) hoặc Hoàn tất, 2 = Hoàn tất
  int _currentStep = 0;

  // Controllers thông tin người đăng (chuẩn thẻ Figma Minh Trang)
  final _authorNameController = TextEditingController();
  final _authorAgeController = TextEditingController();
  final _authorOccupationController = TextEditingController();
  String _authorGender = 'Nữ';

  // Controllers thông tin bài đăng
  final _addressController = TextEditingController();
  final _streetController = TextEditingController();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  final _phoneController = TextEditingController();

  // Trạng thái phòng (true: Đã có nhà / phòng, false: Chưa có nhà / phòng)
  bool _hasRoom = true;

  // Lựa chọn địa giới hành chính toàn quốc 34 Tỉnh/TP mới
  String _selectedProvince = 'TP. Hồ Chí Minh';
  String? _selectedDistrict;
  String? _selectedWard;

  String _selectedPropertyType = 'Căn hộ chung cư';
  String _targetGender = 'Nữ';
  final List<String> _selectedHabits = [];
  final TextEditingController _customHabitController = TextEditingController();

  // Danh sách hình ảnh nhà & chú thích ảnh
  final List<String> _selectedImages = [];
  final List<String> _selectedCaptions = [];

  final ImagePicker _imagePicker = ImagePicker();
  bool _isSubmitting = false;
  RoommatePostModel? _createdPost;

  final List<String> _propertyTypes = [
    'Nhà trọ / Phòng trọ / Căn hộ mini',
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
    'Căn hộ chung cư',
    'Nhà nguyên căn',
    'Ký túc xá / Sleepbox',
  ];

<<<<<<< HEAD
  @override
  void initState() {
    super.initState();
    // Tự động tải thông tin thực tế từ tài khoản người dùng đăng nhập, không hardcode dữ liệu giả
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFromUserProfile();
    });
  }

  Future<void> _initFromUserProfile() async {
    final user = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).value;

    if (profile != null) {
      if (profile.displayName.isNotEmpty) {
        _authorNameController.text = profile.displayName;
      }
      if (profile.phoneNumber.isNotEmpty) {
        _phoneController.text = profile.phoneNumber;
      }
      if (profile.occupation.isNotEmpty) {
        _authorOccupationController.text = profile.occupation;
      }
      if (profile.birthDate != null) {
        final age = DateTime.now().year - profile.birthDate!.year;
        if (age > 0) _authorAgeController.text = age.toString();
      }
      if (profile.gender.isNotEmpty) {
        final g = profile.gender.toLowerCase();
        if (g == 'nam' || g == 'male') {
          _authorGender = 'Nam';
        } else if (g == 'nu' || g == 'nữ' || g == 'female') {
          _authorGender = 'Nữ';
        } else {
          _authorGender = 'Khác';
        }
      }
      final savedHobbies = profile.hobbies.isNotEmpty
          ? profile.hobbies
          : await ref.read(userProfileServiceProvider).loadInterestNames(profile.uid);
      for (final h in savedHobbies) {
        if (!_selectedHabits.contains(h)) _selectedHabits.add(h);
      }
      if (mounted) setState(() {});
    } else if (user != null) {
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        _authorNameController.text = user.displayName!;
      }
      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        _phoneController.text = user.phoneNumber!;
      }
      if (mounted) setState(() {});
    }
  }

=======
  final List<String> _commonHabits = [
    'Không hút thuốc',
    'Yên tĩnh sau 23h',
    'Sạch sẽ ngăn nắp',
    'Giờ giấc tự do 24/7',
    'Có xe máy riêng',
    'Nấu ăn tại phòng',
    'Thân thiện vui vẻ',
    'Thú cưng (Chó/Mèo)',
    'Dậy sớm (Trước 7h)',
  ];

  void _syncFromProfile(UserProfile? profile, {bool force = false}) {
    if (profile == null) return;
    if (force || _authorNameController.text.isEmpty || _authorNameController.text == 'Minh Trang') {
      if (profile.displayName.isNotEmpty) _authorNameController.text = profile.displayName;
    }
    if (force || _phoneController.text.isEmpty) {
      if (profile.phoneNumber.isNotEmpty) _phoneController.text = profile.phoneNumber;
    }
    if (force || _authorOccupationController.text.isEmpty || _authorOccupationController.text == 'SV Đại học Ngoại Thương CS2') {
      if (profile.occupation.isNotEmpty) _authorOccupationController.text = profile.occupation;
    }
    if (force || _authorAgeController.text.isEmpty || _authorAgeController.text == '21') {
      if (profile.birthDate != null) {
        _authorAgeController.text = (DateTime.now().year - profile.birthDate!.year).toString();
      }
    }
    final g = profile.gender.trim().toLowerCase();
    if (g == 'nam') _authorGender = 'Nam';
    if (g.contains('nu') || g.contains('nữ')) _authorGender = 'Nữ';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(userProfileProvider).value;
      if (profile != null) {
        _syncFromProfile(profile, force: true);
      } else {
        if (_authorNameController.text.isEmpty) _authorNameController.text = 'Minh Trang';
        if (_authorAgeController.text.isEmpty) _authorAgeController.text = '21';
        if (_authorOccupationController.text.isEmpty) _authorOccupationController.text = 'SV Đại học Ngoại Thương CS2';
      }
      if (_titleController.text.isEmpty) _titleController.text = 'Cần tìm 1 bạn nữ ở ghép căn hộ Sunview Town (Đã có phòng)';
      if (_priceController.text.isEmpty) _priceController.text = '1.800.000';
      if (_selectedHabits.isEmpty) {
        _selectedHabits.addAll(['Không hút thuốc', 'Yên tĩnh sau 23h', 'Sạch sẽ ngăn nắp', 'Thân thiện vui vẻ']);
      }
      if (mounted) setState(() {});
    });
  }

>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
  @override
  void dispose() {
    _authorNameController.dispose();
    _authorAgeController.dispose();
    _authorOccupationController.dispose();
<<<<<<< HEAD
    _phoneController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _addressController.dispose();
=======
    _addressController.dispose();
    _streetController.dispose();
    _titleController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _phoneController.dispose();
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
    _customHabitController.dispose();
    super.dispose();
  }

<<<<<<< HEAD
  void _syncFromProfile() {
    final profile = ref.read(userProfileProvider).value;
    if (profile == null) return;

    setState(() {
      if (profile.displayName.isNotEmpty) _authorNameController.text = profile.displayName;
      if (profile.phoneNumber.isNotEmpty) _phoneController.text = profile.phoneNumber;
      if (profile.occupation.isNotEmpty) _authorOccupationController.text = profile.occupation;
      if (profile.birthDate != null) {
        _authorAgeController.text = (DateTime.now().year - profile.birthDate!.year).toString();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Đã đồng bộ thông tin từ tài khoản của bạn ✓'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
=======
  void _resetForm() {
    setState(() {
      _currentStep = 0;
      _createdPost = null;
      _selectedImages.clear();
      _selectedCaptions.clear();
      _selectedHabits.clear();
      _selectedHabits.addAll(['Không hút thuốc', 'Yên tĩnh sau 23h', 'Sạch sẽ ngăn nắp', 'Thân thiện vui vẻ']);
      _streetController.clear();
      _addressController.clear();
      _selectedDistrict = null;
      _selectedWard = null;
    });
  }

  /// Tổng hợp chuỗi địa chỉ đầy đủ từ 3 cấp hành chính và số nhà
  void _composeAddress() {
    final parts = <String>[];
    final street = _streetController.text.trim();
    if (street.isNotEmpty) parts.add(street);
    if (_selectedWard != null && _selectedWard!.isNotEmpty) parts.add(_selectedWard!);
    if (_selectedDistrict != null && _selectedDistrict!.isNotEmpty) parts.add(_selectedDistrict!);
    if (_selectedProvince.isNotEmpty) parts.add(_selectedProvince);
    _addressController.text = parts.join(', ');
  }

  /// Mở BottomSheet tìm kiếm và chọn địa giới hành chính
  Future<String?> _showSearchablePicker({
    required BuildContext context,
    required String title,
    required List<String> items,
    String? selectedItem,
    bool allowCustom = false,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SearchablePickerSheet(
        title: title,
        items: items,
        selectedItem: selectedItem,
        allowCustom: allowCustom,
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
      ),
    );
  }

<<<<<<< HEAD
  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        // Cho phép người dùng chọn cùng lúc nhiều ảnh từ thư viện
        final pickedList = await _imagePicker.pickMultiImage(
          imageQuality: 75,
          maxWidth: 1024,
          maxHeight: 1024,
        );
        if (pickedList.isNotEmpty) {
          setState(() {
            for (final file in pickedList) {
              if (!_selectedImages.contains(file.path)) {
                _selectedImages.add(file.path);
              }
            }
          });
        }
      } else {
        // Chụp ảnh từ Camera
        final picked = await _imagePicker.pickImage(
          source: source,
          imageQuality: 75,
          maxWidth: 1024,
          maxHeight: 1024,
        );
        if (picked != null) {
          setState(() {
            if (!_selectedImages.contains(picked.path)) {
              _selectedImages.add(picked.path);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Lỗi chọn ảnh: $e');
    }
  }

  void _addCustomHabit() {
    final text = _customHabitController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        if (!_customHabits.contains(text) && !_commonHabits.contains(text)) {
          _customHabits.add(text);
        }
        if (!_selectedHabits.contains(text)) {
          _selectedHabits.add(text);
        }
        _customHabitController.clear();
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm tiêu chí: "$text" ✓'),
          duration: const Duration(seconds: 1),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  bool _validateStep0() {
    final formOk = _currentStep != 0 || (_formKey.currentState?.validate() ?? false);
    final name = _authorNameController.text.trim();
    final ageStr = _authorAgeController.text.trim();
    final occ = _authorOccupationController.text.trim();
    final phone = _phoneController.text.trim().replaceAll(' ', '');

    // Không yêu cầu số ký tự tối thiểu, chỉ cần có nhập và không phải khoảng trắng
    if (!formOk || name.isEmpty || ageStr.isEmpty || occ.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng điền thông tin người đăng ở Bước 1!'),
          backgroundColor: AppColors.danger,
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }
    return true;
  }

  bool _validateStep1() {
    final formOk = _currentStep != 1 || (_formKey.currentState?.validate() ?? false);
    final title = _titleController.text.trim();
    final rawPrice = _priceController.text.trim();
    final address = _addressController.text.trim();
    final desc = _descController.text.trim();

    // Không yêu cầu số ký tự tối thiểu, chỉ cần có nhập và không phải khoảng trắng
    if (!formOk || title.isEmpty || rawPrice.isEmpty || address.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng điền thông tin bài đăng ở Bước 2!'),
          backgroundColor: AppColors.danger,
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    // Cho phép đăng linh hoạt, không chặn người dùng
    return true;
  }

  Future<void> _submitPost() async {
    if (_isSubmitting) return;

    final user = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).value;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập trước khi đăng bài tìm ở ghép!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!_validateStep0()) {
      setState(() => _currentStep = 0);
      return;
    }
    if (!_validateStep1()) {
      setState(() => _currentStep = 1);
      return;
    }
    if (!_validateStep2()) {
      setState(() => _currentStep = 2);
      return;
    }

    final title = _titleController.text.trim();
    final rawPrice = _priceController.text.trim().replaceAll('.', '').replaceAll(',', '');
    final price = double.tryParse(rawPrice) ?? 0.0;
    final specificAddress = _addressController.text.trim();

    final authorId = user.uid;
    final authorName = _authorNameController.text.trim().isNotEmpty
        ? _authorNameController.text.trim()
        : (profile?.displayName ?? user.displayName ?? 'Người dùng HomeShare');
    final authorAge = int.tryParse(_authorAgeController.text.trim()) ??
        (profile?.birthDate != null ? (DateTime.now().year - profile!.birthDate!.year) : 20);
    final authorOcc = _authorOccupationController.text.trim().isNotEmpty
        ? _authorOccupationController.text.trim()
        : (profile?.occupation.isNotEmpty == true ? profile!.occupation : 'Sinh viên / Người đi làm');

    setState(() => _isSubmitting = true);

    try {
      final postId = 'post_${DateTime.now().millisecondsSinceEpoch}';
      // Tải ảnh lên Firebase Storage nếu có với cơ chế fallback an toàn
      final uploadedUrls = await ref.read(imageStorageServiceProvider).uploadRoommateImages(
        localPaths: _selectedImages,
        postId: postId,
      );

      final fullAddress = '$specificAddress, $_selectedWard, $_selectedDistrict, $_selectedProvince';

      final post = RoommatePostModel(
        id: postId,
        authorId: authorId,
        authorName: authorName,
        authorAge: authorAge,
        authorGender: _authorGender,
        authorOccupation: authorOcc,
        authorAvatar: profile?.avatarUrl ?? user.photoURL ?? '',
        title: title,
        description: _descController.text.trim(),
        postType: _hasRoom ? 'timNguoiOGhep' : 'dangTimPhong',
        propertyType: _selectedPropertyType,
        pricePerPerson: price,
        budgetMin: price > 500000 ? price - 500000 : price,
        budgetMax: price + 500000,
        address: fullAddress,
        district: _selectedDistrict,
        targetGender: _targetGender,
        habits: _selectedHabits.isNotEmpty ? _selectedHabits : ['Sạch sẽ', 'Hòa đồng'],
        images: uploadedUrls,
        imageCaptions: uploadedUrls.map((_) => 'Ảnh phòng').toList(),
        isVerified: profile?.isCccdVerified ?? false,
        matchRate: 0,
        hasRoom: _hasRoom,
        contactPhone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : (profile?.phoneNumber ?? ''),
        createdAt: DateTime.now(),
      );

      await ref.read(roommateServiceProvider).createPost(post);

      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi đăng tin: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF10B981), size: 28),
            SizedBox(width: 8),
            Text('Đăng tin thành công!'),
          ],
        ),
        content: const Text(
          'Bài đăng tìm bạn ở ghép của bạn đã được xuất bản và hiển thị ngay trên Cộng đồng HomeShare.',
          style: TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Đóng dialog
              // Chuyển tab sang "Tìm ở ghép"
              ref.read(renterBottomNavIndexProvider.notifier).setIndex(3);
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Xem trên cộng đồng', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
=======
  /// Thêm tiêu chí sinh hoạt tùy chỉnh do người dùng nhập
  void _addCustomHabit() {
    final text = _customHabitController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      if (!_commonHabits.contains(text)) {
        _commonHabits.add(text);
      }
      if (!_selectedHabits.contains(text)) {
        _selectedHabits.add(text);
      }
      _customHabitController.clear();
    });
  }

  /// Chọn thêm ảnh từ thư viện
  Future<void> _pickImages() async {
    try {
      final pickedFiles = await _imagePicker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          for (final f in pickedFiles) {
            _selectedImages.add(f.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chọn ảnh: $e')),
        );
      }
    }
  }

  /// Xóa ảnh khỏi danh sách
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  /// Xử lý chuyển bước tiếp theo từ Bước 1
  void _onNextFromStep1() {
    _composeAddress();
    if (_selectedDistrict == null || _selectedDistrict!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn Quận / Huyện')),
      );
      return;
    }
    if (_selectedWard == null || _selectedWard!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn Phường / Xã')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    if (_hasRoom) {
      // Đã có phòng -> Chuyển sang Bước 2: Hình ảnh
      setState(() => _currentStep = 1);
    } else {
      // Chưa có phòng -> Không cần ảnh, gửi đăng bài luôn và chuyển thẳng sang Hoàn tất!
      _submitPost(hasRoom: false);
    }
  }

  /// Lưu bài đăng vào Firestore / Service
  Future<void> _submitPost({required bool hasRoom}) async {
    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(currentUserProvider);
      final profile = ref.read(userProfileProvider).value;

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng đăng nhập tài khoản để đăng tin ở ghép!'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }

      final priceVal = double.tryParse(_priceController.text.replaceAll(RegExp(r'\D'), '')) ?? 1800000;
      final district = _selectedDistrict ?? _extractDistrict(_addressController.text);
      final authorName = _authorNameController.text.trim().isNotEmpty
          ? _authorNameController.text.trim()
          : (profile?.displayName.isNotEmpty == true
              ? profile!.displayName
              : (user.displayName?.isNotEmpty == true ? user.displayName! : 'Minh Trang'));
      final authorAge = int.tryParse(_authorAgeController.text.trim()) ??
          (profile?.birthDate != null ? (DateTime.now().year - profile!.birthDate!.year) : 21);
      final authorOccupation = _authorOccupationController.text.trim().isNotEmpty
          ? _authorOccupationController.text.trim()
          : (profile?.occupation.isNotEmpty == true ? profile!.occupation : 'SV Đại học Ngoại Thương CS2');
      final authorPhone = _phoneController.text.trim().isNotEmpty
          ? _phoneController.text.trim()
          : (profile?.phoneNumber.isNotEmpty == true ? profile!.phoneNumber : '0981234567');

      // Danh sách chú thích ảnh mặc định nếu chưa nhập
      final captions = <String>[];
      if (hasRoom && _selectedImages.isNotEmpty) {
        for (int i = 0; i < _selectedImages.length; i++) {
          if (i < _selectedCaptions.length && _selectedCaptions[i].isNotEmpty) {
            captions.add(_selectedCaptions[i]);
          } else {
            captions.add(i == 0 ? 'Phòng ngủ máy lạnh' : 'Bếp chung rộng');
          }
        }
      }

      // Tải hình ảnh lên Firebase Storage / Cloud để tất cả thiết bị khác luôn thấy ảnh
      final postId = 'rm_${DateTime.now().millisecondsSinceEpoch}';
      List<String> uploadedImages = [];
      if (hasRoom && _selectedImages.isNotEmpty) {
        uploadedImages = await ref.read(imageStorageServiceProvider).uploadRoommateImages(
          localPaths: _selectedImages,
          postId: postId,
        );
      }

      final post = RoommatePostModel(
        id: postId,
        authorId: user.uid,
        authorName: authorName,
        authorAge: authorAge,
        authorGender: _authorGender,
        authorOccupation: authorOccupation,
        authorAvatar: profile?.avatarUrl.isNotEmpty == true
            ? profile!.avatarUrl
            : (user.photoURL?.isNotEmpty == true
                ? user.photoURL!
                : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400'),
        title: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : 'Cần tìm 1 bạn nữ ở ghép căn hộ Sunview Town (Đã có phòng)',
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : 'Căn hộ thoáng mát, đầy đủ tiện nghi, tìm bạn ở ghép lịch sự, sạch sẽ.',
        postType: hasRoom ? 'timNguoiOGhep' : 'dangTimPhong',
        propertyType: _selectedPropertyType,
        pricePerPerson: priceVal,
        budgetMin: hasRoom ? priceVal : (priceVal * 0.8).roundToDouble(),
        budgetMax: hasRoom ? priceVal : (priceVal * 1.2).roundToDouble(),
        address: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : 'Hiệp Bình Phước, TP. Thủ Đức (Gần cầu Bình Triệu)',
        district: district,
        targetGender: _targetGender,
        habits: _selectedHabits.isNotEmpty
            ? List.from(_selectedHabits)
            : ['Không hút thuốc', 'Yên tĩnh sau 23h', 'Sạch sẽ ngăn nắp', 'Thân thiện vui vẻ'],
        images: hasRoom ? uploadedImages : [],
        imageCaptions: captions,
        hasRoom: hasRoom,
        status: 'dangMo',
        isVerified: true,
        matchRate: 94,
        contactPhone: authorPhone,
        createdAt: DateTime.now(),
      );

      final saved = await ref.read(roommateServiceProvider).createPost(post);
      ref.read(roommatePostsRefreshTrigger.notifier).trigger();

      if (mounted) {
        setState(() {
          _createdPost = saved;
          // Đã có phòng: step 2 là Hoàn tất. Chưa có phòng: step 1 là Hoàn tất.
          _currentStep = hasRoom ? 2 : 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _extractDistrict(String addr) {
    if (_selectedDistrict != null && _selectedDistrict!.isNotEmpty) {
      return _selectedDistrict!;
    }
    final lower = addr.toLowerCase();
    if (lower.contains('thủ đức')) return 'TP. Thủ Đức';
    if (lower.contains('bình thạnh')) return 'Bình Thạnh';
    if (lower.contains('quận 1')) return 'Quận 1';
    if (lower.contains('quận 9')) return 'Quận 9';
    if (lower.contains('gò vấp')) return 'Gò Vấp';
    if (lower.contains('tân bình')) return 'Tân Bình';
    return 'TP. Thủ Đức';
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Đăng tin tìm ở ghép',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (_currentStep == 0)
            TextButton.icon(
              onPressed: _syncFromProfile,
              icon: const Icon(Icons.sync, size: 16, color: AppColors.primary),
              label: const Text('Đồng bộ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Step Indicator Bar
          _buildStepIndicator(),

          // Main Step Content
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                child: _buildCurrentStepContent(),
              ),
            ),
          ),

          // Bottom Action Bar
          _buildBottomActionBar(),
        ],
=======
    ref.listen<AsyncValue<UserProfile?>>(userProfileProvider, (prev, next) {
      final p = next.value;
      if (p != null && mounted) {
        setState(() {
          _syncFromProfile(p, force: false);
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildFigmaAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Stepper Thanh Tiến Trình (Tùy biến động 3 bước nếu có phòng, 2 bước nếu chưa có phòng)
            _buildStepperHeader(),

            const Divider(height: 1, color: Color(0xFFF1F5F9)),

            // Nội dung theo từng bước
            Expanded(
              child: _buildCurrentStepContent(),
            ),
          ],
        ),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildStepIndicator() {
    final steps = ['Hồ sơ', 'Phòng & Giá', 'Lối sống & Ảnh'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: List.generate(steps.length, (idx) {
          final isPassed = idx < _currentStep;
          final isCurrent = idx == _currentStep;
          final color = isPassed || isCurrent ? AppColors.primary : const Color(0xFFCBD5E1);

          return Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: color,
                  child: Text(
                    '${idx + 1}',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      steps[idx],
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                        color: isCurrent ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                if (idx < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: isPassed ? AppColors.primary : const Color(0xFFE2E8F0),
                    ),
                  ),
              ],
            ),
=======
  /// AppBar chuẩn Figma: Back button + Tiêu đề "đăng bài"
  PreferredSizeWidget _buildFigmaAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF1E293B)),
        onPressed: () {
          if (_currentStep > 0 && (_hasRoom && _currentStep < 2)) {
            setState(() => _currentStep--);
          } else {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          }
        },
      ),
      title: const Text(
        'đăng bài',
        style: TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 16.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Stepper Header chuẩn Figma:
  /// - Đã có phòng: 1 Thông tin -> 2 Hình ảnh -> 3 Hoàn tất
  /// - Chưa có phòng: 1 Thông tin -> 2 Hoàn tất
  Widget _buildStepperHeader() {
    final stepLabels = _hasRoom
        ? ['Thông tin', 'Hình ảnh', 'Hoàn tất']
        : ['Thông tin', 'Hoàn tất'];

    final totalSteps = stepLabels.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(totalSteps * 2 - 1, (index) {
          if (index.isOdd) {
            // Đường kẻ nối
            final stepIdx = index ~/ 2;
            final isCompleted = _currentStep > stepIdx;
            return Expanded(
              child: Container(
                height: 2,
                color: isCompleted ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
              ),
            );
          }

          // Nút tròn số bước
          final stepIdx = index ~/ 2;
          final isCurrent = _currentStep == stepIdx;
          final isDone = _currentStep > stepIdx;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: (isCurrent || isDone) ? const Color(0xFF2563EB) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (isCurrent || isDone) ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: isDone
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text(
                        '${stepIdx + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isCurrent ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                stepLabels[stepIdx],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                ),
              ),
            ],
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
          );
        }),
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Profile();
      case 1:
        return _buildStep2RoomAndPrice();
      case 2:
      default:
        return _buildStep3LifestyleAndImages();
    }
  }

  // BƯỚC 1: Hồ sơ bản thân
  Widget _buildStep1Profile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'Thông tin cá nhân người đăng',
          subtitle: 'Giúp người tìm phòng hiểu rõ hơn về bạn cùng phòng tiềm năng',
          icon: Icons.person_outline,
          children: [
            _buildTextField(
              label: 'Họ và tên *',
              controller: _authorNameController,
              hint: 'Nhập họ và tên đầy đủ',
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Vui lòng nhập họ và tên của bạn';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'Tuổi *',
                    controller: _authorAgeController,
                    keyboardType: TextInputType.number,
                    hint: 'Ví dụ: 21',
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Vui lòng nhập tuổi';
                      final age = int.tryParse(val.trim());
                      if (age == null || age <= 0) return 'Tuổi không hợp lệ';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Giới tính *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _authorGender,
                        items: ['Nam', 'Nữ', 'Khác'].map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 12.5)))).toList(),
                        onChanged: (val) => setState(() => _authorGender = val ?? 'Nữ'),
                        decoration: _inputDecoration(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Nghề nghiệp / Trường học *',
              controller: _authorOccupationController,
              hint: 'Ví dụ: SV Đại học Bách Khoa / Lập trình viên',
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Vui lòng nhập nghề nghiệp hoặc trường học';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Số điện thoại / Zalo liên hệ *',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              hint: 'Ví dụ: 0912345678',
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Vui lòng nhập số điện thoại liên hệ';
                return null;
              },
            ),
          ],
        ),
      ],
    );
  }

  // BƯỚC 2: Thông tin bài đăng & phòng
  Widget _buildStep2RoomAndPrice() {
    final provinces = VietnamLocations.provinces;
    final districts = VietnamLocations.getAdministrativeDistricts(_selectedProvince);
    final wards = VietnamLocations.getWards(_selectedProvince, _selectedDistrict);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'Tình trạng phòng hiện tại',
          subtitle: 'Bạn đã có phòng sẵn để share hay đang tìm bạn đi thuê cùng?',
          icon: Icons.home_work_outlined,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildSelectCard(
                    title: 'Đã có phòng',
                    subtitle: 'Tìm người dọn vào ở cùng',
                    isSelected: _hasRoom,
                    onTap: () => setState(() => _hasRoom = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSelectCard(
                    title: 'Chưa có phòng',
                    subtitle: 'Tìm bạn cùng đi thuê',
                    isSelected: !_hasRoom,
                    onTap: () => setState(() => _hasRoom = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'Tiêu đề bài đăng *',
              controller: _titleController,
              hint: 'Ví dụ: Tìm bạn nữ ở ghép căn hộ 2PN',
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Vui lòng nhập tiêu đề bài đăng';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: _hasRoom ? 'Chi phí thuê / người (VNĐ / tháng) *' : 'Ngân sách mong muốn / người *',
              controller: _priceController,
              keyboardType: TextInputType.number,
              hint: 'Ví dụ: 1800000',
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Vui lòng nhập số tiền chi phí';
                final raw = val.trim().replaceAll('.', '').replaceAll(',', '');
                final parsed = double.tryParse(raw);
                if (parsed == null || parsed <= 0) return 'Số tiền chi phí không hợp lệ';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tỉnh / Thành phố *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: ValueKey('province_$_selectedProvince'),
                  initialValue: provinces.contains(_selectedProvince) ? _selectedProvince : provinces.first,
                  items: provinces.map((p) => DropdownMenuItem(value: p, child: Text(p, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedProvince = val;
                        final newDistricts = VietnamLocations.getAdministrativeDistricts(_selectedProvince);
                        _selectedDistrict = newDistricts.isNotEmpty ? newDistricts.first : '';
                        final newWards = VietnamLocations.getWards(_selectedProvince, _selectedDistrict);
                        _selectedWard = newWards.isNotEmpty ? newWards.first : '';
                      });
                    }
                  },
                  decoration: _inputDecoration(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quận / Huyện *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        key: ValueKey('district_${_selectedProvince}_$_selectedDistrict'),
                        initialValue: districts.contains(_selectedDistrict) ? _selectedDistrict : (districts.isNotEmpty ? districts.first : null),
                        items: districts.map((d) => DropdownMenuItem(value: d, child: Text(d, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)))).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedDistrict = val ?? districts.first;
                            final newWards = VietnamLocations.getWards(_selectedProvince, _selectedDistrict);
                            _selectedWard = newWards.isNotEmpty ? newWards.first : 'Linh Trung';
                          });
                        },
                        decoration: _inputDecoration(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Phường / Xã', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        key: ValueKey('ward_${_selectedDistrict}_$_selectedWard'),
                        initialValue: wards.contains(_selectedWard) ? _selectedWard : (wards.isNotEmpty ? wards.first : 'Linh Trung'),
                        items: wards.map((w) => DropdownMenuItem(value: w, child: Text(w, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)))).toList(),
                        onChanged: (val) => setState(() => _selectedWard = val ?? 'Linh Trung'),
                        decoration: _inputDecoration(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Loại hình nhà ở *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _selectedPropertyType,
                        items: _propertyTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)))).toList(),
                        onChanged: (val) => setState(() => _selectedPropertyType = val ?? _propertyTypes.first),
                        decoration: _inputDecoration(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Giới tính tìm kiếm *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _targetGender,
                        items: ['Nữ', 'Nam', 'Tất cả'].map((g) => DropdownMenuItem(value: g, child: Text(g, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)))).toList(),
                        onChanged: (val) => setState(() => _targetGender = val ?? 'Nữ'),
                        decoration: _inputDecoration(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Địa chỉ cụ thể *',
              controller: _addressController,
              hint: 'Ví dụ: Số 10 đường Số 8, P. Linh Trung',
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Vui lòng nhập địa chỉ cụ thể của phòng';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Mô tả chi tiết phòng & yêu cầu *',
              controller: _descController,
              maxLines: 3,
              hint: 'Mô tả không gian, tiện ích có sẵn, giờ giấc, nội quy phòng...',
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Vui lòng nhập mô tả chi tiết phòng';
                return null;
              },
            ),
          ],
        ),
      ],
    );
  }

  // BƯỚC 3: Lối sống & Ảnh phòng
  Widget _buildStep3LifestyleAndImages() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          title: 'Tiêu chí sinh hoạt & Lối sống',
          subtitle: 'Chọn tiêu chí có sẵn hoặc nhập thêm tiêu chí mong muốn của bạn',
          icon: Icons.interests_outlined,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allHabits.map((habit) {
                final isSelected = _selectedHabits.contains(habit);
                final isCustom = _customHabits.contains(habit);
                return FilterChip(
                  label: Text(habit),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedHabits.add(habit);
                      } else {
                        _selectedHabits.remove(habit);
                      }
                    });
                  },
                  onDeleted: isCustom
                      ? () {
                          setState(() {
                            _customHabits.remove(habit);
                            _selectedHabits.remove(habit);
                          });
                        }
                      : null,
                  deleteIcon: isCustom
                      ? const Icon(Icons.close_rounded, size: 14, color: Color(0xFF64748B))
                      : null,
                  selectedColor: AppColors.primarySurface,
                  checkmarkColor: AppColors.primary,
                  backgroundColor: const Color(0xFFF1F5F9),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: isSelected ? AppColors.primaryDark : const Color(0xFF334155),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : const Color(0xFFE2E8F0),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
=======
  /// Nội dung tương ứng với bước hiện tại
  Widget _buildCurrentStepContent() {
    if (_hasRoom) {
      switch (_currentStep) {
        case 0:
          return _buildStep1InformationForm();
        case 1:
          return _buildStep2Images();
        case 2:
        default:
          return _buildStepSuccess();
      }
    } else {
      switch (_currentStep) {
        case 0:
          return _buildStep1InformationForm();
        case 1:
        default:
          return _buildStepSuccess();
      }
    }
  }

  // ===========================================================================
  // BƯỚC 1: THÔNG TIN CƠ BẢN
  // ===========================================================================
  Widget _buildStep1InformationForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Thông tin người đăng bài
            Container(
              padding: const EdgeInsets.all(14),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
<<<<<<< HEAD
                  const Text(
                    'Nhập tiêu chí sinh hoạt cho người muốn thêm:',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _customHabitController,
                          decoration: _inputDecoration(
                            hint: 'VD: Thích nuôi mèo, Không nấu ăn đêm...',
                          ).copyWith(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addCustomHabit(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _addCustomHabit,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Thêm tiêu chí'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
=======
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.person_pin_rounded, size: 18, color: Color(0xFF2563EB)),
                          SizedBox(width: 6),
                          Text(
                            'Thông tin người đăng bài',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () {
                          final p = ref.read(userProfileProvider).value;
                          if (p != null) {
                            setState(() {
                              _syncFromProfile(p, force: true);
                            });
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã đồng bộ thông tin từ tài khoản của bạn ✓'),
                                backgroundColor: Color(0xFF2563EB),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.sync, size: 14, color: Color(0xFF2563EB)),
                        label: const Text('Lấy từ tài khoản', style: TextStyle(fontSize: 11.5, color: Color(0xFF2563EB))),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Họ và tên người đăng *'),
                            TextFormField(
                              controller: _authorNameController,
                              decoration: _inputDecoration('Ví dụ: Minh Trang'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Nhập họ tên' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Tuổi *'),
                            TextFormField(
                              controller: _authorAgeController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('Ví dụ: 21'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Nhập tuổi' : null,
                            ),
                          ],
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                        ),
                      ),
                    ],
                  ),
<<<<<<< HEAD
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _buildSectionCard(
          title: 'Hình ảnh phòng thực tế',
          subtitle: _selectedImages.isNotEmpty
              ? 'Đã chọn ${_selectedImages.length} ảnh. Bạn có thể chọn thêm nhiều ảnh nữa.'
              : 'Chọn nhiều ảnh từ thư viện để bài đăng trực quan và thu hút hơn',
          icon: Icons.photo_library_outlined,
          children: [
            if (_selectedImages.isNotEmpty) ...[
              SizedBox(
                height: 95,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (ctx, idx) {
                    return Stack(
                      children: [
                        Container(
                          width: 95,
                          height: 95,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(
                              image: FileImage(File(_selectedImages[idx])),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 12,
                          child: InkWell(
                            onTap: () => setState(() => _selectedImages.removeAt(idx)),
                            child: const CircleAvatar(
                              radius: 11,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Chụp ảnh'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Chọn nhiều ảnh từ thư viện'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
=======
                  const SizedBox(height: 10),
                  _buildFieldLabel('Trường học / Nghề nghiệp *'),
                  TextFormField(
                    controller: _authorOccupationController,
                    decoration: _inputDecoration('Ví dụ: SV Đại học Ngoại Thương CS2'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Nhập trường / nghề nghiệp' : null,
                  ),
                  const SizedBox(height: 10),
                  _buildFieldLabel('Giới tính của bạn (Người đăng bài) *'),
                  Row(
                    children: ['Nam', 'Nữ'].map((g) {
                      final isSel = _authorGender == g;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: ChoiceChip(
                          label: Text(g),
                          selected: isSel,
                          selectedColor: const Color(0xFF2563EB),
                          labelStyle: TextStyle(
                            color: isSel ? Colors.white : const Color(0xFF334155),
                            fontSize: 13,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                          ),
                          onSelected: (_) => setState(() => _authorGender = g),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Thông tin phòng & bài đăng',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 14),

            // Tỉnh / Thành phố (Toàn quốc 34 Tỉnh/TP mới)
            _buildFieldLabel('Tỉnh / Thành phố (Toàn quốc) *'),
            InkWell(
              onTap: () async {
                final res = await _showSearchablePicker(
                  context: context,
                  title: 'Chọn Tỉnh / Thành phố',
                  items: VietnamLocations.provinces,
                  selectedItem: _selectedProvince,
                );
                if (res != null && res != _selectedProvince) {
                  setState(() {
                    _selectedProvince = res;
                    _selectedDistrict = null;
                    _selectedWard = null;
                    _composeAddress();
                  });
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_city_outlined, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedProvince,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Quận / Huyện / Thị xã
            _buildFieldLabel('Quận / Huyện / Thị xã *'),
            InkWell(
              onTap: () async {
                final districts = VietnamLocations.getAdministrativeDistricts(_selectedProvince);
                final res = await _showSearchablePicker(
                  context: context,
                  title: 'Chọn Quận / Huyện ($_selectedProvince)',
                  items: districts,
                  selectedItem: _selectedDistrict,
                );
                if (res != null && res != _selectedDistrict) {
                  setState(() {
                    _selectedDistrict = res;
                    _selectedWard = null;
                    _composeAddress();
                  });
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedDistrict != null ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.map_outlined, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedDistrict ?? 'Chọn Quận / Huyện...',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: _selectedDistrict != null ? FontWeight.w500 : FontWeight.normal,
                          color: _selectedDistrict != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Phường / Xã / Thị trấn
            _buildFieldLabel('Phường / Xã / Thị trấn *'),
            InkWell(
              onTap: () async {
                if (_selectedDistrict == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vui lòng chọn Quận / Huyện trước!')),
                  );
                  return;
                }
                final wards = VietnamLocations.getWards(_selectedProvince, _selectedDistrict!);
                final res = await _showSearchablePicker(
                  context: context,
                  title: 'Chọn Phường / Xã ($_selectedDistrict)',
                  items: wards,
                  selectedItem: _selectedWard,
                  allowCustom: true,
                );
                if (res != null) {
                  setState(() {
                    _selectedWard = res;
                    _composeAddress();
                  });
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedWard != null ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.holiday_village_outlined, size: 18, color: Color(0xFF2563EB)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedWard ?? (_selectedDistrict == null ? 'Vui lòng chọn Quận / Huyện trước' : 'Chọn Phường / Xã...'),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: _selectedWard != null ? FontWeight.w500 : FontWeight.normal,
                          color: _selectedWard != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, size: 20, color: Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Số nhà, tên đường *
            _buildFieldLabel('Số nhà, tên đường *'),
            TextFormField(
              controller: _streetController,
              decoration: _inputDecoration('Ví dụ: Số 123 Đường Số 8, KDC Nam Long...'),
              onChanged: (_) => _composeAddress(),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Vui lòng nhập số nhà, tên đường';
                }
                if (_selectedDistrict == null || _selectedDistrict!.isEmpty) {
                  return 'Vui lòng chọn Quận / Huyện';
                }
                if (_selectedWard == null || _selectedWard!.isEmpty) {
                  return 'Vui lòng chọn Phường / Xã';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Xem trước địa chỉ đầy đủ tự động
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Địa chỉ bài đăng đầy đủ:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _addressController.text.trim().isNotEmpty
                              ? _addressController.text.trim()
                              : 'Chưa đủ thông tin (vui lòng chọn Tỉnh/TP, Quận/Huyện, Phường/Xã và số nhà)',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: _addressController.text.trim().isNotEmpty ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Loại hình *
            _buildFieldLabel('Loại hình *'),
            DropdownButtonFormField<String>(
              initialValue: _selectedPropertyType,
              decoration: _inputDecoration(''),
              items: _propertyTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13.5)))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedPropertyType = val);
              },
            ),
            const SizedBox(height: 14),

            // Tiêu đề bài đăng *
            _buildFieldLabel('Tiêu đề bài đăng *'),
            TextFormField(
              controller: _titleController,
              decoration: _inputDecoration(
                _hasRoom
                    ? 'Ví dụ: Cần tìm 1 bạn nữ ở ghép căn hộ Sunview Town (Đã có phòng)'
                    : 'Ví dụ: Muốn tìm 1 bạn nữ hòa đồng cùng tìm phòng Thủ Đức',
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập tiêu đề bài đăng' : null,
            ),
            const SizedBox(height: 14),

            // Giá thuê / Ngân sách dự kiến *
            _buildFieldLabel(_hasRoom ? 'Giá thuê mỗi người (VNĐ/tháng) *' : 'Ngân sách tìm phòng dự kiến (VNĐ/tháng) *'),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Ví dụ: 1.800.000'),
              validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập giá' : null,
            ),
            const SizedBox(height: 14),

            // Giới tính mong muốn (chỉ Nam / Nữ theo yêu cầu)
            _buildFieldLabel('Giới tính mong muốn *'),
            Row(
              children: ['Nam', 'Nữ'].map((g) {
                final isSel = _targetGender == g;
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: ChoiceChip(
                    label: Text(g),
                    selected: isSel,
                    selectedColor: const Color(0xFF2563EB),
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : const Color(0xFF334155),
                      fontSize: 13,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    ),
                    onSelected: (_) => setState(() => _targetGender = g),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Tiêu chí sinh hoạt & Thói quen (chọn hoặc nhập để thêm)
            _buildFieldLabel('Tiêu chí sinh hoạt & Thói quen (chọn hoặc nhập để thêm)'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _commonHabits.map((h) {
                final isSel = _selectedHabits.contains(h);
                return FilterChip(
                  label: Text(h),
                  selected: isSel,
                  selectedColor: const Color(0xFFEFF6FF),
                  checkmarkColor: const Color(0xFF2563EB),
                  labelStyle: TextStyle(
                    color: isSel ? const Color(0xFF2563EB) : const Color(0xFF475569),
                    fontSize: 11.5,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSel ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                  ),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedHabits.add(h);
                      } else {
                        _selectedHabits.remove(h);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),

            // Ô nhập tiêu chí mới
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: TextField(
                      controller: _customHabitController,
                      decoration: InputDecoration(
                        hintText: 'Nhập tiêu chí khác (ví dụ: Không nhậu nhẹt, WFH...)',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                        ),
                      ),
                      onSubmitted: (_) => _addCustomHabit(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: _addCustomHabit,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Thêm', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                    ),
                  ),
                ),
              ],
            ),
<<<<<<< HEAD
          ],
        ),
      ],
    );
  }

  // Action buttons
  Widget _buildBottomActionBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Quay lại', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () {
                if (_currentStep == 0) {
                  if (_validateStep0()) setState(() => _currentStep = 1);
                } else if (_currentStep == 1) {
                  if (_validateStep1()) setState(() => _currentStep = 2);
                } else {
                  _submitPost();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      _currentStep < 2 ? 'Tiếp tục' : 'Đăng bài ngay',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ],
=======
            const SizedBox(height: 14),

            // Số điện thoại / Zalo liên hệ *
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFieldLabel('Số điện thoại liên hệ *'),
                if (ref.watch(userProfileProvider).value?.phoneNumber.isNotEmpty == true)
                  TextButton.icon(
                    onPressed: () {
                      final p = ref.read(userProfileProvider).value;
                      if (p != null) {
                        setState(() => _phoneController.text = p.phoneNumber);
                      }
                    },
                    icon: const Icon(Icons.person_pin_circle_outlined, size: 14, color: Color(0xFF2563EB)),
                    label: const Text('Lấy từ tài khoản', style: TextStyle(fontSize: 12, color: Color(0xFF2563EB))),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                  ),
              ],
            ),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration('Số điện thoại Zalo để người tìm ghép liên hệ'),
              validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập số điện thoại liên hệ' : null,
            ),
            const SizedBox(height: 14),

            // Nội dung
            _buildFieldLabel('Nội dung'),
            TextFormField(
              controller: _descController,
              maxLines: 4,
              decoration: _inputDecoration('nội dung bài đăng'),
            ),
            const SizedBox(height: 16),

            // Trạng thái (Radio options: Đã có nhà vs Chưa có nhà)
            _buildFieldLabel('Trạng thái'),
            Row(
              children: [
                _buildStatusRadio(
                  label: 'Đã có nhà',
                  isSelected: _hasRoom,
                  onTap: () => setState(() => _hasRoom = true),
                ),
                const SizedBox(width: 24),
                _buildStatusRadio(
                  label: 'Chưa có nhà',
                  isSelected: !_hasRoom,
                  onTap: () => setState(() => _hasRoom = false),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Nút Tiếp theo
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _onNextFromStep1,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text(
                        'Tiếp theo',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          ...children,
        ],
=======
  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildSelectCard({
    required String title,
    required String subtitle,
=======
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
    );
  }

  Widget _buildStatusRadio({
    required String label,
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
<<<<<<< HEAD
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySurface : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppColors.primary : const Color(0xFF0F172A),
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? AppColors.primary : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
=======
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                width: isSelected ? 5.5 : 1.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BƯỚC 2: HÌNH ẢNH NHÀ (CHỈ ÁP DỤNG KHI ĐÃ CÓ PHÒNG)
  // ===========================================================================
  Widget _buildStep2Images() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hình ảnh nhà',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 3),
          const Text(
            'Chọn ít nhất 1 ảnh để thu hút người thuê',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          // Khung to nét đứt chọn ảnh
          InkWell(
            onTap: _pickImages,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF93C5FD),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    child: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'chọn ảnh hoặc kéo thả',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Tối thiểu 1 tấm, tối đa 12 tấm',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),

          if (_selectedImages.isEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedImages.addAll([
                      'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?w=600',
                      'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?w=600',
                    ]);
                    _selectedCaptions.addAll([
                      'Phòng ngủ máy lạnh',
                      'Bếp chung rộng',
                    ]);
                  });
                },
                icon: const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF2563EB)),
                label: const Text(
                  'Dùng ảnh phòng đẹp (Phòng ngủ + Bếp)',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF93C5FD)),
                  backgroundColor: const Color(0xFFEFF6FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Lưới ảnh 3 cột
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemCount: _selectedImages.length + 1,
            itemBuilder: (context, index) {
              if (index == _selectedImages.length) {
                // Ô cuối: + Thêm ảnh
                return InkWell(
                  onTap: _pickImages,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
                      color: const Color(0xFFF8FAFC),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 24, color: Color(0xFF2563EB)),
                        SizedBox(height: 2),
                        Text(
                          'Thêm ảnh',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final imgPath = _selectedImages[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: imgPath.startsWith('http')
                        ? Image.network(imgPath, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => Container(color: Colors.grey.shade200))
                        : Image.file(File(imgPath), fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => Container(color: Colors.grey.shade200)),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 28),

          // 2 Nút: Quay lại & Hoàn tất
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _currentStep = 0),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Quay lại', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () {
                            if (_selectedImages.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Vui lòng chọn ít nhất 1 hình ảnh phòng thật của bạn'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }
                            _submitPost(hasRoom: true);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Hoàn tất', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: _inputDecoration(hint: hint),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      errorStyle: const TextStyle(fontSize: 11, color: AppColors.danger, height: 1.2),
    );
  }
}
=======
  // ===========================================================================
  // BƯỚC 3 / HOÀN TẤT: ĐĂNG BÀI THÀNH CÔNG
  // ===========================================================================
  Widget _buildStepSuccess() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),

          // Minh họa nhà có dấu tick xanh chuẩn Figma
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.home_outlined,
                  size: 52,
                  color: Color(0xFF60A5FA),
                ),
                Positioned(
                  right: 18,
                  bottom: 18,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Tiêu đề
          const Text(
            'đăng bài thành công!',
            style: TextStyle(
              fontSize: 18.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),

          // Mô tả
          const Text(
            'bài đăng của bạn đã được lưu và sẵn sàng để đăng tin cho thuê.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF64748B),
            ),
          ),

          const Spacer(),

          // Nút Xem bài đăng
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                // 1. Chuyển tab sang mục Ở ghép (Tab 3)
                ref.read(renterBottomNavIndexProvider.notifier).setIndex(3);
                // 2. Đóng màn hình nếu được mở qua push
                if (Navigator.canPop(context)) {
                  Navigator.pop(context, _createdPost);
                }
                // 3. Reset form
                _resetForm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text('Xem bài đăng', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 12),

          // Nút Quay lại trang chủ
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                // 1. Chuyển tab sang mục Khám phá (Tab 0)
                ref.read(renterBottomNavIndexProvider.notifier).setIndex(0);
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
                _resetForm();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFFBFDBFE)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text('quay lại trang chủ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// BottomSheet tìm kiếm và chọn địa giới hành chính (Tỉnh/TP, Quận/Huyện, Phường/Xã)
class _SearchablePickerSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? selectedItem;
  final bool allowCustom;

  const _SearchablePickerSheet({
    required this.title,
    required this.items,
    this.selectedItem,
    this.allowCustom = false,
  });

  @override
  State<_SearchablePickerSheet> createState() => _SearchablePickerSheetState();
}

class _SearchablePickerSheetState extends State<_SearchablePickerSheet> {
  final _searchController = TextEditingController();
  late List<String> _filteredItems;

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(widget.items);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredItems = List.from(widget.items);
      } else {
        _filteredItems = widget.items.where((item) => item.toLowerCase().contains(q)).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: EdgeInsets.only(bottom: keyboardHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thanh kéo
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Tiêu đề và nút đóng
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Ô tìm kiếm
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm ${widget.title.toLowerCase().replaceAll('chọn ', '')}...',
                hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              onChanged: _onSearch,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          // Danh sách kết quả
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            widget.allowCustom && _searchController.text.trim().isNotEmpty
                                ? 'Không tìm thấy trong danh mục'
                                : 'Không tìm thấy kết quả phù hợp',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
                          ),
                          if (widget.allowCustom && _searchController.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => Navigator.pop(context, _searchController.text.trim()),
                              icon: const Icon(Icons.add, size: 16),
                              label: Text('Dùng "${_searchController.text.trim()}"'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    itemCount: _filteredItems.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF8FAFC)),
                    itemBuilder: (ctx, idx) {
                      final item = _filteredItems[idx];
                      final isSelected = item == widget.selectedItem;
                      return ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        tileColor: isSelected ? const Color(0xFFEFF6FF) : null,
                        title: Text(
                          item,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, size: 18, color: Color(0xFF2563EB))
                            : null,
                        onTap: () => Navigator.pop(context, item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
