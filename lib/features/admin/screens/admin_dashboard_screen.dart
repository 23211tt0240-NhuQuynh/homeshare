import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_notifications_screen.dart';
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
          if (type == 'disbursement' && widget.onNavigateToOrders != null) {
            widget.onNavigateToOrders!();
          } else if (type == 'post_approval' && widget.onNavigateToPosts != null) {
            widget.onNavigateToPosts!();
          } else if (widget.onNavigateToHistory != null) {
            widget.onNavigateToHistory!();
          }
        },
      ),
    );
  }

  void _showDisbursementDialog(DocumentSnapshot bookingDoc) {
    final data = bookingDoc.data() as Map<String, dynamic>? ?? {};
    final bookingId = bookingDoc.id;
    final orderCode = data['bookingCode'] ?? data['orderCode'] ?? '#${bookingId.substring(0, bookingId.length > 6 ? 6 : bookingId.length).toUpperCase()}';
    final hostName = data['hostName'] ?? data['landlordName'] ?? 'Chủ trọ';
    final hostPhone = data['hostPhone'] ?? data['landlordPhone'] ?? 'Đang cập nhật';
    final hostBank = data['hostBankName'] ?? 'MB Bank';
    final hostAcc = data['hostAccountNumber'] ?? '---';
    final roomTitle = data['roomTitle'] ?? 'Phòng trọ';
    final amount = (data['amount'] ?? data['depositAmount'] ?? 0.0) as num;

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
                        'Mã đơn: $orderCode',
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
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Tên chủ trọ:', hostName),
                  const Divider(height: 16),
                  _buildDetailRow('Số điện thoại:', hostPhone),
                  const Divider(height: 16),
                  _buildDetailRow('Ngân hàng thụ hưởng:', '$hostBank ($hostAcc)'),
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
                        await FirebaseFirestore.instance
                            .collection('bookings')
                            .doc(bookingId)
                            .update({
                          'status': 'completed',
                          'disbursedAt': FieldValue.serverTimestamp(),
                        });
                        _showNotice('Đã cập nhật giải ngân đơn $orderCode thành công!');
                      } catch (e) {
                        _showNotice('Lỗi cập nhật Firestore: $e');
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

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
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
              color: isHighlight ? const Color(0xFF155EEF) : const Color(0xFF101828),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: 20,
        toolbarHeight: 70,
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
              _selectedTimeRange == RevenueTimeRange.year
                  ? 'Dữ liệu tổng quan & Báo cáo tài chính'
                  : 'Dữ liệu tổng quan toàn hệ thống',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF667085),
              ),
            ),
          ],
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
                      color: Color(0xFFF2F4F7),
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
            return FirebaseFirestore.instance.collection('bookings').snapshots();
          } catch (_) {
            return const Stream<QuerySnapshot>.empty();
          }
        }(),
        builder: (context, bookingSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: () {
              try {
                return FirebaseFirestore.instance.collection('users').snapshots();
              } catch (_) {
                return const Stream<QuerySnapshot>.empty();
              }
            }(),
            builder: (context, userSnapshot) {
              final now = DateTime.now();

              final bookingDocs = bookingSnapshot.data?.docs ?? [];
              final userDocs = userSnapshot.data?.docs ?? [];

              double totalFlow = 0;
              double netRevenue = 0;
              int successfulTxCount = 0;

              List<double> weekChartData = List.filled(7, 0.0);
              List<double> monthChartData = List.filled(4, 0.0);
              List<double> yearChartData = List.filled(12, 0.0);

              for (var doc in bookingDocs) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                final amount = (data['amount'] ?? data['depositAmount'] ?? 0.0) as num;
                final status = data['status'] ?? '';
                final Timestamp? timeStamp = data['createdAt'] as Timestamp?;
                final DateTime date = timeStamp != null ? timeStamp.toDate() : now;

                if (status == 'completed' || status == 'disburse' || status == 'confirmed') {
                  successfulTxCount++;
                  totalFlow += amount;
                  netRevenue += (amount * 0.1);

                  if (date.year == now.year) {
                    yearChartData[date.month - 1] += (amount * 0.1) / 1000000;
                  }

                  if (date.year == now.year && date.month == now.month) {
                    int weekIdx = ((date.day - 1) ~/ 7).clamp(0, 3);
                    monthChartData[weekIdx] += (amount * 0.1) / 1000000;
                  }

                  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
                  if (date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
                      date.isBefore(startOfWeek.add(const Duration(days: 7)))) {
                    int dayIdx = (date.weekday - 1).clamp(0, 6);
                    weekChartData[dayIdx] += (amount * 0.1) / 1000000;
                  }
                }
              }

              final totalUsers = userDocs.length;
              int newHostsCount = 0;
              for (var u in userDocs) {
                final uData = u.data() as Map<String, dynamic>? ?? {};
                final role = uData['role'] ?? '';
                final Timestamp? uTime = uData['createdAt'] as Timestamp?;
                if (role == 'host' || role == 'landlord') {
                  if (uTime != null && uTime.toDate().month == now.month && uTime.toDate().year == now.year) {
                    newHostsCount++;
                  }
                }
              }

              final pendingDisbursementDocs = bookingDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                return data['status'] == 'disburse';
              }).toList();

              final isYearView = _selectedTimeRange == RevenueTimeRange.year;
              final isWeekView = _selectedTimeRange == RevenueTimeRange.week;

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
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
                            badgeText: isYearView ? '+18.4% YOY' : 'Realtime',
                            badgeColor: const Color(0xFFECFDF3),
                            badgeTextColor: const Color(0xFF027A48),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKpiCard(
                            title: isYearView ? 'DOANH THU SÀN' : 'DOANH THU SÀN (THỰC NHẬN)',
                            value: _formatMoney(netRevenue),
                            valueColor: const Color(0xFF155EEF),
                            subtext: 'Hoa hồng từ cọc',
                            subtextColor: const Color(0xFF2E90FA),
                            backgroundColor: const Color.fromARGB(255, 252, 252, 253),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Hàng 2
                    Row(
                      children: [
                        Expanded(
                          child: _buildKpiCard(
                            title: 'GIAO DỊCH THÀNH CÔNG',
                            value: '$successfulTxCount Đơn',
                            valueColor: const Color(0xFFD97706),
                            subtext: 'Đã xác nhận & giải ngân',
                            subtextColor: const Color(0xFF667085),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKpiCard(
                            title: isYearView ? 'TỔNG USER TOÀN SÀN' : 'TỔNG USER HỆ THỐNG',
                            value: '$totalUsers Users',
                            valueColor: const Color(0xFF101828),
                            badgeText: '▲ +$newHostsCount chủ trọ mới',
                            badgeColor: const Color(0xFFECFDF3),
                            badgeTextColor: const Color(0xFF027A48),
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
                              duration: const Duration(milliseconds: 250),
                              child: _selectedTimeRange == RevenueTimeRange.year
                                  ? RevenueBarChart(
                                      key: const ValueKey('year_chart'),
                                      monthlyData: yearChartData,
                                    )
                                  : RevenueLineChart(
                                      key: ValueKey('line_chart_${_selectedTimeRange.name}'),
                                      labels: isWeekView
                                          ? const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
                                          : const ['Tuần 1', 'Tuần 2', 'Tuần 3', 'Tuần 4'],
                                      weeklyData: isWeekView ? weekChartData : monthChartData,
                                      activeIndex: isWeekView ? (now.weekday - 1).clamp(0, 6) : 3,
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
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFECDCA)),
                              ),
                              child: Text(
                                '${pendingDisbursementDocs.length} việc chờ',
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
                                color: Color(0xFF155EEF),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (pendingDisbursementDocs.isNotEmpty) ...[
                      for (var pendingDoc in pendingDisbursementDocs.take(3)) ...[
                        _buildDisbursementAlertItem(pendingDoc),
                        const SizedBox(height: 10),
                      ]
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
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
                                    'Hiện không có đơn cọc nào chờ giải ngân',
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

  Widget _buildDisbursementAlertItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final orderCode = data['bookingCode'] ?? data['orderCode'] ?? '#${doc.id.substring(0, doc.id.length > 6 ? 6 : doc.id.length).toUpperCase()}';
    final hostName = data['hostName'] ?? data['landlordName'] ?? 'Chủ trọ';
    final amount = (data['amount'] ?? data['depositAmount'] ?? 0.0) as num;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAECF0)),
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
                  'Giải ngân cọc $orderCode',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Chủ trọ: $hostName • Quyết toán: ${_formatMoney(amount)}',
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
            onPressed: () => _showDisbursementDialog(doc),
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
    Color borderColor = const Color(0xFFEAECF0),
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF667085),
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          if (badgeText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor ?? const Color(0xFFECFDF3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: badgeTextColor ?? const Color(0xFF027A48),
                ),
              ),
            )
          else if (subtext != null)
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
          color: isSelected ? const Color(0xFF1E60FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1E60FF).withValues(alpha: 0.25),
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
