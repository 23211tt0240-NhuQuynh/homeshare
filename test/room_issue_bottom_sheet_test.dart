import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/data/models/booking_model.dart';
import 'package:home_share/data/models/room_issue_model.dart';
import 'package:home_share/features/renter/widgets/report_room_issue_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleBooking = BookingRequestModel(
    id: 'BK_TEST_01',
    renterId: 'RENTER_TOAN_01',
    renterName: 'Trần Thanh Anh Toàn',
    renterPhone: '0382542737',
    roomId: 'ROOM_SE',
    roomTitle: 'Phòng SE',
    roomAddress: 'Six Seven, P. Hiệp Bình Chánh, TP. Thủ Đức',
    roomPrice: 5000000,
    deposit: 2500000,
    status: 'active',
    hostId: 'HOST_QA_01',
    hostName: 'QA',
    moveInDate: DateTime(2026, 11, 3),
    createdAt: DateTime(2026, 11, 1),
  );

  Widget createTestWidget({BookingRequestModel? booking}) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: ReportRoomIssueBottomSheet(
            booking: booking ?? sampleBooking,
          ),
        ),
      ),
    );
  }

  group('ReportRoomIssueBottomSheet UI & Validation Tests', () {
    testWidgets('Khởi tạo giao diện chuẩn với thông tin phòng và người báo', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tiêu đề & Thông tin phòng
      expect(find.text('Báo Cáo Sự Cố Phòng'), findsOneWidget);
      expect(find.textContaining('Phòng SE'), findsOneWidget);
      expect(find.textContaining('Chủ trọ: QA'), findsOneWidget);

      // Danh mục & Mức độ khẩn cấp
      expect(find.text('1. Loại sự cố cần hỗ trợ (*)'), findsOneWidget);
      expect(find.text('2. Mức độ khẩn cấp'), findsOneWidget);
      expect(find.text('3. Mô tả cụ thể sự cố (*)'), findsOneWidget);
      expect(find.text('5. Thông tin người báo sự cố'), findsOneWidget);

      // Nút gửi báo cáo
      expect(find.text('GỬI BÁO CÁO SỰ CỐ ĐẾN CHỦ TRỌ'), findsOneWidget);

      // Thông tin người báo điền sẵn
      expect(find.text('Trần Thanh Anh Toàn'), findsOneWidget);
      expect(find.text('0382542737'), findsOneWidget);
    });

    testWidgets('Bấm gửi khi ô mô tả còn rỗng: Hiển thị cảnh báo đỏ trực quan, không gửi đi', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Cuộn xuống nút gửi và nhấn
      final submitBtn = find.text('GỬI BÁO CÁO SỰ CỐ ĐẾN CHỦ TRỌ');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Xác thực cảnh báo đỏ nội tuyến xuất hiện
      expect(find.text('* Bắt buộc nhập'), findsOneWidget);
      expect(find.textContaining('Vui lòng nhập mô tả hoặc chọn gợi ý bên dưới'), findsWidgets);
    });

    testWidgets('Chạm vào chip gợi ý nhanh (Quick Suggestion): Tự động điền mô tả và xóa cảnh báo lỗi', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 1. Nhấn gửi trước để kích hoạt lỗi
      final submitBtn = find.text('GỬI BÁO CÁO SỰ CỐ ĐẾN CHỦ TRỌ');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();
      expect(find.text('* Bắt buộc nhập'), findsOneWidget);

      // 2. Chạm vào chip gợi ý đầu tiên (ví dụ: 'Mất điện toàn phòng')
      final suggestionChip = find.text('Mất điện toàn phòng');
      expect(suggestionChip, findsOneWidget);
      await tester.tap(suggestionChip);
      await tester.pumpAndSettle();

      // 3. Ô mô tả đã được tự động điền nội dung và lỗi biến mất
      expect(find.text('Mất điện toàn phòng'), findsWidgets); // xuất hiện cả ở chip và trong TextField
      expect(find.text('* Bắt buộc nhập'), findsNothing);
    });

    testWidgets('Đổi loại sự cố sang "Máy lạnh / Điều hòa": Gợi ý nhanh tự động cập nhật', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Chọn loại "Máy lạnh / Điều hòa"
      final hvacChip = find.text(RoomIssueCategories.hvac);
      expect(hvacChip, findsOneWidget);
      await tester.tap(hvacChip);
      await tester.pumpAndSettle();

      // Các gợi ý nhanh phải đổi sang chủ đề máy lạnh
      expect(find.text('Máy lạnh không mát'), findsOneWidget);
      expect(find.text('Máy lạnh chảy nước'), findsOneWidget);
      expect(find.text('Hỏng remote máy lạnh'), findsOneWidget);

      // Chạm vào 'Máy lạnh không mát'
      await tester.tap(find.text('Máy lạnh không mát'));
      await tester.pumpAndSettle();
      expect(find.text('Máy lạnh không mát'), findsWidgets);
    });

    testWidgets('Xác thực số điện thoại: Báo lỗi khi số điện thoại không hợp lệ', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Điền mô tả hợp lệ vào TextField mô tả
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'Mô tả sự cố phòng trọ chi tiết');
      await tester.pumpAndSettle();

      // Sửa số điện thoại thành quá ngắn (123)
      await tester.enterText(textFields.last, '123');
      await tester.pumpAndSettle();

      // Nhấn gửi
      final submitBtn = find.text('GỬI BÁO CÁO SỰ CỐ ĐẾN CHỦ TRỌ');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Cảnh báo số điện thoại không hợp lệ xuất hiện trên banner hoặc errorText
      expect(find.textContaining('9-11'), findsWidgets);
    });
  });
}
