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
  double _commissionRate = 0.10;
  bool _commissionRateFrozen = false;

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
    _loadCommissionRate();
    _loadData();
  }

  Future<void> _loadCommissionRate() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('system_configs')
          .doc('platform_settings')
          .get();
      final rate = doc.data()?['commission_rate'];
      if (rate is num && mounted && !_commissionRateFrozen) {
        setState(() => _commissionRate = rate.toDouble().clamp(0, 100) / 100);
      }
    } catch (e) {
      debugPrint('Không tải được hoa hồng khi xử lý đơn hủy: $e');
    }
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
      for (final item in loaded) {
        final savedRate = item['cancellationCommissionRate'];
        if (savedRate is num) {
          _commissionRate = savedRate.toDouble() / 100;
          _commissionRateFrozen = true;
          break;
        }
      }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không lưu được tài khoản: $e')));
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

      final refs = widget.bookingIds
          .map((id) => db.collection('bookings').doc(id))
          .toList();
      final shouldComplete = await db.runTransaction<bool>((tx) async {
        final snapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final ref in refs) {
          final snap = await tx.get(ref);
          if (!snap.exists) throw StateError('Không tìm thấy đơn ${ref.id}.');
          snapshots.add(snap);
        }
        for (var i = 0; i < refs.length; i++) {
          final data = snapshots[i].data() ?? {};
          final alreadyHandled = targetRole == 'host'
              ? data['cancellationHostPaid'] == true
              : data['cancellationRenterRefunded'] == true;
          if (alreadyHandled || data['isRefunded'] == true) {
            throw StateError(
              'Đơn đã được ghi nhận chuyển tiền, không thể xác nhận lần nữa.',
            );
          }
        }
        for (var i = 0; i < refs.length; i++) {
          final data = snapshots[i].data() ?? {};
          final fullPayment = [
            'full',
            'toanbo',
            'trahet',
          ].contains((data['paymentOption'] ?? '').toString().toLowerCase());
          final otherSideDone = targetRole == 'host'
              ? data['cancellationRenterRefunded'] == true
              : data['cancellationHostPaid'] == true;
          final completesOrder = !fullPayment || otherSideDone;
          final orderAmount = BookingUtils.amount(data);
          final hostShare = fullPayment
              ? (orderAmount / 2).round()
              : orderAmount.round();
          final orderPlatformFee = (hostShare * _commissionRate).round();
          tx.update(refs[i], {
            targetRole == 'host'
                    ? 'cancellationHostPaid'
                    : 'cancellationRenterRefunded':
                true,
            targetRole == 'host'
                    ? 'cancellationHostPaidAt'
                    : 'cancellationRenterRefundedAt':
                FieldValue.serverTimestamp(),
            'cancellationPlatformFee': orderPlatformFee,
            'cancellationCommissionRate': _commissionRate * 100,
            if (completesOrder) 'isRefunded': true,
            if (completesOrder) 'refundedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        return true;
      });
      if (mounted) {
        setState(() {
          for (final booking in _bookingDataList) {
            booking[targetRole == 'host'
                    ? 'cancellationHostPaid'
                    : 'cancellationRenterRefunded'] =
                true;
            final full = ['full', 'toanbo', 'trahet'].contains(
              (booking['paymentOption'] ?? '').toString().toLowerCase(),
            );
            final otherDone = targetRole == 'host'
                ? booking['cancellationRenterRefunded'] == true
                : booking['cancellationHostPaid'] == true;
            if (!full || otherDone) booking['isRefunded'] = true;
          }
        });
      }

      if (recipientId.isNotEmpty && recipientId != 'guest' && shouldComplete) {
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
              isFullPayment: ['full', 'toanbo', 'trahet'].contains(
                (_bookingDataList.first['paymentOption'] ?? '')
                    .toString()
                    .toLowerCase(),
              ),
              commissionRate: _commissionRate,
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
            content: Text('Lỗi: $e'),
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

    final isFullPayment = [
      'full',
      'toanbo',
      'trahet',
    ].contains((first['paymentOption'] ?? '').toString().toLowerCase());
    var hostGross = 0;
    var renterRefund = 0;
    var platformFee = 0;
    for (final booking in _bookingDataList) {
      final amount = BookingUtils.amount(booking).round();
      final full = [
        'full',
        'toanbo',
        'trahet',
      ].contains((booking['paymentOption'] ?? '').toString().toLowerCase());
      final landlordShare = full ? (amount / 2).round() : amount;
      hostGross += landlordShare;
      if (full) renterRefund += amount - landlordShare;
      platformFee += (landlordShare * _commissionRate).round();
    }
    final hostCompensation = hostGross - platformFee;

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
        bottom: isFullPayment
            ? TabBar(
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
              )
            : null,
      ),
      body: AdminPageBackdrop(
        child: isFullPayment
            ? TabBarView(
                controller: _tabController,
                children: [
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
                    isFullPayment: isFullPayment,
                  ),
                  _buildRenterInvoiceTab(
                    orderCodes: orderCodes,
                    transferReference: transferReference,
                    renterName: renterName.isNotEmpty
                        ? renterName
                        : 'Khách thuê',
                    renterPhone: renterPhone,
                    renterBank: renterBank,
                    renterAcc: renterAcc,
                    renterBankCode: renterBankCode,
                    renterId: (first['renterId'] ?? '').toString(),
                    totalDeposit: totalDeposit.round(),
                    platformFee: platformFee,
                    hostCompensation: hostCompensation,
                    renterRefund: renterRefund,
                  ),
                ],
              )
            : _buildHostInvoiceTab(
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
                isFullPayment: isFullPayment,
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
    required bool isFullPayment,
  }) {
    final memo = _transferMemo('QUYET TOAN HUY', transferReference);
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
    final hostGross = hostCompensation + platformFee;
    final hostBankLine =
        '${hostBank.isEmpty ? 'Chưa cập nhật ngân hàng' : hostBank} - '
        '${hostAcc.isEmpty ? 'chưa có STK' : hostAcc}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thông tin người nhận, cùng cấu trúc với hóa đơn quyết toán.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDCEAF5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE9F5FC),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.home_work_rounded,
                        color: Color(0xFF398FC0),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hostName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF101828),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF0C7),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Text(
                        'Chờ thanh toán',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB54708),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ngân hàng: $hostBankLine',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: hostAcc.isEmpty
                              ? const Color(0xFFB42318)
                              : const Color(0xFF667085),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _editBankAccount(
                        role: 'host',
                        userId: hostId,
                        currentBank: hostBank,
                        currentAccount: hostAcc,
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 14),
                      label: Text(hostAcc.isEmpty ? 'Nhập STK' : 'Đổi STK'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF398FC0),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '📅 Kỳ đối soát: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF344054),
                      ),
                    ),
                    Text(
                      '${widget.bookingIds.length} đơn hủy',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD92D20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tổng tiền thực chuyển; giữ cùng thẻ tổng quan như hóa đơn cọc.
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCEAF5)),
            ),
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFFECFDF3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF12B76A),
                    size: 22,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'HÓA ĐƠN QUYẾT TOÁN ĐƠN HỦY',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                    color: Color(0xFF027A48),
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${currencyFormatter.format(hostCompensation)} đ',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF101828),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Số tiền thực chuyển cho chủ trọ sau khi trừ hoa hồng',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF667085)),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _buildAmountBadge(
                      'Tổng tiền cọc (${_bookingDataList.length} đơn)',
                      '${currencyFormatter.format(totalDeposit)} đ',
                      const Color(0xFFEAF4FA),
                      const Color(0xFF344054),
                    ),
                    _buildAmountBadge(
                      'Hoa hồng sàn (${(_commissionRate * 100).toStringAsFixed(_commissionRate * 100 % 1 == 0 ? 0 : 1)}%)',
                      '-${currencyFormatter.format(platformFee)} đ',
                      const Color(0xFFFEF3F2),
                      const Color(0xFFD92D20),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'DANH SÁCH GIAO DỊCH (${_bookingDataList.length} đơn)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF101828),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          ..._bookingDataList.map((booking) {
            final amount = BookingUtils.amount(booking).round();
            final full = ['full', 'toanbo', 'trahet'].contains(
              (booking['paymentOption'] ?? '').toString().toLowerCase(),
            );
            final gross = full ? (amount / 2).round() : amount;
            final fee = (gross * _commissionRate).round();
            final code =
                (booking['orderCode'] ??
                        booking['transferNote'] ??
                        booking['id'] ??
                        '')
                    .toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDCEAF5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF398FC0),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          (booking['renterName'] ?? 'Khách thuê').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF101828),
                          ),
                        ),
                        Text(
                          (booking['roomTitle'] ?? 'Phòng trọ').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF667085),
                          ),
                        ),
                        Text(
                          full ? 'Đã trả hết • hoàn khách 50%' : 'Chỉ cọc',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFD92D20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${currencyFormatter.format(amount)} đ',
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF101828),
                        ),
                      ),
                      Text(
                        'Nhận: ${currencyFormatter.format(gross - fee)} đ',
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF027A48),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),

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
                    'HÓA ĐƠN QUYẾT TOÁN ĐƠN HỦY',
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
                  'Hoàn người thuê (50% cọc):',
                  '-${currencyFormatter.format(renterRefund)} đ',
                  color: const Color(0xFF667085),
                ),
                const SizedBox(height: 8),
                _buildRow(
                  'Hoa hồng sàn (${(_commissionRate * 100).toStringAsFixed(_commissionRate * 100 % 1 == 0 ? 0 : 1)}%):',
                  '-${currencyFormatter.format(platformFee)} đ',
                  color: const Color(0xFFD92D20),
                ),
                const SizedBox(height: 8),
                _buildRow(
                  'Phần chủ trọ trước hoa hồng:',
                  '${currencyFormatter.format(hostGross)} đ',
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
                      const Expanded(
                        child: Text(
                          'THỰC CHUYỂN CHO CHỦ TRỌ:',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF027A48),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${currencyFormatter.format(hostCompensation)} đ',
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
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
                  ? 'Chủ trọ chưa có tài khoản nhận tiền.'
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
            onPressed:
                _isProcessing ||
                    _bookingDataList.any(
                      (b) => b['cancellationHostPaid'] == true,
                    )
                ? null
                : () => _sendNotificationAndRecord(
                    targetRole: 'host',
                    amount: hostCompensation,
                    title: 'Thông báo bồi thường đơn hủy phòng ($orderCodes)',
                    body:
                        'Đơn $orderCodes đã hủy. Phần chủ trọ sau hoa hồng là ${currencyFormatter.format(hostCompensation)}đ.',
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
              _bookingDataList.any((b) => b['cancellationHostPaid'] == true)
                  ? 'ĐÃ GHI NHẬN CHUYỂN'
                  : (_isProcessing
                        ? 'ĐANG XỬ LÝ...'
                        : 'XÁC NHẬN & GỬI HÓA ĐƠN CHO CHỦ TRỌ'),
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
                  'Phần còn lại chuyển chủ trọ trước hoa hồng:',
                  '${currencyFormatter.format(totalDeposit - renterRefund)} đ',
                  color: const Color(0xFF475467),
                  isBold: true,
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 4, top: 2),
                  child: Text(
                    '• Hoàn lại 50% tiền cọc cho khách; hoa hồng trừ trong phần của chủ trọ.',
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
                        'SỐ TIỀN HOÀN (50% CỌC):',
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
            onPressed:
                _isProcessing ||
                    _bookingDataList.any(
                      (b) => b['cancellationRenterRefunded'] == true,
                    )
                ? null
                : () => _sendNotificationAndRecord(
                    targetRole: 'renter',
                    amount: renterRefund,
                    title: 'Biên lai hoàn tiền cọc đơn hủy ($orderCodes)',
                    body:
                        'Đơn $orderCodes đã hủy. Bạn được hoàn 50% tiền cọc là ${currencyFormatter.format(renterRefund)}đ.',
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
              _bookingDataList.any(
                    (b) => b['cancellationRenterRefunded'] == true,
                  )
                  ? 'ĐÃ GHI NHẬN HOÀN TIỀN'
                  : (_isProcessing
                        ? 'ĐANG XỬ LÝ...'
                        : 'XÁC NHẬN & GỬI HÓA ĐƠN CHO NGƯỜI THUÊ'),
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
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: color ?? const Color(0xFF475467),
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              color: color ?? const Color(0xFF101828),
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountBadge(
    String title,
    String amount,
    Color background,
    Color foreground,
  ) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132, maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
          Text(
            amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
