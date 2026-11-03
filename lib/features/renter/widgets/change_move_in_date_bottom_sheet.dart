import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/booking_service.dart';
import '../../../data/models/booking_model.dart';

/// Modal BottomSheet cho phép Người thuê thay đổi ngày dọn vào ở
/// (Áp dụng cho các đơn đặt thuê / lịch xem phòng ở trạng thái Đang xử lý hoặc Đã duyệt)
class ChangeMoveInDateBottomSheet extends ConsumerStatefulWidget {
  final BookingRequestModel booking;

  const ChangeMoveInDateBottomSheet({
    super.key,
    required this.booking,
  });

  static Future<bool?> show(
    BuildContext context, {
    required BookingRequestModel booking,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeMoveInDateBottomSheet(booking: booking),
    );
  }

  @override
  ConsumerState<ChangeMoveInDateBottomSheet> createState() =>
      _ChangeMoveInDateBottomSheetState();
}

class _ChangeMoveInDateBottomSheetState
    extends ConsumerState<ChangeMoveInDateBottomSheet> {
  late DateTime _selectedDate;
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _quickReasons = [
    'Bận việc đột xuất',
    'Dời lịch công tác',
    'Chờ bạn cùng phòng',
    'Chưa dọn xong nhà cũ',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = widget.booking.moveInDate;
    final currentDay = DateTime(current.year, current.month, current.day);

    // Nếu ngày dọn vào hiện tại vẫn ở tương lai thì mặc định ngày đó,
    // ngược lại (hoặc là ngày cũ) thì mặc định là ngày mai
    if (currentDay.isAfter(today)) {
      _selectedDate = currentDay;
    } else {
      _selectedDate = today.add(const Duration(days: 1));
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String _formatWeekdayVi(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'Thứ Hai';
      case DateTime.tuesday:
        return 'Thứ Ba';
      case DateTime.wednesday:
        return 'Thứ Tư';
      case DateTime.thursday:
        return 'Thứ Năm';
      case DateTime.friday:
        return 'Thứ Sáu';
      case DateTime.saturday:
        return 'Thứ Bảy';
      case DateTime.sunday:
        return 'Chủ Nhật';
      default:
        return '';
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstAllowed = DateTime(now.year, now.month, now.day);
    final lastAllowed = firstAllowed.add(const Duration(days: 180));

    final initial = _selectedDate.isBefore(firstAllowed)
        ? firstAllowed
        : (_selectedDate.isAfter(lastAllowed) ? lastAllowed : _selectedDate);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstAllowed,
      lastDate: lastAllowed,
      helpText: 'CHỌN NGÀY DỌN VÀO MỚI',
      confirmText: 'CHỌN',
      cancelText: 'HỦY',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _applyQuickOffset(int days) {
    final base = DateTime.now();
    final target = DateTime(base.year, base.month, base.day).add(Duration(days: days));
    setState(() {
      _selectedDate = target;
    });
  }

  Future<void> _handleConfirm() async {
    final currentDay = DateTime(
      widget.booking.moveInDate.year,
      widget.booking.moveInDate.month,
      widget.booking.moveInDate.day,
    );

    if (_selectedDate == currentDay && _reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ngày mới khác ngày hiện tại.'),
          backgroundColor: Color(0xFFD92D20),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final bookingService = ref.read(bookingServiceProvider);
      await bookingService.updateMoveInDate(
        bookingId: widget.booking.id,
        newMoveInDate: _selectedDate,
        reason: _reasonController.text.trim(),
        booking: widget.booking,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF027A48),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đã đổi ngày dọn vào sang ${DateFormat('dd/MM/yyyy').format(_selectedDate)} thành công!',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD92D20),
            content: Text('Không thể cập nhật ngày dọn vào: $e'),
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
    final oldDate = widget.booking.moveInDate;
    final oldDateFormatted = DateFormat('dd/MM/yyyy').format(oldDate);
    final newDateFormatted = DateFormat('dd/MM/yyyy').format(_selectedDate);
    final newWeekday = _formatWeekdayVi(_selectedDate);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF8FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFB2DDFF)),
                      ),
                      child: const Icon(
                        Icons.edit_calendar_rounded,
                        color: Color(0xFF155EEF),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Thay Đổi Ngày Dọn Vào',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF101828),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Điều chỉnh lịch nhận phòng & dọn vào ở',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thông tin phòng & ngày hiện tại
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEAECF0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.home_work_outlined,
                                size: 17,
                                color: Color(0xFF155EEF),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.booking.roomTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF101828),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.booking.roomAddress,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Ngày dọn vào hiện tại:',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF475467),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F4F7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  oldDateFormatted,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF344054),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tiêu đề chọn ngày mới
                    const Text(
                      'CHỌN NGÀY DỌN VÀO MỚI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475467),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Hộp chọn ngày tương tác
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFB9E6FE),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.calendar_today_rounded,
                                color: Color(0xFF155EEF),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$newWeekday, $newDateFormatted',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF026AA2),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Chạm để mở lịch chọn ngày cụ thể',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF026AA2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down_circle_outlined,
                              color: Color(0xFF155EEF),
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Quick chip dời nhanh
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQuickChip('+3 ngày', () => _applyQuickOffset(3)),
                          const SizedBox(width: 6),
                          _buildQuickChip('+1 tuần', () => _applyQuickOffset(7)),
                          const SizedBox(width: 6),
                          _buildQuickChip('+2 tuần', () => _applyQuickOffset(14)),
                          const SizedBox(width: 6),
                          _buildQuickChip('+1 tháng', () => _applyQuickOffset(30)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Lý do thay đổi
                    const Text(
                      'LÝ DO THAY ĐỔI (TÙY CHỌN)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475467),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Gợi ý lý do nhanh
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _quickReasons.map((r) {
                        return ActionChip(
                          label: Text(r),
                          labelStyle: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF344054),
                          ),
                          backgroundColor: const Color(0xFFF2F4F7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Color(0xFFEAECF0)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          onPressed: () {
                            setState(() {
                              _reasonController.text = r;
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: _reasonController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Nhập ghi chú thêm cho chủ trọ (nếu có)...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF98A2B3),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFEAECF0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFEAECF0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF155EEF)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Hộp thông báo an toàn
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF8FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFB2DDFF)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Color(0xFF155EEF),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Lịch dọn vào mới sẽ được cập nhật trực tiếp vào đơn thuê và gửi thông báo trực tiếp đến chủ trọ.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF175CD3),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Hàng nút bấm
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF475467),
                              side: const BorderSide(color: Color(0xFFD0D5DD)),
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Đóng'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _handleConfirm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF155EEF),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Xác nhận đổi ngày'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEAECF0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.add_circle_outline_rounded,
              size: 13,
              color: Color(0xFF155EEF),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF344054),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

