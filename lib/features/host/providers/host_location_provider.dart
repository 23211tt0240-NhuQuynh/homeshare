import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/vietnam_locations.dart';

/// Chủ trọ - Danh sách khu vực - Luồng đi: Chỉ lấy tỉnh/thành từ danh mục
/// hiện hành đã nạp; không trộn tên tỉnh cũ trong Firestore vào bộ chọn.
final hostLocationsProvider = StreamProvider.autoDispose<List<String>>((ref) {
  return Stream.value(VietnamLocations.provinces);
});

class HostLocationSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String q) => state = q;
}

/// Chủ trọ - Từ khóa khu vực - Luồng đi: Lưu nội dung tìm nhanh trong bảng chọn.
final hostLocationSearchQueryProvider =
    NotifierProvider.autoDispose<HostLocationSearchNotifier, String>(
      HostLocationSearchNotifier.new,
    );

/// Chủ trọ - Lọc khu vực - Luồng đi: Lọc tỉnh/thành hiện hành theo từ khóa đã nhập.
final hostFilteredLocationsProvider = Provider.autoDispose<List<String>>((ref) {
  final query = ref.watch(hostLocationSearchQueryProvider).trim().toLowerCase();
  final locationsAsync = ref.watch(hostLocationsProvider);
  final allLocations = locationsAsync.value ?? VietnamLocations.provinces;

  if (query.isEmpty) return allLocations;
  return allLocations
      .where((loc) => loc.toLowerCase().contains(query))
      .toList();
});
