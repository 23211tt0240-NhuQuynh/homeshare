<<<<<<< HEAD
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../widgets/admin_page_backdrop.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/utils/vietqr_helper.dart';
import '../utils/booking_utils.dart';
import '../widgets/admin_branded_title.dart';
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
  }

  String get _commissionRateLabel {
    final percent = _commissionRate * 100;
    final digits = percent == percent.roundToDouble() ? 0 : 1;
    return '${percent.toStringAsFixed(digits)}%';
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
        final hostId = (canonicalData['hostId'] ?? '').toString();
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
        if (!hasBank) {
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

      await db.runTransaction((tx) async {
        // Đọc & kiểm tra tất cả đơn trước khi ghi
        for (final item in items) {
          final ref = db.collection('bookings').doc(item['docId'] as String);
          final snap = await tx.get(ref);
          if (!snap.exists) {
            throw Exception('Đơn ${item['orderCode']} không còn tồn tại');
          }
          final st = BookingUtils.status(snap.data() ?? {});
          final isDisbursed = snap.data()?['isDisbursed'] == true;
          if (isDisbursed ||
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
            BookingFields.platformFee: (item['fee'] as num).round(),
            BookingFields.platformFeeRate: commissionRate * 100,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        tx.set(disbursementRef, {
          'receiptCode': receiptCode,
          'hostId': hostId,
          'hostName': hostName,
          'hostBankName': bankName,
          'hostAccountNumber': accountNo,
          'totalDeposit': totalDeposit,
          'platformFee': platformFee,
          BookingFields.platformFeeRate: commissionRate * 100,
          'totalAmount': netSettlement,
          'itemCount': items.length,
          'bookingIds': items.map((e) => e['docId']).toList(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Nhật ký kiểm toán — ghi đủ cả hai bộ trường đang dùng trong app
        // (xem ghi chú: cần thống nhất khi có admin_history_screen.dart)
        tx.set(auditLogRef, {
          'action': 'Duyệt giải ngân cọc',
          'actor': 'Admin',
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
          'performer': 'Admin',
          'code': receiptCode,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FF),
=======
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/vietqr_helper.dart';

class SettlementInvoiceScreen extends StatelessWidget {
  final String hostName;
  final String hostPhone;
  final String hostBankName;
  final String hostAccountNumber;
  final String hostCode;
  final double totalDeposit;
  final double platformFee;
  final double netSettlement;
  final List<Map<String, dynamic>> settlementItems;
  final VoidCallback? onConfirmDisbursement;

  const SettlementInvoiceScreen({
    super.key,
    this.hostName = 'Chủ trọ A (Khu Bình Thạnh)',
    this.hostPhone = '0388529900',
    this.hostBankName = 'MB Bank',
    this.hostAccountNumber = '0388529900',
    this.hostCode = 'CT0089',
    this.totalDeposit = 4100000.0,
    this.platformFee = 350000.0,
    this.netSettlement = 3750000.0,
    this.settlementItems = const [
      {
        'orderCode': '1-0482',
        'renterName': 'Nguyễn Văn Nam',
        'roomCode': 'Phòng 201 - Bình Thạnh',
        'itemType': 'Tiền cọc • Đặt cọc giữ phòng',
        'amount': 1000000.0,
        'fee': 100000.0,
        'net': 900000.0,
      },
      {
        'orderCode': '1-5821',
        'renterName': 'Trần Thị Mai',
        'roomCode': 'Phòng 104 - Bình Thạnh',
        'itemType': 'Tiền cọc • Đặt cọc đảm bảo nhận phòng',
        'amount': 500000.0,
        'fee': 50000.0,
        'net': 450000.0,
      },
      {
        'orderCode': '1-6012',
        'renterName': 'Hoàng Minh Tuấn',
        'roomCode': 'Phòng 302 - Bình Thạnh',
        'itemType': 'Tiền cọc • Cọc hẹn dọn vào',
        'amount': 1500000.0,
        'fee': 120000.0,
        'net': 1380000.0,
      },
      {
        'orderCode': '1-7145',
        'renterName': 'Lê Thu Thảo',
        'roomCode': 'Phòng 102 - Bình Thạnh',
        'itemType': 'Tiền cọc • Cọc đơn hạn 1 tháng',
        'amount': 1100000.0,
        'fee': 80000.0,
        'net': 1020000.0,
      },
    ],
    this.onConfirmDisbursement,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,###', 'vi_VN');

    // Build VietQR image URL
    final qrImageUrl = VietQRHelper.buildVietQrImageUrl(
      amount: netSettlement,
      addInfo: 'NT0009 CHU TRO A',
      accountNo: hostAccountNumber.isNotEmpty ? hostAccountNumber : '0382542737',
      bankCode: 'MB',
      accountName: hostName.toUpperCase(),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
<<<<<<< HEAD
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
                !_commissionRateLoaded) {
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
              if (data['isDisbursed'] == true ||
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
              final fee = (amount * _commissionRate).round();
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
=======
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF101828)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Hóa Đơn & Quyết Toán',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF101828),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Color(0xFF155EEF)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettlementReceiptScreen(
                    amount: netSettlement,
                    hostName: hostName,
                    hostAccountNumber: hostAccountNumber,
                    hostBankName: hostBankName,
                    settlementItems: settlementItems,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Host Info Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEAECF0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_pin_rounded, color: Color(0xFF155EEF), size: 22),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                        ),
                      ),
                    ],
                  ),
<<<<<<< HEAD
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
            final hostId = _pick(sources, ['hostId']);
            final hostName =
                _pick(sources, ['hostName', 'fullName', 'name']).isNotEmpty
                ? _pick(sources, ['hostName', 'fullName', 'name'])
                : 'Chủ trọ';
            final bankName = _pick(sources, [
              'hostBankName',
              'bankName',
              'nganHang',
            ]);
            final accountNo = _pick(sources, [
              'hostAccountNumber',
              'bankAccountNumber',
              'accountNumber',
              'bankAccount',
              'soTaiKhoan',
              'stk',
            ]).replaceAll(RegExp(r'\s+'), '');

            final netSettlement = totalDeposit - platformFee;
            final storedBankCode = _pick(sources, [
              'hostBankCode',
              'bankCode',
            ]).toUpperCase();
            final bankCode = _bankAliases.containsKey(storedBankCode)
                ? storedBankCode
                : _vietQrBankCode(bankName);
            final hasAccount = accountNo.isNotEmpty;
            final bankBin = bankCode == null ? null : _bankBins[bankCode];

            final orderRef =
                _removeDiacritics(
                      (settlementItems.isEmpty
                              ? ''
                              : settlementItems.first['orderCode'] ?? '')
                          .toString(),
                    )
                    .toUpperCase()
                    .replaceAll(RegExp(r'[^A-Z0-9 ]'), ' ')
                    .replaceAll(RegExp(r'\s+'), ' ')
                    .trim();
            final transferInfoRaw =
                'QUYET TOAN ${orderRef.isEmpty ? 'COC' : orderRef}';
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
                accountName: 'NGUOI NHAN',
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
                                'Hoa hồng sàn ($_commissionRateLabel) trừ\n-${currencyFormatter.format(platformFee)} đ',
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
=======
                  const SizedBox(height: 6),
                  Text(
                    'MB Bank: $hostAccountNumber • Chủ tài khoản: $hostName',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kỳ đối soát: 16/09/2026',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
                      ),
                      Text(
                        'Chi 02 phòng ▼',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF155EEF)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Settlement Total Banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD1E0FF), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF155EEF).withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'HÓA ĐƠN QUYẾT TOÁN TIỀN CHỦ TRỌ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Color(0xFF475467),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${currencyFormatter.format(netSettlement)} đ',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF027A48),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '(Số tiền thực chuyển EX tự động khấu trừ hoa hồng dịch vụ)',
                    style: TextStyle(fontSize: 11, color: Color(0xFF98A2B3)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F4F7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Tổng tiền cọc: ${currencyFormatter.format(totalDeposit)} đ',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF344054)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3F2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Hoa hồng sàn: -${currencyFormatter.format(platformFee)} đ',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFD92D20)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Settlement Breakdown Items
            const Text(
              'DANH SÁCH GIAO DỊCH QUYẾT TOÁN (4 đơn)',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF344054),
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            ...settlementItems.map((item) {
              final amt = (item['amount'] as num).toDouble();
              final fee = (item['fee'] as num).toDouble();
              final net = (item['net'] as num).toDouble();

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEAECF0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item['orderCode'],
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF155EEF),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item['renterName'],
                                style: const TextStyle(
                                  fontSize: 13,
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF101828),
                                ),
                              ),
<<<<<<< HEAD
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
                            Text(
                              '1. Tổng tiền cọc giữ chỗ (${settlementItems.length} đơn):',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF667085),
                              ),
                            ),
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
                            Text(
                              '2. Hoa hồng sàn ($_commissionRateLabel) (Trừ):',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFD92D20),
                              ),
                            ),
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
                              const Text(
                                'TỔNG CỘNG THỰC CHUYỂN:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF027A48),
                                ),
                              ),
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
                      OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Tính năng in phiếu đang được phát triển',
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'In Phiếu',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF344054),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
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
=======
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item['roomCode'],
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF667085)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['itemType'],
                            style: const TextStyle(fontSize: 11, color: Color(0xFF98A2B3)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${currencyFormatter.format(amt)} đ',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF101828),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Nhận: ${currencyFormatter.format(net)} đ',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF027A48),
                          ),
                        ),
                        Text(
                          'Phí: -${currencyFormatter.format(fee)} đ',
                          style: const TextStyle(fontSize: 10, color: Color(0xFFD92D20)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),

            // 4. Accounting Summary Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'CHI TIẾT KHOẢN THU / CHI',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475467),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('1. Tổng tiền cọc giữ chỗ (4 đơn):', style: TextStyle(fontSize: 12, color: Color(0xFF667085))),
                      Text('${currencyFormatter.format(totalDeposit)} đ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF101828))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('2. Hoa hồng môi giới dịch vụ (sàn):', style: TextStyle(fontSize: 12, color: Color(0xFF667085))),
                      Text('-${currencyFormatter.format(platformFee)} đ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD92D20))),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TỔNG CỘNG THỰC CHUYỂN:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF101828)),
                      ),
                      Text(
                        '${currencyFormatter.format(netSettlement)} đ',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF027A48)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 5. QR Code Section for Host
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEAECF0)),
              ),
              child: Column(
                children: [
                  const Text(
                    'MÃ QR CHUYỂN KHOẢN CHO CHỦ TRỌ',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF155EEF),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 190,
                    height: 190,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD0D5DD)),
                    ),
                    child: Image.network(
                      qrImageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.qr_code_2_rounded, size: 70, color: Color(0xFF155EEF)),
                            const SizedBox(height: 4),
                            Text(
                              'MB Bank • $hostAccountNumber',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Quét mã để chuyển nhanh ${currencyFormatter.format(netSettlement)} đ qua Napas 24/7',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF667085)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF155EEF)),
                      const SizedBox(width: 4),
                      Text(
                        'Sao chép STK: $hostAccountNumber',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF155EEF),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                        ),
                      ),
                    ],
                  ),
