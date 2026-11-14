import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/admin_page_backdrop.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/utils/vietqr_helper.dart';
import '../utils/booking_utils.dart';
import '../utils/commission_rate_service.dart';
import '../widgets/admin_branded_title.dart';
import '../services/admin_audit_identity.dart';
import 'settlement_receipt_screen.dart';

class SettlementInvoiceScreen extends StatefulWidget {
  /// Các đơn (document id trong `bookings`) cần quyết toán cho MỘT chủ trọ.
  final List<String> selectedBookingIds;

  const SettlementInvoiceScreen({super.key, required this.selectedBookingIds});

  @override
  State<SettlementInvoiceScreen> createState() =>
      _SettlementInvoiceScreenState();
}

class _SettlementInvoiceScreenState extends State<SettlementInvoiceScreen> {
  // Tỷ lệ được chụp vào từng đơn khi xác nhận quyết toán.
  double _commissionRate = 0.10;
  bool _commissionRateLoaded = false;
  bool _bookingRatesLoaded = false;
  final Map<String, double> _bookingCommissionRates = {};

  final currencyFormatter = NumberFormat('#,###', 'vi_VN');
  bool _isProcessing = false;

  // Hồ sơ chủ trọ (collection users) để lấy tài khoản ngân hàng
  Map<String, dynamic>? _hostProfile;
  bool _hostLoaded = false;

  // Cho phép Admin nhập / đổi STK trực tiếp ngay trên màn hình hóa đơn
  String? _customBankName;
  String? _customAccountNo;

  @override
  void initState() {
    super.initState();
    _loadHostProfile();
    _loadCommissionRate();
    _loadBookingCommissionRates();
  }

