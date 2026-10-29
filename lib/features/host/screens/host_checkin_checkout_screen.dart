import '../../../core/constants/app_colors.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/firestore_collections.dart';
import '../providers/checkin_checkout_provider.dart';
import '../providers/host_management_provider.dart';
import '../repositories/checkin_checkout_repository.dart';
import '../widgets/checkin_checkout_card.dart';
import '../widgets/host_qr_scanner_modal.dart';
import '../widgets/host_checkin_qr_result_sheet.dart';
import 'host_checkin_handover_screen.dart';
import 'host_management_menu.dart';
import 'host_violation_management_screen.dart';

class HostCheckinCheckoutScreen extends ConsumerStatefulWidget {
  final ValueChanged<HostManagementSection>? onSectionChanged;
  final int initialTab;

  const HostCheckinCheckoutScreen({
    super.key,
    this.onSectionChanged,
    this.initialTab = 1,
  });

  @override
  ConsumerState<HostCheckinCheckoutScreen> createState() =>
      _HostCheckinCheckoutScreenState();
}

class _HostCheckinCheckoutScreenState
    extends ConsumerState<HostCheckinCheckoutScreen> {
  late int _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab == 0 ? 0 : 1;
  }

  void _openSwitcherMenu() {
    HostManagementMenu.show(
      context: context,
      currentSection: HostManagementSection.checkinCheckout,
      onSelect: (section) {
        if (widget.onSectionChanged != null) {
          widget.onSectionChanged!(section);
        } else if (section == HostManagementSection.tenants) {
          Navigator.of(context).pushReplacementNamed('/host/tenants');
        } else if (section == HostManagementSection.violations) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const HostViolationManagementScreen(),
            ),
          );
        }
      },
    );
  }

  void _openQrScanner() {
    final checkinItems = ref.read(hostCheckinItemsProvider).value ?? [];
    final checkoutItems = ref.read(hostCheckoutItemsProvider).value ?? [];
    final firstPending = _selectedTab == 0
        ? checkinItems.where((i) => !i.isCompleted).firstOrNull
        : checkoutItems.where((i) => !i.isCompleted).firstOrNull;

    final sampleCode = firstPending != null
        ? jsonEncode({
            'type': _selectedTab == 0 ? 'checkin' : 'checkout',
            'bookingId': firstPending.bookingId,
            'roomId': firstPending.roomId,
            'roomCode': firstPending.roomCode,
            'roomTitle': firstPending.roomTitle.isNotEmpty
                ? firstPending.roomTitle
                : firstPending.propertyName,
            'renterId': firstPending.renterId,
            'renterName': firstPending.renterName,
            'renterPhone': firstPending.renterPhone,
            'roomPrice': firstPending.roomPrice,
            'deposit': firstPending.deposit,
            'totalAmount': firstPending.totalAmount,
            'paymentOption': firstPending.paymentOption,
          })
        : '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HostQrScannerModal(
        isCheckin: _selectedTab == 0,
        sampleCode: sampleCode,
        sampleRoomCode: firstPending?.roomCode ?? '',
        onCodeScanned: (code) {
          _handleQrDetected(code);
        },
      ),
    );
  }

  Future<void> _handleQrDetected(String code) async {
    final rawTrimmed = code.trim();
    if (rawTrimmed.isEmpty) return;

    String parsedBookingId = '';
    String parsedRoomId = '';
    String parsedRoomCode = '';
    String parsedRenterName = '';
    Map<String, dynamic> qrPayload = {};

    try {
      if (rawTrimmed.startsWith('{') && rawTrimmed.endsWith('}')) {
        final map = jsonDecode(rawTrimmed) as Map<String, dynamic>;
        qrPayload = Map<String, dynamic>.from(map);
        parsedBookingId = map['bookingId']?.toString() ?? '';
        parsedRoomId = map['roomId']?.toString() ?? '';
        parsedRoomCode = map['roomCode']?.toString() ?? '';
        parsedRenterName = map['renterName']?.toString() ?? '';
      } else if (rawTrimmed.startsWith('HOMESHARE_CHECKIN:')) {
        final parts = rawTrimmed.split(':');
        if (parts.length >= 2) parsedBookingId = parts[1];
        if (parts.length >= 3) parsedRoomId = parts[2];
        if (parts.length >= 4) parsedRoomCode = parts[3];
      } else if (rawTrimmed.contains('CHECKIN') ||
          rawTrimmed.contains('CHECKOUT')) {
        final digits = RegExp(r'\d+').firstMatch(rawTrimmed)?.group(0);
        if (digits != null) parsedRoomCode = digits;
      } else if (rawTrimmed.startsWith('bk_') ||
          rawTrimmed.startsWith('DP_') ||
          rawTrimmed.length >= 10) {
        parsedBookingId = rawTrimmed;
      } else {
        parsedRoomCode = rawTrimmed;
      }
    } catch (_) {
      parsedRoomCode = rawTrimmed;
    }

    if (!mounted) return;

    if (_selectedTab == 0) {
      // ── LUỒNG CHECK-IN: LẤY THÔNG TIN ĐẦY ĐỦ VÀ HIỂN THỊ SHEET KẾT QUẢ ──
      // 1. Nếu có bookingId, tra cứu thêm từ Firestore để đảm bảo thông tin mới nhất
      if (parsedBookingId.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection(FirestoreCollections.bookings)
              .doc(parsedBookingId)
              .get();
          if (doc.exists && doc.data() != null) {
            final data = doc.data()!;
            qrPayload['bookingId'] = parsedBookingId;
            qrPayload['roomId'] ??= data['roomId'] ?? data['phongId'];
            qrPayload['roomCode'] ??= data['roomCode'] ?? data['maPhong'];
            qrPayload['roomTitle'] ??= data['roomTitle'] ?? data['tieuDePhong'];
            qrPayload['roomAddress'] ??=
                data['roomAddress'] ?? data['diaChiPhong'];
            qrPayload['roomPrice'] ??=
                data['roomPrice'] ??
                data['giaThue'] ??
                data['giaPhong'] ??
                data['price'] ??
                data['rentalPrice'];
            qrPayload['deposit'] ??=
                data['deposit'] ?? data['tienCoc'] ?? data['depositAmount'];
            qrPayload['totalAmount'] ??=
                data['totalAmount'] ??
                data['tongPhaiTra'] ??
                data['paymentAmount'] ??
                data['amount'];
            qrPayload['paymentOption'] ??=
                data['paymentOption'] ??
                data['hinhThucThanhToan'] ??
                data['paymentType'];
            qrPayload['rentalMonths'] ??=
                data['rentalMonths'] ?? data['soThangThue'];
            qrPayload['renterId'] ??= data['renterId'] ?? data['nguoiDungId'];
            qrPayload['renterName'] ??= data['renterName'] ?? data['tenNguoiO'];
            qrPayload['renterPhone'] ??=
                data['renterPhone'] ?? data['sdtNguoiO'];
            qrPayload['renterUserCode'] ??=
                data['renterUserCode'] ?? data['maNguoiDung'];
            qrPayload['status'] ??= data['status'] ?? data['trangThai'];
            if (data['moveInDate'] is Timestamp) {
              qrPayload['moveInDate'] = (data['moveInDate'] as Timestamp)
                  .toDate()
                  .toIso8601String();
            } else if (data['ngayVao'] is Timestamp) {
              qrPayload['moveInDate'] = (data['ngayVao'] as Timestamp)
                  .toDate()
                  .toIso8601String();
            }
          }
        } catch (e) {
          debugPrint('Error fetching booking doc on scan: $e');
        }
      }

      // 2. Nếu chưa có thông tin phòng, tìm trong checkinItems
      final checkinItems = ref.read(hostCheckinItemsProvider).value ?? [];
      CheckinCheckoutItem? matchedItem;
      for (final item in checkinItems) {
        if ((parsedBookingId.isNotEmpty && item.bookingId == parsedBookingId) ||
            (parsedRoomId.isNotEmpty && item.roomId == parsedRoomId) ||
            (parsedRoomCode.isNotEmpty &&
                item.roomCode.toLowerCase() == parsedRoomCode.toLowerCase())) {
          matchedItem = item;
          break;
        }
      }

      if (matchedItem != null) {
        qrPayload['bookingId'] ??= matchedItem.bookingId;
        qrPayload['roomId'] ??= matchedItem.roomId;
        qrPayload['roomCode'] ??= matchedItem.roomCode;
        qrPayload['roomTitle'] ??= matchedItem.roomTitle.isNotEmpty
            ? matchedItem.roomTitle
            : 'Phòng ${matchedItem.roomCode} - ${matchedItem.propertyName}';
        qrPayload['renterId'] ??= matchedItem.renterId;
        qrPayload['renterName'] ??= matchedItem.renterName;
        qrPayload['renterPhone'] ??= matchedItem.renterPhone;
        qrPayload['deposit'] ??= matchedItem.deposit;
        qrPayload['roomPrice'] ??= matchedItem.roomPrice;
        qrPayload['totalAmount'] ??= matchedItem.totalAmount;
        qrPayload['paymentOption'] ??= matchedItem.paymentOption;
        qrPayload['moveInDate'] ??= matchedItem.expectedDate.toIso8601String();
      }

      // 3. Fallback tra cứu Firestore collection rooms nếu roomPrice hoặc deposit vẫn bằng 0
      final resolvedRoomId = (qrPayload['roomId'] ?? parsedRoomId).toString();
      if (resolvedRoomId.isNotEmpty &&
          (qrPayload['roomPrice'] == null ||
              qrPayload['roomPrice'] == 0 ||
              qrPayload['deposit'] == null ||
              qrPayload['deposit'] == 0)) {
        try {
          final roomDoc = await FirebaseFirestore.instance
              .collection('rooms')
              .doc(resolvedRoomId)
              .get();
          if (roomDoc.exists && roomDoc.data() != null) {
            final rData = roomDoc.data()!;
            qrPayload['roomPrice'] ??=
                rData['price'] ?? rData['giaPhong'] ?? rData['giaThue'];
            qrPayload['deposit'] ??= rData['deposit'] ?? rData['tienCoc'];
            qrPayload['roomTitle'] ??= rData['title'] ?? rData['tieuDe'];
            qrPayload['roomAddress'] ??= rData['address'] ?? rData['diaChi'];
          }
        } catch (_) {}
      }

      // Fallback nếu payload vẫn trống
      qrPayload['bookingId'] ??= parsedBookingId.isNotEmpty
          ? parsedBookingId
          : 'DP_DEMO_${DateTime.now().millisecondsSinceEpoch % 10000}';
      qrPayload['roomCode'] ??= parsedRoomCode.isNotEmpty
          ? parsedRoomCode
          : '204';
      qrPayload['roomTitle'] ??= 'Phòng ${qrPayload['roomCode']}';
      qrPayload['renterName'] ??= parsedRenterName.isNotEmpty
          ? parsedRenterName
          : 'Khách thuê';

      final hostId = ref.read(hostSessionProvider).value ?? '';
      if (!mounted) return;

      // Hiển thị Sheet thông tin phòng & khách thuê cho chủ trọ
      await HostCheckinQrResultSheet.show(
        context: context,
        qrData: qrPayload,
        hostId: hostId,
        onStatusChanged: () {
          ref.invalidate(hostCheckinItemsProvider);
        },
      );
      return;
    } else {
      // LUỒNG CHECK-OUT: Tìm phòng trong danh sách trả phòng
      final checkoutItems = ref.read(hostCheckoutItemsProvider).value ?? [];
      CheckinCheckoutItem? matchedItem;

      for (final item in checkoutItems) {
        if (parsedBookingId.isNotEmpty &&
            (item.bookingId == parsedBookingId ||
                item.periodId == parsedBookingId)) {
          matchedItem = item;
          break;
        }
        if (parsedRoomId.isNotEmpty && item.roomId == parsedRoomId) {
          matchedItem = item;
          break;
        }
        if (parsedRoomCode.isNotEmpty &&
            (item.roomCode == parsedRoomCode ||
                item.roomCode.toLowerCase() == parsedRoomCode.toLowerCase())) {
          matchedItem = item;
          break;
        }
      }

      if (matchedItem != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nhận diện trả phòng: P.${matchedItem.roomCode} - ${matchedItem.renterName}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        _showCheckoutDialog(matchedItem);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Mã QR "$rawTrimmed" không nằm trong danh sách phòng chờ trả phòng.',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showCheckoutDialog(CheckinCheckoutItem item) {
    final deductionCtrl = TextEditingController(text: '0');
    final noteCtrl = TextEditingController();
    double currentDeduction = 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final refundAmount = (item.deposit - currentDeduction).clamp(
              0.0,
              double.infinity,
            );

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Chốt trả phòng P.${item.roomCode}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Thông tin tiền cọc
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tiền cọc ban đầu:',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                            Text(
                              '${NumberFormat.decimalPattern('vi').format(item.deposit)} đ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Khoản khấu trừ:',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.danger,
                              ),
                            ),
                            Text(
                              '- ${NumberFormat.decimalPattern('vi').format(currentDeduction)} đ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tiền hoàn cọc thực tế:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              '${NumberFormat.decimalPattern('vi').format(refundAmount)} đ',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: deductionCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Khoản khấu trừ hư hỏng/điện nước (VNĐ)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        currentDeduction = double.tryParse(val.trim()) ?? 0.0;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Lý do khấu trừ & ghi chú biên bản',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      try {
                        await ref
                            .read(checkinCheckoutRepositoryProvider)
                            .performCheckout(
                              roomId: item.roomId,
                              periodId: item.periodId,
                              renterId: item.renterId,
                              initialDeposit: item.deposit,
                              deductionAmount: currentDeduction,
                              note: noteCtrl.text.trim(),
                            );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã hoàn tất check-out phòng!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Lỗi check-out: $e')),
                          );
                        }
                      }
                    },
                    child: const Text(
                      'Xác nhận Hoàn cọc & Check-out',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkinItemsAsync = ref.watch(hostCheckinItemsProvider);
    final checkoutItemsAsync = ref.watch(hostCheckoutItemsProvider);

    final checkinCount =
        checkinItemsAsync.value?.where((i) => !i.isCompleted).length ?? 1;
    final checkoutCount =
        checkoutItemsAsync.value?.where((i) => !i.isCompleted).length ?? 2;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: AppColors.surface,
              child: Row(
                children: [
                  InkWell(
                    onTap: _openSwitcherMenu,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.menu,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Quản lý Check in & Check Out',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.border),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // Banner QR Tốc Hành
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x332563EB),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedTab == 0
                                    ? 'Quét QR Check-in\nTốc Hành'
                                    : 'Quét QR Check-out\nTốc Hành',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Bàn giao & kiểm tra phòng tức thì',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: _openQrScanner,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Quét mã',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tab chuyển đổi (Check-in / Check-out)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTabPill(
                            index: 0,
                            title: 'Check-in',
                            count: checkinCount,
                          ),
                        ),
                        Expanded(
                          child: _buildTabPill(
                            index: 1,
                            title: 'Check-out',
                            count: checkoutCount,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Nội dung theo Tab
                  if (_selectedTab == 0)
                    _buildCheckinContent(checkinItemsAsync)
                  else
                    _buildCheckoutContent(checkoutItemsAsync),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPill({
    required int index,
    required String title,
    required int count,
  }) {
    final isSelected = _selectedTab == index;

    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.border,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckinContent(
    AsyncValue<List<CheckinCheckoutItem>> itemsAsync,
  ) {
    return itemsAsync.when(
      data: (items) {
        final pending = items.where((i) => !i.isCompleted).toList();
        final completed = items.where((i) => i.isCompleted).toList();

        if (pending.isEmpty && completed.isEmpty) {
          return _buildEmptyState(
            icon: Icons.meeting_room_outlined,
            title: 'Chưa có phòng nào cần Check-in',
            subtitle:
                'Các đơn cọc hoặc thanh toán thành công sẽ xuất hiện tại đây.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pending.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'DANH SÁCH CẦN XỬ LÝ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${pending.length} phòng liên quan',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...pending.map(
                (item) => CheckinCheckoutCard(
                  item: item,
                  isCheckinTab: true,
                  onAction: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HostCheckinHandoverScreen(
                          bookingId: item.bookingId,
                          roomId: item.roomId,
                          roomCode: item.roomCode,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (completed.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'PHÒNG ĐÃ HOÀN TẤT',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              ...completed.map(
                (item) => CheckinCheckoutCard(
                  item: item,
                  isCheckinTab: true,
                  onAction: () {},
                ),
              ),
            ],
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('Không thể tải danh sách nhận phòng.'),
              ElevatedButton(
                onPressed: () => ref.refresh(hostCheckinItemsProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutContent(
    AsyncValue<List<CheckinCheckoutItem>> itemsAsync,
  ) {
    return itemsAsync.when(
      data: (items) {
        final pending = items.where((i) => !i.isCompleted).toList();
        final completed = items.where((i) => i.isCompleted).toList();

        if (pending.isEmpty && completed.isEmpty) {
          return _buildEmptyState(
            icon: Icons.exit_to_app_rounded,
            title: 'Chưa có phòng nào cần Check-out',
            subtitle:
                'Các phòng sắp hết hạn thuê hoặc trả phòng sẽ xuất hiện tại đây.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pending.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'DANH SÁCH CẦN XỬ LÝ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${pending.length} phòng liên quan',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...pending.map(
                (item) => CheckinCheckoutCard(
                  item: item,
                  isCheckinTab: false,
                  onAction: () => _showCheckoutDialog(item),
                ),
              ),
            ],
            if (completed.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'PHÒNG ĐÃ HOÀN TẤT',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              ...completed.map(
                (item) => CheckinCheckoutCard(
                  item: item,
                  isCheckinTab: false,
                  onAction: () {},
                ),
              ),
            ],
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('Không thể tải danh sách trả phòng.'),
              ElevatedButton(
                onPressed: () => ref.refresh(hostCheckoutItemsProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
