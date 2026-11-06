import 'host_management_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Danh sách gợi ý mặc định, không ghi thành collection riêng.
const List<String> defaultHostAmenities = [
  'Wifi',
  'Máy lạnh',
  'Tủ lạnh',
  'Máy giặt',
  'Gác lửng',
  'Ban công',
  'Bảo vệ 24/7',
  'Chỗ để xe',
  'Bếp nấu ăn',
  'Camera an ninh',
  'Giờ giấc tự do',
  'Thang máy',
  'Nội thất đầy đủ',
];

/// Gợi ý từ danh sách mặc định và tiện ích đã lưu trong host_rooms.
final hostAmenitiesProvider =
    StreamProvider.autoDispose<List<Map<String, String>>>((ref) {
      final rooms = ref.watch(hostRoomsProvider).value ?? [];
      final names = <String, String>{};
      for (final name in [
        ...defaultHostAmenities,
        for (final room in rooms) ...room.amenities,
      ]) {
        final clean = name.trim();
        if (clean.isNotEmpty) {
          names.putIfAbsent(clean.toLowerCase(), () => clean);
        }
      }
      return Stream.value([
        for (final entry in names.entries)
          {'id': entry.key, 'name': entry.value},
      ]);
    });

/// Provider danh sách tên tiện ích đơn giản
final hostAmenityNamesProvider = Provider.autoDispose<List<String>>((ref) {
  final asyncVal = ref.watch(hostAmenitiesProvider);
  return asyncVal.when(
    data: (list) => list.map((item) => item['name']!).toList(),
    loading: () => defaultHostAmenities,
    error: (error, stack) => defaultHostAmenities,
  );
});
