import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';

import 'vietnam_address_parser.dart';

const unresolvedMapAddressLabel = 'Không xác định được địa điểm này trên bản đồ';

class MapLocation {
  final double latitude;
  final double longitude;

  const MapLocation(this.latitude, this.longitude);

  LatLng get latLng => LatLng(latitude, longitude);
}

bool isMissingMapAddress(String address) {
  final value = address.trim();
  return value.isEmpty || value == 'Chưa có địa chỉ';
}

bool isInVietnam(double latitude, double longitude) {
  return latitude >= 8 && latitude <= 24 && longitude >= 102 && longitude <= 110;
}

/// Tọa độ đã lưu trên bài chỉ dùng khi nằm trong Việt Nam.
MapLocation? storedMapLocation(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return null;
  if (!isInVietnam(latitude, longitude)) return null;
  return MapLocation(latitude, longitude);
}

/// Tìm điểm trên bản đồ. Không ghim theo quận/tỉnh dự phòng — địa chỉ không
/// có thật thì trả về null để UI hiện [unresolvedMapAddressLabel].
Future<MapLocation?> locateAddressOnMap({
  required String address,
  double? latitude,
  double? longitude,
}) async {
  final stored = storedMapLocation(latitude, longitude);
  if (stored != null) return stored;

  final query = address.trim();
  if (isMissingMapAddress(query)) return null;

  final hit = await photonSearch(query, bias: knownPlaceBias(query));
  if (hit == null || !isRealMapHit(query: query, hit: hit)) return null;
  return MapLocation(hit.point.latitude, hit.point.longitude);
}

/// Kết quả Photon chỉ được chấp nhận khi nằm ở Việt Nam và khớp địa chỉ,
/// không ghim đại theo quận/tỉnh khi đường phố không có thật.
bool isRealMapHit({
  required String query,
  required PhotonHit hit,
}) {
  if (!isInVietnam(hit.point.latitude, hit.point.longitude)) return false;
  final street = VietnamAddressParser.resolve(query).specificAddress.trim();
  if (street.isEmpty) return true;

  final type = hit.type.toLowerCase();
  final hay = '${hit.name} ${hit.street} ${hit.houseNumber}'.toLowerCase();
  final tokens = street
      .toLowerCase()
      .split(RegExp(r'[\s,./]+'))
      .where((token) => token.length > 2 && int.tryParse(token) == null)
      .where((token) => token != 'đường' && token != 'phố' && token != 'số')
      .toList();
  if (tokens.any((token) => hay.contains(token))) return true;

  const coarse = {
    'city',
    'district',
    'county',
    'state',
    'country',
    'locality',
    'localadmin',
  };
  if (coarse.contains(type)) return false;
  return true;
}

class PhotonHit {
  final LatLng point;
  final String type;
  final String name;
  final String street;
  final String houseNumber;

  const PhotonHit({
    required this.point,
    this.type = '',
    this.name = '',
    this.street = '',
    this.houseNumber = '',
  });
}

String displayedMapAddress({
  required String address,
  required bool? foundOnMap,
}) {
  if (foundOnMap == false && !isMissingMapAddress(address)) {
    return unresolvedMapAddressLabel;
  }
  final value = address.trim();
  return value.isEmpty ? 'Chưa có địa chỉ' : value;
}

Future<PhotonHit?> photonSearch(String query, {LatLng? bias}) async {
  final client = HttpClient();
  try {
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': query,
      'limit': '1',
      'lat': '${bias?.latitude ?? 10.7769}',
      'lon': '${bias?.longitude ?? 106.7009}',
    });
    final request = await client.getUrl(uri);
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'HomeShare/1.0 (com.homeshare.app.home_share)',
    );
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map) return null;
    final features = decoded['features'];
    if (features is! List || features.isEmpty) return null;
    final geometry = features.first is Map ? features.first['geometry'] : null;
    if (geometry is! Map) return null;
    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) return null;
    final lon = double.tryParse('${coordinates[0]}');
    final lat = double.tryParse('${coordinates[1]}');
    if (lat == null || lon == null) return null;
    final properties =
        features.first is Map ? features.first['properties'] : null;
    final props = properties is Map ? properties : const {};
    return PhotonHit(
      point: LatLng(lat, lon),
      type: '${props['type'] ?? props['osm_value'] ?? ''}',
      name: '${props['name'] ?? ''}',
      street: '${props['street'] ?? ''}',
      houseNumber: '${props['housenumber'] ?? ''}',
    );
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Chỉ dùng để thiên vị kết quả tìm kiếm, không phải điểm ghim.
LatLng? knownPlaceBias(String query) {
  final text = query.toLowerCase();
  const places = <(String, double, double)>[
    ('phường linh trung', 10.8696, 106.7782),
    ('linh trung', 10.8696, 106.7782),
    ('phường 25', 10.8036, 106.7302),
    ('bình thạnh', 10.8036, 106.7302),
    ('binh thanh', 10.8036, 106.7302),
    ('tân phong', 10.7312, 106.7204),
    ('tan phong', 10.7312, 106.7204),
    ('quận 7', 10.7340, 106.7218),
    ('quan 7', 10.7340, 106.7218),
    ('phường 16', 10.8380, 106.6648),
    ('gò vấp', 10.8380, 106.6648),
    ('go vap', 10.8380, 106.6648),
    ('dịch vọng', 21.0360, 105.7895),
    ('cầu giấy', 21.0278, 105.7900),
    ('hải châu', 16.0715, 108.2238),
    ('thủ đức', 10.8497, 106.7717),
    ('thu duc', 10.8497, 106.7717),
    ('hà nội', 21.0285, 105.8542),
    ('ha noi', 21.0285, 105.8542),
    ('đà nẵng', 16.0544, 108.2022),
    ('da nang', 16.0544, 108.2022),
    ('hồ chí minh', 10.7769, 106.7009),
    ('ho chi minh', 10.7769, 106.7009),
  ];
  for (final place in places) {
    if (text.contains(place.$1)) return LatLng(place.$2, place.$3);
  }
  return null;
}
