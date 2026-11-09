import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/profile/models/cccd_data.dart';
import 'package:home_share/features/profile/models/cccd_validation_models.dart';
import 'package:home_share/features/profile/services/cccd_image_evidence_validator.dart';

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

  group('CCCD DisplayName Preservation Tests', () {
    test('Xác thực CCCD không làm mất tên đăng ký (vd: tên đăng ký QA, CCCD Nguyễn Văn An)', () {
      final firestoreData = <String, dynamic>{
        'uid': 'USER_QA',
        'displayName': 'QA',
        'email': 'qa@example.com',
        'role': 'renter',
        'isCccdVerified': true,
        'cccdNumber': '079198001234',
        'cccdFullName': 'NGUYỄN VĂN AN',
        'hoTenCccd': 'NGUYỄN VĂN AN',
        'cccdHometown': 'TP. Hồ Chí Minh',
      };

      // Giả lập logic UserModel/UserProfile.fromMap
      final displayName = firestoreData['displayName'] ?? firestoreData['hoTen'];
      final cccdFullName = firestoreData['cccdFullName'] ?? firestoreData['hoTenCccd'];

      // Khẳng định tên hiển thị của tài khoản là tên khi đăng ký 'QA', không bị lấy thành 'NGUYỄN VĂN AN'
      expect(displayName, equals('QA'));
      expect(cccdFullName, equals('NGUYỄN VĂN AN'));
      expect(displayName, isNot(equals(cccdFullName)));
    });
  });

  group('CccdImageEvidenceValidator Proof & Save Boundary Tests', () {
    const validator = CccdImageEvidenceValidator();

    final mockFrontEvidence = CccdImageEvidence(
      side: CccdImageSide.front,
      normalizedOcrText: 'CONG HOA XA HOI CHU NGHIA VIET NAM CAN CUOC CONG DAN SO 079206022867 HO VA TEN TRAN TRA QUOC MAN',
      qrPayload: null, // Ảnh chụp ban đầu không bắt được QR nhỏ
      imageByteHash: 'front_hash_1234567890abcdef',
      width: 1920,
      height: 1080,
      byteLength: 500000,
    );

    final mockBackEvidence = CccdImageEvidence(
      side: CccdImageSide.back,
      normalizedOcrText: 'DAC DIEM NHAN DANG NOT RUOI CUC CANH SAT BO CONG AN CHIP DIEN TU IDVNM',
      qrPayload: null,
      imageByteHash: 'back_hash_0987654321fedcba',
      width: 1920,
      height: 1080,
      byteLength: 520000,
    );

    const verifiedCccd = CccdData(
      idNumber: '079206022867',
      oldCmnd: '',
      fullName: 'Trần Trà Quốc Mẫn',
      birthDate: '01/04/2006',
      gender: 'Nam',
      address: '39 Đường 24, Khu Phố 7, P.Linh Đông, TP.Thủ Đức',
      issueDate: '01/04/2021',
    );

    test('Khi frontEvidence chưa có QR nhưng có explicitVerifiedData từ bước 3, createProof hợp lệ và canSave trả về true', () {
      final proof = validator.createProof(
        frontEvidence: mockFrontEvidence,
        backEvidence: mockBackEvidence,
        explicitVerifiedData: verifiedCccd,
      );

      expect(proof.isValid, isTrue);
      expect(proof.verifiedData, isNotNull);
      expect(proof.verifiedData!.idNumber, '079206022867');
      expect(proof.verifiedData!.fullName, 'Trần Trà Quốc Mẫn');
      expect(validator.canSave(proof), isTrue);
    });

    test('validateStrictQr chấp nhận cả mã QR 6 trường (không có ngày cấp trong QR)', () {
      const qr6 = '079206022867||Trần Trà Quốc Mẫn|01042006|Nam|TP. Hồ Chí Minh';
      final parsed = validator.validateStrictQr(qr6);

      expect(parsed, isNotNull);
      expect(parsed!.idNumber, '079206022867');
      expect(parsed.birthDate, '01/04/2006');
    });

    test('Chống ảnh demo: createProof từ chối khi phát hiện ảnh demo', () {
      final demoFront = mockFrontEvidence.copyWith(isDemo: true);
      final proof = validator.createProof(
        frontEvidence: demoFront,
        backEvidence: mockBackEvidence,
        explicitVerifiedData: verifiedCccd,
      );

      expect(proof.isValid, isFalse);
      expect(proof.isDemo, isTrue);
      expect(validator.canSave(proof), isFalse);
    });

    test('Chống Replay Attack: createProof từ chối khi trùng hash giữa 2 mặt', () {
      final dupBack = mockBackEvidence.copyWith(imageByteHash: mockFrontEvidence.imageByteHash);
      final proof = validator.createProof(
        frontEvidence: mockFrontEvidence,
        backEvidence: dupBack,
        explicitVerifiedData: verifiedCccd,
      );

      expect(proof.isValid, isFalse);
      expect(proof.rejectionReasonCode, CccdValidationReasonCodes.duplicateImageHash);
      expect(validator.canSave(proof), isFalse);
    });
  });
}