  Future<void> _loadBookingCommissionRates() async {
    final rates = <String, double>{};
    for (final id in widget.selectedBookingIds) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('bookings')
            .doc(id)
            .get();
        final raw = doc.data();
        if (raw == null) continue;
        final data = BookingUtils.canonical(raw);
        final stored =
            data['commissionRateAtBooking'] ?? data['platformFeeRate'];
        if (stored is num) {
          rates[id] = stored.toDouble().clamp(0, 50) / 100;
        } else {
          rates[id] = await CommissionRateService.rateAt(
            BookingUtils.createdAt(data),
            fallback: _commissionRate,
          );
        }
      } catch (error) {
        debugPrint('Không tải được tỷ lệ hoa hồng của đơn $id: $error');
      }
    }
    if (mounted) {
      setState(() {
        _bookingCommissionRates
          ..clear()
          ..addAll(rates);
        _bookingRatesLoaded = true;
      });
    }
  }

  Future<void> _loadCommissionRate() async {
    try {
      _commissionRate = await _readCommissionRate(fallback: _commissionRate);
    } catch (error) {
      debugPrint('Không đọc được tỷ lệ hoa hồng, dùng mặc định 10%: $error');
    } finally {
      if (mounted) setState(() => _commissionRateLoaded = true);
    }
  }

  Future<double> _readCommissionRate({required double fallback}) async {
    try {
      final config = await FirebaseFirestore.instance
          .collection('system_configs')
          .doc('platform_settings')
          .get();
      final rawRate = config.data()?['commission_rate'];
      if (rawRate is num) {
        return rawRate.toDouble().clamp(0, 100) / 100;
      }
    } catch (error) {
      debugPrint('Không đọc được tỷ lệ hoa hồng mới nhất: $error');
    }
    return fallback;
  }

  Future<void> _loadHostProfile() async {
    try {
      if (widget.selectedBookingIds.isNotEmpty) {
        final db = FirebaseFirestore.instance;
        final first = await db
            .collection('bookings')
            .doc(widget.selectedBookingIds.first)
            .get();
        final rawData = first.data() ?? {};
        final canonicalData = BookingUtils.canonical(rawData);
        final hostIds = <String>{};
        for (final key in const [
          'hostId',
          'landlordId',
          'hostUserId',
          'landlordUserId',
          'ownerId',
          'propertyOwnerId',
        ]) {
          final candidateId = (rawData[key] ?? canonicalData[key] ?? '')
              .toString()
              .trim();
          if (candidateId.isNotEmpty) hostIds.add(candidateId);
        }
        final hostId = hostIds.isEmpty ? '' : hostIds.first;
        if (hostId.isNotEmpty) {
          final u = await db.collection('users').doc(hostId).get();
          _hostProfile = u.data();
        }

        // Fallback: Nếu user doc chưa có bank info, thử tìm theo hostName trong collection users
        final hasBank = _pick(
          [_hostProfile],
          [
            'accountNumber',
            'bankAccountNumber',
            'bankAccount',
            'hostAccountNumber',
            'soTaiKhoan',
            'stk',
          ],
        ).isNotEmpty;
        if (_hostProfile == null && !hasBank) {
          final hostName = (canonicalData['hostName'] ?? '').toString().trim();
          if (hostName.isNotEmpty) {
            final query = await db
                .collection('users')
                .where('fullName', isEqualTo: hostName)
                .limit(1)
                .get();
            if (query.docs.isNotEmpty) {
              _hostProfile = query.docs.first.data();
            } else {
              final query2 = await db
                  .collection('users')
                  .where('name', isEqualTo: hostName)
                  .limit(1)
                  .get();
              if (query2.docs.isNotEmpty) {
                _hostProfile = query2.docs.first.data();
              }
            }
          }
        }

        // bank_accounts là nguồn chuẩn và mới nhất cho tài khoản nhận tiền.
        // Ưu tiên document id == userId, sau đó tra theo userId/hostId.
        if (hostId.isNotEmpty) {
          try {
            final bankCollection = db.collection('bank_accounts');
            Map<String, dynamic>? bankData;
            for (final candidateId in hostIds) {
              final bankById = await bankCollection.doc(candidateId).get();
              if (bankById.exists) {
                bankData = bankById.data();
              } else {
                final byUserId = await bankCollection
                    .where('userId', isEqualTo: candidateId)
                    .limit(1)
                    .get();
                if (byUserId.docs.isNotEmpty) {
                  bankData = byUserId.docs.first.data();
                } else {
                  final byHostId = await bankCollection
                      .where('hostId', isEqualTo: candidateId)
                      .limit(1)
                      .get();
                  if (byHostId.docs.isNotEmpty) {
                    bankData = byHostId.docs.first.data();
                  }
                }
              }
              final hasAccountNumber = _pick(
                [bankData],
                ['accountNumber', 'bankAccountNumber'],
              ).isNotEmpty;
              if (hasAccountNumber) break;
            }
            if (bankData != null) {
              _hostProfile = {
                ...(_hostProfile ?? {}),
                'accountNumber': _pick(
                  [bankData, _hostProfile],
                  [
                    'accountNumber',
                    'bankAccountNumber',
                    'hostAccountNumber',
                    'soTaiKhoan',
                    'stk',
                  ],
                ),
                'bankName': _pick(
                  [bankData, _hostProfile],
                  ['bankName', 'hostBankName', 'nganHang', 'tenNganHang'],
                ),
                'bankCode': _pick(
                  [bankData, _hostProfile],
                  ['bankCode', 'hostBankCode'],
                ),
                'accountHolder': _pick(
                  [bankData, _hostProfile],
                  ['accountHolder', 'accountName', 'hostAccountHolder'],
                ),
              };
            }
          } catch (e) {
            debugPrint('Fallback bank_accounts read error: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Load host profile error: $e');
    }
    if (mounted) setState(() => _hostLoaded = true);
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

  // Danh sách ngân hàng phổ biến để Admin chọn nhanh bằng Chip
  static const List<Map<String, String>> _popularBanks = [
    {'code': 'MB', 'name': 'MBBank'},
    {'code': 'VCB', 'name': 'Vietcombank'},
    {'code': 'TCB', 'name': 'Techcombank'},
    {'code': 'ACB', 'name': 'ACB'},
    {'code': 'BIDV', 'name': 'BIDV'},
    {'code': 'ICB', 'name': 'VietinBank'},
    {'code': 'VPB', 'name': 'VPBank'},
    {'code': 'TPB', 'name': 'TPBank'},
    {'code': 'STB', 'name': 'Sacombank'},
    {'code': 'VBA', 'name': 'Agribank'},
  ];

  // Mã ngân hàng cho VietQR. Không nhận diện được -> null (KHÔNG đoán, tránh QR sai ngân hàng).
  static const Map<String, List<String>> _bankAliases = {
    'MB': ['mb', 'mbb', 'mbbank', 'quan doi', 'quandoi'],
    'VCB': ['vcb', 'vietcombank', 'ngoai thuong', 'ngoaithuong'],
    'TCB': ['tcb', 'techcombank', 'ky thuong', 'kythuong'],
    'ACB': ['acb', 'a chau', 'achau'],
    'BIDV': ['bidv', 'dau tu va phat trien', 'dautuvaphattrien'],
    'ICB': ['icb', 'ctg', 'vietinbank', 'vietin', 'cong thuong', 'congthuong'],
    'VPB': ['vpb', 'vpbank', 'viet nam thinh vuong', 'thinh vuong'],
    'TPB': ['tpb', 'tpbank', 'tien phong', 'tienphong'],
    'STB': ['stb', 'sacombank', 'sai gon thuong tin'],
    'VBA': ['vba', 'agribank', 'agri', 'nong nghiep', 'nongnghiep'],
    'SHB': ['shb', 'sai gon ha noi'],
    'VIB': ['vib', 'quoc te'],
    'HDB': ['hdb', 'hdbank', 'phat trien tphcm'],
    'OCB': ['ocb', 'phuong dong', 'phuongdong'],
    'MSB': ['msb', 'hang hai', 'maritime'],
    'EIB': ['eib', 'eximbank', 'xuat nhap khau'],
    'SCB': ['scb', 'sai gon'],
    'LPB': ['lpb', 'lpbank', 'lienvietpostbank', 'buu dien lien viet'],
    'TIMO': ['timo'],
    'CAKE': ['cake'],
  };

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
    'OCB': '970448',
    'MSB': '970426',
    'EIB': '970431',
    'SCB': '970429',
    'LPB': '970449',
  };

  String? _vietQrBankCode(String bankName) {
    final n = bankName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (n.isEmpty) return null;
    for (final e in _bankAliases.entries) {
      if (n == e.key.toLowerCase()) return e.key;
      for (final a in e.value) {
        if (n == a || n == '${a}bank') return e.key;
      }
    }
    return null;
  }

  String _removeDiacritics(String input) {
    const from =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
        'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
    const to =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
        'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    final buf = StringBuffer();
    for (final ch in input.split('')) {
      final idx = from.indexOf(ch);
      buf.write(idx >= 0 ? to[idx] : ch);
    }
    return buf.toString();
  }

  void _openEditBankDialog({
    required String currentBankName,
    required String currentAccountNo,
    required String hostId,
  }) {
    final bankCtrl = TextEditingController(text: currentBankName);
    final accountCtrl = TextEditingController(text: currentAccountNo);
    String? selectedCode = _vietQrBankCode(currentBankName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Cập nhật tài khoản nhận tiền',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF101828),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: Color(0xFF667085),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Nhập ngân hàng và số tài khoản để tạo VietQR. Không cần nhập tên; app ngân hàng sẽ hiện người nhận khi quét.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Quick Bank Selection Chips
                    const Text(
                      'Chọn ngân hàng phổ biến:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF344054),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _popularBanks.map((b) {
                        final isSelected = selectedCode == b['code'];
                        return ChoiceChip(
                          label: Text(
                            b['name']!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF344054),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF398FC0),
                          backgroundColor: const Color(0xFFEAF4FA),
                          showCheckmark: false,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                selectedCode = b['code']!;
                                bankCtrl.text = b['name']!;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Bank Name Field
                    TextField(
                      controller: bankCtrl,
                      decoration: InputDecoration(
                        labelText: 'Tên ngân hàng / Mã NH',
                        hintText: 'VD: MBBank, Vietcombank, Techcombank...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (v) {
                        final code = _vietQrBankCode(v);
                        setModalState(() => selectedCode = code);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Account No Field
                    TextField(
                      controller: accountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Số tài khoản (STK)',
                        hintText: 'Nhập số tài khoản ngân hàng',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    const SizedBox(height: 8),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                        label: const Text(
                          'LƯU & TẠO MÃ VIETQR NGAY',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF398FC0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          final bank = bankCtrl.text.trim();
                          final acc = accountCtrl.text.trim();

                          if (bank.isEmpty ||
                              acc.isEmpty ||
                              selectedCode == null) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Chọn đúng ngân hàng trong danh sách và nhập số tài khoản',
                                ),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            _customBankName = bank;
                            _customAccountNo = acc;
                          });

                          // Lưu vào Firestore trong nền để các lần sau không cần nhập lại
                          try {
                            final db = FirebaseFirestore.instance;
                            if (hostId.isNotEmpty) {
                              await db.collection('users').doc(hostId).set({
                                'bankName': bank,
                                'bankCode': selectedCode,
                                'bankAccountNumber': acc,
                                'accountNumber': acc,
                                'updatedAt': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));
                            }
                            // Cập nhật cả trên các booking đã chọn
                            for (final bId in widget.selectedBookingIds) {
                              await db.collection('bookings').doc(bId).set({
                                'hostBankName': bank,
                                'hostBankCode': selectedCode,
                                'hostAccountNumber': acc,
                              }, SetOptions(merge: true));
                            }
                          } catch (e) {
                            debugPrint('Failed to persist bank info: $e');
                          }

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Color(0xFF12B76A),
                                content: Text(
                                  'Đã cập nhật STK và tạo mã QR thành công!',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Hỏi xác nhận trước khi ghi sổ (không thể hoàn tác)
  Future<void> _confirmAndProcess({
    required List<Map<String, dynamic>> items,
    required int totalDeposit,
    required int platformFee,
    required int netSettlement,
    required String hostId,
    required String hostName,
    required String bankName,
    required String bankCode,
    required String accountHolder,
    required String accountNo,
  }) async {
    final appliedRate = _commissionRate;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Xác nhận đã chuyển khoản?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Bạn xác nhận ĐÃ chuyển ${currencyFormatter.format(netSettlement)} đ '
          'đến $bankName - $accountNo ($hostName) cho ${items.length} đơn?\n\n'
          'Hệ thống chỉ ghi sổ theo xác nhận của bạn và không thể hoàn tác.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Chưa'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đã chuyển xong'),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    await _processDisbursement(
      items: items,
      totalDeposit: totalDeposit,
      platformFee: platformFee,
      netSettlement: netSettlement,
      commissionRate: appliedRate,
      hostId: hostId,
      hostName: hostName,
      bankName: bankName,
      bankCode: bankCode,
      accountHolder: accountHolder,
      accountNo: accountNo,
    );
  }

  // Ghi sổ giải ngân (transaction: chặn giải ngân trùng nếu đơn đã được xử lý ở nơi khác)
  Future<void> _processDisbursement({
    required List<Map<String, dynamic>> items,
    required int totalDeposit,
    required int platformFee,
    required int netSettlement,
    required double commissionRate,
    required String hostId,
    required String hostName,
    required String bankName,
    required String bankCode,
    required String accountHolder,
    required String accountNo,
  }) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final db = FirebaseFirestore.instance;
      final disbursementRef = db.collection('disbursements').doc();
      final auditLogRef = db.collection('audit_logs').doc();
      final now = DateTime.now();
      final receiptCode =
          '#REC-${DateFormat('yyyyMMdd-HHmmss').format(now)}-${disbursementRef.id.substring(0, 4).toUpperCase()}';
      final actorFields = await AdminAuditIdentity.currentActorFields();

      await db.runTransaction((tx) async {
        // Đọc & kiểm tra tất cả đơn trước khi ghi
        for (final item in items) {
          final ref = db.collection('bookings').doc(item['docId'] as String);
          final snap = await tx.get(ref);
          if (!snap.exists) {
            throw Exception('Đơn ${item['orderCode']} không còn tồn tại');
          }
          final booking = BookingUtils.canonical(snap.data() ?? {});
          final st = BookingUtils.uiStatus(booking);
          final isDisbursed = BookingUtils.isDisbursed(booking);
          if (isDisbursed ||
              booking['isCheckIn'] != true ||
              (st != BookingUtils.statusDepositPaid &&
                  st != BookingUtils.statusCompleted)) {
            throw Exception(
              'Đơn ${item['orderCode']} đã giải ngân hoặc chưa đủ điều kiện',
            );
          }
        }

        for (final item in items) {
          final ref = db.collection('bookings').doc(item['docId'] as String);
          tx.update(ref, {
            'isDisbursed': true,
            'disbursedAt': FieldValue.serverTimestamp(),
            'disbursementId': disbursementRef.id,
            'platformFee': (item['fee'] as num).round(),
            'platformFeeRate':
                ((item['commissionRate'] as num).toDouble()) * 100,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        tx.set(disbursementRef, {
          'receiptCode': receiptCode,
          'hostId': hostId,
          'hostName': hostName,
          'hostBankName': bankName,
          'hostBankCode': bankCode,
          'hostAccountHolder': accountHolder,
          'hostAccountNumber': accountNo,
          'totalDeposit': totalDeposit,
          'platformFee': platformFee,
          'platformFeeRate': totalDeposit == 0
              ? commissionRate * 100
              : platformFee / totalDeposit * 100,
          'totalAmount': netSettlement,
          'netAmount': netSettlement,
          'itemCount': items.length,
          'bookingIds': items.map((e) => e['docId']).toList(),
          'bookingDetails': items
              .map(
                (item) => {
                  'bookingId': item['docId'],
                  'orderCode': item['rawOrderCode'] ?? item['orderCode'],
                  'amount': (item['amount'] as num).round(),
                  'platformFee': (item['fee'] as num).round(),
                  'platformFeeRate':
                      ((item['commissionRate'] as num).toDouble()) * 100,
                  'netAmount': (item['net'] as num).round(),
                },
              )
              .toList(),
          'status': 'completed',
          'disbursedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Nhật ký kiểm toán — ghi đủ cả hai bộ trường đang dùng trong app
        // (xem ghi chú: cần thống nhất khi có admin_history_screen.dart)
        tx.set(auditLogRef, {
          ...actorFields,
          'action': 'Duyệt giải ngân cọc',
          'details':
              'Admin xác nhận đã chuyển ${currencyFormatter.format(netSettlement)} đ '
              'cho chủ trọ $hostName ($bankName - $accountNo), ${items.length} đơn. Mã $receiptCode',
          'target': 'Giải ngân ${disbursementRef.id}',
          'category': 'taiChinh',
          'createdAt': FieldValue.serverTimestamp(),
          'title': 'Duyệt Giải Ngân Cọc $receiptCode',
          'subtitle':
              'Chuyển ${currencyFormatter.format(netSettlement)} đ ➔ Chủ trọ $hostName',
          'amount': netSettlement,
          'code': receiptCode,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      // Gửi thông báo "Admin đã giải ngân" vào tab Đã thanh toán của chủ trọ.
      await _notifyHostDisbursement(
        hostId: hostId,
        hostName: hostName,
        netSettlement: netSettlement,
        itemCount: items.length,
        disbursementId: disbursementRef.id,
        receiptCode: receiptCode,
        bookingIds: items.map((e) => '${e['docId']}').toList(),
      );

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SettlementReceiptScreen(
              amount: netSettlement.toDouble(),
              hostName: hostName,
              hostAccountNumber: accountNo,
              hostBankName: bankName,
              settlementItems: items,
              receiptCode: receiptCode,
              executedAt: now,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD92D20),
            content: Text('Không thể ghi sổ giải ngân: $e'),
          ),
        );
      }
    }
  }

  Future<void> _notifyHostDisbursement({
    required String hostId,
    required String hostName,
    required int netSettlement,
    required int itemCount,
    required String disbursementId,
    required String receiptCode,
    required List<String> bookingIds,
  }) async {
    final cleanHostId = hostId.trim();
    if (cleanHostId.isEmpty) return;

    final moneyText = currencyFormatter.format(netSettlement);
    final orderLabel = itemCount <= 1 ? '1 đơn' : '$itemCount đơn';
    final displayName = hostName.trim().isEmpty ? 'chủ trọ' : hostName.trim();
    final notifId = 'disbursement_$disbursementId';

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.notifications)
          .doc(notifId)
          .set({
            NotificationFields.notificationId: notifId,
            NotificationFields.receiverId: cleanHostId,
            NotificationFields.senderId: 'admin',
            NotificationFields.notificationType: 'paymentCompleted',
            'actionType': 'disbursement',
            NotificationFields.title: 'Admin đã giải ngân',
            NotificationFields.message:
                'Admin đã giải ngân $moneyText đ cho $displayName ($orderLabel).',
            NotificationFields.amount: netSettlement.toDouble(),
            NotificationFields.statusId: 'completed',
            NotificationFields.isRead: false,
            NotificationFields.createdAt: FieldValue.serverTimestamp(),
            NotificationFields.updatedAt: FieldValue.serverTimestamp(),
            'disbursementId': disbursementId,
            'receiptCode': receiptCode,
            if (bookingIds.isNotEmpty) 'bookingIds': bookingIds,
            if (bookingIds.isNotEmpty)
              NotificationFields.bookingId: bookingIds.first,
          }, SetOptions(merge: true));
    } catch (error) {
      debugPrint('Không tạo được thông báo giải ngân cho chủ trọ: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Color(0xFF101828),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: false,
        title: const AdminBrandedTitle(title: 'Hóa đơn quyết toán'),
      ),
      body: AdminPageBackdrop(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('bookings').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                !_hostLoaded ||
                !_commissionRateLoaded ||
                !_bookingRatesLoaded) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF398FC0)),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Lỗi tải dữ liệu: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            final allDocs = snapshot.data?.docs ?? [];
            final selectedDocs = allDocs
                .where((d) => widget.selectedBookingIds.contains(d.id))
                .toList();

            // Chỉ đơn ĐÃ CỌC (admin đã xác nhận) và CHƯA giải ngân mới được quyết toán
            final List<Map<String, dynamic>> settlementItems = [];
            final Set<String> hostIds = {};
            Map<String, dynamic>? firstBooking;
            int totalDeposit = 0;
            int platformFee = 0;
            int excludedCount = 0;

            for (final doc in selectedDocs) {
              final data = BookingUtils.canonical(
                doc.data() as Map<String, dynamic>? ?? {},
              );
              final st = BookingUtils.uiStatus(data);
              // Cả đơn Đã cọc (deposit_paid) và Đã cọc hết / Đã trả hết (completed / paid) đều được quyết toán nếu chưa giải ngân
              if (BookingUtils.isDisbursed(data) ||
                  data['isCheckIn'] != true ||
                  (st != BookingUtils.statusDepositPaid &&
                      st != BookingUtils.statusCompleted)) {
                excludedCount++;
                continue;
              }
              firstBooking ??= data;
              hostIds.add(
                (data['hostId'] ?? data['hostName'] ?? '').toString(),
              );

              final amount = BookingUtils.amount(data).round();
              final commissionRate =
                  _bookingCommissionRates[doc.id] ?? _commissionRate;
              final fee = (amount * commissionRate).round();
              totalDeposit += amount;
              platformFee += fee;

              String displayCode = (data['userCode'] ?? '').toString().trim();
              if (displayCode.isEmpty) {
                final raw =
                    (data['orderCode'] ?? data['transferNote'] ?? doc.id)
                        .toString()
                        .trim();
                if (raw.contains('_')) {
                  displayCode = '#${raw.split('_').last}';
                } else if (raw.length > 8) {
                  displayCode =
                      '#${raw.substring(raw.length - 6).toUpperCase()}';
                } else {
                  displayCode = raw.startsWith('#') ? raw : '#$raw';
                }
              } else {
                displayCode = displayCode.startsWith('#')
                    ? displayCode
                    : '#$displayCode';
              }

              settlementItems.add({
                'docId': doc.id,
                'orderCode': displayCode,
                'rawOrderCode': (data['orderCode'] ?? '').toString(),
                'renterName': (data['renterName'] ?? 'Khách thuê').toString(),
                'roomCode': (data['roomTitle'] ?? 'Phòng trọ').toString(),
                'itemType': (data['note'] ?? 'Tiền cọc • Đặt cọc giữ phòng')
                    .toString(),
                'amount': amount.toDouble(),
                'fee': fee.toDouble(),
                'commissionRate': commissionRate,
                'net': (amount - fee).toDouble(),
              });
            }

            if (settlementItems.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 56,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Không có đơn nào đủ điều kiện quyết toán',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF344054),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Chỉ đơn đã cọc và chưa giải ngân mới được quyết toán.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (hostIds.length > 1) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Các đơn đã chọn thuộc nhiều chủ trọ khác nhau.\nVui lòng chọn đơn của MỘT chủ trọ để tạo hóa đơn.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFB42318),
                      height: 1.4,
                    ),
                  ),
                ),
              );
            }

            // Thông tin chủ trọ & tài khoản nhận tiền (ưu tiên dữ liệu nhập tay của admin, dữ liệu trên đơn, sau đó hồ sơ users)
            final sources = <Map<String, dynamic>?>[
              if (_customBankName != null || _customAccountNo != null)
                {
                  'bankName': _customBankName,
                  'accountNumber': _customAccountNo,
                },
              firstBooking,
              _hostProfile,
            ];
            final bankSources = <Map<String, dynamic>?>[
              if (_customBankName != null || _customAccountNo != null)
                {
                  'bankName': _customBankName,
                  'accountNumber': _customAccountNo,
                },
              _hostProfile,
              firstBooking,
            ];
            final hostId = _pick(sources, ['hostId']);
            // Booking có thể chỉ lưu nhãn mặc định "Chủ nhà". Ưu tiên tên
            // hồ sơ users tải theo hostId rồi mới dùng tên trên booking.
            final profileHostName = _pick(
              [_hostProfile],
              ['displayName', 'fullName', 'hoTen', 'name', 'hostName'],
            );
            final bookingHostName = _pick([firstBooking], ['hostName']);
            final hostName = profileHostName.isNotEmpty
                ? profileHostName
                : (bookingHostName.isNotEmpty ? bookingHostName : 'Chủ trọ');
            final bankName = _pick(bankSources, [
              'hostBankName',
              'bankName',
              'nganHang',
            ]);
            final accountNo = _pick(bankSources, [
              'hostAccountNumber',
              'bankAccountNumber',
              'accountNumber',
              'bankAccount',
              'soTaiKhoan',
              'stk',
            ]).replaceAll(RegExp(r'\s+'), '');

            final netSettlement = totalDeposit - platformFee;
            final effectiveCommissionPercent = totalDeposit == 0
                ? _commissionRate * 100
                : platformFee / totalDeposit * 100;
            final commissionRateLabel =
                '${effectiveCommissionPercent.toStringAsFixed(effectiveCommissionPercent % 1 == 0 ? 0 : 1)}%';
            final storedBankCode = _pick(bankSources, [
              'hostBankCode',
              'bankCode',
            ]).toUpperCase();
            final bankCode = _bankAliases.containsKey(storedBankCode)
                ? storedBankCode
                : _vietQrBankCode(bankName);
            final hasAccount = accountNo.isNotEmpty;
            final bankBin = bankCode == null ? null : _bankBins[bankCode];
            final accountHolder = _pick(bankSources, [
              'accountHolder',
              'accountName',
              'hostAccountHolder',
            ]);

            String extractHostCode() {
              final hostProfileCode = _pick(
                [_hostProfile],
                ['hostCode', 'maChuTro', 'userCode', 'maNguoiDung', 'idNguoiDung'],
              ).toUpperCase();
              final bookingHostCode = _pick(
                [firstBooking],
                ['hostCode', 'maChuTro'],
              ).toUpperCase();
              final candidate = hostProfileCode.isNotEmpty
                  ? hostProfileCode
                  : bookingHostCode;
              final ctMatch = RegExp(r'CT\d{2,5}').firstMatch(candidate);
              if (ctMatch != null) return ctMatch.group(0)!;
              final ntMatch = RegExp(r'NT(\d{2,5})').firstMatch(candidate);
              if (ntMatch != null) return 'CT${ntMatch.group(1)!}';
              final cleanDigits = candidate.replaceAll(RegExp(r'[^A-Z0-9]'), '');
              if (RegExp(r'^\d{3,4}$').hasMatch(cleanDigits)) {
                return 'CT$cleanDigits';
              }
              if (hostId.isNotEmpty) {
                var hash = 0;
                for (var i = 0; i < hostId.length; i++) {
                  hash = (hash * 31 + hostId.codeUnitAt(i)) & 0x7FFFFFFF;
                }
                final val = (hash % 900) + 100;
                return 'CT$val';
              }
              return 'CT';
            }

            String shortItemCode(Map<String, dynamic> item, {int maxLen = 4}) {
              final rawOrder = (item['rawOrderCode'] ?? '').toString().trim();
              final docId = (item['docId'] ?? '').toString().trim();
              final raw = (rawOrder.isNotEmpty ? rawOrder : docId).toUpperCase();
              if (raw.contains('_')) {
                final parts = raw
                    .split('_')
                    .where(
                      (p) =>
                          p.isNotEmpty &&
                          p != 'DP' &&
                          !RegExp(r'^20\d{6}$').hasMatch(p) &&
                          !RegExp(r'^(NT|CT)[A-Z0-9]+$').hasMatch(p),
                    )
                    .toList();
                if (parts.isNotEmpty) {
                  final mid = parts.first.replaceAll(RegExp(r'[^A-Z0-9]'), '');
                  if (mid.isNotEmpty) {
                    return mid.length > maxLen
                        ? mid.substring(mid.length - maxLen)
                        : mid;
                  }
                }
              }
              final clean = _removeDiacritics(raw)
                  .replaceAll(RegExp(r'[^A-Z0-9]'), '');
              return clean.length > maxLen
                  ? clean.substring(clean.length - maxLen)
                  : clean;
            }

            final hostCode = extractHostCode();
            String transferInfoRaw;
            if (settlementItems.length > 1) {
              final batchPrefix = 'QT ${settlementItems.length}D $hostCode';
              String? matchedBatch;
              for (final len in [4, 3, 2]) {
                final codes = settlementItems
                    .map((item) => shortItemCode(item, maxLen: len))
                    .where((c) => c.isNotEmpty)
                    .toList();
                final candidate = '$batchPrefix ${codes.join(' ')}'
                    .replaceAll(RegExp(r'\s+'), ' ')
                    .trim();
                if (candidate.length <= 25) {
                  matchedBatch = candidate;
                  break;
                }
              }
              transferInfoRaw = matchedBatch ??
                  'QT ${settlementItems.length}D $hostCode ${DateFormat('ddMM').format(DateTime.now())}';
            } else {
              final singleCode = settlementItems.isEmpty
                  ? ''
                  : shortItemCode(settlementItems.first, maxLen: 4);
              transferInfoRaw = 'QT $hostCode $singleCode'
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim();
            }
            final transferInfo = transferInfoRaw.length > 25
                ? transferInfoRaw.substring(0, 25).trimRight()
                : transferInfoRaw;

            String? qrPayload;
            if (hasAccount && bankCode != null && bankBin != null) {
              qrPayload = VietQRHelper.generateNapasEmvcoPayload(
                amount: netSettlement.toDouble(),
                addInfo: transferInfo,
                accountNo: accountNo,
                bankBin: bankBin,
                accountName: accountHolder.isEmpty
                    ? 'NGUOI NHAN'
                    : accountHolder,
              );
            }
            final canConfirm = hasAccount && bankBin != null && !_isProcessing;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Thẻ Chủ trọ
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDCEAF5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
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
                                Text(
                                  hostName,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF101828),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF0C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Chờ thanh toán',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB54708),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Ngân hàng: ${bankName.isEmpty ? '—' : bankName} - ${hasAccount ? accountNo : 'chưa có STK'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: hasAccount
                                      ? FontWeight.w500
                                      : FontWeight.bold,
                                  color: hasAccount
                                      ? const Color(0xFF667085)
                                      : const Color(0xFFB42318),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => _openEditBankDialog(
                                currentBankName: bankName,
                                currentAccountNo: accountNo,
                                hostId: hostId,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      hasAccount
                                          ? Icons.edit_rounded
                                          : Icons.add_rounded,
                                      size: 14,
                                      color: const Color(0xFF398FC0),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      hasAccount ? 'Đổi STK' : 'Nhập STK',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF398FC0),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
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
                              '${settlementItems.length} đơn cọc',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF398FC0),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Banner Tổng tiền
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 16,
                    ),
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
                          'HÓA ĐƠN QUYẾT TOÁN TIỀN CHỦ TRỌ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                            color: Color(0xFF027A48),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${currencyFormatter.format(netSettlement)} đ',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF101828),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Số tiền thực chuyển (Đã tự động khấu trừ hoa hồng dịch vụ)',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF667085),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF4FA),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Tổng tiền cọc (${settlementItems.length} đơn)\n${currencyFormatter.format(totalDeposit)} đ',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF344054),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3F2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Hoa hồng sàn ($commissionRateLabel) trừ\n-${currencyFormatter.format(platformFee)} đ',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD92D20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Danh sách đơn
                  Text(
                    'DANH SÁCH GIAO DỊCH QUYẾT TOÁN (${settlementItems.length} Đơn)',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF101828),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...settlementItems.map((item) {
                    final amt = (item['amount'] as num).toDouble();
                    final net = (item['net'] as num).toDouble();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDCEAF5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      flex: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE9F5FC),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 130,
                                          ),
                                          child: Text(
                                            item['orderCode'].toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF398FC0),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item['renterName'].toString(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF101828),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item['roomCode'].toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF667085),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item['itemType'].toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF398FC0),
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
                                '${currencyFormatter.format(amt)} đ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF101828),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Nhận: ${currencyFormatter.format(net)} đ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                  const SizedBox(height: 12),

                  // 4. Chi tiết thu chi
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
                        const Text(
                          'CHI TIẾT KHOẢN THU / CHI',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF101828),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '1. Tổng tiền cọc giữ chỗ (${settlementItems.length} đơn):',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF667085),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${currencyFormatter.format(totalDeposit)} đ',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF101828),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                '2. Hoa hồng sàn ($commissionRateLabel) (Trừ):',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFD92D20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '-${currencyFormatter.format(platformFee)} đ',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD92D20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'TỔNG CỘNG THỰC CHUYỂN:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF027A48),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${currencyFormatter.format(netSettlement)} đ',
                                style: const TextStyle(
                                  fontSize: 14,
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

                  // 5. Mã QR VietQR
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFDCEAF5)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'MÃ QR CHUYỂN KHOẢN CHO CHỦ TRỌ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF101828),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: 200,
                          height: 200,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD0D5DD)),
                          ),
                          child: qrPayload != null
                              ? QrImageView(
                                  data: qrPayload,
                                  version: QrVersions.auto,
                                  size: 184,
                                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                                )
                              : Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.qr_code_scanner_rounded,
                                          size: 36,
                                          color: Color(0xFFB42318),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          !hasAccount
                                              ? 'Chưa có số tài khoản của chủ trọ'
                                              : 'Chưa nhận diện được ngân hàng. Hãy chọn ngân hàng đúng để tạo VietQR.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFB42318),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        ElevatedButton.icon(
                                          onPressed: () => _openEditBankDialog(
                                            currentBankName: bankName,
                                            currentAccountNo: accountNo,
                                            hostId: hostId,
                                          ),
                                          icon: const Icon(
                                            Icons.edit_rounded,
                                            size: 14,
                                          ),
                                          label: Text(
                                            hasAccount
                                                ? 'Chọn ngân hàng / sửa STK'
                                                : 'Nhập STK tạo QR ngay',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF398FC0,
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                        if (qrPayload != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF0C7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '⚡ Auto điền ${currencyFormatter.format(netSettlement)} đ cho $hostName',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB54708),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nội dung chuyển khoản: $transferInfo',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF475467),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton.icon(
                            onPressed: () => _openEditBankDialog(
                              currentBankName: bankName,
                              currentAccountNo: accountNo,
                              hostId: hostId,
                            ),
                            icon: const Icon(
                              Icons.edit_note_rounded,
                              size: 16,
                              color: Color(0xFF667085),
                            ),
                            label: const Text(
                              'Đổi tài khoản nhận tiền khác',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF667085),
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (excludedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '$excludedCount đơn đã chọn bị bỏ qua vì đã giải ngân hoặc chưa đủ điều kiện.',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFFB54708),
                        ),
                      ),
                    ),
                  if (!hasAccount || bankBin == null)
                    Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        !hasAccount
                            ? 'Chủ trọ chưa có số tài khoản nhận tiền, chưa thể xác nhận chuyển khoản.'
                            : 'Ngân hàng chưa được nhận diện; hãy cập nhật và chọn ngân hàng đúng trước khi xác nhận.',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFFB42318),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Chuyển tiền bằng app ngân hàng của bạn, sau đó bấm "Xác nhận đã chuyển" để ghi sổ.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ),

                  // 6. Nút chuyển khoản
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: !canConfirm
                              ? null
                              : () => _confirmAndProcess(
                                  items: settlementItems,
                                  totalDeposit: totalDeposit,
                                  platformFee: platformFee,
                                  netSettlement: netSettlement,
                                  hostId: hostId,
                                  hostName: hostName,
                                  bankName: bankName,
                                  bankCode: bankCode ?? '',
                                  accountHolder: accountHolder,
                                  accountNo: accountNo,
                                ),
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 18),
                          label: Text(
                            _isProcessing
                                ? 'ĐANG XỬ LÝ...'
                                : 'XÁC NHẬN ĐÃ CHUYỂN',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF398FC0),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