<<<<<<< HEAD
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
=======
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 6. Action Buttons
            Row(
              children: [
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đang xuất phiếu quyết toán định dạng PDF...')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    side: const BorderSide(color: Color(0xFFD0D5DD)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('In Phiếu', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF344054))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (onConfirmDisbursement != null) {
                        onConfirmDisbursement!();
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SettlementReceiptScreen(
                            amount: netSettlement,
                            hostName: hostName,
                            hostAccountNumber: hostAccountNumber,
                            hostBankName: hostBankName,
                            settlementItems: settlementItems,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF155EEF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'XÁC NHẬN CHUYỂN KHOẢN',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
        ),
      ),
    );
  }
}
<<<<<<< HEAD
=======

class SettlementReceiptScreen extends StatelessWidget {
  final double amount;
  final String hostName;
  final String hostAccountNumber;
  final String hostBankName;
  final List<Map<String, dynamic>> settlementItems;

  const SettlementReceiptScreen({
    super.key,
    required this.amount,
    required this.hostName,
    required this.hostAccountNumber,
    required this.hostBankName,
    this.settlementItems = const [],
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,###', 'vi_VN');

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF101828)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Biên Lai Giao Dịch',
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: Color(0xFF101828)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFEAECF0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Color(0xFFECFDF3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF12B76A), size: 36),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'CHUYỂN KHOẢN THÀNH CÔNG',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF027A48),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${currencyFormatter.format(amount)} đ',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF101828),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Số tiền thực thanh toán cho chủ trọ',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF667085)),
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  _buildReceiptRow('Mã biên lai:', '#REC-20260916-SUM'),
                  _buildReceiptRow('Thời gian thực hiện:', '14:32 - 16/09/2026'),
                  _buildReceiptRow('Phương thức:', 'VietQR (Auto MB Bank)'),
                  _buildReceiptRow('Người thụ hưởng:', hostName),
                  _buildReceiptRow('Tài khoản nhận:', '$hostBankName: $hostAccountNumber'),
                  _buildReceiptRow('Khu trọ áp dụng:', 'Khu Bình Thạnh'),
                  _buildReceiptRow('Nội dung chuyển:', 'NT0009 CHU TRO A'),

                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'BẢNG KÊ ĐỐI SOÁT CHI TIẾT',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF344054)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Table(
                    columnWidths: const {
                      0: FlexColumnWidth(2.5),
                      1: FlexColumnWidth(1.5),
                      2: FlexColumnWidth(1.5),
                      3: FlexColumnWidth(1.5),
                    },
                    children: [
                      const TableRow(
                        children: [
                          Text('Khách & HĐ', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF98A2B3))),
                          Text('Tiền cọc', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF98A2B3))),
                          Text('Hoa hồng', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF98A2B3))),
                          Text('Thực chuyển', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF98A2B3))),
                        ],
                      ),
                      ...settlementItems.map((item) {
                        return TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text('${item['orderCode']} - ${item['renterName']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(currencyFormatter.format(item['amount']), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text('-${currencyFormatter.format(item['fee'])}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFFD92D20))),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(currencyFormatter.format(item['net']), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF027A48))),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TỔNG CỘNG THỰC CHUYỂN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF101828))),
                      Text('${currencyFormatter.format(amount)} đ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF027A48))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đang tải phiếu PDF biên lai...')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('In phiếu'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF155EEF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('XÁC NHẬN NHẬN TIỀN', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF667085))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF101828))),
        ],
      ),
    );
  }
}
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
