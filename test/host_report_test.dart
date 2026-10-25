import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/utils/host_report_policy.dart';
import 'package:home_share/core/utils/id_generator.dart';

void main() {
  group('HostReportPolicy', () {
    test('phải đăng nhập và không tự báo cáo', () {
      expect(
        HostReportPolicy.canReport(reporterId: '', hostId: 'host1'),
        isFalse,
      );
      expect(
        HostReportPolicy.canReport(reporterId: 'host1', hostId: 'host1'),
        isFalse,
      );
      expect(
        HostReportPolicy.canReport(reporterId: 'renter1', hostId: 'host1'),
        isTrue,
      );
    });

    test('phải chọn ít nhất một lý do', () {
      expect(
        HostReportPolicy.validate(
          reporterId: 'renter1',
          hostId: 'host1',
          selectedReasons: const [],
          otherText: '',
        ),
        'Vui lòng chọn ít nhất một lý do.',
      );
    });

    test('chọn nhiều lý do có sẵn thì không cần khung khác', () {
      expect(
        HostReportPolicy.validate(
          reporterId: 'renter1',
          hostId: 'host1',
          selectedReasons: HostReportPolicy.reasons.take(2),
          otherText: '',
          evidenceCount: 1,
        ),
        isNull,
      );
    });

    test('lý do khác bắt buộc nhập text', () {
      expect(
        HostReportPolicy.validate(
          reporterId: 'renter1',
          hostId: 'host1',
          selectedReasons: const [HostReportPolicy.otherReason],
          otherText: '',
        ),
        'Vui lòng nhập lý do khác.',
      );
      expect(
        HostReportPolicy.validate(
          reporterId: 'renter1',
          hostId: 'host1',
          selectedReasons: [
            HostReportPolicy.reasons.first,
            HostReportPolicy.otherReason,
          ],
          otherText: 'Nhắn chuyển khoản lạ',
          evidenceCount: 1,
        ),
        isNull,
      );
    });

    test('mọi lý do đều bắt buộc ảnh minh chứng', () {
      expect(
        HostReportPolicy.validate(
          reporterId: 'renter1',
          hostId: 'host1',
          selectedReasons: HostReportPolicy.reasons.take(1),
          otherText: '',
        ),
        'Vui lòng thêm ít nhất một ảnh minh chứng.',
      );
    });

    test('tối đa 5 ảnh minh chứng', () {
      expect(
        HostReportPolicy.validate(
          reporterId: 'renter1',
          hostId: 'host1',
          selectedReasons: HostReportPolicy.reasons.take(1),
          otherText: '',
          evidenceCount: 6,
        ),
        'Tối đa 5 ảnh minh chứng.',
      );
    });

    test('mã báo cáo bắt đầu bằng BC_', () {
      expect(IdGenerator.hostReport(), startsWith('BC_'));
    });
  });
}
