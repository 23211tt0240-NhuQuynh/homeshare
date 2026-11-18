import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/localization/app_translations.dart';
import 'package:home_share/features/home/screens/home_screen.dart';

void main() {
  test('HomeScreen chứa giao diện box lịch xem phòng có thể biên dịch', () {
    expect(const HomeScreen(), isA<HomeScreen>());
  });

  test('Kiểm tra nội dung bản dịch cho box Lịch xem phòng & Đơn thuê', () {
    expect(
      AppTranslations.tr('view_schedule_bookings', 'vi'),
      'Lịch xem phòng & Đơn thuê',
    );
    expect(
      AppTranslations.tr('view_schedule_sub', 'vi'),
      'Theo dõi yêu cầu xem phòng của bạn',
    );
    expect(
      AppTranslations.tr('view_schedule_bookings', 'en'),
      'Room Viewings & Bookings',
    );
    expect(
      AppTranslations.tr('view_schedule_sub', 'en'),
      'Track your room viewing and booking requests',
    );
  });
}
