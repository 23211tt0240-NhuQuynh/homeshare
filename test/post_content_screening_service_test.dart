import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/features/admin/services/post_content_screening_service.dart';

void main() {
  group('PostContentScreeningService', () {
    test('accepts missing and null post text fields', () {
      expect(
        () => PostContentScreeningService.reviewReasons({
          'title': null,
          'description': null,
          'content': null,
          'moTa': null,
          'noiDung': null,
          'address': null,
          'diaChi': null,
        }),
        returnsNormally,
      );
    });

    test('still checks text fields when other fields are null', () {
      final reasons = PostContentScreeningService.reviewReasons({
        'title': null,
        'description': 'Yêu cầu chuyển tiền trước',
        'content': null,
        'address': null,
      });

      expect(reasons, contains('Yêu cầu chuyển tiền trước khi xem phòng'));
    });
  });
}
