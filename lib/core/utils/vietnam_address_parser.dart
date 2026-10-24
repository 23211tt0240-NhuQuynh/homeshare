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

/// Địa chỉ - Tách địa chỉ có sẵn - Luồng đi: Đối chiếu tỉnh/thành và cấp xã
/// với danh mục hiện hành; không khớp phường/xã thì để trống để chọn lại.
/// Phần địa chỉ chưa nhận diện được giữ trong địa chỉ chi tiết để đối chiếu.
abstract final class VietnamAddressParser {
  static VietnamAddressParts resolve(
    String rawAddress, {
    String fallbackProvince = 'TP. Hồ Chí Minh',
    String fallbackDistrict = '',
    String fallbackWard = '',
  }) {
    final address = rawAddress.trim();
    var province = _bestMatchingLabel(address, VietnamLocations.provinces);
    if (province.isEmpty &&
        VietnamLocations.provinces.contains(fallbackProvince)) {
      province = fallbackProvince;
    }
    const district = '';
    final wards = VietnamLocations.getWards(province);
    // Địa chỉ - Nhận diện cấp xã - Luồng đi: Khớp trọn một phần ngăn bởi
    // dấu phẩy, tránh nhầm tên đường chứa tên phường thành phường đã chọn.
    var ward = '';
    for (final segment in address.split(',')) {
      final normalized = _normalize(segment);
      final matches = wards
          .where((label) => _aliases(label).contains(normalized))
          .toList();
      if (matches.length == 1) {
        ward = matches.single;
        break;
      }
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

    return VietnamAddressParts(
      province: province,
      district: district,
      ward: ward,
      specificAddress: streetParts.isEmpty ? address : streetParts.join(', '),
    );
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
      final exactSegment = normalizedAddress
          .split(' ')
          .join(' ')
          .endsWith(alias);
      final score = alias.length + (exactSegment ? 1000 : 0);
      if (score > best) best = score;
    }
    return best;
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
      'dac khu ',
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
