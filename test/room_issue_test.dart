import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/utils/id_generator.dart';
import 'package:home_share/core/utils/room_issue_policy.dart';
import 'package:home_share/data/models/room_issue_model.dart';
import 'package:home_share/features/host/notifications/models/host_notification_model.dart';
import 'package:home_share/features/host/notifications/notification_types.dart';

void main() {
  group('RoomIssueCategories & Severities Tests', () {
    test('Danh mục sự cố có đủ 8 loại cơ bản', () {
      expect(RoomIssueCategories.all.length, 8);
      expect(RoomIssueCategories.all, contains(RoomIssueCategories.electricity));
      expect(RoomIssueCategories.all, contains(RoomIssueCategories.plumbing));
      expect(RoomIssueCategories.all, contains(RoomIssueCategories.hvac));
      expect(RoomIssueCategories.all, contains(RoomIssueCategories.doorLock));
      expect(RoomIssueCategories.all, contains(RoomIssueCategories.wifi));
      expect(RoomIssueCategories.all, contains(RoomIssueCategories.furniture));
      expect(RoomIssueCategories.all, contains(RoomIssueCategories.leaksWalls));
      expect(RoomIssueCategories.all, contains(RoomIssueCategories.other));
    });

    test('Chuyển đổi mức độ khẩn cấp sang tiếng Việt chuẩn xác', () {
      expect(RoomIssueSeverities.toDisplayVi(RoomIssueSeverities.low), 'Bình thường');
      expect(RoomIssueSeverities.toDisplayVi(RoomIssueSeverities.medium), 'Cần sửa sớm');
      expect(RoomIssueSeverities.toDisplayVi(RoomIssueSeverities.high), 'Khẩn cấp');
      expect(RoomIssueSeverities.toDisplayVi('unknown'), 'Cần sửa sớm');
    });

    test('Chuyển đổi trạng thái xử lý sang tiếng Việt chuẩn xác', () {
      expect(RoomIssueStatuses.toDisplayVi(RoomIssueStatuses.pending), 'Chờ tiếp nhận');
      expect(RoomIssueStatuses.toDisplayVi(RoomIssueStatuses.inProgress), 'Đang xử lý');
      expect(RoomIssueStatuses.toDisplayVi(RoomIssueStatuses.resolved), 'Đã khắc phục');
      expect(RoomIssueStatuses.toDisplayVi(RoomIssueStatuses.cancelled), 'Đã hủy');
    });
  });

  group('RoomIssuePolicy Validation Tests', () {
    test('Dữ liệu hợp lệ trả về null (không có lỗi)', () {
      final error = RoomIssuePolicy.validate(
        category: RoomIssueCategories.plumbing,
        description: 'Vòi sen bị rò rỉ nước liên tục trong nhà vệ sinh',
        reporterPhone: '0901234567',
      );
      expect(error, isNull);
    });

    test('Danh mục rỗng hoặc không nằm trong danh mục chuẩn bị báo lỗi', () {
      final err1 = RoomIssuePolicy.validate(
        category: '',
        description: 'Vòi sen bị hỏng',
        reporterPhone: '0901234567',
      );
      expect(err1, isNotNull);

      final err2 = RoomIssuePolicy.validate(
        category: 'Sự cố sao hỏa',
        description: 'Vòi sen bị hỏng',
        reporterPhone: '0901234567',
      );
      expect(err2, isNotNull);
    });

    test('Mô tả sự cố rỗng hoặc ngắn hơn 5 ký tự bị báo lỗi', () {
      final errEmpty = RoomIssuePolicy.validate(
        category: RoomIssueCategories.electricity,
        description: '',
        reporterPhone: '0901234567',
      );
      expect(errEmpty, isNotNull);

      final errShort = RoomIssuePolicy.validate(
        category: RoomIssueCategories.electricity,
        description: 'Hỏng',
        reporterPhone: '0901234567',
      );
      expect(errShort, isNotNull);
    });

    test('Số điện thoại liên hệ không hợp lệ bị báo lỗi', () {
      final errPhone1 = RoomIssuePolicy.validate(
        category: RoomIssueCategories.wifi,
        description: 'Wifi phòng ngủ mất mạng từ tối qua',
        reporterPhone: '',
      );
      expect(errPhone1, isNotNull);

      final errPhone2 = RoomIssuePolicy.validate(
        category: RoomIssueCategories.wifi,
        description: 'Wifi phòng ngủ mất mạng từ tối qua',
        reporterPhone: '123',
      );
      expect(errPhone2, isNotNull);
    });

    test('Khởi tạo thông báo formatHostMessage và formatTenantMessage chuẩn', () {
      final hostMsg = RoomIssuePolicy.formatHostMessage(
        reporterName: 'Nguyễn Văn An',
        reporterPhone: '0901234567',
        category: RoomIssueCategories.hvac,
        severity: RoomIssueSeverities.high,
        description: 'Điều hòa chảy nước xuống giường',
      );
      expect(hostMsg, contains('Nguyễn Văn An'));
      expect(hostMsg, contains('0901234567'));
      expect(hostMsg, contains('Khẩn cấp'));
      expect(hostMsg, contains(RoomIssueCategories.hvac));

      final tenantMsg = RoomIssuePolicy.formatTenantMessage(
        category: RoomIssueCategories.hvac,
        hostName: 'Trần Văn Bình',
      );
      expect(tenantMsg, contains('Trần Văn Bình'));
      expect(tenantMsg, contains(RoomIssueCategories.hvac));
    });
  });

  group('RoomIssueModel Serialization & State Tests', () {
    test('Khởi tạo và toFirestore / fromMap giữ nguyên toàn vẹn dữ liệu', () {
      final now = DateTime(2026, 11, 2, 14, 0);
      final issue = RoomIssueModel(
        id: 'SC_123456',
        bookingId: 'DP_001',
        roomId: 'R_101',
        roomTitle: 'Phòng 101 - Ban công thoáng',
        hostId: 'H_001',
        hostName: 'Chủ trọ Bình',
        reporterId: 'U_001',
        reporterName: 'Nguyễn Văn An',
        reporterPhone: '0901234567',
        category: RoomIssueCategories.doorLock,
        severity: RoomIssueSeverities.high,
        description: 'Khóa cửa phòng bị kẹt không mở được chìa',
        imageUrls: const ['path/to/img1.jpg', 'path/to/img2.jpg'],
        status: RoomIssueStatuses.pending,
        createdAt: now,
      );

      final map = issue.toFirestore();
      expect(map['id'], 'SC_123456');
      expect(map['targetType'], 'room_issue');
      expect(map['category'], RoomIssueCategories.doorLock);
      expect(map['severity'], RoomIssueSeverities.high);
      expect((map['imageUrls'] as List).length, 2);

      final restored = RoomIssueModel.fromMap(map, 'SC_123456');
      expect(restored.id, 'SC_123456');
      expect(restored.roomTitle, 'Phòng 101 - Ban công thoáng');
      expect(restored.isPending, isTrue);
      expect(restored.isInProgress, isFalse);
      expect(restored.isResolved, isFalse);
      expect(restored.isCancelled, isFalse);
      expect(restored.severityDisplayVi, 'Khẩn cấp');
      expect(restored.statusDisplayVi, 'Chờ tiếp nhận');
    });

    test('copyWith cập nhật trạng thái đã giải quyết chính xác', () {
      final now = DateTime(2026, 11, 2, 14, 0);
      final issue = RoomIssueModel(
        id: 'SC_123456',
        bookingId: 'DP_001',
        roomId: 'R_101',
        roomTitle: 'Phòng 101',
        hostId: 'H_001',
        reporterId: 'U_001',
        reporterName: 'An',
        reporterPhone: '0901234567',
        category: RoomIssueCategories.wifi,
        description: 'Mất kết nối mạng',
        createdAt: now,
      );

      final resolved = issue.copyWith(
        status: RoomIssueStatuses.resolved,
        resolvedAt: now.add(const Duration(hours: 2)),
        hostNotes: 'Đã thay mới modem wifi tầng 1',
      );

      expect(resolved.isResolved, isTrue);
      expect(resolved.isPending, isFalse);
      expect(resolved.statusDisplayVi, 'Đã khắc phục');
      expect(resolved.hostNotes, 'Đã thay mới modem wifi tầng 1');
    });

    test('IdGenerator.roomIssue sinh mã tiền tố SC_', () {
      final id = IdGenerator.roomIssue();
      expect(id.startsWith('SC_'), isTrue);
    });
  });

  group('Host Notifications Room Issue Integration Tests', () {
    test('Thông báo sự cố phòng trọ ánh xạ chuẩn sang HostNotificationModel và nằm ở Tab "Đang xử lý"', () {
      final notifData = {
        'id': 'NF_SC_001',
        'receiverId': 'H_001',
        'senderId': 'U_001',
        'notificationType': 'pendingAction',
        'type': 'room_issue',
        'actionType': 'room_issue',
        'title': 'Báo cáo sự cố: Nước & Thiết bị vệ sinh (Phòng SE)',
        'message': 'Vòi sen toilet bị rò rỉ nước liên tục',
        'roomId': 'R_SE',
        'roomTitle': 'Phòng SE',
        'bookingId': 'BK_001',
        'bookingCode': 'BK_001',
        'renterName': 'Trần Thanh Anh Toàn',
        'reporterName': 'Trần Thanh Anh Toàn',
        'reporterPhone': '0382542737',
        'issueId': 'SC_001',
        'category': 'Nước & Thiết bị vệ sinh',
        'severity': 'medium',
        'imageUrls': ['path/img1.jpg'],
        'statusId': 'pending',
        'status': 'pending',
        'isRead': false,
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Import HostNotificationModel & HostNotificationType
      final hostNotif = HostNotificationModel.fromMap(notifData, 'NF_SC_001');

      expect(hostNotif.id, 'NF_SC_001');
      expect(hostNotif.isRoomIssue, isTrue);
      expect(hostNotif.type, HostNotificationType.pendingAction); // Phải nằm ở tab "Đang xử lý"
      expect(hostNotif.category, 'Nước & Thiết bị vệ sinh');
      expect(hostNotif.severity, 'medium');
      expect(hostNotif.reporterPhone, '0382542737');
      expect(hostNotif.renterName, 'Trần Thanh Anh Toàn');
      expect(hostNotif.roomTitle, 'Phòng SE');
      expect(hostNotif.issueId, 'SC_001');
      expect(hostNotif.imageUrls.length, 1);
    });
  });
}
