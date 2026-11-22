import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/host_management_provider.dart';
import '../utils/finance_property_utils.dart';
import '../widgets/host_finance_style.dart';

// Chủ trọ - Theo dõi bài đăng của tài khoản để nối hóa đơn với phòng và cơ sở.
final hostFinancePostsProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final uid = ref.watch(hostSessionProvider).value;
  if (uid == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('posts')
      .where('hostId', isEqualTo: uid)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList(),
      );
});

// Chủ trọ - Hóa đơn tiền cọc và trả hết - Từ thanh tab quản lý tiền tệ
// mở danh sách tương ứng; chọn Chi tiết để xem thông tin hóa đơn.
class HostFinanceInvoices extends ConsumerStatefulWidget {
  const HostFinanceInvoices({
    super.key,
    required this.bookings,
    required this.isDeposit,
  });
  final List<Map<String, dynamic>> bookings;
  final bool isDeposit;

  @override
  ConsumerState<HostFinanceInvoices> createState() =>
      _HostFinanceInvoicesState();
}

class _HostFinanceInvoicesState extends ConsumerState<HostFinanceInvoices> {
  static const _teal = Color(0xFF5B55CF);
  static const _muted = Color(0xFF7C8193);
  String? _property;
  bool _newest = true;

  // Chủ trọ - Chuẩn hóa giá trị số tiền từ dữ liệu hóa đơn.
  double _number(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  // Chủ trọ - Tính tổng tiền khách thanh toán theo loại hóa đơn đang mở.
  double _gross(Map<String, dynamic> b) => _number(
    b['paymentAmount'] ??
        (widget.isDeposit ? b['depositAmount'] : b['totalPayable']),
  );
  // Chủ trọ - Tính phí sàn từ dữ liệu đã ghi nhận;
  // khi chưa có phí thực tế, ước tính 10% tiền cọc hoặc 5% tiền trả hết.
  double _fee(Map<String, dynamic> b) => b['platformFee'] != null
      ? _number(b['platformFee'])
      : _gross(b) * (widget.isDeposit ? .10 : .05);
  // Chủ trọ - Định dạng số tiền hóa đơn theo đơn vị đồng.
  String _money(num v) =>
      '${v.round().toString().replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.')} đ';
  // Chủ trọ - Chuẩn hóa ngày tháng của hóa đơn từ Firebase.
  DateTime? _date(dynamic v) => v is Timestamp
      ? v.toDate()
      : v is DateTime
      ? v
      : DateTime.tryParse('$v');
  // Chủ trọ - Xác định ngày để sắp xếp hóa đơn mới nhất hoặc cũ nhất.
  DateTime? _created(Map<String, dynamic> b) =>
      _date(b['createdAt'] ?? b['approvedAt']);
  // Chủ trọ - Hiển thị ngày hóa đơn theo định dạng ngày/tháng/năm.
  String _day(dynamic v) {
    final d = _date(v);
    return d == null
        ? 'Chưa cập nhật'
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  // Chủ trọ - Lọc hóa đơn tiền cọc hoặc trả hết theo cơ sở cho thuê,
  // sắp xếp theo ngày và tổng hợp tiền khách đóng, phí sàn, thực nhận dự kiến.
  @override
  Widget build(BuildContext context) {
    final properties = ref.watch(hostPropertiesProvider);
    final rooms = ref.watch(hostRoomsProvider);
    final posts = ref.watch(hostFinancePostsProvider);
    String? resolveProperty(Map<String, dynamic> b) =>
        financePropertyId(b, rooms.value ?? [], posts: posts.value ?? []);
    final selected = properties.value
        ?.where((p) => p.id == _property)
        .firstOrNull;
    final eligible = widget.bookings
        .where(
          (b) =>
              b['paymentOption'] == (widget.isDeposit ? 'deposit' : 'full') &&
              const [
                'approved',
                'paid',
                'active',
                'completed',
              ].contains(b['status']),
        )
        .toList();
    final unresolved = eligible.where((b) => resolveProperty(b) == null).length;
    final activeProperty = selected?.id;
    final invoices =
        eligible
            .where(
              (b) =>
                  b['paymentOption'] ==
                      (widget.isDeposit ? 'deposit' : 'full') &&
                  const [
                    'approved',
                    'paid',
                    'active',
                    'completed',
                  ].contains(b['status']) &&
                  (activeProperty == null ||
                      resolveProperty(b) == activeProperty),
            )
            .toList()
          ..sort((a, b) {
            final comparison = (_created(a) ?? DateTime(1970)).compareTo(
              _created(b) ?? DateTime(1970),
            );
            return _newest ? -comparison : comparison;
          });
    final gross = invoices.fold<double>(0, (s, b) => s + _gross(b));
    final fee = invoices.fold<double>(0, (s, b) => s + _fee(b));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HostFinanceStyle.heading(
                widget.isDeposit
                    ? 'GIỮ PHÒNG & BẢO ĐẢM'
                    : 'TIỀN PHÒNG & DỊCH VỤ',
                widget.isDeposit ? 'Sổ tiền cọc' : 'Hóa đơn trả hết',
                trailing: '${invoices.length} hóa đơn',
              ),
              // Chủ trọ - Chọn cơ sở - Lọc danh sách và tổng tiền theo phòng thuộc cơ sở đã chọn.
              _card(
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EFFB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.apartment_outlined,
                        color: _teal,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CƠ SỞ CHO THUÊ',
                            style: TextStyle(
                              fontSize: 9,
                              color: _muted,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selected?.id ?? '',
                              isDense: true,
                              isExpanded: true,
                              padding: const EdgeInsets.only(top: 6),
                              borderRadius: BorderRadius.circular(18),
                              style: TextStyle(
                                fontFamily: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.fontFamily,
                                color: HostFinanceStyle.ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('Tất cả cơ sở'),
                                ),
                                ...?properties.value?.map(
                                  (p) => DropdownMenuItem(
                                    value: p.id,
                                    child: Text(
                                      p.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) => setState(
                                () => _property = v == '' ? null : v,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (properties.isLoading ||
                  (_property != null && (rooms.isLoading || posts.isLoading)))
                const LinearProgressIndicator(color: _teal),
              if (properties.hasError || rooms.hasError || posts.hasError)
                TextButton(
                  onPressed: () {
                    ref.invalidate(hostPropertiesProvider);
                    ref.invalidate(hostRoomsProvider);
                    ref.invalidate(hostFinancePostsProvider);
                  },
                  child: const Text('Không tải được cơ sở/phòng. Thử lại'),
                ),
              if (unresolved > 0 &&
                  !rooms.isLoading &&
                  !posts.isLoading &&
                  !posts.hasError &&
                  !rooms.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '$unresolved hóa đơn chưa có liên kết cơ sở/phòng. Chọn “Tất cả cơ sở” để xem các đơn này.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9A6700),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              HostFinanceWallet(
                deposit: widget.isDeposit,
                label: 'Thực nhận dự kiến sau phí hoa hồng',
                amount: _money(gross - fee),
                footer: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isDeposit
                                ? 'Tổng cọc khách đóng'
                                : 'Tổng đơn trả hết',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFFCFD0DF),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _money(gross),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.receipt_long_outlined,
                      color: Colors.white38,
                      size: 28,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Danh sách hóa đơn',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: HostFinanceStyle.ink,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: _teal),
                    onPressed: () => setState(() => _newest = !_newest),
                    icon: const Icon(Icons.swap_vert, size: 16),
                    label: Text(
                      _newest ? 'Mới nhất' : 'Cũ nhất',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (invoices.isEmpty)
                _card(
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 26),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 40,
                          color: _muted,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Chưa có hóa đơn phù hợp',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ...invoices.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _invoice(b),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Chủ trọ - Phiếu hóa đơn - Chi tiết mở thông tin; trạng thái giải ngân
  // do admin cập nhật, không còn nút xác nhận nhận tiền trên thẻ.
  Widget _invoice(Map<String, dynamic> b) {
    final disbursed = b['isDisbursed'] == true;
    final tone = widget.isDeposit ? const Color(0xFFA7743F) : _teal;
    final wash = widget.isDeposit
        ? const Color(0xFFFBF1E6)
        : const Color(0xFFF0EFFB);
    final status = disbursed
        ? 'Đã giải ngân'
        : widget.isDeposit && b['isCheckIn'] != true
        ? 'Chờ check-in'
        : 'Đã nhận tiền';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEBECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            color: wash,
            child: Row(
              children: [
                Icon(
                  widget.isDeposit
                      ? Icons.shield_outlined
                      : Icons.receipt_outlined,
                  size: 16,
                  color: tone,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.isDeposit ? 'PHIẾU TIỀN CỌC' : 'PHIẾU THANH TOÁN',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w800,
                      color: tone,
                    ),
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    color: tone,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${b['roomTitle'] ?? b['roomCode'] ?? 'Phòng thuê'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: HostFinanceStyle.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Khách: ${b['renterName'] ?? 'Chưa cập nhật'}',
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
                const SizedBox(height: 16),
                _line('Mã hóa đơn', '${b['orderCode'] ?? b['id']}'),
                _line('Ngày tạo', _day(b['createdAt'])),
                _line(
                  widget.isDeposit ? 'Ngày nhận phòng' : 'Kỳ thuê bắt đầu',
                  _day(b['moveInDate']),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Color(0xFFEBECF3)),
                ),
                _line(
                  widget.isDeposit ? 'Tiền cọc khách đóng' : 'Khách thanh toán',
                  _money(_gross(b)),
                ),
                _line(
                  b['platformFee'] == null ? 'Phí sàn (ước tính)' : 'Phí sàn',
                  '-${_money(_fee(b))}',
                  color: const Color(0xFFC27972),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: wash,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thực nhận dự kiến',
                        style: TextStyle(color: tone, fontSize: 10),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _money(_gross(b) - _fee(b)),
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: tone,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HostFinanceStyle.ink,
                    side: const BorderSide(color: Color(0xFFE1E2EC)),
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _details(b),
                  child: const Text(
                    'Chi tiết',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                if (!disbursed)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Chờ sàn giải ngân. Khi admin chuyển tiền, bạn sẽ nhận thông báo trong tab Đã thanh toán.',
                      style: TextStyle(fontSize: 10, color: _muted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Chủ trọ - Xem chi tiết hóa đơn - Từ nút Chi tiết mở bảng thông tin;
  // nút Đóng trở về danh sách hóa đơn đang xem.
  void _details(Map<String, dynamic> b) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Chi tiết hóa đơn',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _line('Mã đơn', '${b['orderCode'] ?? b['id']}'),
            _line('Phòng', '${b['roomTitle'] ?? 'Chưa cập nhật'}'),
            _line('Khách thuê', '${b['renterName'] ?? 'Chưa cập nhật'}'),
            _line('Ngày tạo', _day(b['createdAt'])),
            _line('Ngày giải ngân', _day(b['disbursedAt'])),
            _line('Khách thanh toán', _money(_gross(b))),
            _line(
              b['platformFee'] == null ? 'Phí sàn (ước tính)' : 'Phí sàn',
              _money(_fee(b)),
            ),
            _line(
              'Thực nhận dự kiến',
              _money(_gross(b) - _fee(b)),
              color: _teal,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    ),
  );

  // Chủ trọ - Hiển thị thẻ cơ sở cho thuê và trạng thái danh sách hóa đơn.
  Widget _card(Widget child) =>
      HostFinanceStyle.surface(child, padding: const EdgeInsets.all(16));

  // Chủ trọ - Hiển thị nhãn và giá trị chi tiết hóa đơn.
  Widget _line(String label, String value, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: _muted),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color ?? const Color(0xFF263D3B),
            ),
          ),
        ),
      ],
    ),
  );
}
