import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/host_notification_model.dart';
import '../providers/host_notification_provider.dart';

/// Màn hình xác nhận thay đổi thông tin cọc / phòng (Figma Image 1)
class HostBookingChangeConfirmationScreen extends ConsumerStatefulWidget {
  final HostNotificationModel notification;

  const HostBookingChangeConfirmationScreen({
    super.key,
    required this.notification,
  });

  @override
  ConsumerState<HostBookingChangeConfirmationScreen> createState() =>
      _HostBookingChangeConfirmationScreenState();
}

class _HostBookingChangeConfirmationScreenState
    extends ConsumerState<HostBookingChangeConfirmationScreen> {
  bool _isLoading = false;

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return '${formatter.format(amount)} đ';
  }

  String _weekdayVi(DateTime date) {
    return switch (date.weekday) {
      DateTime.monday => 'Thứ Hai',
      DateTime.tuesday => 'Thứ Ba',
      DateTime.wednesday => 'Thứ Tư',
      DateTime.thursday => 'Thứ Năm',
      DateTime.friday => 'Thứ Sáu',
      DateTime.saturday => 'Thứ Bảy',
      DateTime.sunday => 'Chủ Nhật',
      _ => '',
    };
  }

  Future<void> _handleConfirm() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(hostNotificationRepositoryProvider);
      await repo.confirmBookingChange(
        bookingId: widget.notification.bookingId,
        notificationId: widget.notification.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF027A48),
            content: Text('Đã xác nhận đồng ý thay đổi đặt chỗ thành công!'),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Không thể xác nhận thay đổi đặt chỗ: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Không thể xác nhận thay đổi. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleReject() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(hostNotificationRepositoryProvider);
      await repo.rejectBookingChange(
        bookingId: widget.notification.bookingId,
        notificationId: widget.notification.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFB54708),
            content: Text(
              'Đã từ chối thay đổi. Yêu cầu hoàn cọc đã được ghi nhận.',
            ),
          ),
        );
        Navigator.of(context).pop(false);
      }
    } catch (e) {
      debugPrint('Không thể từ chối thay đổi đặt chỗ: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Không thể từ chối thay đổi. Vui lòng thử lại.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notif = widget.notification;
    final currencyStr = _formatCurrency(notif.amount);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(left: 12),
          child: Center(
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFEAECF0)),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: Color(0xFF101828),
                ),
              ),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Xác nhận thay đổi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101828),
              ),
            ),
            Text(
              'Mã đơn đặt chỗ: ${notif.displayBookingCode}',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF667085),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF0C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: Color(0xFFB54708),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Chờ duyệt',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB54708),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Thẻ thông báo từ Chủ nhà màu vàng
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0x80FEF0C7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFEDF89)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(0xFFF79009),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.notifications_active_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Thông báo từ Chủ nhà',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF101828),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Chủ nhà đã thay đổi thông tin đặt phòng của bạn. Vui lòng kiểm tra và xác nhận.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF344054)),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '"${notif.adjustmentReason?.trim().isNotEmpty == true ? notif.adjustmentReason!.trim() : 'Không có ghi chú bổ sung.'}"',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFFB54708),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 14),

            // 2. Thẻ thông tin chủ nhà
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEAECF0)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFE0EAFF),
                    child: Text(
                      notif.renterName.isNotEmpty
                          ? notif.renterName[0].toUpperCase()
                          : 'K',
                      style: TextStyle(
                        color: Color(0xFF3538CD),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              notif.renterName.isNotEmpty
                                  ? notif.renterName
                                  : 'Khách thuê',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF101828),
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.verified_rounded,
                              size: 15,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          notif.roomTitle.isNotEmpty
                              ? notif.roomTitle
                              : (notif.displayRoomCode.isNotEmpty
                                    ? 'Phòng ${notif.displayRoomCode}'
                                    : 'Căn hộ / Nhà trọ'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: Color(0xFFD0D5DD)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    icon: Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 14,
                    ),
                    label: Text(
                      'Nhắn tin',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // 3. Tiêu đề: Chi tiết thay đổi đặt chỗ
            Row(
              children: [
                Icon(
                  Icons.sync_alt_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8),
                Text(
                  'Chi tiết thay đổi đặt chỗ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF101828),
                  ),
                ),
                Spacer(),
                Text(
                  'Cập nhật 10 phút trước',
                  style: TextStyle(fontSize: 11, color: Color(0xFF667085)),
                ),
              ],
            ),

            SizedBox(height: 14),

            // Mục 1: CĂN PHÒNG ĐĂNG KÝ
            Text(
              '1. CĂN PHÒNG ĐĂNG KÝ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                // Thông tin cũ
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEAECF0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'THÔNG TIN CŨ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF667085),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          notif.displayRoomCode.isNotEmpty
                              ? 'Phòng ${notif.displayRoomCode}'
                              : 'Phòng hiện tại',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF667085),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          notif.roomFloorInfo.isNotEmpty
                              ? notif.roomFloorInfo
                              : 'Phòng trọ',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF98A2B3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 10),
                // Thông tin mới
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF8FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.primary, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'THÔNG TIN MỚI',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          notif.newRoomTitle?.isNotEmpty == true
                              ? notif.newRoomTitle!
                              : (notif.displayRoomCode.isNotEmpty
                                    ? 'Phòng ${notif.displayRoomCode}'
                                    : 'Phòng đã chọn'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          notif.roomTitle.isNotEmpty
                              ? notif.roomTitle
                              : 'Phòng trọ tiện nghi',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Mục 2: NGÀY NHẬN PHÒNG (CHECK-IN)
            Text(
              '2. NGÀY NHẬN PHÒNG (CHECK-IN)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                // Ngày cũ
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEAECF0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'THÔNG TIN CŨ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF667085),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          notif.checkInDate != null
                              ? DateFormat(
                                  'dd/MM/yyyy',
                                ).format(notif.checkInDate!)
                              : 'Chưa đặt',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF667085),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          notif.checkInDate != null
                              ? '(${_weekdayVi(notif.checkInDate!)})'
                              : '',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF98A2B3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 10),
                // Ngày mới
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF3),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF12B76A),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'THÔNG TIN MỚI',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF027A48),
                              ),
                            ),
                            Icon(
                              Icons.trending_up_rounded,
                              size: 14,
                              color: Color(0xFF027A48),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          notif.newCheckInDate != null
                              ? DateFormat(
                                  'dd/MM/yyyy',
                                ).format(notif.newCheckInDate!)
                              : (notif.checkInDate != null
                                    ? DateFormat(
                                        'dd/MM/yyyy',
                                      ).format(notif.checkInDate!)
                                    : 'Chưa đặt'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF027A48),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          notif.newCheckInDate != null
                              ? '(${_weekdayVi(notif.newCheckInDate!)})'
                              : '',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF027A48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Tiền cọc giữ chỗ (Đã thanh toán)
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEAECF0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tiền cọc giữ chỗ (Đã thanh toán)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF667085),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          currencyStr,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF101828),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FADF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Giữ nguyên giá cọc',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF027A48),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 14),

            // Lưu ý bảo vệ người dùng
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF8FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB2DDFF)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.security_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Nếu từ chối, khoản tiền cọc $currencyStr sẽ được hoàn lại 100% vào ví trong vòng 15 phút.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 30),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: Color(0xFFEAECF0))),
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Nút Từ chối
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _handleReject,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF3F2),
                    foregroundColor: const Color(0xFFD92D20),
                    side: BorderSide(color: Color(0xFFFECDCA)),
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.close_rounded, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Từ chối',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12),
              // Nút Xác nhận đồng ý
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.surface,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Xác nhận đồng ý',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
