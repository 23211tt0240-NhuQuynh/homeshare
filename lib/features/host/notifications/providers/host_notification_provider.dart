import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_share/features/auth/providers/auth_provider.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import '../models/host_notification_model.dart';
import '../notification_types.dart';
import '../repositories/host_notification_repository.dart';

/// Provider khởi tạo Repository duy nhất cho module thông báo
final hostNotificationRepositoryProvider =
    Provider<HostNotificationRepository>((ref) {
  return HostNotificationRepository();
});

/// Notifier quản lý từ khóa tìm kiếm (mã booking, tên khách...)
class HostNotificationSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final hostNotificationSearchQueryProvider =
    NotifierProvider<HostNotificationSearchQueryNotifier, String>(
  HostNotificationSearchQueryNotifier.new,
);

/// Notifier quản lý loại thông báo đang được chọn trên tab
class SelectedHostNotificationTypeNotifier extends Notifier<HostNotificationType> {
  @override
  HostNotificationType build() => HostNotificationType.pendingAction;

  void setType(HostNotificationType type) => state = type;
}

final selectedHostNotificationTypeProvider =
    NotifierProvider<SelectedHostNotificationTypeNotifier, HostNotificationType>(
  SelectedHostNotificationTypeNotifier.new,
);

/// StreamProvider lấy danh sách thông báo theo từng loại (Realtime từ Firestore)
final hostNotificationsProvider =
    StreamProvider.family<List<HostNotificationModel>, HostNotificationType>(
  (ref, type) {
    final authUser = ref.watch(currentUserProvider);
    final firebaseAuthUser = FirebaseAuth.instance.currentUser;
    final userProfile = ref.watch(userProfileProvider).asData?.value;
    final hostId = (authUser?.uid != null && authUser!.uid.isNotEmpty)
        ? authUser.uid
        : (firebaseAuthUser?.uid != null && firebaseAuthUser!.uid.isNotEmpty
            ? firebaseAuthUser.uid
            : (userProfile?.uid ?? ''));

    if (hostId.isEmpty) {
      return Stream.value(const []);
    }

    final repo = ref.watch(hostNotificationRepositoryProvider);
    return repo.watchByType(hostId: hostId, type: type);
  },
);

/// StreamProvider đếm số lượng thông báo theo từng loại để hiển thị badge số lượng
final hostNotificationCountsProvider =
    StreamProvider<Map<HostNotificationType, int>>((ref) {
  final authUser = ref.watch(currentUserProvider);
  final firebaseAuthUser = FirebaseAuth.instance.currentUser;
  final userProfile = ref.watch(userProfileProvider).asData?.value;
  final hostId = (authUser?.uid != null && authUser!.uid.isNotEmpty)
      ? authUser.uid
      : (firebaseAuthUser?.uid != null && firebaseAuthUser!.uid.isNotEmpty
          ? firebaseAuthUser.uid
          : (userProfile?.uid ?? ''));

  if (hostId.isEmpty) {
    return Stream.value({
      HostNotificationType.pendingAction: 0,
      HostNotificationType.staying: 0,
      HostNotificationType.deposit: 0,
      HostNotificationType.paymentCompleted: 0,
    });
  }

  final repo = ref.watch(hostNotificationRepositoryProvider);
  return repo.watchCounts(hostId);
});

/// StreamProvider đếm số lượng thông báo chưa đọc của chủ trọ
final hostUnreadNotificationCountProvider = StreamProvider<int>((ref) {
  final authUser = ref.watch(currentUserProvider);
  final firebaseAuthUser = FirebaseAuth.instance.currentUser;
  final userProfile = ref.watch(userProfileProvider).asData?.value;
  final hostId = (authUser?.uid != null && authUser!.uid.isNotEmpty)
      ? authUser.uid
      : (firebaseAuthUser?.uid != null && firebaseAuthUser!.uid.isNotEmpty
          ? firebaseAuthUser.uid
          : (userProfile?.uid ?? ''));

  if (hostId.isEmpty) {
    return Stream.value(0);
  }

  final repo = ref.watch(hostNotificationRepositoryProvider);
  return repo.getUnreadCount(hostId);
});

/// Provider lọc danh sách thông báo hiện tại kết hợp từ khóa tìm kiếm
final filteredHostNotificationsProvider =
    Provider<AsyncValue<List<HostNotificationModel>>>((ref) {
  final currentType = ref.watch(selectedHostNotificationTypeProvider);
  final asyncList = ref.watch(hostNotificationsProvider(currentType));
  final query = ref.watch(hostNotificationSearchQueryProvider).trim().toLowerCase();

  return asyncList.whenData((list) {
    if (query.isEmpty) return list;
    return list.where((item) {
      final code = item.displayBookingCode.toLowerCase();
      final title = item.roomTitle.toLowerCase();
      final postTitle = item.postTitle.toLowerCase();
      final notifTitle = item.title.toLowerCase();
      final rejectReason = item.rejectReason.toLowerCase();
      final renter = item.renterName.toLowerCase();
      final room = item.roomCode.toLowerCase();
      return code.contains(query) ||
          title.contains(query) ||
          postTitle.contains(query) ||
          notifTitle.contains(query) ||
          rejectReason.contains(query) ||
          renter.contains(query) ||
          room.contains(query);
    }).toList();
  });
});
