import 'dart:convert';
import 'vietnam_divisions_data.dart';

/// Dữ liệu hành chính 34 Tỉnh / Thành phố và các Quận / Huyện / Thị xã / Phường Xã trên toàn quốc Việt Nam.
/// Chuẩn hóa theo Nghị quyết số 202/2025/QH15 của Quốc hội và Figma HomeShare.
class VietnamLocations {
  /// Danh sách 34 Tỉnh và Thành phố trực thuộc Trung ương của Việt Nam theo Nghị quyết số 202/2025/QH15.
  /// Gồm 6 Thành phố trực thuộc Trung ương và 28 Tỉnh thành sau sắp xếp.
  static const List<String> provinces34 = [
    'TP. Hồ Chí Minh',
    'Hà Nội',
    'Đà Nẵng',
    'Hải Phòng',
    'Cần Thơ',
    'Huế',
    'An Giang',
    'Bắc Ninh',
    'Cà Mau',
    'Cao Bằng',
    'Đắk Lắk',
    'Điện Biên',
    'Đồng Nai',
    'Đồng Tháp',
    'Gia Lai',
    'Hà Tĩnh',
    'Hưng Yên',
    'Khánh Hòa',
    'Lai Châu',
    'Lạng Sơn',
    'Lào Cai',
    'Lâm Đồng',
    'Nghệ An',
    'Ninh Bình',
    'Phú Thọ',
    'Quảng Ngãi',
    'Quảng Ninh',
    'Quảng Trị',
    'Sơn La',
    'Tây Ninh',
    'Thái Nguyên',
    'Thanh Hóa',
    'Tuyên Quang',
    'Vĩnh Long',
  ];

  /// Danh sách đơn vị hành chính cấp tỉnh chính thức hiện hành (Chuẩn 34 Tỉnh / Thành phố mới)
  static const List<String> provinces = provinces34;

  /// Danh sách 63 Tỉnh và Thành phố trực thuộc Trung ương trước sắp xếp (hỗ trợ tương thích ngược)
  static const List<String> provinces63 = [
    'TP. Hồ Chí Minh',
    'Hà Nội',
    'Đà Nẵng',
    'Hải Phòng',
    'Cần Thơ',
    'Huế',
    'An Giang',
    'Bà Rịa - Vũng Tàu',
    'Bắc Giang',
    'Bắc Kạn',
    'Bạc Liêu',
    'Bắc Ninh',
    'Bến Tre',
    'Bình Định',
    'Bình Dương',
    'Bình Phước',
    'Bình Thuận',
    'Cà Mau',
    'Cao Bằng',
    'Đắk Lắk',
    'Đắk Nông',
    'Điện Biên',
    'Đồng Nai',
    'Đồng Tháp',
    'Gia Lai',
    'Hà Giang',
    'Hà Nam',
    'Hà Tĩnh',
    'Hải Dương',
    'Hậu Giang',
    'Hòa Bình',
    'Hưng Yên',
    'Khánh Hòa',
    'Kiên Giang',
    'Kon Tum',
    'Lai Châu',
    'Lâm Đồng',
    'Lạng Sơn',
    'Lào Cai',
    'Long An',
    'Nam Định',
    'Nghệ An',
    'Ninh Bình',
    'Ninh Thuận',
    'Phú Thọ',
    'Phú Yên',
    'Quảng Bình',
    'Quảng Nam',
    'Quảng Ngãi',
    'Quảng Ninh',
    'Quảng Trị',
    'Sóc Trăng',
    'Sơn La',
    'Tây Ninh',
    'Thái Bình',
    'Thái Nguyên',
    'Thanh Hóa',
    'Tiền Giang',
    'Trà Vinh',
    'Tuyên Quang',
    'Vĩnh Long',
    'Vĩnh Phúc',
    'Yên Bái',
  ];

 

  // ===========================================================================
  // DỮ LIỆU ĐẦY ĐỦ 3 CẤP HÀNH CHÍNH (TỈNH/TP -> QUẬN/HUYỆN -> PHƯỜNG/XÃ)
  // ===========================================================================
  static Map<String, Map<String, List<String>>>? _fullHierarchy;

  /// Nạp và cache dữ liệu phân cấp hành chính toàn quốc từ bộ nhớ (34 Tỉnh/TP)
  static void _ensureLoaded() {
    if (_fullHierarchy != null) return;
    try {
      final decoded = jsonDecode(vietnamDivisionsRawJson) as Map<String, dynamic>;
      final map = <String, Map<String, List<String>>>{};
      decoded.forEach((provKey, distMapRaw) {
        final distMap = <String, List<String>>{};
        if (distMapRaw is Map) {
          distMapRaw.forEach((distKey, wardsRaw) {
            if (wardsRaw is List) {
              distMap[distKey.toString()] = wardsRaw.map((e) => e.toString()).toList();
            }
          });
        }
        map[provKey] = distMap;
      });
      _fullHierarchy = map;
    } catch (_) {
      _fullHierarchy = {};
    }
  }

  /// Lấy danh sách Quận / Huyện / Phường / Xã tương ứng theo Tỉnh / Thành phố (kèm mục 'Tất cả' cho bộ lọc tìm kiếm)
  static List<String> getDistricts(String province) {
    _ensureLoaded();
    final distMap = _fullHierarchy?[province];
    if (distMap != null && distMap.isNotEmpty) {
      final list = distMap.keys.toList()..sort();
      return ['Tất cả', ...list];
    }
    return const ['Tất cả'];
  }

  /// Lấy danh sách Quận / Huyện chính xác của một Tỉnh / Thành phố (34 Tỉnh/TP chuẩn mới)
  static List<String> getAdministrativeDistricts(String province) {
    _ensureLoaded();
    final distMap = _fullHierarchy?[province];
    if (distMap != null && distMap.isNotEmpty) {
      final list = distMap.keys.toList()..sort();
      return list;
    }
    return const [];
  }

  /// Lấy danh sách đầy đủ Phường / Xã / Thị trấn theo Tỉnh / Thành phố và Quận / Huyện (hoặc tất cả phường/xã của Tỉnh)
  static List<String> getWards(String province, [String? district]) {
    _ensureLoaded();
    final distMap = _fullHierarchy?[province];
    if (distMap == null || distMap.isEmpty) return const [];

    if (district == null || district.trim().isEmpty) {
      final allWards = <String>{};
      for (final wards in distMap.values) {
        allWards.addAll(wards);
      }
      final list = allWards.toList()..sort();
      return list;
    }

    // Tìm kiếm trực tiếp theo tên quận huyện
    if (distMap.containsKey(district)) {
      return distMap[district]!;
    }

    // Tìm kiếm linh hoạt (bỏ tiền tố "Quận ", "Huyện ", "Thị xã " hoặc tìm chứa)
    final cleanDistrict = district
        .replaceAll('Quận ', '')
        .replaceAll('Huyện ', '')
        .replaceAll('Thị xã ', '')
        .replaceAll('TP. ', '')
        .replaceAll('Thành phố ', '')
        .trim()
        .toLowerCase();

    for (final entry in distMap.entries) {
      final entryClean = entry.key
          .replaceAll('Quận ', '')
          .replaceAll('Huyện ', '')
          .replaceAll('Thị xã ', '')
          .replaceAll('TP. ', '')
          .replaceAll('Thành phố ', '')
          .trim()
          .toLowerCase();

      if (entryClean == cleanDistrict ||
          entry.key.toLowerCase().contains(cleanDistrict) ||
          cleanDistrict.contains(entryClean)) {
        return entry.value;
      }
    }

    return const [];
  }
}
