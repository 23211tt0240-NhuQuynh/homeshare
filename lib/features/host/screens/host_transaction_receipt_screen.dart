import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../admin/screens/settlement_receipt_screen.dart';
import '../../admin/utils/booking_utils.dart';

// Chủ trọ - Lập bảng kê biên lai từ các đơn thuộc phiếu giải ngân;
// dùng phí đã lưu hoặc tỷ lệ trên phiếu, không lấy tỷ lệ cấu hình hiện tại.
List<Map<String, dynamic>> hostSettlementReceiptItems(
  Map<String, dynamic> settlement,
  List<Map<String, dynamic>> bookings,
) {
  final ids = ((settlement['bookingIds'] as List?) ?? const [])
      .map((id) => id.toString())
      .toSet();
  if (ids.isEmpty) {
    throw StateError('Phiếu giải ngân chưa có danh sách đơn thuê.');
  }
  final byId = {for (final booking in bookings) '${booking['id']}': booking};
  num? number(dynamic value) => value is num ? value : num.tryParse('$value');
  return ids.map((id) {
    final raw = byId[id];
    if (raw == null) {
      throw StateError('Không tìm thấy đơn thuê $id của phiếu giải ngân.');
    }
    final booking = BookingUtils.canonical(raw);
    final gross = BookingUtils.amount(booking).round();
    final rate = number(settlement['platformFeeRate']);
    final fee =
        number(booking['platformFee'])?.round() ??
        (rate == null ? null : (gross * rate / 100).round());
    if (fee == null) {
      throw StateError('Đơn thuê $id chưa có thông tin phí đã quyết toán.');
    }
    return <String, dynamic>{
      'docId': id,
      'orderCode': booking['userCode'] ?? booking['orderCode'] ?? id,
      'renterName': booking['renterName'] ?? 'Chưa cập nhật',
      'roomCode':
          booking['roomTitle'] ?? booking['roomCode'] ?? 'Chưa cập nhật',
      'amount': gross,
      'fee': fee,
      'net': gross - fee,
    };
  }).toList();
}

// Chủ trọ - Chi tiết giao dịch - Từ giao dịch gần đây mở biên lai của phiếu;
// In phiếu PDF mở chức năng in, Hoàn tất hoặc nút quay lại trở về thống kê.
class HostTransactionReceiptScreen extends StatelessWidget {
  const HostTransactionReceiptScreen({
    super.key,
    required this.settlement,
    required this.bookings,
  });
  final Map<String, dynamic> settlement;
  final List<Map<String, dynamic>> bookings;

  @override
  Widget build(BuildContext context) {
    try {
      final items = hostSettlementReceiptItems(settlement, bookings);
      final rawDate = settlement['createdAt'];
      final date = rawDate is Timestamp
          ? rawDate.toDate()
          : rawDate is DateTime
          ? rawDate
          : DateTime.tryParse('$rawDate');
      if (date == null) {
        throw StateError('Phiếu giải ngân chưa có thời gian xác nhận.');
      }
      final rawAmount = settlement['totalAmount'];
      final amount = rawAmount is num
          ? rawAmount.toDouble()
          : double.tryParse('$rawAmount');
      if (amount == null) {
        throw StateError('Phiếu giải ngân chưa có tổng tiền thực chuyển.');
      }
      final itemTotal = items.fold<num>(
        0,
        (subtotal, item) => subtotal + (item['net'] as num),
      );
      final notice = (itemTotal - amount).abs() > .5
          ? 'Bảng kê đơn thuê hiện tại chênh lệch với tổng tiền trên phiếu. Tổng thực chuyển hiển thị theo phiếu admin đã lưu.'
          : null;
      return SettlementReceiptScreen(
        amount: amount,
        hostName: '${settlement['hostName'] ?? 'Chưa cập nhật'}',
        hostBankName: '${settlement['hostBankName'] ?? 'Chưa cập nhật'}',
        hostAccountNumber:
            '${settlement['hostAccountNumber'] ?? 'Chưa cập nhật'}',
        receiptCode: '${settlement['receiptCode'] ?? settlement['id']}',
        executedAt: date,
        settlementItems: items,
        reconciliationNotice: notice,
      );
    } on StateError catch (error) {
      // Chủ trọ - Báo thiếu dữ liệu đối soát, tránh hiển thị tiền hoặc ngày giả.
      return Scaffold(
        appBar: AppBar(title: const Text('Biên lai giao dịch')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_long_outlined, size: 44),
                const SizedBox(height: 16),
                Text(error.message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Quay lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}
