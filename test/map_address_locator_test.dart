import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/utils/map_address_locator.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('displayedMapAddress', () {
    test('giữ địa chỉ khi tìm được trên bản đồ', () {
      expect(
        displayedMapAddress(
          address: '66 Lê Văn Tăng, TP. Thủ Đức',
          foundOnMap: true,
        ),
        '66 Lê Văn Tăng, TP. Thủ Đức',
      );
    });

    test('địa chỉ không có thật thì hiện thông báo', () {
      expect(
        displayedMapAddress(
          address: 'Số 0 Đường Không Tồn Tại, TP. Thủ Đức',
          foundOnMap: false,
        ),
        unresolvedMapAddressLabel,
      );
      expect(
        unresolvedMapAddressLabel,
        'Không xác định được địa điểm này trên bản đồ',
      );
    });

    test('địa chỉ trống không bị thay bằng thông báo bản đồ', () {
      expect(
        displayedMapAddress(address: '', foundOnMap: false),
        'Chưa có địa chỉ',
      );
      expect(
        displayedMapAddress(address: 'Chưa có địa chỉ', foundOnMap: false),
        'Chưa có địa chỉ',
      );
    });
  });

  group('isRealMapHit', () {
    test('tọa độ ngoài Việt Nam bị loại', () {
      expect(
        isRealMapHit(
          query: 'Paris',
          hit: PhotonHit(point: LatLng(48.8566, 2.3522), type: 'city'),
        ),
        isFalse,
      );
    });

    test('kết quả chỉ ra quận/tỉnh khi đường phố không khớp thì không chấp nhận', () {
      expect(
        isRealMapHit(
          query: 'Số 0 Đường Không Tồn Tại, Phường Linh Trung, TP. Thủ Đức',
          hit: const PhotonHit(
            point: LatLng(10.8497, 106.7717),
            type: 'city',
            name: 'Thủ Đức',
          ),
        ),
        isFalse,
      );
    });

    test('kết quả khớp tên đường thì chấp nhận', () {
      expect(
        isRealMapHit(
          query: '66 Lê Văn Tăng, TP. Thủ Đức',
          hit: const PhotonHit(
            point: LatLng(10.8497, 106.7717),
            type: 'street',
            name: 'Lê Văn Tăng',
            street: 'Lê Văn Tăng',
          ),
        ),
        isTrue,
      );
    });
  });
}
