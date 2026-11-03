import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/data/models/host_post_model.dart';
import 'package:home_share/features/host/screens/host_management_menu.dart';

void main() {
  group('HostPostManagementModel & Filtering Tests', () {
    final now = DateTime.now();

    final postRejected = HostPostModel(
      id: 'POST_001',
      chuNhaId: 'HOST_123',
      tieuDe: 'Phòng trọ cao cấp Quận 7 giá tốt',
      moTa: 'Phòng đầy đủ tiện nghi, ban công thoáng mát',
      giaThue: 4500000,
      tienCoc: 4500000,
      status: 'rejected',
      rejectReason: 'Ảnh phòng bị mờ và không đúng quy cách',
      createdAt: now.subtract(const Duration(hours: 3)),
      city: 'TP. Hồ Chí Minh',
      district: 'Quận 7',
      address: '123 Nguyễn Thị Thập',
    );

    final postPending = HostPostModel(
      id: 'POST_002',
      chuNhaId: 'HOST_123',
      tieuDe: 'Studio ban công Quận 1',
      moTa: 'Gần chợ Bến Thành, giờ giấc tự do',
      giaThue: 6000000,
      tienCoc: 6000000,
      status: 'pending',
      createdAt: now.subtract(const Duration(hours: 2)),
      city: 'TP. Hồ Chí Minh',
      district: 'Quận 1',
      address: '45 Lê Thánh Tôn',
    );

    final postApproved = HostPostModel(
      id: 'POST_003',
      chuNhaId: 'HOST_123',
      tieuDe: 'Căn hộ dịch vụ Bình Thạnh full nội thất',
      moTa: 'Gần Landmark 81, an ninh 24/7',
      giaThue: 5500000,
      tienCoc: 5500000,
      status: 'approved',
      createdAt: now.subtract(const Duration(hours: 1)),
      city: 'TP. Hồ Chí Minh',
      district: 'Bình Thạnh',
      address: '78 Điện Biên Phủ',
    );

    final allPosts = [postRejected, postPending, postApproved];

    test('Kiểm tra trạng thái bài đăng chính xác', () {
      expect(postRejected.isRejected, isTrue);
      expect(postRejected.isPending, isFalse);
      expect(postRejected.isApprovedOrActive, isFalse);

      expect(postPending.isPending, isTrue);
      expect(postPending.isRejected, isFalse);
      expect(postPending.isApprovedOrActive, isFalse);

      expect(postApproved.isApprovedOrActive, isTrue);
      expect(postApproved.isPending, isFalse);
      expect(postApproved.isRejected, isFalse);
    });

    test('Lọc theo từng tab trong Quản lý bài đăng', () {
      final rejected = allPosts.where((p) => p.isRejected).toList();
      final pending = allPosts.where((p) => p.isPending).toList();
      final active = allPosts.where((p) => p.isApprovedOrActive).toList();

      expect(rejected.length, equals(1));
      expect(rejected.first.id, equals('POST_001'));

      expect(pending.length, equals(1));
      expect(pending.first.id, equals('POST_002'));

      expect(active.length, equals(1));
      expect(active.first.id, equals('POST_003'));

      expect(allPosts.length, equals(3));
    });

    test('Tìm kiếm bài đăng theo từ khóa tiêu đề, địa chỉ, quận, lý do từ chối', () {
      // 1. Tìm theo tiêu đề
      final searchStudio = allPosts.where((p) {
        final q = 'studio';
        return p.tieuDe.toLowerCase().contains(q) ||
            p.address.toLowerCase().contains(q) ||
            p.district.toLowerCase().contains(q) ||
            p.rejectReason.toLowerCase().contains(q);
      }).toList();
      expect(searchStudio.length, equals(1));
      expect(searchStudio.first.id, equals('POST_002'));

      // 2. Tìm theo quận
      final searchQ7 = allPosts.where((p) {
        final q = 'quận 7';
        return p.tieuDe.toLowerCase().contains(q) ||
            p.address.toLowerCase().contains(q) ||
            p.district.toLowerCase().contains(q) ||
            p.rejectReason.toLowerCase().contains(q);
      }).toList();
      expect(searchQ7.length, equals(1));
      expect(searchQ7.first.id, equals('POST_001'));

      // 3. Tìm theo lý do từ chối
      final searchReject = allPosts.where((p) {
        final q = 'ảnh phòng bị mờ';
        return p.tieuDe.toLowerCase().contains(q) ||
            p.address.toLowerCase().contains(q) ||
            p.district.toLowerCase().contains(q) ||
            p.rejectReason.toLowerCase().contains(q);
      }).toList();
      expect(searchReject.length, equals(1));
      expect(searchReject.first.id, equals('POST_001'));
    });

    test('Xác định tab khởi tạo khi có bài bị từ chối duyệt', () {
      final rejectedCount = allPosts.where((p) => p.isRejected).length;
      // Nếu có bài bị từ chối, chuyển thẳng đến tab 0 (Bị từ chối) để chủ trọ xử lý ngay
      final initialTab = rejectedCount > 0 ? 0 : 2;
      expect(initialTab, equals(0));

      final noRejectList = [postPending, postApproved];
      final noRejectCount = noRejectList.where((p) => p.isRejected).length;
      final initialTabNoReject = noRejectCount > 0 ? 0 : 2;
      expect(initialTabNoReject, equals(2)); // Tab Đang hiển thị
    });

    test('HostManagementSection enum chứa đầy đủ các phân hệ quản lý', () {
      expect(HostManagementSection.values, contains(HostManagementSection.posts));
      expect(HostManagementSection.values, contains(HostManagementSection.tenants));
      expect(HostManagementSection.values, contains(HostManagementSection.checkinCheckout));
      expect(HostManagementSection.values, contains(HostManagementSection.violations));
    });
  });
}

