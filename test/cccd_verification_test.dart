import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/profile/models/cccd_data.dart';

/// Hàm tính toán điều kiện gửi xác thực: bắt buộc đủ 3/3 bước
/// (Ảnh mặt trước + Ảnh mặt sau + Quét thông tin QR thẻ CCCD)
bool calculateCanSubmit({
  required bool hasFrontImage,
  required bool hasBackImage,
  required bool hasQrData,
}) {
  return hasFrontImage && hasBackImage && hasQrData;
}

void main() {
  group('CCCD QR Parsing & Data Integrity Tests', () {
    test('Parse CCCD QR tiêu chuẩn 7 trường hợp lệ', () {
      const qrPayload = '079198001234|025812345|Nguyễn Văn An|15081998|Nam|Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh|10122021';
      final cccd = CccdData.fromQrString(qrPayload);

      expect(cccd.idNumber, '079198001234');
      expect(cccd.oldCmnd, '025812345');
      expect(cccd.fullName, 'Nguyễn Văn An');
      expect(cccd.birthDate, '15/08/1998');
      expect(cccd.gender, 'Nam');
      expect(cccd.address, 'Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh');
      expect(cccd.issueDate, '10/12/2021');
      expect(cccd.isValid12Digits, isTrue);
    });

    test('Parse CCCD QR trường CMND cũ rỗng vẫn hợp lệ', () {
      const qrPayload = '001099009876||Trần Thị Bình|01011999|Nữ|Quận Hoàn Kiếm, TP. Hà Nội|05052022';
      final cccd = CccdData.fromQrString(qrPayload);

      expect(cccd.idNumber, '001099009876');
      expect(cccd.oldCmnd, isEmpty);
      expect(cccd.fullName, 'Trần Thị Bình');
      expect(cccd.birthDate, '01/01/1999');
      expect(cccd.gender, 'Nữ');
      expect(cccd.isValid12Digits, isTrue);
    });

    test('Parse ngày sinh định dạng dd/MM/yyyy sang DateTime chính xác', () {
      const birthDateStr = '15/08/1998';
      final parts = birthDateStr.split('/');
      expect(parts.length, 3);
      final parsedDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      expect(parsedDate.year, 1998);
      expect(parsedDate.month, 8);
      expect(parsedDate.day, 15);
    });

    test('Serialize và deserialize CccdData qua Map để lưu SharedPreferences Draft', () {
      const qrPayload = '051206004529||Trần Thanh Anh Toàn|21082006|Nam|Khu Dân Cư 22, Thôn 4, Đức Chánh, Mộ Đức, Quảng Ngãi|20012022';
      final cccd = CccdData.fromQrString(qrPayload);
      final map = cccd.toMap();
      final restored = CccdData.fromMap(map);

      expect(restored.idNumber, '051206004529');
      expect(restored.fullName, 'Trần Thanh Anh Toàn');
      expect(restored.gender, 'Nam');
      expect(restored.birthDate, '21/08/2006');
      expect(restored.address, contains('Mộ Đức, Quảng Ngãi'));
      expect(restored.provinceName, 'Quảng Ngãi');
      expect(restored.analyzedBirthYear, 2006);
    });
  });

  group('CCCD Verification Submission Conditions (Bắt buộc đủ 3/3 bước)', () {
    test('Khi chỉ có dữ liệu quét CCCD nhưng chưa có đủ ảnh 2 mặt, nút xác thực BỊ KHÓA', () {
      final canSubmit = calculateCanSubmit(
        hasFrontImage: false,
        hasBackImage: false,
        hasQrData: true,
      );

      expect(canSubmit, isFalse);
    });

    test('Khi chỉ có ảnh mặt trước và quét mã QR, thiếu ảnh mặt sau, nút xác thực BỊ KHÓA', () {
      final canSubmit = calculateCanSubmit(
        hasFrontImage: true,
        hasBackImage: false,
        hasQrData: true,
      );

      expect(canSubmit, isFalse);
    });

    test('Khi chỉ có ảnh 2 mặt nhưng chưa quét mã QR, nút xác thực BỊ KHÓA', () {
      final canSubmit = calculateCanSubmit(
        hasFrontImage: true,
        hasBackImage: true,
        hasQrData: false,
      );

      expect(canSubmit, isFalse);
    });

    test('Khi chưa có bất kỳ thông tin nào, nút xác thực BỊ KHÓA', () {
      final canSubmit = calculateCanSubmit(
        hasFrontImage: false,
        hasBackImage: false,
        hasQrData: false,
      );

      expect(canSubmit, isFalse);
    });

    test('Chỉ khi hoàn tất đủ cả 3 bước (ảnh mặt trước + ảnh mặt sau + quét mã QR), nút xác thực mới MỞ', () {
      final canSubmit = calculateCanSubmit(
        hasFrontImage: true,
        hasBackImage: true,
        hasQrData: true,
      );

      expect(canSubmit, isTrue);
    });
  });
}
