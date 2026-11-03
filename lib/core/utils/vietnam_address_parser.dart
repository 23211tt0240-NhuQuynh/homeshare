import '../constants/vietnam_locations.dart';
import 'vietnamese_utils.dart';

class VietnamAddressParts {
  const VietnamAddressParts({
    required this.province,
    required this.district,
    required this.ward,
    required this.specificAddress,
  });

  final String province;
  final String district;
  final String ward;
  final String specificAddress;
}

/// Tách chuỗi địa chỉ phòng thành các giá trị hợp lệ của ba dropdown hành
/// chính. Bộ phân tích dùng chính danh mục địa điểm của ứng dụng, vì vậy giá
/// trị trả về luôn có trong danh sách tương ứng.
abstract final class VietnamAddressParser {
  static VietnamAddressParts resolve(
    String rawAddress, {
    String fallbackProvince = 'TP. Hồ Chí Minh',
    String fallbackDistrict = '',
    String fallbackWard = '',
  }) {
    final address = rawAddress.trim();
    var province = _bestMatchingLabel(address, VietnamLocations.provinces);
    var district = '';

    if (province.isNotEmpty) {
      district = _bestMatchingLabel(
        address,
        VietnamLocations.getAdministrativeDistricts(province),
      );
    } else {
      var bestDistrictScore = 0;
      for (final candidateProvince in VietnamLocations.provinces) {
        final candidateDistrict = _bestMatchingLabel(
          address,
          VietnamLocations.getAdministrativeDistricts(candidateProvince),
        );
        final score = _matchScore(address, candidateDistrict);
        if (score > bestDistrictScore) {
          bestDistrictScore = score;
          province = candidateProvince;
          district = candidateDistrict;
        }
      }
    }

    if (province.isEmpty || !VietnamLocations.provinces.contains(province)) {
      province = VietnamLocations.provinces.contains(fallbackProvince)
          ? fallbackProvince
          : VietnamLocations.provinces.first;
    }

    final districts = VietnamLocations.getAdministrativeDistricts(province);
    if (district.isEmpty || !districts.contains(district)) {
      district = districts.contains(fallbackDistrict)
          ? fallbackDistrict
          : (districts.isNotEmpty ? districts.first : '');
    }

    final wards = VietnamLocations.getWards(province, district);
    var ward = _bestMatchingLabel(address, wards);
    if (ward.isEmpty || !wards.contains(ward)) {
      ward = wards.contains(fallbackWard)
          ? fallbackWard
          : (wards.isNotEmpty ? wards.first : '');
    }

    // "Hiệp Bình Chánh" từng bị nhận nhầm thành "Bình Chánh". Nếu một phường
    // khác trong cùng tỉnh khớp rõ hơn quận đang chọn thì lấy quận của phường đó.
    final districtScore = _matchScore(address, district);
    final ownWardScore = _matchScore(address, ward);
    var bestWard = '';
    var bestWardScore = 0;
    var bestWardDistrict = '';
    for (final candidateDistrict in VietnamLocations.getAdministrativeDistricts(province)) {
      for (final candidateWard in VietnamLocations.getWards(province, candidateDistrict)) {
        final score = _matchScore(address, candidateWard);
        if (score > bestWardScore) {
          bestWardScore = score;
          bestWard = candidateWard;
          bestWardDistrict = candidateDistrict;
        }
      }
    }
    if (bestWard.isNotEmpty &&
        bestWardScore > ownWardScore &&
        bestWardScore > districtScore &&
        VietnamLocations.getAdministrativeDistricts(province).contains(bestWardDistrict)) {
      district = bestWardDistrict;
      ward = bestWard;
    }

    final administrativeLabels = [
      province,
      district,
      ward,
    ].where((value) => value.isNotEmpty).toList();
    final streetParts = address
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .where(
          (part) => !administrativeLabels.any(
            (label) => _matchScore(part, label) > 0,
          ),
        )
        .toList();

    final street = streetParts.isEmpty ? address : streetParts.join(', ');
    return VietnamAddressParts(
      province: province,
      district: district,
      ward: ward,
      specificAddress: isCityOrProvinceOnly(street) ? '' : street,
    );
  }

  /// Ghép số nhà/đường với phường, quận, tỉnh; bỏ phần trùng.
  static String composeParts({
    String street = '',
    String ward = '',
    String district = '',
    String city = '',
  }) {
    final parts = <String>[];
    void add(String value) {
      final part = value.trim().replaceAll(RegExp(r'^,+|,+$'), '').trim();
      if (part.isEmpty) return;
      final current = parts.join(', ').toLowerCase();
      if (current.contains(part.toLowerCase())) return;
      parts.add(part);
    }

    add(street);
    add(ward);
    add(district);
    add(city);
    return parts.join(', ');
  }

