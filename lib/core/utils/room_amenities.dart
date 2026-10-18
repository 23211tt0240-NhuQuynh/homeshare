import 'vietnamese_utils.dart';

// Chủ trọ - Danh mục tiện ích - Luồng đi: Hai form tạo và chỉnh sửa
// dùng cùng tên chuẩn để không sinh hai mục cho cùng một tiện ích.
const roomAmenityOptions = [
  'Máy lạnh',
  'Có gác lửng',
  'Wifi tốc độ cao',
  'Giờ giấc tự do',
  'Máy giặt',
  'Tủ lạnh',
  'Cho nuôi thú cưng',
  'Ban công / Cửa sổ lớn',
  'Không chung chủ',
  'Chỗ để xe miễn phí',
];

// Chủ trọ - Làm sạch tên nhập - Luồng đi: Bỏ khoảng trắng đầu/cuối
// và gộp khoảng trắng thừa, giữ nguyên dấu và cách viết để hiển thị.
String cleanRoomAmenity(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

// Chủ trọ - Khóa so sánh tiện ích - Luồng đi: Bỏ khác biệt hoa/thường,
// dấu tiếng Việt (kể cả dấu Unicode tách rời), khoảng trắng và dấu nối.
// Chỉ gộp các tên đồng nghĩa khai báo bên dưới; không so khớp gần đúng
// để tránh gộp nhầm tiện ích có điều kiện khác như Wifi trả phí.
String roomAmenityKey(String value) {
  final key = normalizeVietnameseComparison(value)
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'[\s\-_.]+'), '');
  const aliases = {
    'dieuhoa': 'maylanh',
    'maydieuhoa': 'maylanh',
    'gaclung': 'cogaclung',
    'wifi': 'wifitocdocao',
  };
  return aliases[key] ?? key;
}

// Chủ trọ - Gộp tiện ích cũ - Luồng đi: Khi mở chỉnh sửa, loại tên
// rỗng và mục trùng; ưu tiên tên trong danh mục, còn tiện ích tự nhập
// giữ tên xuất hiện đầu tiên. Kết quả chỉ được ghi lên khi lưu phòng.
Set<String> uniqueRoomAmenities(Iterable<String> values) {
  final names = <String, String>{
    for (final option in roomAmenityOptions) roomAmenityKey(option): option,
  };
  final result = <String, String>{};
  for (final raw in values) {
    final value = cleanRoomAmenity(raw);
    if (value.isEmpty) continue;
    final key = roomAmenityKey(value);
    result.putIfAbsent(key, () => names[key] ?? value);
  }
  return result.values.toSet();
}

// Chủ trọ - Tìm tiện ích đã có - Luồng đi: Kiểm tra danh mục trước,
// rồi đến các mục đang chọn; trả tên có sẵn để form chọn lại thay vì
// thêm dòng trùng, trả null khi người dùng nhập tiện ích mới.
String? matchingRoomAmenity(String value, Iterable<String> selected) {
  final key = roomAmenityKey(value);
  for (final option in [...roomAmenityOptions, ...selected]) {
    if (roomAmenityKey(option) == key) return option;
  }
  return null;
}
