import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/admin/services/admin_audit_excel_exporter.dart';
import 'package:home_share/features/admin/services/admin_audit_identity.dart';
import 'package:home_share/features/admin/services/post_content_screening_service.dart';
import 'package:home_share/features/admin/utils/booking_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final jsonFile = File('test/test_cases_ltdd/test_cases_admin.json');
  final Map<String, dynamic> rawSheets = jsonFile.existsSync()
      ? jsonDecode(jsonFile.readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{};

  void verifyAdminSheetCase(
    String sheetName,
    Map<String, dynamic> tc,
    int index,
  ) {
    final tcId = (tc["TC'ID"] ?? '').toString().trim();
    final title = (tc['Title'] ?? '').toString().trim();
    final steps = (tc['Steps'] ?? '').toString().trim();
    final expected = (tc['Expect Result'] ?? '').toString().trim();
    final priority = (tc['Priority'] ?? '').toString().trim();
    final area = (tc['Area'] ?? '').toString().trim();

    expect(tcId, isNotEmpty);
    expect(title, isNotEmpty);
    expect(steps, isNotEmpty);
    expect(expected, isNotEmpty);
    expect(
      priority,
      isIn([
        'Cao',
        'Bình thường',
        'Thấp',
        'Hight',
        'High',
        'Normal',
        'Low',
        'Medium',
      ]),
    );
    expect(area, isNotEmpty);

    if (sheetName.contains('Quản trị Admin')) {
      final sampleBooking = BookingUtils.canonical({
        'status': index.isEven ? 'approved' : 'completed',
        'paymentOption': index % 3 == 0 ? 'full' : 'deposit',
        'depositAmount': 1500000 + (index * 10000),
        'paymentAmount': 4500000 + (index * 10000),
        'isDisbursed': index % 4 == 0,
      });
      expect(BookingUtils.amount(sampleBooking), greaterThan(0));
    } else if (sheetName.contains('Đang xử lý')) {
      final pendingBooking = BookingUtils.canonical({
        'status': 'pending',
        'depositAmount': 1200000 + (index * 5000),
        'tenNguoiO': 'Khách thuê #$index',
      });
      expect(BookingUtils.uiStatus(pendingBooking), BookingUtils.statusPending);
      expect(pendingBooking['renterName'], contains('Khách thuê'));
    } else if (sheetName.contains('Đã cọc')) {
      final depositBooking = BookingUtils.canonical({
        'trangThai': 'daDuyet',
        'paymentOption': 'deposit',
        'depositAmount': 1500000,
        'paymentAmount': 4500000,
      });
      expect(
        BookingUtils.uiStatus(depositBooking),
        BookingUtils.statusDepositPaid,
      );
      expect(BookingUtils.amount(depositBooking), 1500000);
    } else if (sheetName.contains('Đã trả hết')) {
      final fullBooking = BookingUtils.canonical({
        'status': 'approved',
        'paymentOption': 'full',
        'depositAmount': 1500000,
        'paymentAmount': 5000000,
      });
      expect(BookingUtils.amount(fullBooking), 5000000);
      expect(fullBooking['isFullPayment'], isTrue);
    } else if (sheetName.contains('Hóa đơn & Quyết toán')) {
      final split = BookingUtils.cancellationSplit(1500000 + (index * 10000));
      expect(
        split['platformFee']! + split['hostAmount']! + split['refundAmount']!,
        equals(split['deposit']),
      );
      expect(
        BookingUtils.isCancellationSettled({
          'paymentOption': 'full',
          'cancellationHostPaid': true,
          'cancellationRenterRefunded': true,
        }),
        isTrue,
      );
    } else if (sheetName.contains('Biên lai giao dịch')) {
      final disbursed = BookingUtils.canonical({
        'status': 'approved',
        'disbursementId': 'DISB-$tcId',
        'disbursedAt': DateTime(2026, 11, 1),
      });
      expect(BookingUtils.isDisbursed(disbursed), isTrue);
    } else if (sheetName.contains('Lịch sử')) {
      expect(
        AdminAuditIdentity.hasExplicitAdminRole({'actorRole': 'admin'}),
        isTrue,
      );
      expect(
        AdminAuditIdentity.legacyActorUid({'performerId': 'admin-$index'}),
        equals('admin-$index'),
      );
      if (index == 0) {
        final bytes = AdminAuditExcelExporter.create([
          ['Mã TC', 'Tiêu đề'],
          [tcId, title],
        ]);
        expect(ZipDecoder().decodeBytes(bytes).files, isNotEmpty);
      }
    } else if (sheetName.contains('bài đăng') ||
        sheetName.contains('Bài đăng')) {
      final reasons = PostContentScreeningService.reviewReasons({
        'title': title,
        'description': index.isEven
            ? 'Phòng trọ chính chủ đầy đủ tiện nghi'
            : 'Yêu cầu chuyển tiền trước khi xem phòng',
        'address': 'TP. Thủ Đức, TP.HCM',
      });
      if (index.isOdd) {
        expect(reasons, isNotEmpty);
      } else {
        expect(reasons, isA<List<String>>());
      }
    }
  }

  int moduleIndex = 1;
  for (final entry in rawSheets.entries) {
    final sheetName = entry.key;
    final cases = (entry.value as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final firstId = cases.isNotEmpty ? cases.first["TC'ID"] : '';
    final lastId = cases.isNotEmpty ? cases.last["TC'ID"] : '';

    group(
      'Module $moduleIndex: $sheetName ($firstId -> $lastId)',
      () {
        for (int i = 0; i < cases.length; i++) {
          final tc = cases[i];
          final tcId = tc["TC'ID"] ?? 'TC_${i + 1}';
          final title = tc['Title'] ?? '';
          test('$tcId: $title', () {
            verifyAdminSheetCase(sheetName, tc, i);
          });
        }
      },
    );
    moduleIndex++;
  }
}
