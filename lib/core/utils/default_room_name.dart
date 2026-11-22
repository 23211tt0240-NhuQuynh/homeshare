import '../../data/models/room_model.dart';

/// Số phòng tăng trong từng tầng; không dùng lại số còn tồn tại.
String defaultRoomName({
  required String propertyId,
  required String propertyName,
  required int floor,
  required List<RoomModel> rooms,
}) {
  final name = propertyName.trim().replaceFirst(
    RegExp(r'^(nhà|tòa nhà|toà nhà|cơ sở)\s+', caseSensitive: false),
    '',
  );
  final words = name.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
  final abbreviation = words
      .map((word) => word.substring(0, 1))
      .join()
      .toUpperCase();
  final prefix =
      '${abbreviation.isEmpty ? 'N' : abbreviation}${floor.toString().padLeft(2, '0')}-';
  final existing = rooms.where(
    (room) => room.propertyId == propertyId && room.floor == floor,
  );
  var lastNumber = existing.length;
  for (final room in existing) {
    if (!room.title.startsWith(prefix)) continue;
    final number = int.tryParse(room.title.substring(prefix.length));
    if (number != null && number > lastNumber) lastNumber = number;
  }
  return '$prefix${(lastNumber + 1).toString().padLeft(2, '0')}';
}
