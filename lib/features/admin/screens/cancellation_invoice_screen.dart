import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/admin_page_backdrop.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/utils/vietqr_helper.dart';
import '../utils/booking_utils.dart';
import '../widgets/admin_branded_title.dart';
import 'cancellation_receipt_screen.dart';

class CancellationInvoiceScreen extends StatefulWidget {
  final List<String> bookingIds;

  const CancellationInvoiceScreen({super.key, required this.bookingIds});

  @override
  State<CancellationInvoiceScreen> createState() =>
      _CancellationInvoiceScreenState();
}

class _CancellationInvoiceScreenState extends State<CancellationInvoiceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final currencyFormatter = NumberFormat('#,###', 'vi_VN');
  bool _isProcessing = false;

  List<Map<String, dynamic>> _bookingDataList = [];
  Map<String, dynamic>? _hostProfile;
  Map<String, dynamic>? _renterProfile;
  bool _isLoading = true;

  static const Map<String, String> _bankBins = {
    'MB': '970422',
    'VCB': '970436',
    'TCB': '970407',
    'ACB': '970416',
    'BIDV': '970418',
    'ICB': '970415',
    'VPB': '970432',
    'TPB': '970423',
    'STB': '970403',
    'VBA': '970405',
    'SHB': '970443',
    'VIB': '970441',
    'HDB': '970437',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final db = FirebaseFirestore.instance;
      final List<Map<String, dynamic>> loaded = [];

      for (final id in widget.bookingIds) {
        final doc = await db.collection('bookings').doc(id).get();
        if (doc.exists) {
          final data = BookingUtils.canonical(doc.data() ?? {});
          data['id'] = doc.id;
          loaded.add(data);
        }
      }

      if (loaded.isNotEmpty) {
        final first = loaded.first;
        final hostId = (first['hostId'] ?? '').toString();
        final renterId = (first['renterId'] ?? '').toString();

        if (hostId.isNotEmpty) {
          final hDoc = await db.collection('users').doc(hostId).get();
          if (hDoc.exists) _hostProfile = hDoc.data();
        }
        if (renterId.isNotEmpty && renterId != 'guest') {
          final rDoc = await db.collection('users').doc(renterId).get();
          if (rDoc.exists) _renterProfile = rDoc.data();
        }
      }

      _bookingDataList = loaded;
    } catch (e) {
      debugPrint('Load cancellation data error: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  String _pick(List<Map<String, dynamic>?> sources, List<String> keys) {
    for (final src in sources) {
      if (src == null) continue;
      for (final k in keys) {
        final v = src[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
    }
    return '';
  }

  static const Map<String, List<String>> _bankAliases = {
    'MB': ['mb', 'mbb'],
    'VCB': ['vcb', 'vietcombank'],
    'TCB': ['tcb', 'techcombank'],
    'ACB': ['acb'],
    'BIDV': ['bidv'],
    'ICB': ['icb', 'ctg', 'vietinbank'],
    'VPB': ['vpb', 'vpbank'],
    'TPB': ['tpb', 'tpbank'],
    'STB': ['stb', 'sacombank'],
    'VBA': ['vba', 'agribank'],
    'SHB': ['shb'],
    'VIB': ['vib'],
    'HDB': ['hdb', 'hdbank'],
  };

  String? _findBankCode(String input) {
    final s = input.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (s.isEmpty) return null;
    for (final entry in _bankAliases.entries) {
      if (entry.key.toLowerCase() == s) return entry.key;
      for (final alias in entry.value) {
        if (s == alias || s.contains(alias)) return entry.key;
      }
    }
    return null;
  }

  String _transferMemo(String prefix, String reference) {
    final cleanReference = reference
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final memo =
        '$prefix ${cleanReference.isEmpty ? 'DON HUY' : cleanReference}';
    return memo.length > 25 ? memo.substring(0, 25).trimRight() : memo;
  }

  Widget _buildMissingBankCard({
    required String message,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFEDF89)),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFFB54708)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.account_balance_rounded, size: 18),
            label: const Text('NHẬP TÀI KHOẢN ĐỂ TẠO QR'),
          ),
        ],
      ),
    );
  }

  Future<void> _editBankAccount({
    required String role,
    required String userId,
    required String currentBank,
    required String currentAccount,
  }) async {
    final bankCtrl = TextEditingController(text: currentBank);
    final accountCtrl = TextEditingController(text: currentAccount);
    String? selectedCode = _findBankCode(currentBank);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tài khoản nhận chuyển khoản',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Chọn đúng ngân hàng và nhập STK. Không cần nhập tên; app ngân hàng sẽ hiện người nhận khi quét.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  children: _bankBins.keys
                      .map(
                        (code) => ChoiceChip(
                          label: Text(code),
                          selected: selectedCode == code,
                          onSelected: (_) => setSheetState(() {
                            selectedCode = code;
                            bankCtrl.text = code;
                          }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bankCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên ngân hàng',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) =>
                      setSheetState(() => selectedCode = _findBankCode(v)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: accountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số tài khoản',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedCode == null
                        ? null
                        : () => Navigator.pop(sheetContext, true),
                    child: const Text('LƯU THÔNG TIN & TẠO QR'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true) return;

    final bank = bankCtrl.text.trim();
    final account = accountCtrl.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (bank.isEmpty || account.isEmpty || selectedCode == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nhập ngân hàng và STK hợp lệ trước khi tạo QR.'),
          ),
        );
      }
      return;
    }
    try {
      if (userId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'bankName': bank,
          'bankCode': selectedCode,
          'bankAccountNumber': account,
          'accountNumber': account,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      if (mounted) {
        setState(() {
          final updated = {
            ...?(role == 'host' ? _hostProfile : _renterProfile),
          };
          updated['bankName'] = bank;
          updated['bankCode'] = selectedCode;
          updated['bankAccountNumber'] = account;
          updated['accountNumber'] = account;
          if (role == 'host') {
            _hostProfile = updated;
          } else {
            _renterProfile = updated;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu tài khoản. QR chuyển khoản đã được tạo.'),
            backgroundColor: Color(0xFF12B76A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không lưu được tài khoản. Vui lòng thử lại.'),
          ),
        );
      }
    }
  }

  Future<void> _sendNotificationAndRecord({
    required String targetRole, // 'host' hoặc 'renter'
    required int amount,
    required String title,
    required String body,
    required String orderCodes,
    required String recipientName,
    required String bankDetails,
    required int totalDeposit,
    required int renterRefund,
    required int hostCompensation,
    required int platformFee,
  }) async {
    setState(() => _isProcessing = true);
    final db = FirebaseFirestore.instance;

    try {
      final first = _bookingDataList.isNotEmpty ? _bookingDataList.first : {};
      final hostId = (first['hostId'] ?? '').toString();
      final renterId = (first['renterId'] ?? '').toString();
      final recipientId = targetRole == 'host' ? hostId : renterId;

      if (recipientId.isNotEmpty && recipientId != 'guest') {
        await db.collection('notifications').add({
          'recipientId': recipientId,
          'recipientRole': targetRole,
          'title': title,
          'body': body,
          'notificationType': 'cancellation_invoice',
          'bookingIds': widget.bookingIds,
          'amount': amount,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      for (final bId in widget.bookingIds) {
        await db.collection('bookings').doc(bId).set({
          'isRefunded': true,
          'refundedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      final auditRef = db.collection('audit_logs').doc();
      final executedAt = DateTime.now();
      final receiptCode =
          '#CXL-${DateFormat('yyyyMMdd-HHmmss').format(executedAt)}-${auditRef.id.substring(0, 4).toUpperCase()}';
      await auditRef.set({
        'action': targetRole == 'host'
            ? 'Quyết toán bồi thường đơn hủy cho Chủ trọ'
            : 'Hoàn tiền đơn hủy cho Người thuê',
        'actor': 'Admin',
        'category': 'taiChinh',
        'details': body,
        'bookingIds': widget.bookingIds,
        'receiptCode': receiptCode,
        'amount': amount,
        'recipientRole': targetRole,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CancellationReceiptScreen(
              receiptCode: receiptCode,
              orderCodes: orderCodes,
              recipientName: recipientName,
              recipientRole: targetRole,
              bankDetails: bankDetails,
              amount: amount,
              totalDeposit: totalDeposit,
              renterRefund: renterRefund,
              hostCompensation: hostCompensation,
              platformFee: platformFee,
              bookingCount: widget.bookingIds.length,
              executedAt: executedAt,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD92D20),
            content: const Text(
              'Không thể ghi nhận hoàn tiền. Vui lòng thử lại.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F9FF),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF398FC0)),
        ),
      );
    }

    if (_bookingDataList.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const AdminBrandedTitle(title: 'Hóa đơn đơn hủy'),
        ),
        body: const Center(child: Text('Không tìm thấy thông tin đơn hủy.')),
      );
    }

    final first = _bookingDataList.first;
    final totalDeposit = _bookingDataList.fold<double>(
      0.0,
      (acc, item) => acc + BookingUtils.amount(item),
    );

    // Tính toán theo chính sách:
    // Tổng cọc: 100%
    // Phí sàn: 5% (cấn trừ)
    // Bồi thường chủ trọ: 10%
    // Hoàn người thuê: 85% (sau khi trừ 15% phí hủy phòng)
    final split = BookingUtils.cancellationSplit(totalDeposit);
    final platformFee = split['platformFee'] ?? (totalDeposit * 0.05).round();
    final hostCompensation =
        split['hostAmount'] ?? (totalDeposit * 0.10).round();
    final renterRefund = split['refundAmount'] ?? (totalDeposit * 0.85).round();
    final cancellationPenaltyTotal = platformFee + hostCompensation; // 15%

    final hostName = _pick(
      [_hostProfile, first],
      ['fullName', 'name', 'hostName', 'tenChuNha'],
    ).trim();
    final hostPhone = _pick(
      [_hostProfile, first],
      ['phoneNumber', 'phone', 'sdt'],
    ).trim();
    final hostBank = _pick(
      [_hostProfile, first],
      ['bankName', 'nganHang', 'tenNganHang'],
    ).trim();
    final hostAcc = _pick(
      [_hostProfile, first],
      [
        'bankAccountNumber',
        'accountNumber',
        'hostAccountNumber',
        'soTaiKhoan',
        'stk',
      ],
    ).trim();
    final savedHostBankCode = _pick(
      [_hostProfile, first],
      ['hostBankCode', 'bankCode'],
    ).toUpperCase();
    final hostBankCode = _bankBins.containsKey(savedHostBankCode)
        ? savedHostBankCode
        : _findBankCode(hostBank);

    final renterName = _pick(
      [_renterProfile, first],
      ['fullName', 'name', 'renterName', 'tenNguoiO'],
    ).trim();
    final renterPhone = _pick(
      [_renterProfile, first],
      ['phoneNumber', 'phone', 'renterPhone', 'sdtNguoiO'],
    ).trim();
    final renterBank = _pick(
      [_renterProfile, first],
      ['bankName', 'nganHang', 'tenNganHang'],
    ).trim();
    final renterAcc = _pick(
      [_renterProfile, first],
      [
        'bankAccountNumber',
        'accountNumber',
        'renterAccountNumber',
        'soTaiKhoan',
        'stk',
      ],
    ).trim();
    final savedRenterBankCode = _pick(
      [_renterProfile, first],
      ['renterBankCode', 'bankCode'],
    ).toUpperCase();
    final renterBankCode = _bankBins.containsKey(savedRenterBankCode)
        ? savedRenterBankCode
        : _findBankCode(renterBank);

    final orderCodes = _bookingDataList
        .map((e) => (e['orderCode'] ?? e['transferNote'] ?? e['id']).toString())
        .join(', ');
    final transferReference = _pick(
      [first],
      ['userCode', 'renterUserCode', 'transferNote', 'orderCode', 'id'],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const AdminBrandedTitle(title: 'Hóa đơn đơn hủy'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF398FC0),
          unselectedLabelColor: const Color(0xFF667085),
          indicatorColor: const Color(0xFF398FC0),
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13.5,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.real_estate_agent_outlined, size: 20),
              text: '1. GỬI CHỦ TRỌ',
            ),
            Tab(
              icon: Icon(Icons.person_outline_rounded, size: 20),
              text: '2. GỬI NGƯỜI THUÊ',
            ),
          ],
        ),
      ),
      body: AdminPageBackdrop(
        child: TabBarView(
          controller: _tabController,
          children: [
            // ── TAB 1: HÓA ĐƠN GỬI CHỦ TRỌ ──
            _buildHostInvoiceTab(
              orderCodes: orderCodes,
              transferReference: transferReference,
              hostName: hostName.isNotEmpty ? hostName : 'Chủ trọ',
              hostPhone: hostPhone,
              hostBank: hostBank,
              hostAcc: hostAcc,
              hostBankCode: hostBankCode,
              hostId: (first['hostId'] ?? '').toString(),
              totalDeposit: totalDeposit.round(),
              platformFee: platformFee,
              hostCompensation: hostCompensation,
              renterRefund: renterRefund,
            ),

            // ── TAB 2: HÓA ĐƠN GỬI NGƯỜI THUÊ ──
            _buildRenterInvoiceTab(
              orderCodes: orderCodes,
              transferReference: transferReference,
              renterName: renterName.isNotEmpty ? renterName : 'Khách thuê',
              renterPhone: renterPhone,
              renterBank: renterBank,
              renterAcc: renterAcc,
              renterBankCode: renterBankCode,
              renterId: (first['renterId'] ?? '').toString(),
              totalDeposit: totalDeposit.round(),
              platformFee: platformFee,
              hostCompensation: hostCompensation,
              cancellationPenaltyTotal: cancellationPenaltyTotal,
              renterRefund: renterRefund,
            ),
          ],
        ),
      ),
    );
  }

  /// ── TAB 1: HÓA ĐƠN GỬI CHỦ TRỌ ──
  Widget _buildHostInvoiceTab({
    required String orderCodes,
    required String transferReference,
    required String hostName,
    required String hostPhone,
    required String hostBank,
    required String hostAcc,
    required String? hostBankCode,
    required String hostId,
    required int totalDeposit,
    required int platformFee,
    required int hostCompensation,
    required int renterRefund,
  }) {
    final memo = _transferMemo('BOI THUONG', transferReference);
    final bankBin = hostBankCode == null ? null : _bankBins[hostBankCode];
    final qrPayload = (bankBin != null && hostAcc.isNotEmpty)
        ? VietQRHelper.generateNapasEmvcoPayload(
            bankBin: bankBin,
            accountNo: hostAcc.replaceAll(RegExp(r'\s+'), ''),
            amount: hostCompensation.toDouble(),
            accountName: 'NGUOI NHAN',
            addInfo: memo.length > 25 ? memo.substring(0, 25) : memo,
          )
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner thông tin
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE9F5FC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFB2DDFF)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF398FC0),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hóa đơn bồi thường hủy cọc gửi cho Chủ trọ ($hostName).',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF175CD3),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Khối Chi Tiết Hóa Đơn Chủ Trọ
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCEAF5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'HÓA ĐƠN HOÀN TIỀN CỌC ĐƠN HỦY',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color.fromARGB(255, 13, 122, 5),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Đơn: $orderCodes',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF667085),
                    ),
                  ),
                ),
                const Divider(height: 24),

                _buildRow('Chủ trọ thụ hưởng:', hostName, isBold: true),
                const SizedBox(height: 8),
                if (hostPhone.isNotEmpty) ...[
                  _buildRow('Số điện thoại:', hostPhone),
                  const SizedBox(height: 8),
                ],
                _buildRow(
                  'Tài khoản nhận bồi thường:',
                  hostAcc.isNotEmpty ? '$hostBank ($hostAcc)' : 'Chưa cập nhật',
                ),
                const Divider(height: 24),

                // Bảng tỷ lệ rõ ràng
                _buildRow(
                  'Tiền cọc gốc ban đầu (100%):',
                  '${currencyFormatter.format(totalDeposit)} đ',
                  isBold: true,
                ),
                const SizedBox(height: 10),
                _buildRow(
                  'Trả người thuê (85%):',
                  '-${currencyFormatter.format(renterRefund)} đ',
                  color: const Color(0xFF667085),
                ),
                const SizedBox(height: 8),
                _buildRow(
                  'Cấn trừ phí dịch vụ sàn (5%):',
                  '-${currencyFormatter.format(platformFee)} đ',
                  color: const Color(0xFFD92D20),
                ),
                const SizedBox(height: 8),
                _buildRow(
                  'Bồi thường giữ chỗ cho Chủ trọ (+10%):',
                  '+${currencyFormatter.format(hostCompensation)} đ',
                  color: const Color(0xFF027A48),
                  isBold: true,
                ),
                const Divider(height: 24),

                // Tổng thực chuyển cho chủ trọ
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA6F4C5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'THỰC CHUYỂN BỒI THƯỜNG:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF027A48),
                        ),
                      ),
                      Text(
                        '${currencyFormatter.format(hostCompensation)} đ',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF027A48),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Mã QR Chuyển Khoản Cho Chủ Trọ
          if (qrPayload != null) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDCEAF5)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'MÃ VIETQR CHUYỂN BỒI THƯỜNG CHO CHỦ TRỌ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF344054),
                    ),
                  ),
                  const SizedBox(height: 12),
                  QrImageView(
                    data: qrPayload,
                    version: QrVersions.auto,
                    size: 220,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nội dung: $memo',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (qrPayload == null) ...[
            _buildMissingBankCard(
              message: hostAcc.isEmpty
                  ? 'Chủ trọ chưa có tài khoản nhận bồi thường.'
                  : 'Chưa nhận diện được ngân hàng để tạo QR.',
              onPressed: () => _editBankAccount(
                role: 'host',
                userId: hostId,
                currentBank: hostBank,
                currentAccount: hostAcc,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Nút xác nhận & gửi hóa đơn
          ElevatedButton.icon(
            onPressed: _isProcessing
                ? null
                : () => _sendNotificationAndRecord(
                    targetRole: 'host',
                    amount: hostCompensation,
                    title: 'Thông báo bồi thường đơn hủy phòng ($orderCodes)',
                    body:
                        'Khách đã hủy đơn $orderCodes. Tiền cọc ${currencyFormatter.format(totalDeposit)}đ được phân bổ: Hoàn khách 85% (-${currencyFormatter.format(renterRefund)}đ), Phí sàn 5% (-${currencyFormatter.format(platformFee)}đ), Bồi thường giữ chỗ cho bạn 10% (+${currencyFormatter.format(hostCompensation)}đ).',
                    orderCodes: orderCodes,
                    recipientName: hostName,
                    bankDetails: hostAcc.isEmpty ? '' : '$hostBank ($hostAcc)',
                    totalDeposit: totalDeposit,
                    renterRefund: renterRefund,
                    hostCompensation: hostCompensation,
                    platformFee: platformFee,
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF398FC0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(
              _isProcessing
                  ? 'ĐANG XỬ LÝ...'
                  : 'XÁC NHẬN & GỬI HÓA ĐƠN CHO CHỦ TRỌ',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// ── TAB 2: HÓA ĐƠN GỬI NGƯỜI THUÊ ──
  Widget _buildRenterInvoiceTab({
    required String orderCodes,
    required String transferReference,
    required String renterName,
    required String renterPhone,
    required String renterBank,
    required String renterAcc,
    required String? renterBankCode,
    required String renterId,
    required int totalDeposit,
    required int platformFee,
    required int hostCompensation,
    required int cancellationPenaltyTotal,
    required int renterRefund,
  }) {
    final memo = _transferMemo('HOAN TIEN', transferReference);
    final bankBin = renterBankCode == null ? null : _bankBins[renterBankCode];
    final qrPayload = (bankBin != null && renterAcc.isNotEmpty)
        ? VietQRHelper.generateNapasEmvcoPayload(
            bankBin: bankBin,
            accountNo: renterAcc.replaceAll(RegExp(r'\s+'), ''),
            amount: renterRefund.toDouble(),
            accountName: 'NGUOI NHAN',
            addInfo: memo.length > 25 ? memo.substring(0, 25) : memo,
          )
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner thông tin
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECDCA)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.report_problem_outlined,
                  color: Color(0xFFD92D20),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hóa đơn hoàn tiền gửi Người thuê ($renterName).',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFFB42318),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Khối Chi Tiết Hóa Đơn Người Thuê
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCEAF5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'HÓA ĐƠN HOÀN TIỀN CỌC ĐƠN HỦY',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color.fromARGB(255, 48, 118, 238),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Đơn: $orderCodes',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF667085),
                    ),
                  ),
                ),
                const Divider(height: 24),

                _buildRow('Khách thuê:', renterName, isBold: true),
                const SizedBox(height: 8),
                if (renterPhone.isNotEmpty) ...[
                  _buildRow('Số điện thoại:', renterPhone),
                  const SizedBox(height: 8),
                ],
                _buildRow(
                  'Tài khoản nhận tiền hoàn:',
                  renterAcc.isNotEmpty
                      ? '$renterBank ($renterAcc)'
                      : 'Chưa cập nhật',
                ),
                const Divider(height: 24),

                // Bảng chi tiết khấu trừ đúng yêu cầu người dùng
                _buildRow(
                  'Tiền cọc phòng đã thanh toán:',
                  '${currencyFormatter.format(totalDeposit)} đ',
                  isBold: true,
                ),
                const SizedBox(height: 10),
                _buildRow(
                  'Phí hủy phòng (-15%):',
                  '-${currencyFormatter.format(cancellationPenaltyTotal)} đ',
                  color: const Color(0xFFD92D20),
                  isBold: true,
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 4, top: 2),
                  child: Text(
                    '• Bao gồm: 5% phí xử lý sàn & 10% bồi thường chủ trọ giữ phòng',
                    style: TextStyle(fontSize: 11, color: Color(0xFF667085)),
                  ),
                ),
                const Divider(height: 24),

                // Thực hoàn cho khách thuê
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F5FC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFB2DDFF)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'SỐ TIỀN THỰC HOÀN (85%):',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF398FC0),
                        ),
                      ),
                      Text(
                        '${currencyFormatter.format(renterRefund)} đ',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF398FC0),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Mã QR Hoàn Tiền Cho Người Thuê
          if (qrPayload != null) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDCEAF5)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'MÃ VIETQR HOÀN TIỀN CHO KHÁCH THUÊ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF344054),
                    ),
                  ),
                  const SizedBox(height: 12),
                  QrImageView(
                    data: qrPayload,
                    version: QrVersions.auto,
                    size: 220,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nội dung: $memo',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (qrPayload == null) ...[
            _buildMissingBankCard(
              message: renterAcc.isEmpty
                  ? 'Người thuê chưa có tài khoản nhận tiền hoàn.'
                  : 'Chưa nhận diện được ngân hàng để tạo QR.',
              onPressed: () => _editBankAccount(
                role: 'renter',
                userId: renterId,
                currentBank: renterBank,
                currentAccount: renterAcc,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Nút xác nhận & gửi hóa đơn cho người thuê
          ElevatedButton.icon(
            onPressed: _isProcessing
                ? null
                : () => _sendNotificationAndRecord(
                    targetRole: 'renter',
                    amount: renterRefund,
                    title: 'Biên lai hoàn tiền cọc đơn hủy ($orderCodes)',
                    body:
                        'Đơn $orderCodes đã hủy thành công. Tiền cọc ${currencyFormatter.format(totalDeposit)}đ -15% phí hủy phòng (${currencyFormatter.format(cancellationPenaltyTotal)}đ). Số tiền thực hoàn về tài khoản của bạn là ${currencyFormatter.format(renterRefund)}đ (85%).',
                    orderCodes: orderCodes,
                    recipientName: renterName,
                    bankDetails: renterAcc.isEmpty
                        ? ''
                        : '$renterBank ($renterAcc)',
                    totalDeposit: totalDeposit,
                    renterRefund: renterRefund,
                    hostCompensation: hostCompensation,
                    platformFee: platformFee,
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD92D20),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(
              _isProcessing
                  ? 'ĐANG XỬ LÝ...'
                  : 'XÁC NHẬN & GỬI HÓA ĐƠN CHO NGƯỜI THUÊ',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: color ?? const Color(0xFF475467),
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            color: color ?? const Color(0xFF101828),
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
