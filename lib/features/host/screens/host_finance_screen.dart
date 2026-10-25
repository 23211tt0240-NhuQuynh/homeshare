import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../admin/utils/booking_utils.dart';
import '../providers/host_management_provider.dart';
import 'host_finance_invoices.dart';

// Chủ trọ - Theo dõi đơn thuê của tài khoản đang đăng nhập từ Firebase.
final _financeBookingsProvider = StreamProvider<List<Map<String, dynamic>>>((
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

  // Chủ trọ - Xác định ngày ghi nhận thanh toán để thống kê theo kỳ.
  DateTime? _date(Map<String, dynamic> data) {
    final value =
        data['approvedAt'] ?? data['confirmedAt'] ?? data['createdAt'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse('$value');
  }

  // Chủ trọ - Đọc số tiền khách thanh toán theo hình thức cọc hoặc trả hết.
  double _amount(Map<String, dynamic> data) {
    final value =
        data['paymentAmount'] ??
        (data['paymentOption'] == 'full'
            ? data['totalPayable']
            : data['depositAmount']);
    return value is num
        ? value.toDouble()
        : double.tryParse('$value') ?? BookingUtils.amount(data);
  }

  // Chủ trọ - Hiển thị quản lý tiền tệ - Chọn tab để mở Thống kê,
  // danh sách hóa đơn tiền cọc hoặc danh sách hóa đơn trả hết.
  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(_financeBookingsProvider);
    final session = ref.watch(hostSessionProvider);
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
      body: session.isLoading || bookings.isLoading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : session.hasError || bookings.hasError
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Không thể tải dữ liệu tiền tệ.'),
                  TextButton(
                    onPressed: () {
                      ref.invalidate(hostSessionProvider);
                      ref.invalidate(_financeBookingsProvider);
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
                      ? _content(bookings.value ?? [])
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

  // Chủ trọ - Thống kê thanh toán theo tuần, tháng, năm;
  // tổng hợp số đơn, trạng thái giải ngân, biểu đồ và giao dịch gần đây.
  Widget _content(List<Map<String, dynamic>> all) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = _range == 0
        ? today.subtract(Duration(days: now.weekday - 1))
        : _range == 1
        ? DateTime(now.year, now.month)
        : DateTime(now.year);
    final paid =
        all
            .where(
              (b) => const [
                'approved',
                'paid',
                'active',
                'completed',
              ].contains(b['status']),
            )
            .where((b) {
              final date = _date(b);
              return date != null &&
                  !date.isBefore(start) &&
                  !date.isAfter(now);
            })
            .toList()
          ..sort((a, b) => _date(b)!.compareTo(_date(a)!));
    final total = paid.fold<double>(0, (subtotal, b) => subtotal + _amount(b));
    final disbursed = paid.where((b) => b['isDisbursed'] == true).length;
    final bins = List<double>.filled(
      _range == 0
          ? 7
          : _range == 1
          ? 5
          : 12,
      0,
    );
    for (final b in paid) {
      final date = _date(b)!;
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _kpi(
                        width,
                        'TỔNG THANH TOÁN',
                        _money(total),
                        'Đã được xác nhận trong kỳ',
                        Icons.payments_outlined,
                        _accent,
                      ),
                      _kpi(
                        width,
                        'GIAO DỊCH THÀNH CÔNG',
                        '${paid.length} đơn',
                        'Đã cọc hoặc thanh toán đủ',
                        Icons.task_alt,
                        const Color(0xFF7C3AED),
                      ),
                      _kpi(
                        width,
                        'ĐÃ GIẢI NGÂN',
                        '$disbursed đơn',
                        'Sàn đã chuyển tiền cho bạn',
                        Icons.account_balance_outlined,
                        const Color(0xFF0284C7),
                      ),
                      _kpi(
                        width,
                        'CHỜ GIẢI NGÂN',
                        '${paid.length - disbursed} đơn',
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
                    const Text(
                      'THỐNG KÊ THANH TOÁN',
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
                    const SizedBox(height: 24),
                    if (total == 0)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Chưa có thanh toán trong kỳ này.',
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      ),
                    SizedBox(
                      height: 170,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(bins.length, (i) {
                          final maximum = bins.fold<double>(
                            1,
                            (a, b) => a > b ? a : b,
                          );
                          final label = _range == 0
                              ? ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'][i]
                              : _range == 1
                              ? 'T${i + 1}'
                              : '${i + 1}';
                          return Expanded(
                            child: Tooltip(
                              message: '$label: ${_money(bins[i])}',
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      height: 4 + bins[i] / maximum * 134,
                                      decoration: BoxDecoration(
                                        color: bins[i] > 0
                                            ? _accent
                                            : const Color(0xFFE2EFEC),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      label,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Số tiền khách thanh toán • Đơn vị: đồng',
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
                      final date = _date(b)!;
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
                          '${b['roomTitle'] ?? b['orderCode'] ?? 'Đơn thuê'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${date.day}/${date.month}/${date.year} · ${b['isDisbursed'] == true ? 'Đã giải ngân' : 'Chờ giải ngân'}',
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
