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
