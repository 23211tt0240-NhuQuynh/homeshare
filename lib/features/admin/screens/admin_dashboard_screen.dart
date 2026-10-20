<<<<<<< HEAD
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_notifications_screen.dart';
import '../utils/booking_utils.dart';
import '../widgets/admin_branded_title.dart';
import '../widgets/revenue_line_chart.dart';
import '../widgets/revenue_bar_chart.dart';
import 'cancellation_invoice_screen.dart';

enum RevenueTimeRange { week, month, year }

class AdminDashboardScreen extends StatefulWidget {
=======
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/user_provider.dart';
import '../services/admin_service.dart';
import '../widgets/admin_alert_card.dart';
import '../widgets/admin_kpi_card.dart';
import '../widgets/revenue_bar_chart.dart';
import '../widgets/revenue_line_chart.dart';
import 'settlement_invoice_screen.dart';

enum RevenueTimeRange { week, month, year }

class AdminDashboardScreen extends ConsumerStatefulWidget {
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
<<<<<<< HEAD
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  RevenueTimeRange _selectedTimeRange = RevenueTimeRange.year;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _checkinsSub;
  Set<String> _checkedInBookingIds = {};

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _checkinsSub?.cancel();
    super.dispose();
  }

  String _formatMoney(num amount) {
    return "${amount.toStringAsFixed(0).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.')} đ";
  }
=======
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  RevenueTimeRange _selectedTimeRange = RevenueTimeRange.year;
  final currencyFormatter = NumberFormat('#,###', 'vi_VN');
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62

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

<<<<<<< HEAD
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

=======
  void _handleNavigateToPosts() {
    if (widget.onNavigateToPosts != null) {
      widget.onNavigateToPosts!();
    } else {
      _showNotice('Chuyển sang trang Duyệt Bài Đăng');
    }
  }

  void _handleNavigateToOrders() {
    if (widget.onNavigateToOrders != null) {
      widget.onNavigateToOrders!();
    } else {
      _showNotice('Chuyển sang trang Quản Lý Đơn Cọc');
    }
  }

  void _handleNavigateToHistory() {
    if (widget.onNavigateToHistory != null) {
      widget.onNavigateToHistory!();
    } else {
      _showNotice('Chuyển sang trang Lịch Sử');
    }
  }

  void _showDisbursementDialog(AdminActionItem item) {
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
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
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xFF12B76A),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phê Duyệt Giải Ngân Cọc',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF101828),
                        ),
                      ),
                      Text(
<<<<<<< HEAD
                        'Mã đơn: $orderCode',
=======
                        'Mã đơn: ${item.highlightCode}',
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF667085),
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
<<<<<<< HEAD
                color: const Color(0xFFF4F9FF),
=======
                color: const Color(0xFFF8FAFC),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
