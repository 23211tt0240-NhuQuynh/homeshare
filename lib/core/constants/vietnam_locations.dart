import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'vietnam_current_data.dart';

/// Địa chỉ - Danh mục hành chính hai cấp - Luồng đi: Nạp tỉnh/thành và
/// phường/xã/đặc khu; các hàm quận/huyện chỉ giữ để tương thích lời gọi cũ.
abstract final class VietnamLocations {
  static const endpoint = 'https://provinces.open-api.vn/api/v2/?depth=2';
  static const _cacheKey = 'vietnam_administrative_v2';
  static Map<String, List<String>> _wards = decodeCatalogue(
    vietnamCurrentRawJson,
  );
  static List<String> get provinces => List.unmodifiable(_wards.keys);

  // Địa chỉ - Tên tỉnh/thành - Luồng đi: Chuẩn hóa tiền tố API theo cách
  // hiển thị của ứng dụng để cùng một tỉnh không sinh nhiều tên khác nhau.
  static String provinceLabel(String name) {
    if (name == 'Thành phố Hồ Chí Minh') return 'TP. Hồ Chí Minh';
    return name.replaceFirst(RegExp(r'^(Tỉnh |Thành phố )'), '');
  }

  /// Địa chỉ - Kiểm tra dữ liệu API - Luồng đi: Kiểm tra cấu trúc, danh sách
  /// phường/xã và mã trùng trước khi thay danh mục đang sử dụng.
  static Map<String, List<String>> decodeCatalogue(String raw) {
    final rows = jsonDecode(raw) as List;
    if (rows.length < 30) throw const FormatException('Incomplete provinces');
    final result = <String, List<String>>{};
    final codes = <int>{};
    for (final row in rows) {
      final name = provinceLabel(row['name'] as String);
      final wards = row['wards'] as List;
      if (name.isEmpty || wards.isEmpty || result.containsKey(name)) {
        throw const FormatException('Invalid province');
      }
      final labels = <String>[];
      for (final ward in wards) {
        final label = ward['name'] as String;
        if (label.isEmpty || !codes.add(ward['code'] as int)) {
          throw const FormatException('Invalid ward');
        }
        labels.add(label);
      }
      labels.sort();
      result[name] = List.unmodifiable(labels);
    }
    return Map.unmodifiable(result);
  }

  /// Địa chỉ - Cập nhật danh mục - Luồng đi: Đọc cache trước, sau đó gọi API
  /// với thời gian chờ tối đa 6 giây và lưu lại phản hồi hợp lệ. Nếu API lỗi,
  /// giữ dữ liệu đã nạp; lần đầu chưa có cache thì dùng bản dự phòng trong app.
  static Future<void> initialize({http.Client? client}) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      if (cached != null) _wards = decodeCatalogue(cached);
    } catch (_) {
      // Địa chỉ - Cache lỗi - Luồng đi: Giữ danh mục đang dùng nếu cache không đọc được.
    }
    final transport = client ?? http.Client();
    try {
      final response = await transport
          .get(Uri.parse(endpoint))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return;
      final raw = utf8.decode(response.bodyBytes);
      final fresh = decodeCatalogue(raw);
      _wards = fresh;
      await prefs?.setString(_cacheKey, raw);
    } catch (_) {
      // Địa chỉ - API lỗi - Luồng đi: Giữ danh mục hợp lệ đã nạp khi mất mạng hoặc phản hồi lỗi.
    } finally {
      if (client == null) transport.close();
    }
  }

  // Địa chỉ - Tra cứu cấp xã - Luồng đi: Lấy phường/xã/đặc khu trực tiếp
  // theo tỉnh/thành; tham số district chỉ giữ tương thích và không dùng để lọc.
  static List<String> getWards(String province, [String district = '']) =>
      _wards[provinceLabel(province)] ?? const [];

  // Địa chỉ - Tương thích mã cũ - Luồng đi: Trả danh sách rỗng để không
  // cung cấp quận/huyện cho các màn hình chọn địa chỉ hiện hành.
  static List<String> getAdministrativeDistricts(String province) => const [];
  static List<String> getDistricts(String province) => const [];
}
