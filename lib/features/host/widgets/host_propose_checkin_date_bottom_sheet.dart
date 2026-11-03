import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../repositories/checkin_checkout_repository.dart';

/// BottomSheet cho phép Chủ trọ đề xuất thay đổi ngày dọn vào và gửi thông báo cho khách thuê
class HostProposeCheckInDateBottomSheet extends ConsumerStatefulWidget {
  final CheckinCheckoutItem item;

  const HostProposeCheckInDateBottomSheet({
    super.key,
    required this.item,
  });

  static Future<bool?> show(
    BuildContext context, {
    required CheckinCheckoutItem item,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HostProposeCheckInDateBottomSheet(item: item),
    );
  }

  @override
  ConsumerState<HostProposeCheckInDateBottomSheet> createState() =>
      _HostProposeCheckInDateBottomSheetState();
}

class _HostProposeCheckInDateBottomSheetState
    extends ConsumerState<HostProposeCheckInDateBottomSheet> {
  late DateTime _selectedDate;
  late TextEditingController _reasonController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.item.expectedDate;
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: now.subtract(const Duration(days: 7)),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'CHỌN NGÀY DỌN VÀO MỚI',
      confirmText: 'CHỌN',
      cancelText: 'HỦY',
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _sendProposal() async {
    final reason = _reasonController.text.trim();
    if (_selectedDate.year == widget.item.expectedDate.year &&
        _selectedDate.month == widget.item.expectedDate.month &&
        _selectedDate.day == widget.item.expectedDate.day) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFD92D20),
          content: Text('Vui lòng chọn ngày mới khác với ngày dọn vào hiện tại.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final hostUser = ref.read(currentUserProvider);
      final profile = ref.read(userProfileProvider).value;
      final hostName = profile?.displayName ??
          hostUser?.displayName ??
          'Chủ trọ HomeShare';
      final hostId = hostUser?.uid ?? '';

      final newDateStr = DateFormat('dd/MM/yyyy').format(_selectedDate);
      final oldDateStr =
          DateFormat('dd/MM/yyyy').format(widget.item.expectedDate);

      final batch = FirebaseFirestore.instance.batch();

      // 1. Tạo thông báo gửi đến chuông người thuê (notification_user)
      final renterNotifRef = FirebaseFirestore.instance
          .collection(FirestoreCollections.notificationUser)
          .doc();
      batch.set(renterNotifRef, {
        'id': renterNotifRef.id,
        'receiverId': widget.item.renterId,
        'recipientId': widget.item.renterId,
        'userId': widget.item.renterId,
        'recipientRole': 'renter',
        'title': 'Chủ trọ đề xuất đổi lịch dọn vào',
        'message':
            'Chủ trọ đề xuất dời ngày nhận phòng từ $oldDateStr sang $newDateStr.'
            '${reason.isNotEmpty ? " Lý do: $reason" : ""}',
        'notificationType': 'booking_date_change',
        'type': 'booking_date_change',
        'bookingId': widget.item.bookingId,
        'roomId': widget.item.roomId,
        'roomCode': widget.item.roomCode,
        'roomTitle': widget.item.propertyName,
        'checkInDate': Timestamp.fromDate(widget.item.expectedDate),
        'oldCheckInDate': Timestamp.fromDate(widget.item.expectedDate),
        'newCheckInDate': Timestamp.fromDate(_selectedDate),
        'adjustmentReason': reason,
        'hostId': hostId,
        'hostName': hostName,
        'status': 'pending',
        'isRead': false,
        'daDoc': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Cập nhật trạng thái tạm chờ xác nhận trên đơn đặt phòng (bookings)
      if (widget.item.bookingId.isNotEmpty) {
        final bRef = FirebaseFirestore.instance
            .collection(FirestoreCollections.bookings)
            .doc(widget.item.bookingId);
        batch.set(bRef, {
          'newCheckInDate': Timestamp.fromDate(_selectedDate),
          'adjustmentReason': reason,
          'adjustmentStatus': 'pending',
          'status': 'choXacNhanThayDoi',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 3. Tạo thông báo bên phía Chủ trọ để theo dõi (notifications)
      if (hostId.isNotEmpty) {
        final hostNotifRef = FirebaseFirestore.instance
            .collection(FirestoreCollections.notifications)
            .doc();
        batch.set(hostNotifRef, {
          'id': hostNotifRef.id,
          'receiverId': hostId,
          'recipientRole': 'host',
          'notificationType': 'booking_adjustment',
          'type': 'booking_adjustment',
          'title': 'Đã gửi đề xuất đổi lịch dọn vào',
          'message':
              'Đã gửi đề xuất chuyển ngày nhận phòng sang $newDateStr cho khách thuê ${widget.item.renterName}. Đang chờ khách xác nhận.',
          'bookingId': widget.item.bookingId,
          'roomId': widget.item.roomId,
          'roomCode': widget.item.roomCode,
          'roomTitle': widget.item.propertyName,
          'oldCheckInDate': Timestamp.fromDate(widget.item.expectedDate),
          'newCheckInDate': Timestamp.fromDate(_selectedDate),
          'adjustmentReason': reason,
          'status': 'choXacNhanThayDoi',
          'statusId': 'choXacNhanThayDoi',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF027A48),
            content: Text(
              'Đã gửi đề xuất đổi ngày dọn vào ($newDateStr) đến người thuê thành công!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD92D20),
            content: Text('Lỗi khi gửi đề xuất: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final oldDateStr = DateFormat('dd/MM/yyyy').format(item.expectedDate);
    final newDateStr = DateFormat('dd/MM/yyyy').format(_selectedDate);
    final isDateChanged = _selectedDate.day != item.expectedDate.day ||
        _selectedDate.month != item.expectedDate.month ||
        _selectedDate.year != item.expectedDate.year;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thanh kéo nhỏ
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tiêu đề
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF8FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.edit_calendar_rounded,
                    color: Color(0xFF155EEF),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đề xuất đổi ngày dọn vào',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Gửi thông báo đề xuất dời ngày cho người thuê xác nhận',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Thông tin phòng & khách thuê
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.meeting_room_outlined,
                          size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text(
                        'Phòng ${item.roomCode} • ${item.propertyName}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text(
                        'Khách thuê: ${item.renterName}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.history_rounded,
                          size: 16, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      const Text(
                        'Ngày hiện tại: ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        oldDateStr,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Chọn ngày mới
            const Text(
              'Ngày dọn vào mới đề xuất *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDateChanged
                      ? const Color(0xFFEFF8FF)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDateChanged
                        ? const Color(0xFF84ADFF)
                        : const Color(0xFFCBD5E1),
                    width: isDateChanged ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 20,
                      color: isDateChanged
                          ? const Color(0xFF155EEF)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        newDateStr,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDateChanged
                              ? const Color(0xFF155EEF)
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Thay đổi',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Lý do đề xuất thay đổi
            const Text(
              'Lý do thay đổi (gửi cho khách)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'Ví dụ: Phòng đang được sơn sửa hoàn thiện, xin phép dời thêm 2 ngày...',
                hintStyle: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF94A3B8),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 20),

            // Nút bấm Gửi đề xuất & Hủy
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Hủy',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendProposal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF155EEF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Gửi đề xuất',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

