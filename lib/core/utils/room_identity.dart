import 'dart:math';

// Chủ trọ - ID phòng ngắn - Luồng đi: Cấp 12 ký tự ngẫu nhiên an toàn,
// bỏ ký tự dễ nhầm; dùng cùng ID cho document, trường id và liên kết roomId.
// Form giữ ID trong suốt lần tạo để thử lưu lại không sinh thêm phòng.
String newRoomId() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  return List.generate(
    12,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();
}

bool isShortRoomId(String value) =>
    RegExp(r'^[A-HJ-NP-Z2-9]{12}$').hasMatch(value);
