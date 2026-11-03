import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../admin/utils/booking_utils.dart';
import '../../admin/widgets/revenue_line_chart.dart';
import '../providers/host_management_provider.dart';
import 'host_finance_invoices.dart';

// Chủ trọ - Theo dõi đơn thuê của tài khoản đang đăng nhập từ Firebase.
final hostFinanceBookingsProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final uid = ref.watch(hostSessionProvider).value;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('bookings')
      .where('hostId', isEqualTo: uid)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => BookingUtils.canonical({...doc.data(), 'id': doc.id}))
            .toList(),
      );
});

// Chủ trọ - Theo dõi tiền thực nhận - Admin giải ngân tạo bản ghi trong disbursements.
final hostFinanceDisbursementsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
      final uid = ref.watch(hostSessionProvider).value;
      if (uid == null) return Stream.value([]);
      return FirebaseFirestore.instance
          .collection('disbursements')
          .where('hostId', isEqualTo: uid)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => {...doc.data(), 'id': doc.id})
                .toList(),
          );
    });

// Chủ trọ - Quản lý tiền tệ - Từ tab QL Tiền tệ mở Thống kê;
// chuyển sang HĐ Tiền cọc hoặc HĐ Trả hết bằng thanh tab phía trên.
class HostFinanceScreen extends ConsumerStatefulWidget {
  const HostFinanceScreen({super.key});

  @override
  ConsumerState<HostFinanceScreen> createState() => _HostFinanceScreenState();
}

class _HostFinanceScreenState extends ConsumerState<HostFinanceScreen> {
  static const _accent = Color(0xFF0D9488);
  static const _ink = Color(0xFF134E4A);
  int _range = 2;
  int _tab = 0;

