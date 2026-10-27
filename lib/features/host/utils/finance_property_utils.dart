import '../../../data/models/room_model.dart';

// Chủ trọ - Xác định cơ sở của hóa đơn từ mã cơ sở hoặc liên kết phòng cũ/mới.
String? financePropertyId(
  Map<String, dynamic> booking,
  List<RoomModel> rooms, {
  List<Map<String, dynamic>> posts = const [],
}) {
  String? read(List<String> keys) {
    for (final key in keys) {
      final value = booking[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  final property = read([
    'propertyId',
    'property_id',
    'bat_dong_san_id',
    'nhaTroId',
    'maNhaTro',
  ]);
  if (property != null) return property;
  final roomId = read(['roomId', 'phongId', 'phong_id']);
  for (final room in rooms) {
    if (room.id == roomId && room.propertyId.isNotEmpty) return room.propertyId;
  }
  // Chủ trọ - Đối chiếu đơn dùng ID bài đăng - Bài đăng dẫn tới phòng gốc,
  // phòng gốc dẫn tới cơ sở; không suy đoán theo tên phòng hoặc tên nhà.
  final postIds = [
    booking['postId'],
    booking['baiDangId'],
    booking['bai_dang_id'],
    roomId,
  ].whereType<String>().where((id) => id.trim().isNotEmpty).toSet();
  for (final post in posts) {
    if (!postIds.contains(post['id'])) continue;
    final directProperty = financePropertyId(post, rooms);
    if (directProperty != null) return directProperty;
  }
  return null;
}
