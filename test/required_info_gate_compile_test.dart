import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/main.dart';

void main() {
  test('AuthGate có thể biên dịch cùng luồng nhắc thông tin bắt buộc', () {
    expect(const AuthGate(), isA<AuthGate>());
  });
}
