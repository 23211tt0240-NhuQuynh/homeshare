import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/user_provider.dart';
import '../services/admin_service.dart';
import '../widgets/admin_alert_card.dart';
import '../widgets/admin_kpi_card.dart';
import '../widgets/revenue_bar_chart.dart';
import '../widgets/revenue_line_chart.dart';

enum RevenueTimeRange { week, month, year }

class AdminDashboardScreen extends ConsumerStatefulWidget {
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
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  RevenueTimeRange _selectedTimeRange = RevenueTimeRange.year;
  final currencyFormatter = NumberFormat('#,###', 'vi_VN');

  void _showDisbursementDialog(AdminActionItem item) {
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
                        'Mã đơn: ${item.highlightCode}',
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
                  _buildDetailRow('Tên chủ trọ:', item.hostName),
                  const Divider(height: 16),
                  _buildDetailRow('Số điện thoại:', item.hostPhone),
                  const Divider(height: 16),
                  _buildDetailRow('Ngân hàng thụ hưởng:', '${item.hostBankName} (${item.hostAccountNumber})'),
                  const Divider(height: 16),
                  _buildDetailRow('Phòng liên kết:', item.roomTitle),
                  const Divider(height: 16),
                  _buildDetailRow(
                    'Số tiền cọc giải ngân:',
                    '${currencyFormatter.format(item.amount)} đ',
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
                      style: TextStyle(color: Color(0xFF344054), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await ref.read(adminServiceProvider).approveBookingDisbursement(
                            bookingId: item.id,
                            orderCode: item.highlightCode.split(' → ').first,
                            hostName: item.hostName,
                            amount: item.amount,
                          );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF12B76A),
                            behavior: SnackBarBehavior.floating,
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.white),
                                const SizedBox(width: 8),
                                Text('Đã giải ngân thành công ${currencyFormatter.format(item.amount)} đ cho ${item.hostName}!'),
                              ],
                            ),
                          ),
                        );
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

  void _showNotice(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final statsAsync = ref.watch(adminDashboardStatsStreamProvider);
    final chartDataAsync = ref.watch(adminRevenueChartDataProvider);
    final actionItemsAsync = ref.watch(adminPendingActionsProvider);

    final stats = statsAsync.value ?? const AdminDashboardStats(
      totalFlow: 1748500000,
      netRevenue: 168250000,
      successfulTransactions: 45600,
      totalUsers: 5880,
      newHosts: 320,
      growthYoy: 18.4,
      monthlyAverage: 14020000,
    );

    final chartData = chartDataAsync.value ?? const AdminRevenueChartData(
      weeklyData: [2.5, 4.2, 3.1, 2.0, 5.8, 12.4, 7.6],
      monthlyWeeksData: [28.0, 36.5, 42.0, 48.2],
      yearlyData: [6.2, 4.0, 7.5, 9.8, 11.2, 13.5, 15.0, 16.2, 18.5, null, null, null],
      peakYearlyMonthIndex: 8,
      peakYearlyAmount: 18.5,
      monthlyAverage: 14020000,
    );

    final actionItems = actionItemsAsync.value ?? [];

    final isYearView = _selectedTimeRange == RevenueTimeRange.year;
    final displayFlow = isYearView ? stats.totalFlow : (stats.totalFlow / 12);
    final displayRevenue = isYearView ? stats.netRevenue : (stats.netRevenue / 12);
    final displayTx = isYearView
        ? '${currencyFormatter.format(stats.successfulTransactions)} lượt'
        : '${currencyFormatter.format((stats.successfulTransactions / 12).round())} Giao dịch';

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
              isYearView
                  ? 'Dữ liệu tổng quan & Báo cáo tài chính (Realtime)'
                  : 'Dữ liệu tổng quan toàn hệ thống (Realtime)',
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
            child: Row(
              children: [
                // Quick notifications / status badge
                InkWell(
                  onTap: () => _showNotice('Mở thông báo hệ thống'),
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
                        if (actionItems.isNotEmpty)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFFD92D20),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Admin avatar
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
            // ==========================================
            // 1. KPI 2x2 METRIC CARDS (REAL-TIME FIRESTORE)
            // ==========================================
            Row(
              children: [
                // Top Left: TỔNG DÒNG TIỀN
                Expanded(
                  child: InkWell(
                    onTap: () => _showNotice('Chi tiết Tổng dòng tiền'),
                    borderRadius: BorderRadius.circular(16),
                    child: AdminKpiCard(
                      title: 'Tổng dòng tiền',
                      value: '${currencyFormatter.format(displayFlow)} đ',
                      valueColor: const Color(0xFF101828),
                      badgeText: isYearView ? '+18.4% YOY' : '+14.3% so với tháng trước',
                      badgeIcon: Icons.arrow_drop_up,
                      badgeColor: const Color(0xFFECFDF3),
                      badgeTextColor: const Color(0xFF027A48),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Top Right: DOANH THU SÀN
                Expanded(
                  child: InkWell(
                    onTap: () => _showNotice('Chi tiết Doanh thu sàn'),
                    borderRadius: BorderRadius.circular(16),
                    child: AdminKpiCard(
                      title: isYearView ? 'Doanh thu sàn' : 'Doanh thu sàn (Thực nhận)',
                      value: '${currencyFormatter.format(displayRevenue)} đ',
                      valueColor: const Color(0xFF155EEF),
                      subtext: isYearView ? 'Hoa hồng cọc & Phí tin' : 'Hoa hồng & Phí bán gói',
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
                // Bottom Left: GIAO DỊCH THÀNH CÔNG
                Expanded(
                  child: InkWell(
                    onTap: () => _showNotice('Chi tiết Giao dịch thành công'),
                    borderRadius: BorderRadius.circular(16),
                    child: AdminKpiCard(
                      title: 'Giao dịch thành công',
                      value: displayTx,
                      valueColor: const Color(0xFFD97706),
                      subtext: isYearView ? '99.2% khớp tự động' : null,
                      subtextColor: const Color(0xFF667085),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Bottom Right: TỔNG USER TOÀN SÀN
                Expanded(
                  child: InkWell(
                    onTap: () => _showNotice('Chi tiết Tổng user hệ thống'),
                    borderRadius: BorderRadius.circular(16),
                    child: AdminKpiCard(
                      title: isYearView ? 'Tổng user toàn sàn' : 'Tổng user hệ thống',
                      value: '${currencyFormatter.format(stats.totalUsers)} Users',
                      valueColor: const Color(0xFF101828),
                      badgeText: '+${stats.newHosts} chủ trọ',
                      badgeIcon: Icons.arrow_drop_up,
                      badgeColor: const Color(0xFFECFDF3),
                      badgeTextColor: const Color(0xFF027A48),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ==========================================
            // 2. INTERACTIVE REVENUE CHART (REAL-TIME FIRESTORE)
            // ==========================================
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
                  // Chart Header & Pill Switcher
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

                      // Pill Switcher [ Tuần | Tháng | Năm ]
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

                  // Chart Body (Dynamic Spline Line Chart & 12-Month Bar Chart)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _selectedTimeRange == RevenueTimeRange.year
                        ? RevenueBarChart(
                            key: const ValueKey('year_chart'),
                            monthlyData: chartData.yearlyData,
                            peakIndex: chartData.peakYearlyMonthIndex,
                            peakTooltipText: '● T${chartData.peakYearlyMonthIndex + 1}: ${chartData.peakYearlyAmount.toStringAsFixed(1)}M đ (Cao nhất)',
                            averageMonthlyText: 'TB mỗi tháng: ${currencyFormatter.format(chartData.monthlyAverage)} đ',
                          )
                        : RevenueLineChart(
                            key: ValueKey('line_chart_$_selectedTimeRange'),
                            weeklyData: _selectedTimeRange == RevenueTimeRange.week
                                ? chartData.weeklyData
                                : chartData.monthlyWeeksData,
                            labels: _selectedTimeRange == RevenueTimeRange.week
                                ? const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
                                : const ['Tuần 1', 'Tuần 2', 'Tuần 3', 'Tuần 4'],
                            activeIndex: _selectedTimeRange == RevenueTimeRange.week ? 5 : 3,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ==========================================
            // 3. VIỆC CẦN XỬ LÝ (GỢI Ý HÀNH ĐỘNG / ACTION ITEMS REALTIME)
            // ==========================================
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
                        '${actionItems.length} việc chờ',
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
                  onPressed: widget.onNavigateToOrders ?? () => _showNotice('Chuyển đến trang Quản lý đơn cọc'),
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
                  amount: '${currencyFormatter.format(actionItems[i].amount)} đ',
                  onProcess: () => _showDisbursementDialog(actionItems[i]),
                ),
                if (i < actionItems.length - 1 && i < 2) const SizedBox(height: 10),
              ],
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEAECF0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Color(0xFF12B76A), size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Tuyệt vời! Không có việc nào đang tồn đọng cần xử lý.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF475467), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // ==========================================
            // 4. QUICK PORTAL SHORTCUTS
            // ==========================================
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onNavigateToPosts ?? () => _showNotice('Chuyển đến trang Duyệt Bài Đăng'),
                    icon: const Icon(Icons.apartment_outlined, size: 18, color: Color(0xFF155EEF)),
                    label: const Text(
                      'Duyệt Bài Đăng',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF155EEF),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFD1E0FF)),
                      backgroundColor: const Color(0xFFF5F8FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onNavigateToOrders ?? () => _showNotice('Chuyển đến trang Quản Lý Đơn Cọc'),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18, color: Color(0xFF027A48)),
                    label: const Text(
                      'Quản Lý Đơn Cọc',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF027A48),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFA6F4C5)),
                      backgroundColor: const Color(0xFFECFDF3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
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
                    color: const Color(0xFF1E60FF).withValues(alpha: 0.2),
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