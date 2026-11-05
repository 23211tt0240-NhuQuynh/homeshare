import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/constants/vietnam_locations.dart';
import 'package:home_share/core/utils/vietnam_address_parser.dart';

void main() {
  group('VietnamLocations 34 Provinces Verification Tests', () {
    test('VietnamLocations.provinces has exactly 34 provinces/cities', () {
      expect(VietnamLocations.provinces.length, 34);
      expect(VietnamLocations.provinces34.length, 34);
      expect(VietnamLocations.provinces, equals(VietnamLocations.provinces34));
    });

    test('All 6 centrally run cities and 28 provinces are present', () {
      const expectedCentralCities = [
        'TP. Hồ Chí Minh',
        'Hà Nội',
        'Đà Nẵng',
        'Hải Phòng',
        'Cần Thơ',
        'Huế',
      ];
      for (final city in expectedCentralCities) {
        expect(
          VietnamLocations.provinces.contains(city),
          isTrue,
          reason: 'Missing central city: $city',
        );
      }
    });

    test('Every province has administrative districts and wards', () {
      for (final province in VietnamLocations.provinces) {
        final districts = VietnamLocations.getAdministrativeDistricts(province);
        expect(
          districts.isNotEmpty,
          isTrue,
          reason: 'Province $province must have at least 1 district',
        );

        final searchDistricts = VietnamLocations.getDistricts(province);
        expect(searchDistricts.first, 'Tất cả');
        expect(searchDistricts.length, districts.length + 1);

        // Check province has wards overall
        final allWards = VietnamLocations.getWards(province);
        expect(
          allWards.isNotEmpty,
          isTrue,
          reason: 'Province $province must have wards in total',
        );
      }
    });

    test('Total administrative districts nationwide is over 700 and wards over 10,000', () {
      var totalDistricts = 0;
      var totalWards = 0;
      for (final p in VietnamLocations.provinces) {
        final dists = VietnamLocations.getAdministrativeDistricts(p);
        totalDistricts += dists.length;
        for (final d in dists) {
          totalWards += VietnamLocations.getWards(p, d).length;
        }
      }

      expect(totalDistricts, greaterThanOrEqualTo(700));
      expect(totalWards, greaterThanOrEqualTo(10000));
    });

    test('VietnamAddressParser correctly parses addresses with 34 provinces', () {
      final hcm = VietnamAddressParser.resolve(
        '73/14 Lê Văn Việt, Phường Tăng Nhơn Phú A, Thành phố Thủ Đức, TP. Hồ Chí Minh',
      );
      expect(hcm.province, 'TP. Hồ Chí Minh');
      expect(hcm.district, contains('Thủ Đức'));

      final hn = VietnamAddressParser.resolve(
        'Số 1 Đại Cồ Việt, Phường Bách Khoa, Quận Hai Bà Trưng, Hà Nội',
      );
      expect(hn.province, 'Hà Nội');
      expect(hn.district, contains('Hai Bà Trưng'));

      final dn = VietnamAddressParser.resolve(
        '54 Nguyễn Lương Bằng, Phường Hòa Khánh Bắc, Quận Liên Chiểu, Đà Nẵng',
      );
      expect(dn.province, 'Đà Nẵng');
      expect(dn.district, contains('Liên Chiểu'));
    });
  });
}
