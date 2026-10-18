import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/utils/room_amenities.dart';

void main() {
  // Chủ trọ - Kiểm thử nhận diện tên - Luồng đi: Các cách viết khác
  // nhau và tên đồng nghĩa phải trả về cùng một mục trong danh mục.
  test(
    'matches catalog despite case, accents, whitespace or known aliases',
    () {
      for (final input in [
        '  MÁY   LẠNH ',
        'may lanh',
        'điều hòa',
        'điều hoà',
      ]) {
        expect(matchingRoomAmenity(input, []), 'Máy lạnh');
      }
      expect(matchingRoomAmenity('Wi-Fi', []), 'Wifi tốc độ cao');
      expect(matchingRoomAmenity('ma\u0301y la\u0323nh', []), 'Máy lạnh');
    },
  );

  test('deduplicates existing room data and retains distinct amenities', () {
    // Chủ trọ - Kiểm thử dữ liệu cũ - Luồng đi: Gộp mục trùng nhưng
    // vẫn giữ tiện ích riêng và không gộp nhầm yêu cầu có nghĩa khác.
    expect(
      uniqueRoomAmenities([
        'may lanh',
        'Máy lạnh',
        'Điều hòa',
        '  Sân   phơi ',
        'san phoi',
        'Máy giặt',
        'Máy sấy',
        '',
      ]),
      {'Máy lạnh', 'Sân phơi', 'Máy giặt', 'Máy sấy'},
    );
    expect(matchingRoomAmenity('SAN PHOI', ['Sân phơi']), 'Sân phơi');
    expect(matchingRoomAmenity('Không cho nuôi thú cưng', []), isNull);
    expect(matchingRoomAmenity('Wifi trả phí', []), isNull);
  });
}
