import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_share/core/constants/vietnam_locations.dart';
import 'package:home_share/core/constants/vietnam_current_data.dart';
import 'package:home_share/core/utils/vietnam_address_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Snapshot includes all provinces, wards and special zones', () {
    final catalogue = VietnamLocations.decodeCatalogue(vietnamCurrentRawJson);
    expect(catalogue.length, 34);
    expect(
      catalogue.values.fold<int>(0, (sum, wards) => sum + wards.length),
      3321,
    );
    expect(
      catalogue['TP. Hồ Chí Minh'],
      containsAll(['Phường Sài Gòn', 'Đặc khu Côn Đảo']),
    );
    expect(catalogue['Hà Nội'], contains('Phường Cầu Giấy'));
    expect(catalogue.keys, isNot(contains('Bình Dương')));
    expect(VietnamLocations.getAdministrativeDistricts('Hà Nội'), isEmpty);
  });

  test('Incomplete or duplicate API responses are rejected', () {
    expect(() => VietnamLocations.decodeCatalogue('[]'), throwsFormatException);
    final rows = jsonDecode(vietnamCurrentRawJson) as List;
    rows.first['wards'] = [];
    expect(
      () => VietnamLocations.decodeCatalogue(jsonEncode(rows)),
      throwsFormatException,
    );
  });

  test('Refresh persists data and offline startup restores it', () async {
    final rows = jsonDecode(vietnamCurrentRawJson) as List;
    rows.first['wards'].first['name'] = 'Phường Kiểm Thử';
    final fresh = jsonEncode(rows);
    await VietnamLocations.initialize(
      client: MockClient((request) async {
        expect(request.url.toString(), VietnamLocations.endpoint);
        return http.Response(
          fresh,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    expect(VietnamLocations.getWards('Hà Nội'), contains('Phường Kiểm Thử'));
    await VietnamLocations.initialize(
      client: MockClient((_) async => throw Exception('offline')),
    );
    expect(VietnamLocations.getWards('Hà Nội'), contains('Phường Kiểm Thử'));
    await VietnamLocations.initialize(
      client: MockClient(
        (_) async => http.Response(
          vietnamCurrentRawJson,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
  });

  test('Parser accepts current wards and does not guess legacy wards', () {
    final current = VietnamAddressParser.resolve(
      '12 đường A, Phường Sài Gòn, TP. Hồ Chí Minh',
    );
    expect(current.province, 'TP. Hồ Chí Minh');
    expect(current.ward, 'Phường Sài Gòn');
    expect(current.district, isEmpty);
    final legacy = VietnamAddressParser.resolve(
      '12 đường A, Phường Hiệp Bình Chánh, Thành phố Thủ Đức, TP. Hồ Chí Minh',
    );
    expect(legacy.ward, isEmpty);
    expect(legacy.specificAddress, contains('Hiệp Bình Chánh'));
    final street = VietnamAddressParser.resolve(
      '12 đường Tân Định, TP. Hồ Chí Minh',
    );
    expect(street.ward, isEmpty);
  });
}
