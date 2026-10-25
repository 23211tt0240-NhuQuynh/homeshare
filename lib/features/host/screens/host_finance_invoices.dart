import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/host_management_provider.dart';
import '../utils/finance_property_utils.dart';

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
  static const _teal = Color(0xFF0D9488);
  static const _muted = Color(0xFF8296A1);
  String? _property;
  bool _newest = true;
  final Set<String> _saving = {};

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
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CƠ SỞ CHO THUÊ',
                      style: TextStyle(
                        fontSize: 10,
                        color: _muted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selected?.id ?? '',
                        isExpanded: true,
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: _muted,
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
                        onChanged: (v) =>
                            setState(() => _property = v == '' ? null : v),
                      ),
                    ),
                    if (properties.isLoading ||
                        (_property != null &&
                            (rooms.isLoading || posts.isLoading)))
                      const LinearProgressIndicator(color: _teal),
                    if (properties.hasError || rooms.hasError || posts.hasError)
                      TextButton(
                        onPressed: () {
                          ref.invalidate(hostPropertiesProvider);
                          ref.invalidate(hostRoomsProvider);
                          ref.invalidate(hostFinancePostsProvider);
                        },
                        child: const Text(
                          'Không tải được cơ sở/phòng. Thử lại',
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              if (unresolved > 0 &&
                  !rooms.isLoading &&
                  !posts.isLoading &&
                  !posts.hasError &&
                  !rooms.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '$unresolved hóa đơn chưa có liên kết cơ sở/phòng. Chọn “Tất cả cơ sở” để xem các đơn này.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9A6700),
                    ),
                  ),
                ),
              Text(
                widget.isDeposit ? 'Hóa đơn tiền cọc' : 'Hóa đơn trả hết',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF142D2B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.isDeposit
                    ? 'Quản lý cọc giữ phòng & bảo đảm'
                    : 'Quản lý tiền phòng & dịch vụ theo đơn thuê',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D9488), Color(0xFF115E59)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x220D9488),
                      blurRadius: 14,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Thực nhận dự kiến sau phí',
                      style: TextStyle(color: Color(0xFFCCFBF1), fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _money(gross - fee),
                      style: const TextStyle(
                        fontSize: 30,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      children: [
                        _summary(
                          widget.isDeposit
                              ? 'Tổng cọc khách đóng'
                              : 'Tổng khách thanh toán',
                          _money(gross),
                        ),
                        _summary('Phí hoa hồng sàn', '-${_money(fee)}'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Ước tính phí ${widget.isDeposit ? '10%' : '5%'} khi đơn chưa ghi nhận phí thực tế. ${invoices.length} hóa đơn.',
                        style: const TextStyle(
                          color: Color(0xFFCCFBF1),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'DANH SÁCH HÓA ĐƠN (${invoices.length})',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _newest = !_newest),
                    icon: const Icon(Icons.swap_vert, size: 16),
                    label: Text(
                      _newest ? 'Mới nhất' : 'Cũ nhất',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
              if (invoices.isEmpty)
                _card(
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 42,
                          color: _teal,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Chưa có hóa đơn phù hợp',
                          style: TextStyle(color: _muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ...invoices.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _invoice(b),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Chủ trọ - Hiển thị từng hóa đơn - Chi tiết mở bảng thông tin;
  // Đã nhận tiền mở hộp xác nhận khi sàn đã giải ngân.
  Widget _invoice(Map<String, dynamic> b) {
    final received = b['hostReceiptConfirmedAt'] != null;
    final disbursed = b['isDisbursed'] == true;
    final id = '${b['id']}';
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                '${b['roomTitle'] ?? b['roomCode'] ?? 'Phòng thuê'}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7F2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  received
                      ? 'Đã nhận tiền'
                      : disbursed
                      ? 'Đã giải ngân'
                      : widget.isDeposit && b['isCheckIn'] != true
                      ? 'Chờ check-in'
                      : 'Chờ giải ngân',
                  style: const TextStyle(
                    fontSize: 10,
                    color: _teal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Khách: ${b['renterName'] ?? 'Chưa cập nhật'}',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          _inset(
            Column(
              children: [
                _line('Mã hóa đơn', '${b['orderCode'] ?? id}'),
                _line('Ngày tạo', _day(b['createdAt'])),
                _line(
                  widget.isDeposit ? 'Ngày nhận phòng' : 'Kỳ thuê bắt đầu',
                  _day(b['moveInDate']),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _inset(
            Column(
              children: [
                _line(
                  widget.isDeposit ? 'Tiền cọc khách đóng' : 'Khách thanh toán',
                  _money(_gross(b)),
                ),
                _line(
                  b['platformFee'] == null ? 'Phí sàn (ước tính)' : 'Phí sàn',
                  '-${_money(_fee(b))}',
                  color: const Color(0xFFE05264),
                ),
                const Divider(height: 20),
                _line(
                  'Thực nhận dự kiến',
                  _money(_gross(b) - _fee(b)),
                  color: _teal,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _details(b),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Chi tiết', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _teal),
                  onPressed: received || !disbursed || _saving.contains(id)
                      ? null
                      : () => _confirm(b),
                  icon: Icon(received ? Icons.done_all : Icons.check, size: 16),
                  label: Text(
                    _saving.contains(id)
                        ? 'Đang lưu…'
                        : received
                        ? 'Đã nhận'
                        : 'Đã nhận tiền',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          if (!disbursed)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Có thể xác nhận nhận tiền sau khi sàn giải ngân.',
                style: TextStyle(fontSize: 10, color: _muted),
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

  // Chủ trọ - Xác nhận nhận tiền - Từ hóa đơn đã giải ngân mở hộp xác nhận;
  // chọn Đã nhận tiền lưu thời điểm nhận vào Firebase và cập nhật danh sách,
  // chọn Để sau đóng hộp thoại và trở về hóa đơn.
  Future<void> _confirm(Map<String, dynamic> b) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận đã nhận tiền'),
        content: const Text(
          'Bạn đã nhận khoản giải ngân của hóa đơn này vào tài khoản?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đã nhận tiền'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    final id = '${b['id']}';
    final uid = ref.read(hostSessionProvider).value;
    if (uid == null) return;
    setState(() => _saving.add(id));
    try {
      final db = FirebaseFirestore.instance;
      // Chủ trọ - Kiểm tra quyền sở hữu và trạng thái giải ngân trước khi
      // lưu xác nhận nhận tiền; không thay đổi trạng thái thanh toán của đơn.
      await db.runTransaction((tx) async {
        final doc = db.collection('bookings').doc(id);
        final snapshot = await tx.get(doc);
        final data = snapshot.data();
        if (data == null ||
            data['hostId'] != uid ||
            !(data['isDisbursed'] == true ||
                data['disbursedAt'] != null ||
                data['ngayGiaiNgan'] != null)) {
          throw StateError(
            'Đơn chưa được giải ngân hoặc không thuộc tài khoản này.',
          );
        }
        if (data['hostReceiptConfirmedAt'] == null) {
          tx.update(doc, {
            'hostReceiptConfirmedAt': FieldValue.serverTimestamp(),
          });
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã xác nhận nhận tiền.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa thể xác nhận. Kiểm tra quyền truy cập và thử lại.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(id));
    }
  }

  // Chủ trọ - Hiển thị thẻ cơ sở cho thuê và thẻ hóa đơn.
  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE5EFEB)),
    ),
    child: child,
  );
  // Chủ trọ - Hiển thị khung thông tin và số tiền bên trong hóa đơn.
  Widget _inset(Widget child) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F9F8),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
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
  // Chủ trọ - Hiển thị tổng tiền khách đóng và phí sàn trên thẻ tổng hợp.
  Widget _summary(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(color: Color(0xFFCCFBF1), fontSize: 11),
      ),
      const SizedBox(height: 5),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    ],
  );
}