  // Chủ trọ - Định dạng số tiền theo đơn vị đồng.
  String _money(num value) =>
      '${value.toStringAsFixed(0).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.')} đ';

  // Chủ trọ - Xác định ngày xác nhận thanh toán để lọc đơn chờ giải ngân theo kỳ.
  DateTime? _date(Map<String, dynamic> data) {
    final value =
        data['approvedAt'] ?? data['confirmedAt'] ?? data['createdAt'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse('$value');
  }

  // Chủ trọ - Đọc tiền thực nhận sau phí từ phiếu giải ngân của admin.
  double _amount(Map<String, dynamic> data) {
    final value = data['totalAmount'];
    return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  }

  // Chủ trọ - Xác định ngày admin giải ngân từ createdAt của phiếu disbursements.
  DateTime? _settledDate(Map<String, dynamic> data) {
    final value = data['createdAt'];
    return value is Timestamp
        ? value.toDate()
        : value is DateTime
        ? value
        : DateTime.tryParse('$value');
  }

  // Chủ trọ - Hiển thị quản lý tiền tệ - Chọn tab để mở Thống kê,
  // danh sách hóa đơn tiền cọc hoặc danh sách hóa đơn trả hết.
  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(hostFinanceBookingsProvider);
    final session = ref.watch(hostSessionProvider);
    final settlements = ref.watch(hostFinanceDisbursementsProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F8F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        toolbarHeight: 76,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quản lý tiền tệ',
              style: TextStyle(
                color: _ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Theo dõi dòng tiền từ các đơn thuê',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: CircleAvatar(
              backgroundColor: Color(0xFFCCFBF1),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                color: _accent,
              ),
            ),
          ),
        ],
      ),
      body:
          session.isLoading ||
              bookings.isLoading ||
              (_tab == 0 && settlements.isLoading)
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : session.hasError ||
                bookings.hasError ||
                (_tab == 0 && settlements.hasError)
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Không thể tải dữ liệu tiền tệ.'),
                  TextButton(
                    onPressed: () {
                      ref.invalidate(hostSessionProvider);
                      ref.invalidate(hostFinanceBookingsProvider);
                      ref.invalidate(hostFinanceDisbursementsProvider);
                    },
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          : session.value == null
          ? const Center(child: Text('Đăng nhập để xem dữ liệu tiền tệ.'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3EFEC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: List.generate(3, (i) {
                        final count = (bookings.value ?? [])
                            .where(
                              (b) =>
                                  const [
                                    'approved',
                                    'paid',
                                    'active',
                                    'completed',
                                  ].contains(b['status']) &&
                                  b['paymentOption'] ==
                                      (i == 1 ? 'deposit' : 'full'),
                            )
                            .length;
                        return Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => _tab = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _tab == i
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                i == 0
                                    ? 'Thống kê'
                                    : '${i == 1 ? 'HĐ Tiền cọc' : 'HĐ Trả hết'} ($count)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _tab == i ? _accent : Colors.blueGrey,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                Expanded(
                  child: _tab == 0
                      ? _content(bookings.value ?? [], settlements.value ?? [])
                      : HostFinanceInvoices(
                          key: ValueKey(_tab),
                          bookings: bookings.value ?? [],
                          isDeposit: _tab == 1,
                        ),
                ),
              ],
            ),
    );
  }

  // Chủ trọ - Thống kê thực nhận theo tuần, tháng, năm từ disbursements.totalAmount;
  // tổng hợp đơn thành công, đơn chờ giải ngân, biểu đồ và phiếu giải ngân gần đây.
  Widget _content(
    List<Map<String, dynamic>> all,
    List<Map<String, dynamic>> settlements,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = _range == 0
        ? today.subtract(Duration(days: now.weekday - 1))
        : _range == 1
        ? DateTime(now.year, now.month)
        : DateTime(now.year);
    bool inPeriod(DateTime? date) =>
        date != null && !date.isBefore(start) && !date.isAfter(now);
    // Chủ trọ - Tổng tiền và biểu đồ chỉ ghi nhận phiếu admin đã giải ngân trong kỳ.
    final paid = settlements.where((s) => inPeriod(_settledDate(s))).toList()
      ..sort((a, b) => _settledDate(b)!.compareTo(_settledDate(a)!));
    final total = paid.fold<double>(0, (subtotal, s) => subtotal + _amount(s));
    final settledIds = settlements
        .expand((s) => (s['bookingIds'] as List?) ?? const [])
        .map((id) => id.toString())
        .toSet();
    final successfulIds = paid
        .expand((s) => (s['bookingIds'] as List?) ?? const [])
        .map((id) => id.toString())
        .toSet();
    // Chủ trọ - Đếm đơn thành công từ bookingIds của phiếu đã giải ngân trong kỳ,
    // loại mã đơn trùng; phiếu thiếu danh sách mã đơn dùng itemCount.
    final successfulCount =
        successfulIds.length +
        paid
            .where((s) => ((s['bookingIds'] as List?) ?? const []).isEmpty)
            .fold<int>(
              0,
              (subtotal, s) =>
                  subtotal + ((s['itemCount'] as num?)?.toInt() ?? 0),
            );
    // Chủ trọ - Đếm đơn đã xác nhận thanh toán trong kỳ nhưng chưa được admin giải ngân.
    final pendingCount = all
        .where(
          (b) =>
              const [
                'approved',
                'paid',
                'active',
                'completed',
              ].contains(b['status']) &&
              b['isDisbursed'] != true &&
              !settledIds.contains(b['id']) &&
              inPeriod(_date(b)),
        )
        .length;
    final bins = List<double>.filled(
      _range == 0
          ? 7
          : _range == 1
          ? 5
          : 12,
      0,
    );
    for (final b in paid) {
      final date = _settledDate(b)!;
      final index = _range == 0
          ? date.weekday - 1
          : _range == 1
          ? (date.day - 1) ~/ 7
          : date.month - 1;
      bins[index] += _amount(b);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _kpi(
                        width,
                        'TỔNG THỰC NHẬN',
                        _money(total),
                        'Tiền admin đã giải ngân trong kỳ',
                        Icons.payments_outlined,
                        _accent,
                      ),
                      _kpi(
                        width,
                        'GIAO DỊCH THÀNH CÔNG',
                        '$successfulCount đơn',
                        'Đơn đã được admin giải ngân',
                        Icons.task_alt,
                        const Color(0xFF7C3AED),
                      ),
                      _kpi(
                        width,
                        'CHỜ GIẢI NGÂN',
                        '$pendingCount đơn',
                        'Đơn xác nhận chưa giải ngân',
                        Icons.schedule,
                        const Color(0xFFD97706),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              _panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chủ trọ - Chọn kỳ thống kê - Đổi tuần/tháng/năm để cập nhật biểu đồ và số liệu.
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      children: List.generate(
                        3,
                        (i) => ChoiceChip(
                          label: Text(['Tuần', 'Tháng', 'Năm'][i]),
                          selected: _range == i,
                          selectedColor: const Color(0xFF0F766E),
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: _range == i ? Colors.white : _ink,
                            fontWeight: FontWeight.w700,
                          ),
                          side: BorderSide(
                            color: _range == i
                                ? const Color(0xFF0F766E)
                                : const Color(0xFFCBD5E1),
                          ),
                          checkmarkColor: Colors.white,
                          onSelected: (_) => setState(() => _range = i),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'THỐNG KÊ THỰC NHẬN',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _range == 0
                          ? 'Tuần này'
                          : _range == 1
                          ? 'Tháng ${now.month}/${now.year}'
                          : 'Năm ${now.year}',
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Chủ trọ - Biểu đồ tiền thực nhận theo ngày admin giải ngân.
                    RevenueLineChart(
                      weeklyData: bins,
                      labels: List.generate(
                        bins.length,
                        (i) => _range == 0
                            ? ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][i]
                            : _range == 1
                            ? 'Tuần ${i + 1}'
                            : '${i + 1}',
                      ),
                      activeIndex: _range == 0
                          ? now.weekday - 1
                          : _range == 1
                          ? (now.day - 1) ~/ 7
                          : now.month - 1,
                      color: _accent,
                      emptyText: 'Chưa có giải ngân trong kỳ này',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tiền thực nhận sau phí • Đơn vị: đồng',
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _panel(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GIAO DỊCH GẦN ĐÂY',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (paid.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'Chưa có giao dịch trong kỳ này.',
                            style: TextStyle(color: Colors.blueGrey),
                          ),
                        ),
                      ),
                    ...paid.take(10).map((b) {
                      final date = _settledDate(b)!;
                      // Chủ trọ - Hiển thị tên bài viết từ đơn thuê của phiếu giải ngân;
                      // phiếu gộp nhiều bài hiển thị các tên, không lặp tên trùng.
                      final bookingIds =
                          ((b['bookingIds'] as List?) ?? const [])
                              .map((id) => id.toString())
                              .toSet();
                      final titles = all
                          .where(
                            (booking) => bookingIds.contains(booking['id']),
                          )
                          .map(
                            (booking) =>
                                (booking['roomTitle'] ?? '').toString().trim(),
                          )
                          .where((title) => title.isNotEmpty)
                          .toSet();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFCCFBF1),
                          child: Icon(
                            Icons.south_west,
                            color: _accent,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          titles.isEmpty
                              ? 'Bài viết không còn thông tin'
                              : titles.join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${date.day}/${date.month}/${date.year} · Admin đã giải ngân',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Text(
                          _money(_amount(b)),
                          style: const TextStyle(
                            color: _accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Chủ trọ - Hiển thị khung nội dung thống kê.
  Widget _panel(Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFDCEBE7)),
    ),
    child: child,
  );

  // Chủ trọ - Hiển thị thẻ chỉ số thanh toán và giải ngân.
  Widget _kpi(
    double width,
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) => SizedBox(
    width: width,
    child: _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
          ),
        ],
      ),
    ),
  );
}