<<<<<<< HEAD
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
=======
                  _buildDetailRow('Tên chủ trọ:', item.hostName),
                  const Divider(height: 16),
                  _buildDetailRow('Số điện thoại:', item.hostPhone),
                  const Divider(height: 16),
                  _buildDetailRow(
                    'Ngân hàng thụ hưởng:',
                    '${item.hostBankName} (${item.hostAccountNumber})',
                  ),
                  const Divider(height: 16),
                  _buildDetailRow('Phòng liên kết:', item.roomTitle),
                  const Divider(height: 16),
                  _buildDetailRow(
                    'Số tiền cọc giải ngân:',
                    '${currencyFormatter.format(item.amount)} đ',
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
                      side: const BorderSide(color: Color(0xFFD0D5DD)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Đóng',
                      style: TextStyle(
                        color: Color(0xFF344054),
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
<<<<<<< HEAD
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
                        _showNotice('Lỗi cập nhật Firestore: $e');
=======
                        await ref
                            .read(adminServiceProvider)
                            .approveBookingDisbursement(
                              bookingId: item.id,
                              orderCode: item.highlightCode.split(' → ').first,
                              hostName: item.hostName,
                              amount: item.amount,
                            );
                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SettlementInvoiceScreen(
                                hostName: item.hostName,
                                hostPhone: item.hostPhone,
                                hostBankName: item.hostBankName,
                                hostAccountNumber: item.hostAccountNumber,
                                totalDeposit: item.amount,
                                platformFee: item.amount * 0.1,
                                netSettlement: item.amount * 0.9,
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        _showNotice('Không thể giải ngân: $e');
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF12B76A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
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
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF667085)),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: isHighlight ? 15 : 13,
              fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
              color: isHighlight
<<<<<<< HEAD
                  ? const Color(0xFF398FC0)
=======
                  ? const Color(0xFF155EEF)
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                  : const Color(0xFF101828),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    return Scaffold(
      backgroundColor: Colors.transparent,
=======
    // Lấy dữ liệu an toàn từ Riverpod
    final profile = ref.watch(userProfileProvider).value;
    final statsAsync = ref.watch(adminDashboardStatsStreamProvider);
    final chartDataAsync = ref.watch(adminRevenueChartDataProvider);
    final actionItemsAsync = ref.watch(adminPendingActionsProvider);

    final stats = statsAsync.value ??
        const AdminDashboardStats(
          totalFlow: 1748500000,
          netRevenue: 168250000,
          successfulTransactions: 45600,
          totalUsers: 5880,
          newHosts: 320,
          growthYoy: 18.4,
          monthlyAverage: 14020000,
        );

    // Xử lý an toàn cho mảng yearlyData — giữ null cho tháng tương lai (dashed bar)
    final rawChartData = chartDataAsync.value;
    final List<double?> safeYearlyData = rawChartData?.yearlyData.toList() ??
        const [6.2, 4.0, 7.5, 9.8, 11.2, 13.5, 15.0, 16.2, 18.5, null, null, null];

    final chartData = rawChartData ??
        AdminRevenueChartData(
          weeklyData: const [2.5, 4.2, 3.1, 2.0, 5.8, 12.4, 7.6],
          monthlyWeeksData: const [28.0, 36.5, 42.0, 48.2],
          yearlyData: safeYearlyData,
          peakYearlyMonthIndex: 8,
          peakYearlyAmount: 18.5,
          monthlyAverage: 14020000,
        );

    final actionItems = actionItemsAsync.value ?? [];

    final isYearView = _selectedTimeRange == RevenueTimeRange.year;
    final displayFlow = isYearView ? stats.totalFlow : (stats.totalFlow / 12);
    final displayRevenue =
        isYearView ? stats.netRevenue : (stats.netRevenue / 12);
    final displayTx = isYearView
        ? '${currencyFormatter.format(stats.successfulTransactions)} lượt'
        : '${currencyFormatter.format((stats.successfulTransactions / 12).round())} Giao dịch';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: 20,
        toolbarHeight: 70,
<<<<<<< HEAD
        title: AdminBrandedTitle(
          title: 'Tổng quan',
          subtitle: _selectedTimeRange == RevenueTimeRange.year
              ? 'Báo cáo tài chính toàn hệ thống'
              : 'Dữ liệu tổng quan toàn hệ thống',
=======
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'QUẢN TRỊ ADMIN',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: Color(0xFF101828),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isYearView
                  ? 'Dữ liệu tổng quan & Báo cáo tài chính'
                  : 'Dữ liệu tổng quan toàn hệ thống',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF667085),
              ),
            ),
          ],
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
<<<<<<< HEAD
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
=======
            child: Row(
              children: [
                InkWell(
                  onTap: () => _showNotice('Mở danh sách thông báo hệ thống'),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
<<<<<<< HEAD
                      color: Color(0xFFEAF4FA),
=======
                      color: Color(0xFFF2F4F7),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.notifications_none_outlined,
                          color: Color(0xFF344054),
                          size: 21,
                        ),
<<<<<<< HEAD
                        if (unreadCount > 0)
=======
                        if (actionItems.isNotEmpty)
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
<<<<<<< HEAD
                              width: 8,
                              height: 8,
=======
                              width: 7,
                              height: 7,
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                              decoration: const BoxDecoration(
                                color: Color(0xFFD92D20),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
<<<<<<< HEAD
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
                flowComparisonColor = const Color(0xFF138A58);
                flowComparisonBackground = const Color(0xFFE8F8F0);
              } else if (previousTotalFlow == 0) {
                flowComparisonText = 'Chưa có dòng tiền kỳ trước';
                flowComparisonColor = const Color(0xFF64748B);
                flowComparisonBackground = const Color(0xFFF1F5F9);
              } else {
                final arrow = flowChangePercent >= 0 ? '▲' : '▼';
                flowComparisonText =
                    '$arrow ${flowChangePercent.abs().toStringAsFixed(1).replaceAll('.', ',')}% so với $periodLabel';
                flowComparisonColor = flowChangePercent >= 0
                    ? const Color(0xFF138A58)
                    : const Color(0xFFB54708);
                flowComparisonBackground = flowChangePercent >= 0
                    ? const Color(0xFFE8F8F0)
                    : const Color(0xFFFFF4E5);
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
                            valueColor: const Color(0xFF101828),
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
                            valueColor: const Color(0xFF398FC0),
                            subtext: 'Cọc và phí hủy đã ghi nhận',
                            subtextColor: const Color(0xFF398FC0),
                            backgroundColor: const Color.fromARGB(
                              255,
                              252,
                              252,
                              253,
                            ),
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
                            valueColor: const Color(0xFFD97706),
                            subtext:
                                '$depositTxCount đơn cọc • $cancellationTxCount đơn hủy',
                            subtextColor: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKpiCard(
                            title: isYearView
                                ? 'TỔNG USER TOÀN SÀN'
                                : 'TỔNG USER HỆ THỐNG',
                            value: '$totalUsers Users',
                            valueColor: const Color(0xFF101828),
                            badgeText: userBadgeText,
                            badgeColor:
                                (newHostsCount > 0 || newRentersCount > 0)
                                ? const Color(0xFFECFDF3)
                                : const Color(0xFFEAF4FA),
                            badgeTextColor:
                                (newHostsCount > 0 || newRentersCount > 0)
                                ? const Color(0xFF027A48)
                                : const Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Thống kê Doanh Thu Chart
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFDCEAF5),
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
                                    const Text(
                                      'THỐNG KÊ DOANH THU',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF101828),
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isYearView
                                          ? 'Phí hoa hồng cọc năm ${now.year}'
                                          : 'Tổng phí hoa hồng sàn thực nhận',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF667085),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF4FA),
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
                            const Text(
                              'VIỆC CẦN XỬ LÝ',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF344054),
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
                                color: const Color(0xFFFEF3F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFECDCA),
                                ),
                              ),
                              child: Text(
                                '${pendingTransferDocs.length} việc chờ chuyển tiền',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB42318),
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
                            child: const Text(
                              'Xem tất cả',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF398FC0),
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDCEAF5)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.check_circle_outline_rounded,
                                  color: Color(0xFF12B76A),
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tất cả tác vụ đã hoàn tất',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF101828),
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Hiện không có đơn nào chờ chuyển tiền',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF667085),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCEAF5)),
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
              color: const Color(0xFFFEF3F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                '!',
                style: TextStyle(
                  color: Color(0xFFF04438),
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  actionDetail,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF667085),
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
              backgroundColor: const Color(0xFF12B76A),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
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
    Color backgroundColor = Colors.white,
    Color borderColor = const Color(0xFFDCEAF5),
  }) {
    return Container(
      height: 108,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
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
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
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
                color: badgeColor ?? const Color(0xFFECFDF3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badgeText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: badgeTextColor ?? const Color(0xFF027A48),
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
                color: subtextColor ?? const Color(0xFF667085),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
=======
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => _showNotice('Mở thông tin tài khoản Admin'),
                  borderRadius: BorderRadius.circular(19),
                  child: CircleAvatar(
                    radius: 19,
                    backgroundColor: const Color(0xFFE0EAFF),
                    child: Text(
                      (profile?.displayName.isNotEmpty ?? false)
                          ? profile!.displayName[0].toUpperCase()
                          : 'A',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF155EEF),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. THẺ THỐNG KÊ 2x2
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showNotice('Chi tiết Tổng dòng tiền'),
                    borderRadius: BorderRadius.circular(16),
                    child: AdminKpiCard(
                      title: 'TỔNG DÒNG TIỀN',
                      value: '${currencyFormatter.format(displayFlow)} đ',
                      valueColor: const Color(0xFF101828),
                      badgeText: isYearView
                          ? '+18.4% YOY'
                          : '+14.3% so với tháng trước',
                      badgeIcon: Icons.arrow_drop_up,
                      badgeColor: const Color(0xFFECFDF3),
                      badgeTextColor: const Color(0xFF027A48),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _showNotice('Chi tiết Doanh thu sàn'),
                    borderRadius: BorderRadius.circular(16),
                    child: AdminKpiCard(
                      title: isYearView
                          ? 'DOANH THU SÀN'
                          : 'DOANH THU SÀN (THỰC NHẬN)',
                      value: '${currencyFormatter.format(displayRevenue)} đ',
                      valueColor: const Color(0xFF155EEF),
                      subtext: isYearView
                          ? 'Hoa hồng cọc & Phí tin'
                          : 'Hoa hồng & Phí bán gói',
                      subtextColor: const Color(0xFF2E90FA),
                      backgroundColor: const Color(0xFFF5F8FF),
                      borderColor: const Color(0xFFD1E0FF),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showNotice('Chi tiết Giao dịch thành công'),
                    borderRadius: BorderRadius.circular(16),
                    child: AdminKpiCard(
                      title: 'GIAO DỊCH THÀNH CÔNG',
                      value: displayTx,
                      valueColor: const Color(0xFFD97706),
                      subtext: isYearView ? '99.2% khớp tự động' : null,
                      subtextColor: const Color(0xFF667085),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _showNotice('Chi tiết Tổng user hệ thống'),
                    borderRadius: BorderRadius.circular(16),
                    child: AdminKpiCard(
                      title: isYearView
                          ? 'TỔNG USER TOÀN SÀN'
                          : 'TỔNG USER HỆ THỐNG',
                      value:
                          '${currencyFormatter.format(stats.totalUsers)} Users',
                      valueColor: const Color(0xFF101828),
                      badgeText: '+${stats.newHosts} chủ trọ mới',
                      badgeIcon: Icons.arrow_drop_up,
                      badgeColor: const Color(0xFFECFDF3),
                      badgeTextColor: const Color(0xFF027A48),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 2. BIỂU ĐỒ THỐNG KÊ DOANH THU
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFEAECF0), width: 1.2),
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
                            const Text(
                              'THỐNG KÊ DOANH THU',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF101828),
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isYearView
                                  ? 'Phí hoa hồng cọc & Đẩy tin năm 2026'
                                  : 'Tổng phí mua gói & Đẩy tin',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF667085),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F4F7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildPillTab('Tuần', RevenueTimeRange.week),
                            _buildPillTab('Tháng', RevenueTimeRange.month),
                            _buildPillTab('Năm', RevenueTimeRange.year),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  ClipRect(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _selectedTimeRange == RevenueTimeRange.year
                          ? Column(
                              key: const ValueKey('year_chart_container'),
                              children: [
                                RevenueBarChart(
                                  monthlyData: safeYearlyData,
                                  peakIndex: chartData.peakYearlyMonthIndex,
                                  peakTooltipText:
                                      '● T${chartData.peakYearlyMonthIndex + 1}: ${chartData.peakYearlyAmount.toStringAsFixed(1)}M đ (Cao nhất)',
                                  averageMonthlyText:
                                      'TB mỗi tháng: ${currencyFormatter.format(chartData.monthlyAverage)} đ',
                                ),
                              ],
                            )
                          : RevenueLineChart(
                              key: ValueKey('line_chart_$_selectedTimeRange'),
                              weeklyData:
                                  _selectedTimeRange == RevenueTimeRange.week
                                      ? chartData.weeklyData
                                      : chartData.monthlyWeeksData,
                              labels: _selectedTimeRange == RevenueTimeRange.week
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
                              activeIndex:
                                  _selectedTimeRange == RevenueTimeRange.week
                                      ? 5
                                      : 3,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 3. VIỆC CẦN XỬ LÝ
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'VIỆC CẦN XỬ LÝ',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF344054),
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
                        color: const Color(0xFFFEF3F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECDCA)),
                      ),
                      child: Text(
                        '${actionItems.isEmpty ? 1 : actionItems.length} việc chờ',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB42318),
                        ),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _handleNavigateToOrders,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Xem tất cả',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF155EEF),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (actionItems.isNotEmpty) ...[
              for (int i = 0; i < actionItems.length.clamp(0, 3); i++) ...[
                AdminAlertCard.disbursement(
                  orderCode: actionItems[i].highlightCode.split(' → ').first,
                  hostCode: actionItems[i].highlightCode.split(' → ').length > 1
                      ? actionItems[i].highlightCode.split(' → ').last
                      : 'CT0089',
                  hostName: actionItems[i].hostName,
                  amount:
                      '${currencyFormatter.format(actionItems[i].amount)} đ',
                  onProcess: () => _showDisbursementDialog(actionItems[i]),
                ),
                if (i < actionItems.length - 1 && i < 2)
                  const SizedBox(height: 10),
              ],
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEAECF0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          '!',
                          style: TextStyle(
                            color: Color(0xFFF04438),
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
                        children: const [
                          Text(
                            'Giải ngân cọc #DH8821 → CT0089',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF101828),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Chủ trọ: Đặng Thu Hà • Quyết toán...',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF667085),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        _showNotice('Vui lòng chọn đơn cọc thực tế để xử lý');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF12B76A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Xử lý ngay',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // 4. LỐI TẮT ĐIỀU HƯỚNG NHANH
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleNavigateToPosts,
                    icon: const Icon(
                      Icons.apartment_outlined,
                      size: 16,
                      color: Color(0xFF155EEF),
                    ),
                    label: const Text(
                      'Duyệt Bài',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF155EEF),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Color(0xFFD1E0FF)),
                      backgroundColor: const Color(0xFFF5F8FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleNavigateToOrders,
                    icon: const Icon(
                      Icons.receipt_long_outlined,
                      size: 16,
                      color: Color(0xFF027A48),
                    ),
                    label: const Text(
                      'Quản Lý Đơn',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF027A48),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Color(0xFFA6F4C5)),
                      backgroundColor: const Color(0xFFECFDF3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleNavigateToHistory,
                    icon: const Icon(
                      Icons.history_rounded,
                      size: 16,
                      color: Color(0xFF475467),
                    ),
                    label: const Text(
                      'Lịch Sử',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475467),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Color(0xFFEAECF0)),
                      backgroundColor: const Color(0xFFF8FAFC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
<<<<<<< HEAD
          color: isSelected ? const Color(0xFF398FC0) : Colors.transparent,
=======
          color: isSelected ? const Color(0xFF1E60FF) : Colors.transparent,
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
<<<<<<< HEAD
                    color: const Color(0xFF398FC0).withValues(alpha: 0.25),
=======
                    color: const Color(0xFF1E60FF).withValues(alpha: 0.2),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
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
            color: isSelected ? Colors.white : const Color(0xFF667085),
          ),
        ),
      ),
    );
  }
<<<<<<< HEAD
}
=======
}
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
