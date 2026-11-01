import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/localization/app_translations.dart';
import '../../../core/services/booking_service.dart';
import '../../../core/services/host_review_service.dart';
import '../../../core/services/resident_service.dart';
import '../../../core/services/room_service.dart';
import '../../../core/utils/host_review_policy.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/checkout_record_model.dart';
import '../../../data/models/room_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/widgets/host_review_sheet.dart';
import '../widgets/send_roommate_invite_sheet.dart';
import 'room_detail_screen.dart';

/// Item tóm tắt lịch sử căn phòng/nhà người dùng đã từng thuê trong quá khứ
class PastRentalHomeItem {
  final String id;
  final String roomId;
  final String roomTitle;
  final String roomAddress;
  final String hostId;
  final String hostName;
  final String hostPhone;
  final double roomPrice;
  final double depositAmount;
  final double deductionAmount;
  final double refundAmount;
  final DateTime moveInDate;
  final DateTime? moveOutDate;
  final String status;
  final String note;
  final double finalElectricityMeter;
  final double finalWaterMeter;
  final bool hasCheckoutRecord;
  final BookingRequestModel? booking;
  final CheckoutRecordModel? checkoutRecord;

  const PastRentalHomeItem({
    required this.id,
    required this.roomId,
    required this.roomTitle,
    required this.roomAddress,
    required this.hostId,
    required this.hostName,
    this.hostPhone = '',
    required this.roomPrice,
    this.depositAmount = 0.0,
    this.deductionAmount = 0.0,
    this.refundAmount = 0.0,
    required this.moveInDate,
    this.moveOutDate,
    this.status = 'Đã trả phòng',
    this.note = '',
    this.finalElectricityMeter = 0.0,
    this.finalWaterMeter = 0.0,
    this.hasCheckoutRecord = false,
    this.booking,
    this.checkoutRecord,
  });
}

PastRentalHomeItem pastHomeFromEndedBooking(BookingRequestModel booking) {
  return PastRentalHomeItem(
    id: booking.id,
    roomId: booking.roomId,
    roomTitle: booking.roomTitle.isNotEmpty ? booking.roomTitle : 'Phòng đã thuê',
    roomAddress:
        booking.roomAddress.isNotEmpty ? booking.roomAddress : 'Địa chỉ phòng trọ',
    hostId: booking.hostId,
    hostName: booking.hostName.isNotEmpty ? booking.hostName : 'Chủ nhà',
    roomPrice: booking.roomPrice,
    depositAmount: booking.deposit,
    refundAmount: booking.deposit,
    moveInDate: booking.moveInDate,
    moveOutDate: booking.moveOutDate ?? booking.acceptedDate,
    status: booking.note == 'Ở ghép' ? 'Đã kết thúc ở ghép' : 'Đã trả phòng',
    note: booking.note,
    booking: booking,
  );
}

List<PastRentalHomeItem> mergeEndedBookingsIntoPastHomes(
  List<PastRentalHomeItem> items,
  Iterable<BookingRequestModel> endedBookings,
) {
  final covered = <String>{};
  void cover(String? id) {
    final value = (id ?? '').trim();
    if (value.isNotEmpty) covered.add(value);
  }

  for (final item in items) {
    cover(item.id);
    cover(item.roomId);
    cover(item.booking?.id);
    cover(item.booking?.roomId);
  }

  final merged = [...items];
  for (final booking in endedBookings) {
    if (covered.contains(booking.id) ||
        covered.contains(booking.roomId.trim())) {
      continue;
    }
    cover(booking.id);
    cover(booking.roomId);
    merged.add(pastHomeFromEndedBooking(booking));
  }
  merged.sort((a, b) {
    final dateA = a.moveOutDate ?? a.moveInDate;
    final dateB = b.moveOutDate ?? b.moveInDate;
    return dateB.compareTo(dateA);
  });
  return merged;
}

