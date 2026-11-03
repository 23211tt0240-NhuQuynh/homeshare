import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/booking_service.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/vietqr_helper.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/room_model.dart';
import '../../auth/providers/user_provider.dart';
import 'renter_bookings_screen.dart';

/// Màn hình Thanh toán đặt phòng / cọc phòng chuẩn Figma
/// Tích hợp Mã QR chuyển khoản thật 100% đến STK 0382542737 MBBank - TRẦN THANH ANH TOÀN
class BookingPaymentScreen extends ConsumerStatefulWidget {
  final RoomModel room;
  final BookingRequestModel booking;
  final double paymentAmount;
  final String paymentType; // 'deposit' (tiền cọc) hoặc 'full' (tháng đầu + cọc)

  const BookingPaymentScreen({
    super.key,
    required this.room,
    required this.booking,
    required this.paymentAmount,
    this.paymentType = 'deposit',
  });

  @override
  ConsumerState<BookingPaymentScreen> createState() => _BookingPaymentScreenState();
}

class _BookingPaymentScreenState extends ConsumerState<BookingPaymentScreen> {
  late String _transferContent;
  late String _qrImageUrl;
  late String _emvcoPayload;

  static const int timeoutMinutes = 15; // Giai đoạn 1: 15 phút đếm ngược quét QR giữ chỗ
  Timer? _countdownTimer;
  int _secondsRemaining = timeoutMinutes * 60; // 15 phút đếm ngược giữ phòng
  bool _isConfirming = false;
  bool _isAutoCancelling = false;
  bool _useVectorQrFallback = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider).value;
    final rCode = (widget.booking.renterUserCode.isNotEmpty)
        ? widget.booking.renterUserCode
        : ((profile?.userCode.isNotEmpty == true)
            ? profile!.userCode
            : UserProfile.generateUserCode(seed: widget.booking.renterId, role: 'renter'));
    // Nội dung chuyển khoản chỉ cần lấy ID của phòng
    final roomId = widget.room.id.isNotEmpty
        ? widget.room.id
        : widget.booking.roomId;

    _transferContent = IdGenerator.transferContent(
      renterCode: rCode,
      roomCode: roomId,
    );

    // Tạo link ảnh VietQR.io và chuỗi EMVCo Napas247 thật
    _qrImageUrl = VietQRHelper.buildVietQrImageUrl(
      amount: widget.paymentAmount,
      addInfo: _transferContent,
      accountNo: VietQRHelper.defaultAccountNo,
      accountName: VietQRHelper.defaultAccountName,
    );

    _emvcoPayload = VietQRHelper.generateNapasEmvcoPayload(
      amount: widget.paymentAmount,
      addInfo: _transferContent,
      accountNo: VietQRHelper.defaultAccountNo,
      bankBin: VietQRHelper.defaultBankBin,
    );

    // Tính toán thời gian còn lại (15 phút tính từ lúc tạo đơn)
    final created = widget.booking.createdAt;
    final expiresAt = created.add(const Duration(minutes: timeoutMinutes));
    final diff = expiresAt.difference(DateTime.now()).inSeconds;
    _secondsRemaining = diff > 0 ? diff : 0;

    // Kích hoạt đồng hồ đếm ngược
    _startTimer();

    if (_secondsRemaining <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleExpired();
      });
    }

    // Nếu ID phòng còn trống thì mới truy vấn ID từ Firestore
    if (roomId.isEmpty) {
      _resolveRoomCodeFromFirestore(rCode);
    }
  }

  Future<void> _resolveRoomCodeFromFirestore(String renterCode) async {
    try {
      final targetDocId = widget.room.id.isNotEmpty
          ? widget.room.id
          : widget.booking.roomId;
      if (targetDocId.isNotEmpty) {
        final roomDoc = await FirebaseFirestore.instance.collection('host_rooms').doc(targetDocId).get();
        if (roomDoc.exists) {
          final newContent = IdGenerator.transferContent(
            renterCode: renterCode,
            roomCode: roomDoc.id,
          );
          if (mounted && _transferContent != newContent) {
            setState(() {
              _transferContent = newContent;
              _qrImageUrl = VietQRHelper.buildVietQrImageUrl(
                amount: widget.paymentAmount,
                addInfo: _transferContent,
                accountNo: VietQRHelper.defaultAccountNo,
                accountName: VietQRHelper.defaultAccountName,
              );
              _emvcoPayload = VietQRHelper.generateNapasEmvcoPayload(
                amount: widget.paymentAmount,
                addInfo: _transferContent,
                accountNo: VietQRHelper.defaultAccountNo,
                bankBin: VietQRHelper.defaultBankBin,
              );
            });
          }
        }
      }
    } catch (_) {}
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) {
          setState(() => _secondsRemaining--);
        }
      } else {
        timer.cancel();
        if (mounted) {
          _handleExpired();
        }
      }
    });
  }

  Future<void> _handleExpired() async {
    if (_isAutoCancelling) return;
    _isAutoCancelling = true;
    _countdownTimer?.cancel();

    try {
      if (widget.booking.id.isNotEmpty) {
        await FirebaseFirestore.instance.collection('bookings').doc(widget.booking.id).set({
          'status': 'cancelled',
          'cancelReason': 'Tự động hủy do quá thời hạn quét mã QR giữ chỗ 15 phút',
          'subTag': 'Đã hủy',
          'description': 'Quá hạn quét mã QR 15 phút',
          'cancelledAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'daHuy': true,
        }, SetOptions(merge: true));

        // Giải phóng giữ phòng trên host_rooms để người khác có thể đặt ngay
        final roomId = widget.room.id.isNotEmpty ? widget.room.id : widget.booking.roomId;
        if (roomId.isNotEmpty) {
          await FirebaseFirestore.instance.collection('host_rooms').doc(roomId).set({
            'status': 'available',
            'isHolding': false,
            'holdingBookingId': FieldValue.delete(),
            'holdingRenterId': FieldValue.delete(),
            'holdingExpiresAt': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      // Khôi phục bài đăng nếu quá hạn thanh toán 6 tiếng
      final targetRoomId = widget.booking.roomId.isNotEmpty
          ? widget.booking.roomId
          : widget.room.id;
      if (targetRoomId.isNotEmpty) {
        await BookingService().restorePostOnCancelledBooking(targetRoomId);
      }
      if (widget.room.id.isNotEmpty && widget.room.id != targetRoomId) {
        await BookingService().restorePostOnCancelledBooking(widget.room.id);
      }
    } catch (e) {
      debugPrint('Error auto cancelling booking: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.timer_off_outlined, color: AppColors.danger),
            SizedBox(width: 8),
            Text(
              'Hết thời gian thanh toán',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'Đã quá thời hạn 15 phút để hoàn tất quét mã QR thanh toán. Đơn đặt phòng này đã tự động hủy để giải phóng phòng cho người khác.',
          style: TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const RenterBookingsScreen(initialStatusFilter: 'Đã hủy'),
                ),
              );
            },
            child: const Text('Xem danh sách đơn'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00:00';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label: $text ✓'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onConfirmPayment() async {
    if (_secondsRemaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thời gian quét mã QR 15 phút đã hết. Đơn đã tự động hủy!'),
          backgroundColor: AppColors.danger,
        ),
      );
      _handleExpired();
      return;
    }

    setState(() => _isConfirming = true);

    try {
      final isFullPayment = widget.paymentType == 'full';
      final typeTitle = isFullPayment ? 'toàn bộ tiền thuê' : 'tiền cọc';
      final durationText = _secondsRemaining > 0 ? 'Còn ${_formatDuration(_secondsRemaining)}' : 'Hết hạn';
      final amountFormatted = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(widget.paymentAmount);

      // 1. Cập nhật trạng thái booking thành chờ Admin xác nhận trong Firestore (100% tiếng Anh)
      final confirmationExpiresAt = DateTime.now().add(const Duration(hours: 6));
      if (widget.booking.id.isNotEmpty) {
        await FirebaseFirestore.instance.collection('bookings').doc(widget.booking.id).set({
          'status': 'pending_confirmation',
          'description': 'Chờ xác nhận',
          'isPaid': false,
          'paymentType': widget.paymentType,
          'paymentAmount': widget.paymentAmount,
          'transferNote': _transferContent,
          'userCode': _transferContent,
          'durationText': durationText,
          'note': isFullPayment ? 'Thanh toán toàn bộ tiền phòng (không tính cọc)' : 'Đặt cọc giữ phòng',
          'confirmedAt': FieldValue.serverTimestamp(),
          'confirmationDeadline': Timestamp.fromDate(confirmationExpiresAt),
          'updatedAt': FieldValue.serverTimestamp(),
          // Xóa triệt để các trường tiếng Việt trên Firebase
          'trangThai': FieldValue.delete(),
          'moTa': FieldValue.delete(),
          'daThanhToan': FieldValue.delete(),
          'hinhThucThanhToan': FieldValue.delete(),
          'soTienThanhToan': FieldValue.delete(),
          'ghiChuChuyenKhoan': FieldValue.delete(),
          'maNguoiDung': FieldValue.delete(),
          'hanChuyen': FieldValue.delete(),
          'ghiChu': FieldValue.delete(),
          'ngayXacNhan': FieldValue.delete(),
          'ngayCapNhat': FieldValue.delete(),
        }, SetOptions(merge: true));

        // Chuyển phòng sang trạng thái pending_confirmation (Khóa chính thức 6 tiếng chờ Admin/Host duyệt)
        final targetRoomId = widget.room.id.isNotEmpty ? widget.room.id : widget.booking.roomId;
        if (targetRoomId.isNotEmpty) {
          await FirebaseFirestore.instance.collection('host_rooms').doc(targetRoomId).set({
            'isHolding': false,
            'status': 'pending_confirmation',
            'depositStatus': 'pending_confirmation',
            'holdingBookingId': FieldValue.delete(),
            'holdingRenterId': FieldValue.delete(),
            'holdingExpiresAt': FieldValue.delete(),
            'confirmationDeadline': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 6))),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      // 1b. Giai đoạn 2: Chuyển host_rooms sang pending_confirmation (khóa phòng 6 tiếng chờ Admin/Host đối soát)
      final targetRoomId = widget.room.id.isNotEmpty ? widget.room.id : widget.booking.roomId;
      if (targetRoomId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('host_rooms').doc(targetRoomId).set({
          'isHolding': false,
          'status': 'pending_confirmation',
          'depositStatus': 'pending_confirmation',
          'holdingBookingId': FieldValue.delete(),
          'holdingRenterId': FieldValue.delete(),
          'holdingExpiresAt': FieldValue.delete(),
          'confirmationDeadline': Timestamp.fromDate(confirmationExpiresAt),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 2. Gửi thông báo đến Admin (vaiTroNguoiNhan: 'admin')
      final notifId = IdGenerator.notification();
      await FirebaseFirestore.instance.collection('notifications').doc(notifId).set({
        'id': notifId,
        'recipientRole': 'admin',
        'title': 'Khách thuê đã chuyển khoản ngoài app',
        'message': 'Khách ${widget.booking.renterName} (Mã: $_transferContent) đã bấm xác nhận chuyển khoản $typeTitle $amountFormatted cho phòng "${widget.room.title}". Ghi chú CK: "$_transferContent".',
        'notificationType': 'booking',
        'bookingId': widget.booking.id,
        'userCode': _transferContent,
        'paymentType': widget.paymentType,
        'paymentAmount': widget.paymentAmount,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2b. Gửi thông báo đến Chủ trọ (Role Host: pendingAction - Đang xử lý)
      final hostId = widget.booking.hostId.isNotEmpty
          ? widget.booking.hostId
          : widget.room.hostId;
      if (hostId.isNotEmpty && hostId != 'guest') {
        final hostNotifId = IdGenerator.notification();
        await FirebaseFirestore.instance.collection('notifications').doc(hostNotifId).set({
          'id': hostNotifId,
          'notificationId': hostNotifId,
          'receiverId': hostId,
          'senderId': widget.booking.renterId,
          'recipientRole': 'host',
          'notificationType': 'pendingAction',
          'title': 'Yêu cầu đặt phòng đang chờ xử lý',
          'message': 'Khách ${widget.booking.renterName} đã chuyển khoản $typeTitle $amountFormatted cho phòng "${widget.room.title}". Đang chờ Admin xác nhận.',
          'bookingId': widget.booking.id,
          'bookingCode': widget.booking.id,
          'roomId': widget.room.id,
          'roomCode': widget.room.roomCode.isNotEmpty ? widget.room.roomCode : widget.room.maPhong,
          'roomTitle': widget.room.title,
          'roomFloorInfo': 'Tầng ${widget.room.floor > 0 ? widget.room.floor : 1} • ${widget.room.roomType}',
          'propertyId': widget.room.propertyId,
          'amount': widget.paymentAmount,
          'statusId': 'pending',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'renterName': widget.booking.renterName,
          'renterAvatarUrl': '',
          'checkInDate': Timestamp.fromDate(widget.booking.moveInDate),
          'paymentMethod': 'Chuyển khoản QR',
          'paymentType': widget.paymentType,
        });
      }

      // 2c. Ẩn bài đăng ngay khi gửi thông báo đặt phòng đang chờ xử lý
      final bookingService = BookingService();
      final targetRoomId = widget.booking.roomId.isNotEmpty
          ? widget.booking.roomId
          : widget.room.id;
      if (targetRoomId.isNotEmpty) {
        await bookingService.hidePostOnPendingBooking(
          targetRoomId,
          reason: 'Đang có yêu cầu đặt phòng chờ xử lý',
        );
      }
      if (widget.room.id.isNotEmpty && widget.room.id != targetRoomId) {
        await bookingService.hidePostOnPendingBooking(
          widget.room.id,
          reason: 'Đang có yêu cầu đặt phòng chờ xử lý',
        );
      }

      // 3. Ghi vết kiểm toán hệ thống vào audit_logs
      final logId = IdGenerator.auditLog();
      await FirebaseFirestore.instance.collection('audit_logs').doc(logId).set({
        'id': logId,
        'action': 'Khách xác nhận chuyển khoản',
        'actor': widget.booking.renterName,
        'actorRole': 'renter',
        'actorUid': widget.booking.renterId,
        'actorId': widget.booking.renterId,
        'performer': widget.booking.renterName,
        'performerId': widget.booking.renterId,
        'category': 'taiChinh',
        'details':
            'Khách ${widget.booking.renterName} (Mã: $_transferContent) báo đã chuyển khoản ngoài app số tiền $amountFormatted ($typeTitle). Ghi chú CK: "$_transferContent". Đang chờ Admin đối soát.',
        'target': 'Đơn ${widget.booking.id}',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Thông báo hoàn tất thanh toán
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primaryContainer,
                    child: Icon(Icons.check_circle, size: 48, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'ĐÃ GỬI XÁC NHẬN CHUYỂN KHOẢN!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Yêu cầu thanh toán $typeTitle $amountFormatted cho phòng "${widget.room.title}" đã được gửi đến Ban Quản Trị.\n\n'
                    'Mã đối soát ghi chú chuyển khoản của bạn: "$_transferContent".\n'
                    'Admin sẽ đối soát sao kê và duyệt phòng cho bạn trong ít phút!',
                    style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textDark),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx); // Đóng dialog
                        // Điều hướng về danh sách đơn đặt phòng
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RenterBookingsScreen(),
                          ),
                        );
                      },
                      child: const Text('Xem Đơn Đặt Phòng Của Tôi', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConfirming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Thanh Toán Đặt Phòng'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Thẻ đếm ngược thời gian giữ phòng
            _buildCountdownBanner(),

            const SizedBox(height: 16),

            // 2. Thẻ Mã QR Chuyển Khoản Thật (VietQR MBBank)
            _buildQrCard(),

            const SizedBox(height: 16),

            // 3. Thẻ Thông Tin Thụ Hưởng Chi Tiết (Có nút Copy)
            _buildBankDetailsCard(currencyFmt),

            const SizedBox(height: 16),

            // 4. Hướng dẫn các bước thanh toán
            _buildGuideCard(),

            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActionBar(),
    );
  }

  Widget _buildCountdownBanner() {
    final isExpiringSoon = _secondsRemaining < 300; // Dưới 5 phút

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isExpiringSoon ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpiringSoon ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time_filled,
            size: 20,
            color: isExpiringSoon ? Colors.red : AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Phòng đang được tạm giữ (Thời hạn 15 phút)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDark),
                ),
                Text(
                  _secondsRemaining > 0
                      ? 'Vui lòng chuyển khoản trong 15 phút để hoàn tất giữ chỗ'
                      : 'Đơn đặt phòng đã hết thời hạn giữ phòng',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isExpiringSoon ? Colors.red : AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _formatDuration(_secondsRemaining),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'MBBANK',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'NAPAS 24/7',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'VIETQR THẬT',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Quét mã QR bằng App Ngân Hàng để chuyển khoản',
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 14),

          // Khung hiển thị mã QR thật
          Semantics(
            image: true,
            label: 'Mã QR thanh toán chuyển khoản ngân hàng MBBank, số tài khoản ${VietQRHelper.defaultAccountNo}, chủ tài khoản ${VietQRHelper.defaultAccountDisplayName}, số tiền ${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(widget.paymentAmount)}, nội dung: $_transferContent',
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
              ),
              child: _useVectorQrFallback
                  ? QrImageView(
                      data: _emvcoPayload,
                      version: QrVersions.auto,
                      size: 240.0,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.primary),
                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                    )
                  : CachedNetworkImage(
                      imageUrl: _qrImageUrl,
                      height: 260,
                      width: 260,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => SizedBox(
                        height: 240,
                        width: 240,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              const SizedBox(height: 10),
                              Text('Đang tạo mã VietQR thật...', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) {
                        // Tự động chuyển sang fallback QrImageView offline
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _useVectorQrFallback = true);
                        });
                        return QrImageView(
                          data: _emvcoPayload,
                          version: QrVersions.auto,
                          size: 240.0,
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Quét mã sẽ TỰ ĐỘNG ĐIỀN đúng số tài khoản, tên chủ thẻ và số tiền',
            style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetailsCard(NumberFormat currencyFmt) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'THÔNG TIN CHUYỂN KHOẢN THỦ CÔNG',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
              ),
            ],
          ),
          const Divider(height: 20),

          // Ngân hàng
          _buildInfoTile(
            label: 'Ngân hàng thụ hưởng',
            value: VietQRHelper.defaultBankName,
            isBold: true,
          ),
          const SizedBox(height: 10),

          // Số tài khoản
          _buildCopyableTile(
            label: 'Số tài khoản',
            value: VietQRHelper.defaultAccountNo,
            copyText: VietQRHelper.defaultAccountNo,
            isHighlight: true,
          ),
          const SizedBox(height: 10),

          // Chủ tài khoản
          _buildCopyableTile(
            label: 'Chủ tài khoản',
            value: VietQRHelper.defaultAccountDisplayName,
            copyText: VietQRHelper.defaultAccountDisplayName,
            isBold: true,
          ),
          const SizedBox(height: 10),

          // Số tiền
          _buildCopyableTile(
            label: 'Số tiền thanh toán',
            value: currencyFmt.format(widget.paymentAmount),
            copyText: widget.paymentAmount.toInt().toString(),
            isHighlight: true,
            highlightColor: const Color(0xFFDC2626),
          ),
          const SizedBox(height: 10),

          // Nội dung chuyển khoản
          _buildCopyableTile(
            label: 'Nội dung chuyển khoản (Mã người dùng & ID phòng)',
            value: _transferContent,
            copyText: _transferContent,
            isBold: true,
            isHighlight: true,
            highlightColor: AppColors.primary,
            subtitle: 'Chỉ gồm mã người dùng và ID phòng (Ví dụ: $_transferContent)',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({required String label, required String value, bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildCopyableTile({
    required String label,
    required String value,
    required String copyText,
    String? subtitle,
    bool isBold = false,
    bool isHighlight = false,
    Color? highlightColor,
  }) {
    return Semantics(
      button: true,
      label: '$label: $value. Chạm để sao chép',
      child: InkWell(
        onTap: () => _copyToClipboard(copyText, label),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: isHighlight ? 16 : 14,
                        fontWeight: (isBold || isHighlight) ? FontWeight.bold : FontWeight.w600,
                        color: highlightColor ?? (isHighlight ? AppColors.primary : AppColors.textDark),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 10.5, color: AppColors.primary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy, size: 14, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text('Sao chép', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Color(0xFF1D4ED8)),
              SizedBox(width: 6),
              Text(
                'Lưu ý thanh toán an toàn',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1D4ED8)),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '• Quét mã QR hoặc nhập chính xác STK 0382542737 tại MBBank.\n'
            '• Giữ đúng nội dung chuyển khoản để hệ thống tự động đối soát.\n'
            '• Sau khi chuyển tiền, nhấn nút "Tôi đã chuyển khoản thành công" bên dưới.',
            style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF1E3A8A)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    final isExpired = _secondsRemaining <= 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isExpired ? Colors.grey : AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: (_isConfirming || isExpired) ? null : _onConfirmPayment,
            child: _isConfirming
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isExpired ? Icons.timer_off : Icons.check_circle_outline, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isExpired ? 'Hết Hạn Giữ Phòng (Đặt Lại)' : 'Tôi Đã Chuyển Khoản Thành Công',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
