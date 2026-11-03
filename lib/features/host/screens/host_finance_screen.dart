import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../admin/utils/booking_utils.dart';
import '../widgets/host_finance_style.dart';
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
  static const _accent = Color(0xFF5B55CF);
  static const _ink = Color(0xFF202737);
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
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        backgroundColor: HostFinanceStyle.canvas,
        surfaceTintColor: HostFinanceStyle.canvas,
        toolbarHeight: 90,
        titleSpacing: 22,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'KHÔNG GIAN CHỦ TRỌ',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 2,
                color: HostFinanceStyle.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'Tài chính của bạn',
              style: TextStyle(
                fontSize: 25,
                color: _ink,
                fontWeight: FontWeight.w800,
                letterSpacing: -.6,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 22),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECEBFC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.wallet_outlined,
                color: _accent,
                size: 24,
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
                // Chủ trọ - Chuyển màn tài chính - Chọn Thống kê, Tiền cọc hoặc Trả hết.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: List.generate(3, (i) {
                      final selected = _tab == i;
                      return Expanded(
                        child: Semantics(
                          selected: selected,
                          button: true,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setState(() => _tab = i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: selected
                                        ? _accent
                                        : const Color(0xFFE5E5EF),
                                    width: selected ? 3 : 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    [
                                      Icons.insights_outlined,
                                      Icons.shield_outlined,
                                      Icons.receipt_long_outlined,
                                    ][i],
                                    size: 17,
                                    color: selected
                                        ? _accent
                                        : HostFinanceStyle.muted,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      ['Thống kê', 'Tiền cọc', 'Trả hết'][i],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: selected
                                            ? _accent
                                            : HostFinanceStyle.muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
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
    final period = _range == 0
        ? 'Tuần này'
        : _range == 1
        ? 'Tháng ${now.month}/${now.year}'
        : 'Năm ${now.year}';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HostFinanceStyle.heading(
                'TỔNG QUAN',
                'Dòng tiền của bạn',
                trailing: period,
              ),
              HostFinanceWallet(
                label: 'TỔNG THỰC NHẬN',
                amount: _money(total),
                footer: const Row(
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      size: 15,
                      color: HostFinanceStyle.lime,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tiền admin đã giải ngân trong kỳ',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFCFD0DF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _metric(
                      'Giao dịch thành công',
                      '$successfulCount đơn',
                      Icons.check_circle_outline,
                      const Color(0xFF5B55CF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _metric(
                      'Chờ giải ngân',
                      '$pendingCount đơn',
                      Icons.timelapse_outlined,
                      const Color(0xFFB47D32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              HostFinanceStyle.surface(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HostFinanceStyle.heading('PHÂN TÍCH', 'Nhịp dòng tiền'),
                    // Chủ trọ - Chọn kỳ thống kê - Cập nhật số liệu và biểu đồ theo tuần, tháng hoặc năm.
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: HostFinanceStyle.canvas,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: List.generate(
                          3,
                          (i) => Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(9),
                              onTap: () => setState(() => _range = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: _range == i
                                      ? _accent
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  ['Tuần', 'Tháng', 'Năm'][i],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _range == i
                                        ? Colors.white
                                        : HostFinanceStyle.muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Chủ trọ - Biểu đồ cột thực nhận - Chạm từng cột để xem số tiền admin giải ngân.
                    HostCashflowChart(
                      values: bins,
                      labels: List.generate(
                        bins.length,
                        (i) => _range == 0
                            ? ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][i]
                            : _range == 1
                            ? 'Tuần ${i + 1}'
                            : '${i + 1}',
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Thực nhận sau phí hoa hồng · Đơn vị: Việt Nam đồng',
                      style: TextStyle(
                        color: HostFinanceStyle.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              HostFinanceStyle.heading(
                'LỊCH SỬ',
                'Giao dịch gần đây',
                trailing: '${paid.length} phiếu',
              ),
              if (paid.isEmpty)
                HostFinanceStyle.surface(
                  const Column(
                    children: [
                      Icon(
                        Icons.swap_horiz_rounded,
                        size: 36,
                        color: HostFinanceStyle.muted,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Chưa có giao dịch trong kỳ này.',
                        style: TextStyle(
                          color: HostFinanceStyle.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ...paid.take(10).map((b) {
                final date = _settledDate(b)!;
                // Chủ trọ - Lấy tên bài viết qua các đơn thuê thuộc phiếu giải ngân.
                final ids = ((b['bookingIds'] as List?) ?? const [])
                    .map((id) => id.toString())
                    .toSet();
                final titles = all
                    .where((booking) => ids.contains(booking['id']))
                    .map(
                      (booking) =>
                          (booking['roomTitle'] ?? '').toString().trim(),
                    )
                    .where((title) => title.isNotEmpty)
                    .toSet();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: HostFinanceStyle.surface(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF4E7),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: const Icon(
                                Icons.south_west,
                                color: Color(0xFF668244),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                titles.isEmpty
                                    ? 'Bài viết không còn thông tin'
                                    : titles.join(', '),
                                style: const TextStyle(
                                  color: _ink,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            Text(
                              '${date.day}/${date.month}/${date.year} · Admin đã giải ngân',
                              style: const TextStyle(
                                fontSize: 10,
                                color: HostFinanceStyle.muted,
                              ),
                            ),
                            Text(
                              _money(_amount(b)),
                              style: const TextStyle(
                                fontSize: 16,
                                color: _ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // Chủ trọ - Hiển thị số đơn thành công và chờ giải ngân bên dưới thẻ ví.
  Widget _metric(String label, String value, IconData icon, Color color) =>
      HostFinanceStyle.surface(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: HostFinanceStyle.muted,
              ),
            ),
          ],
        ),
        padding: const EdgeInsets.all(17),
      );
}
