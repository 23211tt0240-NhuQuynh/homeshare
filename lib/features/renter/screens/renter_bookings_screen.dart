import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/room_model.dart';
import '../../../core/services/booking_service.dart';
import '../../../core/services/room_service.dart';
import '../../../core/services/host_review_service.dart';
import '../../../core/utils/host_review_policy.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/widgets/host_review_sheet.dart';
import 'booking_payment_screen.dart';
import '../widgets/checkin_qr_bottom_sheet.dart';
import '../widgets/send_roommate_invite_sheet.dart';
import '../widgets/report_room_issue_bottom_sheet.dart';
import 'user_notifications_screen.dart';

class RenterBookingsScreen extends ConsumerStatefulWidget {
  final String? initialStatusFilter;
  const RenterBookingsScreen({super.key, this.initialStatusFilter});

  @override
  ConsumerState<RenterBookingsScreen> createState() =>
      _RenterBookingsScreenState();
}

class _RenterBookingsScreenState extends ConsumerState<RenterBookingsScreen> {
  String _selectedStatusFilter = 'Tất cả';
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.initialStatusFilter != null && widget.initialStatusFilter!.isNotEmpty) {
      final f = widget.initialStatusFilter!.toLowerCase();
      if (f == 'chờ duyệt' || f == 'pending' || f == 'đang xử lý') {
        _selectedStatusFilter = 'Đang xử lý';
      } else if (f == 'active' || f == 'dango' || f == 'đang ở') {
        _selectedStatusFilter = 'Đang ở';
      } else if (f == 'approved' || f == 'daduyet' || f == 'đã duyệt') {
        _selectedStatusFilter = 'Đã duyệt';
      } else if (f == 'cancelled' || f == 'dahuy' || f == 'đã hủy') {
        _selectedStatusFilter = 'Đã hủy';
      } else {
        _selectedStatusFilter = widget.initialStatusFilter!;
      }
    }
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Color _getStatusTextColor(BookingRequestModel b) {
    if (b.isCancelled) return const Color(0xFFB42318);
    if (b.isCheckedOut) return const Color(0xFF475467);
    if (b.isActive) return const Color(0xFF027A48);
    if (b.isApproved) return const Color(0xFF175CD3);
    if (b.status == 'pending_payment') return const Color(0xFFB54708);
    return const Color(0xFFB54708); // pending
  }

  Color _getStatusBgColor(BookingRequestModel b) {
    if (b.isCancelled) return const Color(0xFFFEF3F2);
    if (b.isCheckedOut) return const Color(0xFFF2F4F7);
    if (b.isActive) return const Color(0xFFECFDF3);
    if (b.isApproved) return const Color(0xFFEFF8FF);
    if (b.status == 'pending_payment') return const Color(0xFFFEF0C7);
    return const Color(0xFFFEF0C7); // pending
  }

  String _getStatusText(BookingRequestModel b) {
    if (b.status == 'choXacNhanThayDoi') {
      return 'Đã cọc • Chờ bạn xác nhận đổi ngày đến';
    }
    if (b.isCancelled) {
      return 'Đã hủy';
    }
    if (b.isCheckedOut) {
      return 'Đã hoàn tất kỳ ở • Đã trả phòng';
    }
    if (b.isActive) {
      return 'Đang ở (Active)';
    }
    if (b.isApproved) {
      return 'Đã duyệt • Sẵn sàng nhận phòng';
    }
    if (b.status == 'pending_payment') {
      return 'Đang xử lý • Chờ thanh toán';
    }
    if (b.status == 'pending_confirmation') {
      return 'Đang xử lý • Chờ xác nhận';
    }
    return 'Đang xử lý';
  }

  String _formatRemainingTime(Duration duration) {
    if (duration.isNegative || duration.inSeconds <= 0) {
      return 'Hết hạn';
    }
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    final s = duration.inSeconds % 60;
    if (h > 0) {
      return '${h}g ${m.toString().padLeft(2, '0')}p';
    }
    return '${m}p ${s.toString().padLeft(2, '0')}s';
  }

  void _checkAndAutoCancelExpired(List<BookingRequestModel> bookings) {
    final now = DateTime.now();
    for (final b in bookings) {
      if (b.status == 'pending_payment' && !b.isCancelled) {
        final expiresAt = b.createdAt.add(const Duration(minutes: 15));
        if (now.isAfter(expiresAt)) {
          ref.read(bookingServiceProvider).cancelBooking(
            b.id,
            reason: 'Tự động hủy do quá thời gian quét mã QR 15 phút',
          );
        }
      }
    }
  }

  Future<void> _openPaymentScreen(BookingRequestModel b) async {
    final expiresAt = b.createdAt.add(const Duration(minutes: 15));
    if (DateTime.now().isAfter(expiresAt)) {
      await ref.read(bookingServiceProvider).cancelBooking(
        b.id,
        reason: 'Tự động hủy do quá thời gian quét mã QR 15 phút',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đơn đặt phòng này đã quá hạn quét mã QR 15 phút và đã tự động hủy.'),
            backgroundColor: Color(0xFFD92D20),
          ),
        );
      }
      return;
    }

    RoomModel? room;
    try {
      room = await ref.read(roomServiceProvider).resolveRentedRoom(
        roomId: b.roomId,
        hostId: b.hostId,
        roomCode: b.roomCode,
        title: b.roomTitle,
        price: b.roomPrice,
      );
    } catch (_) {}

    room ??= RoomModel(
      id: b.roomId,
      title: b.roomTitle,
      description: 'Phòng thuê ${b.roomTitle}',
      address: b.roomAddress,
      district: 'Hồ Chí Minh',
      area: 25.0,
      roomType: 'Phòng trọ',
      amenities: const [],
      images: const [],
      hostPhone: '',
      createdAt: b.createdAt,
      price: b.roomPrice,
      hostId: b.hostId,
      hostName: b.hostName,
      deposit: b.deposit,
    );

    final amount = b.totalAmount > 0
        ? b.totalAmount
        : (b.deposit > 0 ? b.deposit : b.roomPrice);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingPaymentScreen(
            room: room!,
            booking: b,
            paymentAmount: amount,
            paymentType: b.paymentOption.isNotEmpty ? b.paymentOption : 'deposit',
          ),
        ),
      );
    }
  }

  bool _canReviewHost(BookingRequestModel booking) {
    if (!HostReviewPolicy.isReviewableBooking(booking)) return false;
    return !(ref.watch(hostReviewExistsProvider(booking.id)).value ?? false);
  }

  Future<void> _openHostReview(BookingRequestModel booking) async {
    final ok = await showHostReviewSheet(
      context,
      hostId: booking.hostId,
      hostName: booking.hostName,
      bookingId: booking.id,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã gửi đánh giá thành công.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _cancelBookingDialog(BookingRequestModel booking) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Xác nhận hủy đơn đặt phòng',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn có chắc chắn muốn hủy đơn đặt "${booking.roomTitle}" không?\n'
              'Lưu ý: Thao tác này sẽ chuyển đơn sang trạng thái "Đã hủy".',
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: Color(0xFF475467),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Nhập lý do hủy (tùy chọn)...',
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Giữ lại đơn',
              style: TextStyle(color: Color(0xFF667085)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD92D20),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(bookingServiceProvider)
            .cancelBooking(
              booking.id,
              reason: reasonController.text.trim().isNotEmpty
                  ? reasonController.text.trim()
                  : 'Người thuê chủ động hủy',
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã hủy đơn thuê thành công'),
              backgroundColor: Color(0xFF155EEF),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi hủy: $e'),
              backgroundColor: const Color(0xFFD92D20),
            ),
          );
        }
      }
    }
  }


  Future<void> _openReportRoomIssueSheet(BookingRequestModel b) async {
    final ok = await showReportRoomIssueBottomSheet(context, booking: b);
    if (ok == true && mounted) {
      setState(() {});
    }
  }

  void _showCheckinQrDialog(BookingRequestModel b) {
    CheckinQrBottomSheet.show(context, b);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final currencyFormatter = NumberFormat('#,###', 'vi_VN');

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Quản lý Đơn Thuê')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'Vui lòng đăng nhập để xem đơn thuê & lịch hẹn',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final bookingsAsync = ref.watch(renterBookingsStreamProvider(user.uid));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Lịch xem phòng & Đơn thuê')),
      body: Column(
        children: [
          // Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children:
                    ['Tất cả', 'Đang xử lý', 'Đã duyệt', 'Đang ở', 'Đã trả phòng', 'Đã hủy'].map(
                      (s) {
                        final isSel = _selectedStatusFilter == s;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ChoiceChip(
                            label: Text(s),
                            selected: isSel,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : AppColors.textDark,
                              fontSize: 12,
                              fontWeight: isSel
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            onSelected: (_) =>
                                setState(() => _selectedStatusFilter = s),
                          ),
                        );
                      },
                    ).toList(),
              ),
            ),
          ),

          // Danh sách đơn thuê
          Expanded(
            child: bookingsAsync.when(
              data: (bookings) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _checkAndAutoCancelExpired(bookings);
                  }
                });

                var filtered = bookings;
                if (_selectedStatusFilter == 'Đang xử lý' || _selectedStatusFilter == 'Chờ duyệt') {
                  filtered = bookings.where((b) => b.isPending).toList();
                } else if (_selectedStatusFilter == 'Đã duyệt') {
                  filtered = bookings.where((b) => b.isApproved).toList();
                } else if (_selectedStatusFilter == 'Đang ở') {
                  filtered = bookings.where((b) => b.isActive).toList();
                } else if (_selectedStatusFilter == 'Đã trả phòng') {
                  filtered = bookings.where((b) => b.isEnded).toList();
                } else if (_selectedStatusFilter == 'Đã hủy') {
                  filtered = bookings.where((b) => b.isCancelled).toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selectedStatusFilter == 'Tất cả'
                              ? 'Không có đơn thuê hoặc lịch hẹn nào'
                              : 'Không có đơn thuê nào ở trạng thái "$_selectedStatusFilter"',
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final b = filtered[index];
                    final textColor = _getStatusTextColor(b);
                    final bgColor = _getStatusBgColor(b);
                    final statusText = _getStatusText(b);
                    final priceStr =
                        '${currencyFormatter.format(b.roomPrice)} đ/tháng';
                    final expiresAt = b.createdAt.add(const Duration(minutes: 15));
                    final remaining = expiresAt.difference(DateTime.now());
                    final isPaymentPending =
                        b.status == 'pending_payment' && !b.isCancelled;

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: isPaymentPending
                            ? () => _openPaymentScreen(b)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Status Header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 4,
                                          backgroundColor: textColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          statusText,
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    DateFormat('dd/MM/yyyy HH:mm').format(b.createdAt),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Room Title
                              Text(
                                b.roomTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.5,
                                  color: AppColors.textDark,
                                ),
                              ),
                              if (b.note == 'Ở ghép') ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF8FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFB2DDFF),
                                    ),
                                  ),
                                  child: const Text(
                                    'Ở ghép',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF175CD3),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                b.roomAddress,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Price & Move-in date
                              Row(
                                children: [
                                  const Icon(
                                    Icons.price_change_outlined,
                                    size: 16,
                                    color: Color(0xFF155EEF),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      priceStr,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF155EEF),
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.calendar_today_outlined,
                                          size: 14,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Dọn vào: ${DateFormat('dd/MM/yyyy').format(b.moveInDate)}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textMuted,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              // Tiền cọc & lý do hủy nếu có
                              if (b.deposit > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.shield_outlined,
                                      size: 14,
                                      color: Color(0xFF027A48),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Tiền cọc: ${currencyFormatter.format(b.deposit)} đ',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF027A48),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              if (b.status == 'choXacNhanThayDoi') ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF0C7),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFFEDF89),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline_rounded,
                                        size: 18,
                                        color: Color(0xFFB54708),
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Chủ trọ đề xuất thay đổi lịch dọn vào. Vui lòng mở Thông báo để xác nhận thay đổi thông tin.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF7A2E0E),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const UserNotificationsScreen(),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          minimumSize: const Size(0, 32),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: const Text(
                                          'Xem ngay',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (b.isCancelled &&
                                  b.cancelReason != null &&
                                  b.cancelReason!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3F2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Lý do hủy: ${b.cancelReason}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFFB42318),
                                    ),
                                  ),
                                ),
                              ],

                              // Countdown banner if pending_payment
                              if (isPaymentPending) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: remaining.isNegative
                                        ? const Color(0xFFFEF3F2)
                                        : const Color(0xFFFEF0C7),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: remaining.isNegative
                                          ? const Color(0xFFFECDCA)
                                          : const Color(0xFFFEDF89),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.timer_outlined,
                                        size: 18,
                                        color: remaining.isNegative
                                            ? const Color(0xFFD92D20)
                                            : const Color(0xFFB54708),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              remaining.isNegative
                                                  ? 'Đã hết hạn quét mã QR giữ chỗ (15 phút)'
                                                  : 'Thời gian quét QR còn lại: ${_formatRemainingTime(remaining)}',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.bold,
                                                color: remaining.isNegative
                                                    ? const Color(0xFFD92D20)
                                                    : const Color(0xFFB54708),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              remaining.isNegative
                                                  ? 'Đơn đặt phòng đang được hệ thống tự động hủy.'
                                                  : 'Chạm để mở lại mã QR và hoàn tất chuyển khoản.',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: remaining.isNegative
                                                    ? const Color(0xFFB42318)
                                                    : const Color(0xFF7A2E0E),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 13,
                                        color: remaining.isNegative
                                            ? const Color(0xFFD92D20)
                                            : const Color(0xFFB54708),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 10),

                              // Landlord info and Action
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.person_pin,
                                          size: 18,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Chủ trọ: ${b.hostName}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 1. Khi ĐÃ DUYỆT: Hiển thị Nút "Mã QR nhận phòng"
                                      if (b.isApproved) ...[
                                        TextButton(
                                          onPressed: () =>
                                              _cancelBookingDialog(b),
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(
                                              0xFFD92D20,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            minimumSize: const Size(50, 36),
                                          ),
                                          child: const Text(
                                            'Hủy',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _showCheckinQrDialog(b),
                                          icon: const Icon(
                                            Icons.qr_code_2_rounded,
                                            size: 18,
                                          ),
                                          label: const Text('Mã QR nhận phòng'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF155EEF,
                                            ),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                            minimumSize: const Size(120, 36),
                                            textStyle: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ],

                                      // 2a. Khi ĐANG XỬ LÝ - CHỜ THANH TOÁN (pending_payment):
                                      if (b.status == 'pending_payment') ...[
                                        TextButton(
                                          onPressed: () =>
                                              _cancelBookingDialog(b),
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(
                                              0xFFD92D20,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            minimumSize: const Size(44, 36),
                                          ),
                                          child: const Text(
                                            'Hủy',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _openPaymentScreen(b),
                                          icon: const Icon(
                                            Icons.qr_code_2_rounded,
                                            size: 16,
                                          ),
                                          label: const Text('Thanh toán'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF155EEF,
                                            ),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                            minimumSize: const Size(90, 36),
                                            textStyle: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ] else if (b.isPending) ...[
                                        // 2b. Khi ĐANG XỬ LÝ - ĐÃ BẤM XÁC NHẬN CHỜ DUYỆT (pending_confirmation):
                                        TextButton(
                                          onPressed: () =>
                                              _cancelBookingDialog(b),
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(
                                              0xFFD92D20,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            minimumSize: const Size(50, 36),
                                          ),
                                          child: const Text(
                                            'Hủy yêu cầu',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],

                                      // 3. Khi ĐANG Ở: Tag xanh lá + Nút Báo sự cố phòng
                                      if (b.isActive) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF3),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: const Color(0xFFA6F4C5),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(
                                                Icons.check_circle_rounded,
                                                size: 16,
                                                color: Color(0xFF12B76A),
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Đang cư trú',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF027A48),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _openReportRoomIssueSheet(b),
                                          icon: const Icon(
                                            Icons.build_rounded,
                                            size: 14,
                                          ),
                                          label: const Text('Báo sự cố phòng'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFD97706),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                            minimumSize: const Size(110, 36),
                                            textStyle: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ],

                                      // 4. Khi ĐÃ TRẢ PHÒNG
                                      if (b.isEnded)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF2F4F7),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Đã trả phòng',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF475467),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),

                                      // 5. Khi ĐÃ HỦY: Tag xám/đỏ
                                      if (b.isCancelled)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF2F4F7),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Đã hủy đơn',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF667085),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              if (b.isActive) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      SendRoommateInviteSheet.show(
                                        context,
                                        booking: b,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.group_add_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Gửi tin ở ghép'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF155EEF),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      minimumSize: const Size.fromHeight(42),
                                      textStyle: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (_canReviewHost(b)) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _openHostReview(b),
                                    icon: const Icon(
                                      Icons.rate_review_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Đánh giá chủ trọ'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: const BorderSide(
                                        color: AppColors.primary,
                                      ),
                                      minimumSize: const Size.fromHeight(42),
                                      textStyle: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Lỗi tải dữ liệu: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
