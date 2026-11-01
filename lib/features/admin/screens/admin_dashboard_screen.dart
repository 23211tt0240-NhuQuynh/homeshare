import '../theme/admin_colors.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_notifications_screen.dart';
import '../utils/booking_utils.dart';
import '../widgets/admin_branded_title.dart';
import '../widgets/admin_theme_toggle.dart';
import '../widgets/revenue_line_chart.dart';
import '../widgets/revenue_bar_chart.dart';
import 'cancellation_invoice_screen.dart';

enum RevenueTimeRange { week, month, year }

class AdminDashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToOrders;
  final VoidCallback? onNavigateToPosts;
  final VoidCallback? onNavigateToHistory;

  const AdminDashboardScreen({
    super.key,
    this.onNavigateToOrders,
    this.onNavigateToPosts,
    this.onNavigateToHistory,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  RevenueTimeRange _selectedTimeRange = RevenueTimeRange.year;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _checkinsSub;
  Set<String> _checkedInBookingIds = {};

  @override
  void initState() {
    super.initState();
    try {
      _checkinsSub = FirebaseFirestore.instance
          .collection('checkins')
          .snapshots()
          .listen(
            (snapshot) {
              final ids = <String>{};
              for (final doc in snapshot.docs) {
                final data = doc.data();
                final bookingId = (data['bookingId'] ?? data['donId'] ?? '')
                    .toString()
                    .trim();
                if (bookingId.isNotEmpty) ids.add(bookingId);
                ids.add(doc.id);
              }
              if (mounted) setState(() => _checkedInBookingIds = ids);
            },
            onError: (Object error) {
              debugPrint('Lỗi tải checkins cho dashboard: $error');
            },
          );
    } on FirebaseException catch (error) {
      debugPrint('Chưa thể khởi tạo dữ liệu checkins: ${error.code}');
    }
  }

  @override
  void dispose() {
    _checkinsSub?.cancel();
    super.dispose();
  }

  String _formatMoney(num amount) {
    return "${amount.toStringAsFixed(0).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.')} đ";
  }

  void _showNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openNotificationsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdminNotificationsBottomSheet(
        onNavigateTarget: (type, targetId) {
          if ((type == 'disbursement' || type == 'booking') &&
              widget.onNavigateToOrders != null) {
            widget.onNavigateToOrders!();
          } else if (type == 'post_approval' &&
              widget.onNavigateToPosts != null) {
            widget.onNavigateToPosts!();
          } else if (widget.onNavigateToHistory != null) {
            widget.onNavigateToHistory!();
          }
        },
      ),
    );
  }

  void _showDisbursementDialog(DocumentSnapshot bookingDoc) {
    final data = BookingUtils.canonical(
      bookingDoc.data() as Map<String, dynamic>? ?? {},
    );
    final bookingId = bookingDoc.id;
    final orderCode =
        data['orderCode'] ??
        '#${bookingId.substring(0, bookingId.length > 6 ? 6 : bookingId.length).toUpperCase()}';
    final hostName = data['hostName'] ?? 'Chủ trọ';
    final hostPhone =
        data['hostPhone'] ?? data['landlordPhone'] ?? 'Đang cập nhật';
    final hostBank = data['hostBankName'] ?? 'MB Bank';
    final hostAcc = data['hostAccountNumber'] ?? '---';
    final roomTitle = data['roomTitle'] ?? 'Phòng trọ';
    final amount = BookingUtils.amount(data);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AdminColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AdminColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AdminColors.successContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AdminColors.success,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phê Duyệt Giải Ngân Cọc',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AdminColors.ink,
                        ),
                      ),
                      Text(
                        'Mã đơn: $orderCode',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AdminColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AdminColors.paper,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AdminColors.border),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Tên chủ trọ:', hostName),
                  const Divider(height: 16),
                  _buildDetailRow('Số điện thoại:', hostPhone),
                  const Divider(height: 16),
                  _buildDetailRow(
                    'Ngân hàng thụ hưởng:',
                    '$hostBank ($hostAcc)',
                  ),
                  const Divider(height: 16),
                  _buildDetailRow('Phòng liên kết:', roomTitle),
                  const Divider(height: 16),
                  _buildDetailRow(
                    'Số tiền cọc giải ngân:',
                    _formatMoney(amount),
                    isHighlight: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: AdminColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Đóng',
                      style: TextStyle(
                        color: AdminColors.mutedStrong,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await FirebaseFirestore.instance
                            .collection('bookings')
                            .doc(bookingId)
                            .update({
                              'isDisbursed': true,
                              'disbursedAt': FieldValue.serverTimestamp(),
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                        _showNotice(
                          'Đã cập nhật giải ngân đơn $orderCode thành công!',
                        );
                      } catch (e) {
                        _showNotice(
                          'Không thể cập nhật trạng thái. Vui lòng thử lại.',
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Xác nhận Chuyển tiền',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.5, color: AdminColors.muted),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: isHighlight ? 15 : 13,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
              color: isHighlight
                  ? AdminColors.accent
                  : AdminColors.ink,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AdminColors.card,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: 20,
        toolbarHeight: 70,
        title: AdminBrandedTitle(
          title: 'Tổng quan',
          subtitle: _selectedTimeRange == RevenueTimeRange.year
              ? 'Báo cáo tài chính toàn hệ thống'
              : 'Dữ liệu tổng quan toàn hệ thống',
        ),
        actions: [
          const AdminThemeToggle(padding: EdgeInsets.only(right: 8)),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: StreamBuilder<QuerySnapshot>(
              stream: () {
                try {
                  return FirebaseFirestore.instance
                      .collection('notifications')
                      .where('recipientRole', isEqualTo: 'admin')
                      .where('isRead', isEqualTo: false)
                      .snapshots();
                } catch (_) {
                  return const Stream<QuerySnapshot>.empty();
                }
              }(),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data?.docs.length ?? 0;

                return InkWell(
                  onTap: _openNotificationsBottomSheet,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AdminColors.accentSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none_outlined,
                          color: AdminColors.mutedStrong,
                          size: 21,
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AdminColors.danger,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: () {
          try {
            return FirebaseFirestore.instance
                .collection('bookings')
                .snapshots();
          } catch (_) {
            return const Stream<QuerySnapshot>.empty();
          }
        }(),
        builder: (context, bookingSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: () {
              try {
                return FirebaseFirestore.instance
                    .collection('users')
                    .snapshots();
              } catch (_) {
                return const Stream<QuerySnapshot>.empty();
              }
            }(),
            builder: (context, userSnapshot) {
              final now = DateTime.now();
              final isYearView = _selectedTimeRange == RevenueTimeRange.year;
              final isWeekView = _selectedTimeRange == RevenueTimeRange.week;
              final DateTime periodStart;
              if (isWeekView) {
                final today = DateTime(now.year, now.month, now.day);
                periodStart = today.subtract(Duration(days: now.weekday - 1));
              } else if (_selectedTimeRange == RevenueTimeRange.month) {
                periodStart = DateTime(now.year, now.month);
              } else {
                periodStart = DateTime(now.year);
              }
              // So sánh cùng khoảng thời gian đã trôi qua trong kỳ trước
              // (ví dụ từ đầu tháng đến hôm nay với đầu tháng trước đến ngày tương ứng).
              final periodEnd = now;
              late final DateTime previousPeriodStart;
              late final DateTime previousPeriodEnd;
              if (isWeekView) {
                previousPeriodStart = periodStart.subtract(
                  const Duration(days: 7),
                );
                previousPeriodEnd = periodEnd.subtract(const Duration(days: 7));
              } else if (_selectedTimeRange == RevenueTimeRange.month) {
                previousPeriodStart = DateTime(now.year, now.month - 1);
                final previousMonthLastDay = DateTime(
                  previousPeriodStart.year,
                  previousPeriodStart.month + 1,
                  0,
                ).day;
                previousPeriodEnd = DateTime(
                  previousPeriodStart.year,
                  previousPeriodStart.month,
                  now.day.clamp(1, previousMonthLastDay),
                  now.hour,
                  now.minute,
                  now.second,
                  now.millisecond,
                  now.microsecond,
                );
              } else {
                previousPeriodStart = DateTime(now.year - 1);
                final previousYearLastDay = DateTime(
                  now.year - 1,
                  now.month + 1,
                  0,
                ).day;
                previousPeriodEnd = DateTime(
                  now.year - 1,
                  now.month,
                  now.day.clamp(1, previousYearLastDay),
                  now.hour,
                  now.minute,
                  now.second,
                  now.millisecond,
                  now.microsecond,
                );
              }

              final bookingDocs = bookingSnapshot.data?.docs ?? [];
              final userDocs = userSnapshot.data?.docs ?? [];

              double totalFlow = 0;
              double previousTotalFlow = 0;
              double netRevenue = 0;
              int successfulTxCount = 0;
              int depositTxCount = 0;
              int cancellationTxCount = 0;

              List<double> weekChartData = List.filled(7, 0.0);
              List<double> monthChartData = List.filled(4, 0.0);
              List<double> yearChartData = List.filled(12, 0.0);

              for (var doc in bookingDocs) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                final double amount = BookingUtils.amount(data);
                final String? status = BookingUtils.status(data);
                final rawStatus = (data['status'] ?? data['trangThai'] ?? '')
                    .toString()
                    .toLowerCase();
                final bool isDisbursed = data['isDisbursed'] == true;
                final bool isRefunded = data['isRefunded'] == true;
                final bool isPaid =
                    data['isPaid'] == true || data['daThanhToan'] == true;
                final dynamic settledAtValue =
                    (rawStatus == 'cancelled' ||
                        rawStatus == 'canceled' ||
                        rawStatus == 'rejected' ||
                        rawStatus == 'dahuy')
                    ? (data['refundedAt'] ?? data['updatedAt'])
                    : (data['disbursedAt'] ?? data['updatedAt']);
                final DateTime? date = settledAtValue is Timestamp
                    ? settledAtValue.toDate()
                    : BookingUtils.createdAt(data);

                double orderCommission = 0.0;

                // Tổng dòng tiền là tiền cọc đã xác nhận thu vào; số đơn thành
                // công cũng không phải đợi đến lúc admin giải ngân cho chủ trọ.
                bool contributesToCashFlow = false;
                if (status == BookingUtils.statusDepositPaid ||
                    status == BookingUtils.statusCompleted) {
                  depositTxCount++;
                  successfulTxCount++;
                  contributesToCashFlow = true;
                  if (isDisbursed) {
                    final storedFee = data['platformFee'];
                    final storedRate = data['platformFeeRate'];
                    orderCommission = storedFee is num
                        ? storedFee.toDouble()
                        : amount *
                              (storedRate is num
                                  ? storedRate.toDouble() / 100
                                  : 0.10);
                    netRevenue += orderCommission;
                  }
                }
                // Đơn hủy đã nhận cọc vẫn thuộc dòng tiền vào gộp. Phí hủy
                // chỉ là doanh thu sàn khi admin đã ghi nhận xử lý tiền hủy.
                else if (rawStatus == 'cancelled' ||
                    rawStatus == 'canceled' ||
                    rawStatus == 'rejected' ||
                    rawStatus == 'dahuy') {
                  contributesToCashFlow = isPaid || isRefunded;
                  if (isRefunded) {
                    cancellationTxCount++;
                    successfulTxCount++;
                    orderCommission = amount * BookingUtils.cancelPlatformRate;
                    netRevenue += orderCommission;
                  }
                }

                if (contributesToCashFlow && date != null) {
                  if (!date.isBefore(periodStart) && !date.isAfter(periodEnd)) {
                    totalFlow += amount;
                  } else if (!date.isBefore(previousPeriodStart) &&
                      date.isBefore(previousPeriodEnd)) {
                    previousTotalFlow += amount;
                  }
                }

                // Đưa vào phân bổ biểu đồ doanh thu
                if (orderCommission > 0 && date != null) {
                  if (date.year == now.year) {
                    yearChartData[date.month - 1] += orderCommission / 1000000;
                  }

                  if (date.year == now.year && date.month == now.month) {
                    int weekIdx = ((date.day - 1) ~/ 7).clamp(0, 3);
                    monthChartData[weekIdx] += orderCommission / 1000000;
                  }

                  final startOfWeek = DateTime(
                    now.year,
                    now.month,
                    now.day,
                  ).subtract(Duration(days: now.weekday - 1));
                  final endOfWeek = startOfWeek.add(const Duration(days: 7));
                  if (!date.isBefore(startOfWeek) && date.isBefore(endOfWeek)) {
                    int dayIdx = (date.weekday - 1).clamp(0, 6);
                    weekChartData[dayIdx] += orderCommission / 1000000;
                  }
                }
              }

              final totalUsers = userDocs.length;
              int newHostsCount = 0;
              int newRentersCount = 0;

              for (var u in userDocs) {
                final uData = u.data() as Map<String, dynamic>? ?? {};
                final role = (uData['role'] ?? '').toString().toLowerCase();
                final Timestamp? uTime = uData['createdAt'] as Timestamp?;
                final bool isThisMonth =
                    uTime != null &&
                    uTime.toDate().month == now.month &&
                    uTime.toDate().year == now.year;

                if (role == 'host' || role == 'landlord' || role == 'chutro') {
                  if (isThisMonth) newHostsCount++;
                } else {
                  if (isThisMonth) newRentersCount++;
                }
              }

              final pendingTransferDocs = bookingDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                final booking = BookingUtils.canonical(data);
                final status = BookingUtils.status(booking);
                final bookingStatus = (booking['status'] ?? '').toString();
                final isCancellation =
                    bookingStatus == 'cancelled' || bookingStatus == 'rejected';
                if (isCancellation) {
                  // Đơn hủy chưa được admin ghi nhận hoàn tiền/bồi thường.
                  return booking['isRefunded'] != true &&
                      BookingUtils.amount(booking) > 0;
                }

                final bookingId = (booking['bookingId'] ?? '').toString();
                final orderCode = (booking['orderCode'] ?? '').toString();
                final hasCheckInRecord =
                    _checkedInBookingIds.contains(doc.id) ||
                    _checkedInBookingIds.contains(bookingId) ||
                    _checkedInBookingIds.contains(orderCode);
                return (booking['isCheckIn'] == true || hasCheckInRecord) &&
                    booking['isDisbursed'] != true &&
                    (status == BookingUtils.statusDepositPaid ||
                        status == BookingUtils.statusCompleted);
              }).toList();

              final String periodLabel = isWeekView
                  ? 'tuần trước'
                  : _selectedTimeRange == RevenueTimeRange.month
                  ? 'tháng trước'
                  : 'năm trước';
              final double flowChangePercent = previousTotalFlow == 0
                  ? 0
                  : (totalFlow - previousTotalFlow) /
                        previousTotalFlow.abs() *
                        100;
              final String flowComparisonText;
              final Color flowComparisonColor;
              final Color flowComparisonBackground;
              if (previousTotalFlow == 0 && totalFlow > 0) {
                flowComparisonText = 'Mới phát sinh kỳ này';
                flowComparisonColor = AdminColors.successInk;
                flowComparisonBackground = AdminColors.successContainer;
              } else if (previousTotalFlow == 0) {
                flowComparisonText = 'Chưa có dòng tiền kỳ trước';
                flowComparisonColor = AdminColors.muted;
                flowComparisonBackground = AdminColors.accentSoft;
              } else {
                final arrow = flowChangePercent >= 0 ? '▲' : '▼';
                flowComparisonText =
                    '$arrow ${flowChangePercent.abs().toStringAsFixed(1).replaceAll('.', ',')}% so với $periodLabel';
                flowComparisonColor = flowChangePercent >= 0
                    ? AdminColors.successInk
                    : AdminColors.warningInk;
                flowComparisonBackground = flowChangePercent >= 0
                    ? AdminColors.successContainer
                    : AdminColors.warningContainer;
              }

              // Định dạng ghi chú biến động thành viên mới trong tháng
              final String userBadgeText;
              if (newHostsCount > 0 && newRentersCount > 0) {
                userBadgeText =
                    '+$newHostsCount chủ trọ  +$newRentersCount khách mới';
              } else if (newHostsCount > 0) {
                userBadgeText = '▲ +$newHostsCount chủ trọ mới';
              } else if (newRentersCount > 0) {
                userBadgeText = '▲ +$newRentersCount khách thuê mới';
              } else {
                userBadgeText = 'Thành viên toàn hệ thống';
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 14.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hàng 1
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiCard(
                            title: 'TỔNG DÒNG TIỀN',
                            value: _formatMoney(totalFlow),
                            valueColor: AdminColors.ink,
                            badgeText: flowComparisonText,
                            badgeColor: flowComparisonBackground,
                            badgeTextColor: flowComparisonColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKpiCard(
                            title: isYearView
                                ? 'DOANH THU SÀN'
                                : 'DOANH THU SÀN',
                            value: _formatMoney(netRevenue),
                            valueColor: AdminColors.accentText,
                            subtext: 'Cọc và phí hủy đã ghi nhận',
                            subtextColor: AdminColors.mutedStrong,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Hàng 2: Giao dịch thành công & Tổng user toàn sàn
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiCard(
                            title: 'GIAO DỊCH THÀNH CÔNG',
                            value: '$successfulTxCount Đơn',
                            valueColor: AdminColors.warning,
                            subtext:
                                '$depositTxCount đơn cọc • $cancellationTxCount đơn hủy',
                            subtextColor: AdminColors.muted,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKpiCard(
                            title: isYearView
                                ? 'TỔNG USER TOÀN SÀN'
                                : 'TỔNG USER HỆ THỐNG',
                            value: '$totalUsers Users',
                            valueColor: AdminColors.ink,
                            badgeText: userBadgeText,
                            badgeColor:
                                (newHostsCount > 0 || newRentersCount > 0)
                                ? AdminColors.successContainer
                                : AdminColors.accentSoft,
                            badgeTextColor:
                                (newHostsCount > 0 || newRentersCount > 0)
                                ? AdminColors.successInk
                                : AdminColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Thống kê Doanh Thu Chart
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AdminColors.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AdminColors.border,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'THỐNG KÊ DOANH THU',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: AdminColors.ink,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isYearView
                                          ? 'Phí hoa hồng cọc năm ${now.year}'
                                          : 'Tổng phí hoa hồng sàn thực nhận',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AdminColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: AdminColors.accentSoft,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildPillTab(
                                      'Tuần',
                                      RevenueTimeRange.week,
                                    ),
                                    _buildPillTab(
                                      'Tháng',
                                      RevenueTimeRange.month,
                                    ),
                                    _buildPillTab('Năm', RevenueTimeRange.year),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          ClipRect(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: _selectedTimeRange == RevenueTimeRange.year
                                  ? RevenueBarChart(
                                      key: const ValueKey('year_chart'),
                                      monthlyData: yearChartData,
                                    )
                                  : RevenueLineChart(
                                      key: ValueKey(
                                        'line_chart_${_selectedTimeRange.name}',
                                      ),
                                      labels: isWeekView
                                          ? const [
                                              'T2',
                                              'T3',
                                              'T4',
                                              'T5',
                                              'T6',
                                              'T7',
                                              'CN',
                                            ]
                                          : const [
                                              'Tuần 1',
                                              'Tuần 2',
                                              'Tuần 3',
                                              'Tuần 4',
                                            ],
                                      weeklyData: isWeekView
                                          ? weekChartData
                                          : monthChartData,
                                      activeIndex: isWeekView
                                          ? (now.weekday - 1).clamp(0, 6)
                                          : ((now.day - 1) ~/ 7).clamp(0, 3),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Việc cần xử lý
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'VIỆC CẦN XỬ LÝ',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AdminColors.mutedStrong,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AdminColors.dangerContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AdminColors.dangerContainer,
                                ),
                              ),
                              child: Text(
                                '${pendingTransferDocs.length} việc chờ chuyển tiền',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AdminColors.dangerInk,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (widget.onNavigateToOrders != null)
                          TextButton(
                            onPressed: widget.onNavigateToOrders,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Xem tất cả',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AdminColors.accentText,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (pendingTransferDocs.isNotEmpty) ...[
                      for (var pendingDoc in pendingTransferDocs.take(3)) ...[
                        _buildPendingTransferAlertItem(pendingDoc),
                        const SizedBox(height: 10),
                      ],
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AdminColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AdminColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AdminColors.successContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: AdminColors.success,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tất cả tác vụ đã hoàn tất',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AdminColors.ink,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Hiện không có đơn nào chờ chuyển tiền',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AdminColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPendingTransferAlertItem(DocumentSnapshot doc) {
    final data = BookingUtils.canonical(
      doc.data() as Map<String, dynamic>? ?? {},
    );
    final status = (data['status'] ?? '').toString();
    final isCancellation = status == 'cancelled' || status == 'rejected';
    final orderCode =
        data['orderCode'] ??
        '#${doc.id.substring(0, doc.id.length > 6 ? 6 : doc.id.length).toUpperCase()}';
    final hostName = data['hostName'] ?? 'Chủ trọ';
    final amount = BookingUtils.amount(data);
    final cancelSplit = BookingUtils.cancellationSplit(amount);
    final actionTitle = isCancellation
        ? 'Quyết toán đơn hủy $orderCode'
        : 'Giải ngân cọc $orderCode';
    final actionDetail = isCancellation
        ? 'Hoàn khách ${_formatMoney(cancelSplit['refundAmount'] ?? 0)} • Bồi thường chủ trọ ${_formatMoney(cancelSplit['hostAmount'] ?? 0)}'
        : 'Chủ trọ: $hostName • Quyết toán: ${_formatMoney(amount)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AdminColors.dangerContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '!',
                style: TextStyle(
                  color: AdminColors.danger,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actionTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AdminColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  actionDetail,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AdminColors.muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              if (isCancellation) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CancellationInvoiceScreen(bookingIds: [doc.id]),
                  ),
                );
              } else {
                _showDisbursementDialog(doc);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Xử lý ngay',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required Color valueColor,
    String? badgeText,
    Color? badgeColor,
    Color? badgeTextColor,
    String? subtext,
    Color? subtextColor,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return Container(
      height: 108,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor ?? AdminColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? AdminColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            color: AdminColors.mutedStrong,
            letterSpacing: 0.3,
            ),
            textAlign: TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
            textAlign: TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          if (badgeText != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor ?? AdminColors.successContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badgeText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: badgeTextColor ?? AdminColors.successInk,
                ),
              ),
            ),
            if (subtext != null) const SizedBox(height: 4),
          ],
          if (subtext != null)
            Text(
              subtext,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: subtextColor ?? AdminColors.muted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildPillTab(String title, RevenueTimeRange range) {
    final isSelected = _selectedTimeRange == range;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() {
          _selectedTimeRange = range;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AdminColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AdminColors.accent.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AdminColors.muted,
          ),
        ),
      ),
    );
  }
}
