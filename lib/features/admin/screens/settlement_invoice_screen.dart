import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/vietqr_helper.dart';
import 'settlement_receipt_screen.dart';

class SettlementInvoiceScreen extends StatefulWidget {
  final String hostId;
  final String hostName;
  final String hostPhone;
  final String hostBankName;
  final String hostAccountNumber;
  final List<String> selectedBookingIds;

  const SettlementInvoiceScreen({
    super.key,
    this.hostId = '',
    this.hostName = 'Chủ trọ A (Khu Bình Thạnh)',
    this.hostPhone = '0398829999',
    this.hostBankName = 'MB Bank',
    this.hostAccountNumber = '0398829999',
    this.selectedBookingIds = const [],
  });

  @override
  State<SettlementInvoiceScreen> createState() => _SettlementInvoiceScreenState();
}

class _SettlementInvoiceScreenState extends State<SettlementInvoiceScreen> {
  final currencyFormatter = NumberFormat('#,###', 'vi_VN');
  bool _isProcessing = false;

  // Xác nhận giải ngân trên Firestore
  Future<void> _processDisbursement(List<Map<String, dynamic>> items, double netSettlement) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Cập nhật trạng thái đơn cọc
      for (var item in items) {
        final docId = item['docId'] as String;
        if (docId.isNotEmpty) {
          final ref = FirebaseFirestore.instance.collection('bookings').doc(docId);
          batch.update(ref, {
            'status': 'completed',
            'disbursedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // 2. Ghi lịch sử quyết toán vào collection 'disbursements'
      final disbursementRef = FirebaseFirestore.instance.collection('disbursements').doc();
      final now = DateTime.now();
      final recCode = '#REC-${DateFormat('yyyyMMdd').format(now)}-SUM';
      batch.set(disbursementRef, {
        'disbursementCode': recCode,
        'hostId': widget.hostId,
        'hostName': widget.hostName,
        'hostAccountNumber': widget.hostAccountNumber,
        'hostBankName': widget.hostBankName,
        'totalAmount': netSettlement,
        'itemCount': items.length,
        'bookingIds': items.map((e) => e['docId']).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Ghi nhật ký kiểm toán vào collection 'audit_logs' cho Admin History
      final auditLogRef = FirebaseFirestore.instance.collection('audit_logs').doc();
      batch.set(auditLogRef, {
        'title': 'Duyệt Giải Ngân Cọc $recCode',
        'subtitle': 'Chuyển ${currencyFormatter.format(netSettlement)} đ ➔ Chủ trọ ${widget.hostName}',
        'amount': netSettlement,
        'category': 'finance',
        'performer': 'Admin',
        'code': recCode,
        'timeStr': DateFormat('HH:mm:ss').format(now),
        'dateGroup': 'HÔM NAY - ${DateFormat('dd/MM/yyyy').format(now)}',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SettlementReceiptScreen(
              amount: netSettlement,
              hostName: widget.hostName,
              hostAccountNumber: widget.hostAccountNumber,
              hostBankName: widget.hostBankName,
              settlementItems: items,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi quyết toán Firebase: $e')),
        );
      }
    }
  }

  // Ép kiểu số an toàn tuyệt đối tránh crash màn hình trắng
  double _parseToDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
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
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('bookings').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF155EEF)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Lỗi tải dữ liệu: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            );
          }

          final allDocs = snapshot.data?.docs ?? [];
          
          final selectedDocs = allDocs.where((doc) {
            if (widget.selectedBookingIds.isNotEmpty) {
              return widget.selectedBookingIds.contains(doc.id);
            }
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final host = data['hostName'] ?? data['landlordName'] ?? '';
            return host == widget.hostName || data['hostId'] == widget.hostId;
          }).toList();

          List<Map<String, dynamic>> settlementItems = [];
          double totalDeposit = 0.0;

          for (var doc in selectedDocs) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final amount = _parseToDouble(data['amount'] ?? data['depositAmount'] ?? data['deposit']);
            final fee = amount * 0.1;
            final net = amount - fee;

            totalDeposit += amount;

            settlementItems.add({
              'docId': doc.id,
              'orderCode': data['bookingCode'] ?? data['orderCode'] ?? '#${doc.id.substring(0, doc.id.length > 6 ? 6 : doc.id.length).toUpperCase()}',
              'renterName': data['renterName'] ?? data['userName'] ?? 'Khách thuê',
              'roomCode': data['roomTitle'] ?? data['roomCode'] ?? 'Phòng trọ',
              'itemType': data['note'] ?? 'Tiền cọc • Đặt cọc giữ phòng',
              'amount': amount,
              'fee': fee,
              'net': net,
            });
          }

          // Nếu chọn đơn mock hoặc chưa chọn được đơn nào từ Firestore -> hiển thị dữ liệu mặc định an toàn
          if (settlementItems.isEmpty) {
            settlementItems = [
              {
                'docId': '1-8492',
                'orderCode': '1-8492',
                'renterName': 'Nguyễn Văn Nam',
                'roomCode': 'Phòng 201 - Bình Thạnh',
                'itemType': 'Tiền cọc • Đặt cọc giữ phòng',
                'amount': 1000000.0,
                'fee': 100000.0,
                'net': 900000.0,
              },
              {
                'docId': '1-5821',
                'orderCode': '1-5821',
                'renterName': 'Trần Thị Mai',
                'roomCode': 'Phòng 104 - Bình Thạnh',
                'itemType': 'Tiền cọc • Cọc bảo đảm nhận phòng',
                'amount': 500000.0,
                'fee': 50000.0,
                'net': 450000.0,
              },
            ];
            totalDeposit = 1500000.0;
          }

          final platformFee = totalDeposit * 0.1;
          final netSettlement = totalDeposit - platformFee;

          final qrImageUrl = VietQRHelper.buildVietQrImageUrl(
            amount: netSettlement,
            addInfo: 'QUYET TOAN COK ${widget.hostName.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '')}',
            accountNo: widget.hostAccountNumber.isNotEmpty ? widget.hostAccountNumber : '0398829999',
            bankCode: widget.hostBankName.contains('MB') ? 'MB' : 'VCB',
            accountName: widget.hostName.toUpperCase(),
          );

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
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEFF8FF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.home_work_rounded, color: Color(0xFF155EEF), size: 18),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.hostName,
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
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ngân hàng: ${widget.hostBankName} - ${widget.hostAccountNumber}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '📅 Kỳ đối soát: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF344054)),
                          ),
                          Text(
                            '${settlementItems.length} đơn cọc',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF155EEF)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 2. Banner Tổng tiền
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEAECF0)),
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
                        child: const Icon(Icons.check_rounded, color: Color(0xFF12B76A), size: 22),
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
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF667085)),
                      ),
                      const SizedBox(height: 14),
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
                              'Tổng tiền cọc (${settlementItems.length} đơn)\n${currencyFormatter.format(totalDeposit)} đ',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF344054)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3F2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Hoa hồng môi giới trừ\n-${currencyFormatter.format(platformFee)} đ',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD92D20)),
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
                  final amt = _parseToDouble(item['amount']);
                  final net = _parseToDouble(item['net']);

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
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF8FF),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item['orderCode'].toString(),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF155EEF)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item['renterName'].toString(),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF101828)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item['roomCode'].toString(),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF667085)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['itemType'].toString(),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF155EEF)),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${currencyFormatter.format(amt)} đ',
                              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF101828)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Nhận: ${currencyFormatter.format(net)} đ',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF027A48)),
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
                    border: Border.all(color: const Color(0xFFEAECF0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CHI TIẾT KHOẢN THU / CHI',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF101828)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('1. Tổng tiền cọc giữ chỗ (${settlementItems.length} đơn):', style: const TextStyle(fontSize: 12, color: Color(0xFF667085))),
                          Text('${currencyFormatter.format(totalDeposit)} đ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF101828))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('2. Hoa hồng môi giới dịch vụ (Trừ):', style: TextStyle(fontSize: 12, color: Color(0xFFD92D20))),
                          Text('-${currencyFormatter.format(platformFee)} đ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD92D20))),
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
                            const Text('TỔNG CỘNG THỰC CHUYỂN:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF027A48))),
                            Text('${currencyFormatter.format(netSettlement)} đ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF027A48))),
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
                    border: Border.all(color: const Color(0xFFEAECF0)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'MÃ QR CHUYỂN KHOẢN CHO CHỦ TRỌ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF101828), letterSpacing: 0.3),
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
                        child: Image.network(
                          qrImageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.qr_code_2_rounded, size: 100, color: Color(0xFF155EEF)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF0C7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '⚡ Auto điền ${currencyFormatter.format(netSettlement)} đ cho ${widget.hostName}',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFB54708)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 6. Nút chuyển khoản
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('In Phiếu', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF344054))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing
                            ? null
                            : () => _processDisbursement(settlementItems, netSettlement),
                        icon: _isProcessing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(
                          _isProcessing ? 'ĐANG XỬ LÝ...' : 'XÁC NHẬN CHUYỂN KHOẢN',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF155EEF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    );
  }
}