/// Provider truy vấn danh sách Lịch sử nhà đã ở của người dùng
final pastRentalHomesProvider = FutureProvider.autoDispose.family<List<PastRentalHomeItem>, String>((ref, userId) async {
  if (userId.isEmpty || userId == 'guest') return [];

  final firestore = FirebaseFirestore.instance;
  final bookingService = BookingService(firestore: firestore);
  final residentService = ResidentService(firestore);
  final roomTitleCache = <String, Map<String, dynamic>>{};
  final items = <PastRentalHomeItem>[];
  final processedRoomIds = <String>{};

  Future<void> markRoom(String roomId) async {
    final id = roomId.trim();
    if (id.isEmpty) return;
    processedRoomIds.add(id);
    try {
      processedRoomIds.add(await residentService.resolveRoomId(id));
    } catch (_) {}
  }

  Future<String> hostRoomTitle(String roomId, String fallback) async {
    final title = await bookingService.titleFromHostRooms(
      roomId,
      cache: roomTitleCache,
    );
    return title.isNotEmpty ? title : fallback;
  }

  try {
    // 1. Truy vấn các biên bản trả phòng (checkout_records) mà người dùng là renterId
    final checkoutSnap = await firestore
        .collection(FirestoreCollections.checkoutRecords)
        .where('renterId', isEqualTo: userId)
        .get();

    for (final doc in checkoutSnap.docs) {
      final record = CheckoutRecordModel.fromFirestore(doc);
      await markRoom(record.roomId);

      // Tra cứu thông tin phòng
      String title = 'Phòng đã thuê';
      String address = 'Địa chỉ phòng trọ';
      String hostName = 'Chủ nhà';
      String hostId = '';
      String hostPhone = '';
      double price = 0.0;
      DateTime moveIn = record.checkoutTime.subtract(const Duration(days: 30));

      try {
        final roomDoc = await firestore.collection('rooms').doc(record.roomId).get();
        if (roomDoc.exists) {
          final data = roomDoc.data() ?? {};
          title = data['title'] ?? data['tieuDe'] ?? title;
          address = data['address'] ?? data['diaChi'] ?? address;
          hostName = data['hostName'] ?? data['tenChuNha'] ?? hostName;
          hostId = data['hostId'] ?? data['chuNhaId'] ?? '';
          hostPhone = data['hostPhone'] ?? data['sdtChuNha'] ?? '';
          price = ((data['price'] ?? data['giaThue']) as num?)?.toDouble() ?? 0.0;
        } else {
          final hostRoomDoc = await firestore.collection('host_rooms').doc(record.roomId).get();
          if (hostRoomDoc.exists) {
            final data = hostRoomDoc.data() ?? {};
            title = data['title'] ?? data['tieuDe'] ?? data['roomCode'] ?? title;
            address = data['address'] ?? address;
            hostName = data['hostName'] ?? hostName;
            hostId = data['hostId'] ?? '';
            hostPhone = data['hostPhone'] ?? '';
            price = ((data['price'] ?? data['roomPrice']) as num?)?.toDouble() ?? 0.0;
          }
        }
      } catch (_) {}
      title = await hostRoomTitle(record.roomId, title);

      // Tra cứu thêm ngày dọn vào từ period hoặc booking nếu có
      if (record.periodId.isNotEmpty) {
        try {
          final periodDoc = await firestore.collection(FirestoreCollections.periods).doc(record.periodId).get();
          if (periodDoc.exists) {
            final pData = periodDoc.data() ?? {};
            if (pData['startDate'] is Timestamp) {
              moveIn = (pData['startDate'] as Timestamp).toDate();
            }
          }
        } catch (_) {}
      }

      items.add(
        PastRentalHomeItem(
          id: record.id,
          roomId: record.roomId,
          roomTitle: title,
          roomAddress: address,
          hostId: hostId,
          hostName: hostName,
          hostPhone: hostPhone,
          roomPrice: price,
          depositAmount: record.depositAmount,
          deductionAmount: record.deductionAmount,
          refundAmount: record.refundAmount,
          moveInDate: moveIn,
          moveOutDate: record.checkoutTime,
          status: 'Đã hoàn tất trả phòng',
          note: record.note,
          finalElectricityMeter: record.finalElectricityMeter,
          finalWaterMeter: record.finalWaterMeter,
          hasCheckoutRecord: true,
          checkoutRecord: record,
        ),
      );
    }

    // 2. Truy vấn các đơn booking có trạng thái kết thúc/trả phòng
    final bookingSnap = await firestore
        .collection('bookings')
        .where('renterId', isEqualTo: userId)
        .get();

    for (final doc in bookingSnap.docs) {
      final b = BookingRequestModel.fromFirestore(doc);
      if (!b.isEnded && b.status.toLowerCase() != 'completed') continue;
      var resolvedRoomId = b.roomId.trim();
      try {
        resolvedRoomId = await residentService.resolveRoomId(b.roomId);
      } catch (_) {}
      if (processedRoomIds.contains(b.roomId) ||
          processedRoomIds.contains(resolvedRoomId)) {
        continue;
      }
      await markRoom(b.roomId);
      items.add(
        PastRentalHomeItem(
          id: b.id,
          roomId: b.roomId,
          roomTitle: await hostRoomTitle(
            b.roomId,
            b.roomTitle.isNotEmpty ? b.roomTitle : 'Phòng đã thuê',
          ),
          roomAddress: b.roomAddress,
          hostId: b.hostId,
          hostName: b.hostName,
          roomPrice: b.roomPrice,
          depositAmount: b.deposit,
          refundAmount: b.deposit,
          moveInDate: b.moveInDate,
          moveOutDate: b.moveOutDate ??
              b.acceptedDate ??
              b.createdAt.add(Duration(days: b.rentalMonths * 30)),
          status: 'Đã trả phòng',
          note: b.note,
          hasCheckoutRecord: false,
          booking: b,
        ),
      );
    }

    // 3. Người ở ghép đã rời phòng, không có đơn bookings riêng
    try {
      final endedStays = await BookingService(firestore: firestore)
          .loadResidentStays(userId, activeOnly: false);
      for (final stay in endedStays) {
        var resolvedRoomId = stay.roomId.trim();
        try {
          resolvedRoomId = await residentService.resolveRoomId(stay.roomId);
        } catch (_) {}
        if (stay.roomId.isEmpty ||
            processedRoomIds.contains(stay.roomId) ||
            processedRoomIds.contains(resolvedRoomId)) {
          continue;
        }
        await markRoom(stay.roomId);
        items.add(
          PastRentalHomeItem(
            id: stay.id,
            roomId: stay.roomId,
            roomTitle: await hostRoomTitle(
              stay.roomId,
              stay.roomTitle.isNotEmpty ? stay.roomTitle : 'Phòng đã thuê',
            ),
            roomAddress: stay.roomAddress.isNotEmpty ? stay.roomAddress : 'Địa chỉ phòng trọ',
            hostId: stay.hostId,
            hostName: stay.hostName.isNotEmpty ? stay.hostName : 'Chủ nhà',
            roomPrice: stay.roomPrice,
            depositAmount: stay.deposit,
            refundAmount: stay.deposit,
            moveInDate: stay.moveInDate,
            moveOutDate: stay.moveOutDate ?? stay.createdAt,
            status: stay.note == 'Ở ghép' ? 'Đã kết thúc ở ghép' : 'Đã trả phòng',
            note: stay.note,
            hasCheckoutRecord: false,
            booking: stay,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching past resident stays: $e');
    }

    // 4. Sắp xếp theo ngày kết thúc mới nhất lên đầu
    items.sort((a, b) {
      final dateA = a.moveOutDate ?? a.moveInDate;
      final dateB = b.moveOutDate ?? b.moveInDate;
      return dateB.compareTo(dateA);
    });
  } catch (e) {
    debugPrint('Error fetching past rental homes: $e');
  }

  return items;
});

/// Màn hình "Phòng của tôi" gồm 2 phần:
/// 1. Nhà đang ở
/// 2. Lịch sử nhà đã ở
class MyHomesScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const MyHomesScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<MyHomesScreen> createState() => _MyHomesScreenState();
}

class _MyHomesScreenState extends ConsumerState<MyHomesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'vi_VN');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cảm ơn bạn đã gửi đánh giá chủ trọ!'),
          backgroundColor: Color(0xFF027A48),
        ),
      );
    }
  }

  Future<RoomModel?> _loadListedRoom(String roomId, String title) async {
    final firestore = FirebaseFirestore.instance;
    final id = roomId.trim();
    if (id.isNotEmpty) {
      try {
        final postDoc = await firestore.collection('posts').doc(id).get();
        if (postDoc.exists) return RoomModel.fromFirestore(postDoc);
      } catch (_) {}
      for (final field in ['roomId', 'room_id', 'phongId', 'phong_tro_id']) {
        try {
          final snap = await firestore
              .collection('posts')
              .where(field, isEqualTo: id)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            return RoomModel.fromFirestore(snap.docs.first);
          }
        } catch (_) {}
      }
    }
    final label = title.trim();
    if (label.isEmpty) return null;
    try {
      final snap = await firestore
          .collection('posts')
          .where('title', isEqualTo: label)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return RoomModel.fromFirestore(snap.docs.first);
    } catch (_) {}
    return null;
  }

  Future<void> _openRoomDetail(
    String roomId,
    String title, {
    String hostId = '',
    String roomCode = '',
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    var openedLoading = true;
    void dismissLoading() {
      if (!openedLoading || !mounted) return;
      openedLoading = false;
      Navigator.of(context, rootNavigator: true).pop();
    }

    try {
      RoomModel? room = await ref.read(roomServiceProvider).resolveRentedRoom(
            roomId: roomId,
            hostId: hostId,
            roomCode: roomCode,
            title: title,
          );
      room ??= await _loadListedRoom(roomId, title);

      if (!mounted) return;
      dismissLoading();
      if (room != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room!)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể tìm thấy thông tin phòng: $title'),
            backgroundColor: const Color(0xFFD92D20),
          ),
        );
      }
    } catch (e) {
      dismissLoading();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải thông tin phòng: $e')),
        );
      }
    }
  }

  void _showReportIssueSheet(BookingRequestModel b) {
    final issueController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.build_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.tr('report_room_issue'),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          b.roomTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Mô tả chi tiết sự cố (máy lạnh, bóng đèn, điện nước, wifi...):',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: issueController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Nhập nội dung sự cố cần chủ trọ hỗ trợ sửa chữa...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final text = issueController.text.trim();
                    if (text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng nhập nội dung sự cố')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    try {
                      final notifId = 'NF_ISSUE_${DateTime.now().millisecondsSinceEpoch}';
                      await FirebaseFirestore.instance.collection('notifications').doc(notifId).set({
                        'id': notifId,
                        'recipientId': b.hostId,
                        'recipientRole': 'host',
                        'title': 'Báo cáo sự cố phòng: ${b.roomTitle}',
                        'message': 'Khách thuê ${b.renterName} (${b.renterPhone}) vừa báo cáo sự cố: "$text"',
                        'roomId': b.roomId,
                        'bookingId': b.id,
                        'isRead': false,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã gửi báo cáo sự cố đến chủ trọ thành công!'),
                            backgroundColor: Color(0xFF027A48),
                          ),
                        );
                      }
                    } catch (err) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi gửi báo cáo: $err')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Gửi báo cáo sự cố'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCheckoutDetailModal(PastRentalHomeItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final record = item.checkoutRecord;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF7C3AED), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTranslations.tr('view_checkout_detail'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        item.roomTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Thông tin tài chính hoàn trả cọc
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.border,
                ),
              ),
              child: Column(
                children: [
                  _buildReceiptRow('Tiền cọc ban đầu', '${_currencyFormat.format(item.depositAmount)} đ', isDark: isDark),
                  const SizedBox(height: 8),
                  _buildReceiptRow(
                    'Khấu trừ (hư hại / điện nước)',
                    '- ${_currencyFormat.format(item.deductionAmount)} đ',
                    valueColor: const Color(0xFFD92D20),
                    isDark: isDark,
                  ),
                  const Divider(height: 16),
                  _buildReceiptRow(
                    'Tiền hoàn cọc thực nhận',
                    '${_currencyFormat.format(item.refundAmount)} đ',
                    valueColor: const Color(0xFF027A48),
                    isBold: true,
                    fontSize: 15,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Chỉ số công tơ & Bàn giao
            if (record != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoItem(
                            'Chỉ số điện cuối',
                            '${record.finalElectricityMeter} kWh',
                            Icons.bolt_rounded,
                            const Color(0xFFF59E0B),
                            isDark: isDark,
                          ),
                        ),
                        Expanded(
                          child: _buildInfoItem(
                            'Chỉ số nước cuối',
                            '${record.finalWaterMeter} m³',
                            Icons.water_drop_rounded,
                            const Color(0xFF0284C7),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    if (record.note.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Text(
                        'Ghi chú bàn giao & Hiện trạng:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.note,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Thời gian trả phòng
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 15, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Thời điểm trả phòng: ${item.moveOutDate != null ? DateFormat('HH:mm - dd/MM/yyyy').format(item.moveOutDate!) : "Đã hoàn tất"}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {Color? valueColor, bool isBold = false, double fontSize = 13.5, required bool isDark}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            color: AppColors.textMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? (AppColors.textDark),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon, Color iconColor, {required bool isDark}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = AppColors.background;
    final cardColor = AppColors.surface;
    final borderColor = AppColors.border;
    final textDark = AppColors.textDark;
    final textMuted = AppColors.textMuted;

    if (user == null) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(title: Text(AppTranslations.tr('my_rented_homes'))),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: AppColors.textMuted),
              const SizedBox(height: 16),
              const Text(
                'Vui lòng đăng nhập để xem thông tin phòng của bạn',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    final bookingsAsync = ref.watch(renterBookingsStreamProvider(user.uid));
    final pastHomesAsync = ref.watch(pastRentalHomesProvider(user.uid));
    final endedBookings =
        bookingsAsync.value?.where((b) => b.isEnded).toList() ?? const [];
    final pastHomes = mergeEndedBookingsIntoPastHomes(
      pastHomesAsync.value ?? const [],
      endedBookings,
    );

    // Đếm số lượng nhà đang ở để gắn Badge trên Tab
    final activeCount = bookingsAsync.value?.where((b) => b.isActive).length ?? 0;
    final pastCount = pastHomes.length;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          AppTranslations.tr('my_rented_homes'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor: textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.home_work_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text(AppTranslations.tr('active_homes_tab')),
                      if (activeCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF027A48),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$activeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text(AppTranslations.tr('past_homes_tab')),
                      if (pastCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.textMuted,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$pastCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: NHÀ ĐANG Ở
          _buildActiveHomesTab(
            bookingsAsync: bookingsAsync,
            isDark: isDark,
            cardColor: cardColor,
            borderColor: borderColor,
            textDark: textDark,
            textMuted: textMuted,
          ),

          // TAB 2: LỊCH SỬ NHÀ ĐÃ Ở
          _buildPastHomesTab(
            pastHomesAsync: pastHomesAsync,
            endedBookings: endedBookings,
            isDark: isDark,
            cardColor: cardColor,
            borderColor: borderColor,
            textDark: textDark,
            textMuted: textMuted,
          ),
        ],
      ),
    );
  }

  // ==================== TAB 1: NHÀ ĐANG Ở ====================
  Widget _buildActiveHomesTab({
    required AsyncValue<List<BookingRequestModel>> bookingsAsync,
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
    required Color textDark,
    required Color textMuted,
  }) {
    return bookingsAsync.when(
      data: (bookings) {
        final activeList = bookings.where((b) => b.isActive).toList();

        if (activeList.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.home_work_outlined,
                      size: 64,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    AppTranslations.tr('no_active_homes_msg'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hiện bạn chưa có hợp đồng thuê phòng nào đang hoạt động. Khám phá các căn phòng lý tưởng trên HomeShare ngay hôm nay!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: textMuted, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: Text(AppTranslations.tr('explore_rooms_btn')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activeList.length,
          itemBuilder: (context, index) {
            final b = activeList[index];
            return _buildActiveHomeCard(
              b: b,
              isDark: isDark,
              cardColor: cardColor,
              borderColor: borderColor,
              textDark: textDark,
              textMuted: textMuted,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Lỗi tải dữ liệu: $err')),
    );
  }

  Widget _buildActiveHomeCard({
    required BookingRequestModel b,
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
    required Color textDark,
    required Color textMuted,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badge & Mã phòng
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA6F4C5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF12B76A)),
                      const SizedBox(width: 4),
                      Text(
                        AppTranslations.tr('staying_tag'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF027A48),
                        ),
                      ),
                    ],
                  ),
                ),
                if (b.roomCode.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Mã: ${b.roomCode}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Tiêu đề phòng
            Text(
              b.roomTitle,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textDark,
              ),
            ),
            if (b.note == 'Ở ghép') ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF8FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFB2DDFF)),
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

            // Địa chỉ
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 15, color: textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    b.roomAddress,
                    style: TextStyle(fontSize: 12.5, color: textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Grid Thông tin tài chính & Ngày ở
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.border,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.payments_outlined, size: 16, color: Color(0xFF155EEF)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${_currencyFormat.format(b.roomPrice)} đ/tháng',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF155EEF),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (b.deposit > 0)
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF027A48)),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Cọc: ${_currencyFormat.format(b.deposit)} đ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                    color: Color(0xFF027A48),
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 14, color: textMuted),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Dọn vào: ${DateFormat('dd/MM/yyyy').format(b.moveInDate)}',
                                style: TextStyle(fontSize: 12, color: textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.person_pin_outlined, size: 15, color: textMuted),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Chủ trọ: ${b.hostName}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: textDark,
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
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Các nút hành động chính
            // 1. NÚT GỬI TIN Ở GHÉP (Nổi bật nhất)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  SendRoommateInviteSheet.show(context, booking: b);
                },
                icon: const Icon(Icons.group_add_outlined, size: 18),
                label: Text(AppTranslations.tr('send_roommate_invite')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF155EEF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(42),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 2. CÁC NÚT PHỤ: Báo sự cố & Đánh giá chủ trọ & Chi tiết phòng
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showReportIssueSheet(b),
                    icon: const Icon(Icons.build_outlined, size: 16),
                    label: Text(AppTranslations.tr('report_room_issue')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textDark,
                      side: BorderSide(color: AppColors.border),
                      minimumSize: const Size.fromHeight(38),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openRoomDetail(
                      b.roomId,
                      b.roomTitle,
                      hostId: b.hostId,
                      roomCode: b.roomCode,
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: Text(AppTranslations.tr('re_rent_room')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary),
                      minimumSize: const Size.fromHeight(38),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),

            if (_canReviewHost(b)) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openHostReview(b),
                  icon: const Icon(Icons.rate_review_outlined, size: 16),
                  label: Text(AppTranslations.tr('review_host_btn')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF027A48),
                    side: const BorderSide(color: Color(0xFF027A48)),
                    minimumSize: const Size.fromHeight(38),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== TAB 2: LỊCH SỬ NHÀ ĐÃ Ở ====================
  Widget _buildPastHomesTab({
    required AsyncValue<List<PastRentalHomeItem>> pastHomesAsync,
    required List<BookingRequestModel> endedBookings,
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
    required Color textDark,
    required Color textMuted,
  }) {
    return pastHomesAsync.when(
      data: (items) {
        final merged = mergeEndedBookingsIntoPastHomes(items, endedBookings);
        if (merged.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.history_toggle_off_rounded,
                      size: 64,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    AppTranslations.tr('no_past_homes_msg'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Các căn phòng bạn đã từng thuê sau khi hoàn tất trả phòng (Check-out) sẽ được lưu lại đầy đủ tại đây cùng biên bản bàn giao và lịch sử hoàn cọc.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: textMuted, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: merged.length,
          itemBuilder: (context, index) {
            final item = merged[index];
            return _buildPastHomeCard(
              item: item,
              isDark: isDark,
              cardColor: cardColor,
              borderColor: borderColor,
              textDark: textDark,
              textMuted: textMuted,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Lỗi tải lịch sử: $err')),
    );
  }

  Widget _buildPastHomeCard({
    required PastRentalHomeItem item,
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
    required Color textDark,
    required Color textMuted,
  }) {
    final hasCheckout = item.hasCheckoutRecord && item.checkoutRecord != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge Đã trả phòng & Thời gian kết thúc
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.task_alt_rounded, size: 14, color: Color(0xFF475467)),
                      const SizedBox(width: 4),
                      Text(
                        AppTranslations.tr('checked_out_tag'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF344054),
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.moveOutDate != null)
                  Text(
                    'Đã rời: ${DateFormat('dd/MM/yyyy').format(item.moveOutDate!)}',
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Tiêu đề phòng
            Text(
              item.roomTitle,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: textDark,
              ),
            ),
            const SizedBox(height: 4),

            // Địa chỉ
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 15, color: textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.roomAddress,
                    style: TextStyle(fontSize: 12.5, color: textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Khoảng thời gian đã cư trú & Chủ trọ
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.border,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.date_range_outlined, size: 15, color: textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Thời gian ở: ${DateFormat('dd/MM/yyyy').format(item.moveInDate)} → ${item.moveOutDate != null ? DateFormat('dd/MM/yyyy').format(item.moveOutDate!) : "Kết thúc"}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_pin_outlined, size: 15, color: textMuted),
                          const SizedBox(width: 6),
                          Text(
                            'Chủ trọ: ${item.hostName}',
                            style: TextStyle(fontSize: 12, color: textMuted),
                          ),
                        ],
                      ),
                      if (item.refundAmount > 0)
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF027A48)),
                            const SizedBox(width: 4),
                            Text(
                              'Hoàn cọc: ${_currencyFormat.format(item.refundAmount)} đ',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF027A48),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Nút bấm hành động
            Row(
              children: [
                if (hasCheckout) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showCheckoutDetailModal(item),
                      icon: const Icon(Icons.receipt_long_rounded, size: 16),
                      label: Text(AppTranslations.tr('view_checkout_detail')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(40),
                        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openRoomDetail(
                      item.roomId,
                      item.roomTitle,
                      hostId: item.hostId,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(AppTranslations.tr('re_rent_room')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary),
                      minimumSize: const Size.fromHeight(40),
                      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            if (item.booking != null && _canReviewHost(item.booking!)) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openHostReview(item.booking!),
                  icon: const Icon(Icons.rate_review_outlined, size: 16),
                  label: Text(AppTranslations.tr('review_host_btn')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF027A48),
                    side: const BorderSide(color: Color(0xFF027A48)),
                    minimumSize: const Size.fromHeight(40),
                    textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