  static bool isCityOrProvinceOnly(String value) {
    final normalized = _normalize(value);
    if (normalized.isEmpty) return true;
    const cities = {
      'tp ho chi minh',
      'ho chi minh',
      'tp hcm',
      'tphcm',
      'sai gon',
      'ha noi',
      'tp ha noi',
      'thanh pho ha noi',
      'da nang',
      'tp da nang',
      'thanh pho da nang',
    };
    if (cities.contains(normalized)) return true;
    return VietnamLocations.provinces.any((province) => _normalize(province) == normalized);
  }

  /// Chọn chuỗi địa chỉ cụ thể nhất: có số nhà/đường hơn là chỉ tỉnh/thành.
  static String pickBest(Iterable<String> candidates) {
    var best = '';
    var bestScore = 0;
    for (final raw in candidates) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      final score = _specificity(value);
      if (score > bestScore) {
        best = value;
        bestScore = score;
      }
    }
    return best;
  }

  static int _specificity(String value) {
    if (isCityOrProvinceOnly(value)) return 1;
    var score = value.length;
    if (RegExp(r'\d').hasMatch(value)) score += 80;
    if (value.contains(',')) score += 25;
    final lower = _normalize(value);
    if (lower.contains('duong') ||
        lower.contains('pho') ||
        lower.contains('ap') ||
        lower.contains('khu') ||
        lower.contains('to ')) {
      score += 20;
    }
    return score;
  }

  static String _bestMatchingLabel(String address, Iterable<String> labels) {
    var best = '';
    var bestScore = 0;
    for (final label in labels) {
      final score = _matchScore(address, label);
      if (score > bestScore) {
        best = label;
        bestScore = score;
      }
    }
    return best;
  }

  static int _matchScore(String address, String label) {
    if (label.trim().isEmpty) return 0;
    final normalizedAddress = _normalize(address);
    var best = 0;
    for (final alias in _aliases(label)) {
      if (alias.isEmpty) continue;
      final pattern = RegExp(
        '(^| )${RegExp.escape(alias)}(\$| )',
        caseSensitive: false,
      );
      if (!pattern.hasMatch(normalizedAddress)) continue;
      if (_previousWordBreaksPlace(normalizedAddress, alias)) continue;
      final exactSegment = normalizedAddress
          .split(' ')
          .join(' ')
          .endsWith(alias);
      final score = alias.length + (exactSegment ? 1000 : 0);
      if (score > best) best = score;
    }
    return best;
  }

  /// "bình chánh" không được khớp vào "hiệp bình chánh".
  static bool _previousWordBreaksPlace(String normalizedAddress, String alias) {
    final pattern = RegExp('(^| )${RegExp.escape(alias)}(\$| )');
    final match = pattern.firstMatch(normalizedAddress);
    if (match == null) return false;
    final before = normalizedAddress.substring(0, match.start).trim();
    if (before.isEmpty) return false;
    const prefixes = {
      'phuong',
      'p',
      'xa',
      'quan',
      'q',
      'huyen',
      'tp',
      'thi',
      'tran',
      'thanh',
      'pho',
      'tinh',
    };
    return !prefixes.contains(before.split(' ').last);
  }

  static Set<String> _aliases(String label) {
    final normalized = _normalize(label);
    final aliases = <String>{normalized};
    const prefixes = [
      'thanh pho ',
      'tp ',
      'quan ',
      'q ',
      'huyen ',
      'thi xa ',
      'phuong ',
      'p ',
      'xa ',
      'thi tran ',
    ];
    for (final prefix in prefixes) {
      if (normalized.startsWith(prefix)) {
        final base = normalized.substring(prefix.length).trim();
        if (base.length >= 3 && !RegExp(r'^\d+$').hasMatch(base)) {
          aliases.add(base);
        }
        if (prefix == 'thanh pho ') aliases.add('tp $base');
        if (prefix == 'quan ') aliases.add('q $base');
        if (prefix == 'phuong ') aliases.add('p $base');
      }
    }
    if (normalized == 'tp ho chi minh') {
      aliases.addAll(const [
        'ho chi minh',
        'thanh pho ho chi minh',
        'tp hcm',
        'tphcm',
        'sai gon',
      ]);
    }
    return aliases;
  }

  static String _normalize(String value) {
    return normalizeVietnameseComparison(value)
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
