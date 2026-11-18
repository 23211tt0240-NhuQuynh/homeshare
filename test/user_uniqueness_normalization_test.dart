import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/services/user_uniqueness_service.dart';

void main() {
  test('chuẩn hóa SĐT loại bỏ ký tự trình bày', () {
    expect(
      UserUniquenessService.normalizePhone('0912 345-678'),
      '0912345678',
    );
  });

  test('chuẩn hóa CCCD chỉ giữ chữ số', () {
    expect(
      UserUniquenessService.normalizeCccd('079-203A 001234'),
      '079203001234',
    );
  });

  test('chuẩn hóa STK loại bỏ ký tự trình bày và viết hoa', () {
    expect(
      UserUniquenessService.normalizeBankAccount('ab 12-34.56'),
      'AB123456',
    );
  });
}
