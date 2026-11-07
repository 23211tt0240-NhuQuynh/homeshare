import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/utils/transfer_order_code.dart';

void main() {
  group('TransferOrderCode', () {
    test('lấy 4 ký tự cuối từ orderCode dạng N-ABCD', () {
      expect(TransferOrderCode.last4FromOrderCode('3-L69H'), 'L69H');
      expect(TransferOrderCode.last4FromOrderCode('1-abcd'), 'ABCD');
    });

    test('lấy 4 ký tự cuối từ bookingId kiểu DP_ngày_mã_NT', () {
      expect(
        TransferOrderCode.last4FromBookingId(
          'DP_20261106_JgdbsIE1wYPmXawJL69h_NT968',
        ),
        'L69H',
      );
    });

    test('build ghép hostIndex với đuôi đơn', () {
      expect(
        TransferOrderCode.build(
          hostIndex: 1,
          orderCode: '3-L69H',
        ),
        '1-L69H',
      );
      expect(
        TransferOrderCode.build(
          hostIndex: 2,
          bookingId: 'DP_20261106_JgdbsIE1wYPmXawJL69h_NT968',
        ),
        '2-L69H',
      );
    });
  });
}
