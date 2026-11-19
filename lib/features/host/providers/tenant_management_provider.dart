import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/tenant_repository.dart';
import 'host_management_provider.dart';

final tenantRepositoryProvider = Provider<TenantRepository>((ref) {
  return TenantRepository();
});

/// Stream danh sách người thuê của chủ trọ hiện tại
final hostTenantsProvider = StreamProvider.autoDispose<List<TenantItem>>((ref) {
  final uid = ref.watch(hostSessionProvider).value;
  if (uid == null || uid.isEmpty) {
    return Stream.value([]);
  }
  // Chủ trọ - Giữ danh sách người thuê - Rời màn thì giữ dữ liệu và luồng
  // cập nhật thêm 2 phút; quay lại trong thời gian này thì dùng tiếp luồng cũ.
  final link = ref.keepAlive();
  Timer? release;
  ref.onCancel(() {
    release = Timer(const Duration(minutes: 2), link.close);
  });
  ref.onResume(() => release?.cancel());
  ref.onDispose(() => release?.cancel());
  return ref.watch(tenantRepositoryProvider).watchHostTenants(uid);
});

/// Stream số liệu thống kê: số cơ sở, số người đang thuê, số phòng đang sử dụng
final hostTenantStatsProvider = Provider.autoDispose<AsyncValue<TenantStats>>((
  ref,
) {
  final tenants = ref.watch(hostTenantsProvider);
  final properties = ref.watch(hostPropertiesProvider);
  return properties
      .whenData((facilities) => facilities.length)
      .when(
        data: (count) => tenants.whenData((items) {
          final active = items.where((item) => item.isActive).toList();
          return TenantStats(
            facilityCount: count,
            activeTenantCount: active.fold<int>(
              0,
              (sum, item) => sum + item.memberCount,
            ),
            occupiedRoomCount: active.map((item) => item.roomId).toSet().length,
          );
        }),
        loading: () => const AsyncLoading<TenantStats>(),
        error: (error, stack) => AsyncError<TenantStats>(error, stack),
      );
});
