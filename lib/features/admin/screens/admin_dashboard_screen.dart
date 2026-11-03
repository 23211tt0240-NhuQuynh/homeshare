import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_notifications_screen.dart';
import '../utils/booking_utils.dart';
import '../widgets/admin_branded_title.dart';
import '../widgets/revenue_line_chart.dart';
import '../widgets/revenue_bar_chart.dart';

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

  String _formatMoney(num amount) {
    return "${amount.toStringAsFixed(0).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.')} đ";
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
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
                    decoration: const BoxDecoration(
                      color: Color(0xFFEAF4FA),
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
                        if (unreadCount > 0)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFD92D20),
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
          if (bookingSnapshot.hasError) {
            debugPrint('Lỗi tải bookings trên dashboard: ${bookingSnapshot.error}');
            return const Center(
              child: Text(
                'Không tải được dữ liệu đơn hàng. Kiểm tra mạng hoặc quyền Firestore.',
                textAlign: TextAlign.center,
              ),
            );
          }
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
              if (userSnapshot.hasError) {
                debugPrint('Lỗi tải users trên dashboard: ${userSnapshot.error}');
                return const Center(
                  child: Text(
                    'Không tải được dữ liệu người dùng. Kiểm tra mạng hoặc quyền Firestore.',
                    textAlign: TextAlign.center,
                  ),
                );
              }
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
              int settledDepositTxCount = 0;
              int settledFullPaymentTxCount = 0;
              int settledCancellationTxCount = 0;

              List<double> weekChartData = List.filled(7, 0.0);
              List<double> monthChartData = List.filled(4, 0.0);
              List<double> yearChartData = List.filled(12, 0.0);

              for (var doc in bookingDocs) {
                final rawData = doc.data() as Map<String, dynamic>? ?? {};
                final data = BookingUtils.canonical(rawData);
                final double amount = BookingUtils.amount(data);
                final String? status = BookingUtils.status(data);
                final rawStatus = (data['status'] ?? '')
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

                // Ghi nhận tiền khi Admin đã xác nhận khoản thanh toán của
                // khách hoặc đã giải ngân cho chủ trọ. Hai mốc này được lưu
                // bằng isPaid và isDisbursed tương ứng.
                bool contributesToCashFlow = false;
                if (status == BookingUtils.statusDepositPaid ||
                    status == BookingUtils.statusCompleted) {
                  if (isPaid || isDisbursed) {
                    successfulTxCount++;
                    if (status == BookingUtils.statusCompleted) {
                      settledFullPaymentTxCount++;
                    } else {
                      settledDepositTxCount++;
                    }
                    contributesToCashFlow = true;
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
                    successfulTxCount++;
                    settledCancellationTxCount++;
                    final cancellationFee = data['cancellationPlatformFee'];
                    final cancellationRate = data['cancellationCommissionRate'];
                    orderCommission = cancellationFee is num
                        ? cancellationFee.toDouble()
                        : amount *
                              (cancellationRate is num
                                  ? cancellationRate.toDouble() / 100
                                  : BookingUtils.cancelPlatformRate);
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

              int hostCount = 0;
              int renterCount = 0;
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
                  hostCount++;
                  if (isThisMonth) newHostsCount++;
                } else if (role != 'admin') {
                  // Chỉ tính renter/tenant, bỏ qua admin
                  renterCount++;
                  if (isThisMonth) newRentersCount++;
                }
              }

              final totalUsers = hostCount + renterCount;

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
              final String? userBadgeText;
              if (newHostsCount > 0 && newRentersCount > 0) {
                userBadgeText =
                    '+$newHostsCount chủ trọ  +$newRentersCount khách mới';
              } else if (newHostsCount > 0) {
                userBadgeText = '▲ +$newHostsCount chủ trọ mới';
              } else if (newRentersCount > 0) {
                userBadgeText = '▲ +$newRentersCount khách thuê mới';
              } else {
                userBadgeText = null;
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
                                '$settledDepositTxCount đơn cọc • $settledFullPaymentTxCount đơn trả hết • $settledCancellationTxCount đơn hủy',
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
                            subtext:
                                '$hostCount chủ trọ • $renterCount khách thuê',
                            subtextColor: const Color(0xFF64748B),
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
                  ],
                ),
              );
            },
          );
        },
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
      constraints: const BoxConstraints(minHeight: 108),
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
          color: isSelected ? const Color(0xFF398FC0) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF398FC0).withValues(alpha: 0.25),
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
}
