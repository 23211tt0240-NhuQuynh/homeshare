import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/room_issue_service.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/room_issue_model.dart';
import '../../auth/providers/auth_provider.dart';

/// Hàm tiện ích mở BottomSheet Báo cáo sự cố phòng
Future<bool?> showReportRoomIssueBottomSheet(
  BuildContext context, {
  required BookingRequestModel booking,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ReportRoomIssueBottomSheet(booking: booking),
  );
}

class ReportRoomIssueBottomSheet extends ConsumerStatefulWidget {
  final BookingRequestModel booking;

  const ReportRoomIssueBottomSheet({
    super.key,
    required this.booking,
  });

  @override
  ConsumerState<ReportRoomIssueBottomSheet> createState() =>
      _ReportRoomIssueBottomSheetState();
}

class _ReportRoomIssueBottomSheetState
    extends ConsumerState<ReportRoomIssueBottomSheet> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String _selectedCategory = RoomIssueCategories.electricity;
  String _selectedSeverity = RoomIssueSeverities.medium;
  final List<XFile> _selectedImages = [];
  bool _isSubmitting = false;

  final ScrollController _scrollController = ScrollController();
  String? _descError;
  String? _phoneError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameController.text = widget.booking.renterName.isNotEmpty
        ? widget.booking.renterName
        : (user?.displayName ?? '');
    _phoneController.text = widget.booking.renterPhone.isNotEmpty
        ? widget.booking.renterPhone
        : (user?.phoneNumber ?? '');

    _descController.addListener(() {
      if (_descError != null && _descController.text.trim().length >= 5) {
        setState(() {
          _descError = null;
          _submitError = null;
        });
      }
    });

    _phoneController.addListener(() {
      final digits = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
      if (_phoneError != null && digits.length >= 9) {
        setState(() {
          _phoneError = null;
          _submitError = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _descController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<String> _getQuickSuggestions(String category) {
    switch (category) {
      case RoomIssueCategories.electricity:
        return [
          'Mất điện toàn phòng',
          'Cháy bóng đèn',
          'Chập ổ cắm điện',
          'Hỏng quạt thông gió',
        ];
      case RoomIssueCategories.plumbing:
        return [
          'Vòi sen rò rỉ nước',
          'Tắc bồn cầu / thoát nước chậm',
          'Rỉ nước lavabo',
          'Mất nước sinh hoạt',
        ];
      case RoomIssueCategories.hvac:
        return [
          'Máy lạnh không mát',
          'Máy lạnh chảy nước',
          'Máy lạnh kêu to',
          'Hỏng remote máy lạnh',
        ];
      case RoomIssueCategories.doorLock:
        return [
          'Kẹt khóa cửa phòng',
          'Hỏng tay nắm cửa',
          'Khóa cửa sổ bị lỏng',
          'Kẹt chìa khóa',
        ];
      case RoomIssueCategories.wifi:
        return [
          'Mất kết nối Internet',
          'Wifi chập chờn / rất chậm',
          'Không tìm thấy sóng Wifi',
        ];
      case RoomIssueCategories.furniture:
        return [
          'Gãy giát giường',
          'Hỏng bản lề tủ quần áo',
          'Bàn ghế bị lung lay',
        ];
      case RoomIssueCategories.leaksWalls:
        return [
          'Thấm dột trần khi mưa',
          'Tường ẩm mốc bong tróc',
          'Cửa sổ tạt nước mưa',
        ];
      case RoomIssueCategories.other:
      default:
        return [
          'Cần thợ kiểm tra gấp thiết bị',
          'Sự cố tiếng ồn khu trọ',
          'Vấn đề vệ sinh chung',
        ];
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case RoomIssueCategories.electricity:
        return Icons.lightbulb_outline_rounded;
      case RoomIssueCategories.plumbing:
        return Icons.water_drop_outlined;
      case RoomIssueCategories.hvac:
        return Icons.ac_unit_rounded;
      case RoomIssueCategories.doorLock:
        return Icons.lock_outline_rounded;
      case RoomIssueCategories.wifi:
        return Icons.wifi_rounded;
      case RoomIssueCategories.furniture:
        return Icons.chair_outlined;
      case RoomIssueCategories.leaksWalls:
        return Icons.roofing_rounded;
      case RoomIssueCategories.other:
      default:
        return Icons.build_circle_outlined;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (_selectedImages.length >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chỉ đính kèm tối đa 3 ảnh hiện trường')),
        );
        return;
      }
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() {
          _selectedImages.add(picked);
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

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
              title: const Text('Chụp ảnh từ máy ảnh (Camera)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('Chọn ảnh từ Thư viện'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitIssue() async {
    final desc = _descController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    String? descErr;
    String? phoneErr;

    if (desc.isEmpty) {
      descErr = 'Vui lòng nhập mô tả hoặc chọn gợi ý bên dưới (*)';
    } else if (desc.length < 5) {
      descErr = 'Mô tả quá ngắn. Vui lòng nhập chi tiết hơn (tối thiểu 5 ký tự)';
    }

    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty || digits.length < 9 || digits.length > 11) {
      phoneErr = 'Vui lòng nhập số điện thoại liên hệ hợp lệ (9-11 số)';
    }

    if (descErr != null || phoneErr != null) {
      setState(() {
        _descError = descErr;
        _phoneError = phoneErr;
        _submitError = descErr ?? phoneErr;
      });
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
      _descError = null;
      _phoneError = null;
      _submitError = null;
    });

    try {
      final user = ref.read(currentUserProvider);
      final reporterId = widget.booking.renterId.isNotEmpty
          ? widget.booking.renterId
          : (user?.uid ?? 'guest_uid');

      final imageUrls = _selectedImages.map((e) => e.path).toList();

      await ref.read(roomIssueServiceProvider).submitRoomIssue(
            bookingId: widget.booking.id,
            roomId: widget.booking.roomId,
            roomTitle: widget.booking.roomTitle,
            hostId: widget.booking.hostId,
            hostName: widget.booking.hostName,
            reporterId: reporterId,
            reporterName: name.isNotEmpty ? name : widget.booking.renterName,
            reporterPhone: phone,
            category: _selectedCategory,
            severity: _selectedSeverity,
            description: desc,
            imageUrls: imageUrls,
          );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã gửi báo cáo sự cố [$_selectedCategory] đến chủ trọ thành công!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF027A48),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Lỗi gửi báo cáo sự cố: $e');
      if (mounted) {
        setState(() {
          _submitError = 'Lỗi gửi báo cáo: $e';
        });
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.red),
                SizedBox(width: 8),
                Expanded(child: Text('Không thể gửi báo cáo', style: TextStyle(fontSize: 16))),
              ],
            ),
            content: Text('$e', style: const TextStyle(fontSize: 13.5)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đã hiểu', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final b = widget.booking;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C28) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thanh kéo drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF79009).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.handyman_rounded,
                      color: Color(0xFFD97706),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Báo Cáo Sự Cố Phòng',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${b.roomTitle} • Chủ trọ: ${b.hostName.isNotEmpty ? b.hostName : "Chủ phòng"}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Mục 1: Chọn danh mục sự cố
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '1. Loại sự cố cần hỗ trợ (*)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: Text(
                      _selectedCategory,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: RoomIssueCategories.all.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    avatar: Icon(
                      _getCategoryIcon(cat),
                      size: 16,
                      color: isSelected ? Colors.white : AppColors.primary,
                    ),
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : const Color(0xFF334155)),
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedCategory = cat);
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? const Color(0xFF334155) : Colors.transparent),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Mục 2: Mức độ khẩn cấp
              const Text(
                '2. Mức độ khẩn cấp',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildSeverityOption(
                    severity: RoomIssueSeverities.low,
                    label: 'Bình thường',
                    sublabel: 'Trong 3-5 ngày',
                    icon: Icons.check_circle_outline_rounded,
                    color: const Color(0xFF16A34A),
                    bgColor: const Color(0xFFDCFCE7),
                  ),
                  const SizedBox(width: 8),
                  _buildSeverityOption(
                    severity: RoomIssueSeverities.medium,
                    label: 'Cần sửa sớm',
                    sublabel: 'Trong 24-48 giờ',
                    icon: Icons.error_outline_rounded,
                    color: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFEF3C7),
                  ),
                  const SizedBox(width: 8),
                  _buildSeverityOption(
                    severity: RoomIssueSeverities.high,
                    label: 'Khẩn cấp',
                    sublabel: 'Cần thợ ngay',
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFDC2626),
                    bgColor: const Color(0xFFFEE2E2),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Mục 3: Mô tả chi tiết
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '3. Mô tả cụ thể sự cố (*)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (_descError != null)
                    const Text(
                      '* Bắt buộc nhập',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // Gợi ý nhanh sự cố theo danh mục
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _getQuickSuggestions(_selectedCategory).map((suggestion) {
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _descController.text = suggestion;
                        _descError = null;
                        _submitError = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF8FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFB2DDFF),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 13,
                            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF175CD3),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            suggestion,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF175CD3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Nhập vị trí và tình trạng hỏng hóc cần sửa chữa...',
                  hintStyle: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                  errorText: _descError,
                  errorMaxLines: 2,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _descError != null
                          ? Colors.red
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _descError != null
                          ? Colors.red
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _descError != null ? Colors.red : AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Mục 4: Ảnh chụp hiện trường sự cố (Tùy chọn)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '4. Ảnh chụp hiện trường (Tùy chọn)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  Text(
                    '${_selectedImages.length}/3 ảnh',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    if (_selectedImages.length < 3)
                      InkWell(
                        onTap: _showImageSourcePicker,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 80,
                          height: 80,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 24),
                              SizedBox(height: 4),
                              Text('Thêm ảnh', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ..._selectedImages.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final img = entry.value;
                      return Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                              image: DecorationImage(
                                image: FileImage(File(img.path)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 12,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedImages.removeAt(idx);
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Mục 5: Thông tin người liên hệ
              const Text(
                '5. Thông tin người báo sự cố',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Họ và tên',
                        labelStyle: const TextStyle(fontSize: 12),
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Số điện thoại (*)',
                        labelStyle: const TextStyle(fontSize: 12),
                        errorText: _phoneError,
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Thông báo lỗi tổng quan nếu có
              if (_submitError != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _submitError!,
                          style: const TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Nút Gửi Báo Cáo
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitIssue,
                  icon: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isSubmitting
                        ? 'Đang gửi báo cáo sự cố...'
                        : 'GỬI BÁO CÁO SỰ CỐ ĐẾN CHỦ TRỌ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706), // Warm amber/orange
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeverityOption({
    required String severity,
    required String label,
    required String sublabel,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    final isSelected = _selectedSeverity == severity;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedSeverity = severity),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? bgColor
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? color
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : (isDark ? Colors.white : AppColors.textDark),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 9.5,
                  color: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
