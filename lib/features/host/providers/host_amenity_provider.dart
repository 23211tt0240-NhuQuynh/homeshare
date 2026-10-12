import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Danh sách tiện ích mặc định từ cơ sở dữ liệu nếu Firestore chưa có dữ liệu
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

/// Provider đọc danh mục tiện ích từ Firestore collection 'amenities'
final hostAmenitiesProvider =
    StreamProvider.autoDispose<List<Map<String, String>>>((ref) {
  if (Firebase.apps.isEmpty) {
    return Stream.value(
      defaultHostAmenities
          .map((name) => {'id': name.toLowerCase(), 'name': name})
          .toList(),
    );
  }

  return FirebaseFirestore.instance.collection('amenities').snapshots().map(
    (snapshot) {
      // 1. Luôn nạp sẵn danh sách tiện ích mẫu chuẩn (defaultHostAmenities) làm nền tảng
      final result = <Map<String, String>>[];
      final seenNames = <String>{};

      for (final def in defaultHostAmenities) {
        result.add({'id': def.toLowerCase(), 'name': def});
        seenNames.add(def.toLowerCase());
      }

      // 2. Hợp nhất các tiện ích từ Firestore collection 'amenities' nếu chưa tồn tại
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = (data['name'] ??
                data['ten'] ??
                data['label'] ??
                data['tenTienIch'] ??
                '')
            .toString()
            .trim();
        if (name.isNotEmpty && !seenNames.contains(name.toLowerCase())) {
          seenNames.add(name.toLowerCase());
          result.add({'id': doc.id, 'name': name});
        }
      }

      return result;
    },
  );
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
