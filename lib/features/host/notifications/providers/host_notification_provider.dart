import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_share/features/auth/providers/auth_provider.dart';
import 'package:home_share/features/auth/providers/user_provider.dart';
import '../filters/host_notification_filter.dart';
import '../models/host_notification_model.dart';
import '../notification_types.dart';
import '../repositories/host_notification_repository.dart';

/// Provider khởi tạo Repository duy nhất cho module thông báo
final hostNotificationRepositoryProvider = Provider<HostNotificationRepository>(
  (ref) {
    return HostNotificationRepository();
  },
);

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
class SelectedHostNotificationTypeNotifier
    extends Notifier<HostNotificationType> {
  @override
  HostNotificationType build() => HostNotificationType.pendingAction;

  void setType(HostNotificationType type) => state = type;
}

final selectedHostNotificationTypeProvider =
    NotifierProvider<
      SelectedHostNotificationTypeNotifier,
      HostNotificationType
    >(SelectedHostNotificationTypeNotifier.new);

class HostNotificationFilterNotifier extends Notifier<HostNotificationFilter> {
  @override
  HostNotificationFilter build() => const HostNotificationFilter();

  void setFilter(HostNotificationFilter filter) => state = filter;

  void clear() => state = const HostNotificationFilter();
}

final hostNotificationFilterProvider =
    NotifierProvider<HostNotificationFilterNotifier, HostNotificationFilter>(
      HostNotificationFilterNotifier.new,
    );

/// Đồng bộ trạng thái CCCD realtime từ `users/{uid}.cccdVerificationStatus`
/// vào tab "Đang xử lý" của Chủ trọ nếu chưa có thông báo tương ứng.
List<HostNotificationModel> mergeLiveCccdStatusNotification({
  required List<HostNotificationModel> items,
  required UserProfile? profile,
  required HostNotificationType type,
}) {
  if (type != HostNotificationType.pendingAction || profile == null) {
    return items;
  }

  if (profile.isCccdRejected) {
    final rejectedAt = profile.cccdRejectedAt;
    final hasMatchingRejected = items.any((item) {
      if (!item.isCccdRejectedNotification) return false;
      if (rejectedAt == null) return true;
      return !item.createdAt.isBefore(
        rejectedAt.subtract(const Duration(seconds: 10)),
      );
    });
    if (!hasMatchingRejected) {
      final reason = profile.cccdRejectedReason.trim();
      final msg = reason.isNotEmpty
          ? 'Hồ sơ CCCD của bạn bị từ chối. Lý do: $reason. Vui lòng chụp lại ảnh rõ nét và gửi lại để Admin xét duyệt.'
          : 'Hồ sơ CCCD của bạn chưa đạt yêu cầu. Vui lòng chụp lại ảnh CCCD 2 mặt rõ nét và gửi lại để Admin xét duyệt.';
      final synthetic = HostNotificationModel(
        id: 'live_cccd_rejected_${profile.uid}',
        receiverId: profile.uid,
        senderId: 'admin',
        type: HostNotificationType.pendingAction,
        title: 'Yêu cầu xác thực CCCD bị từ chối',
        message: msg,
        statusId: 'rejected',
        isRead: false,
        createdAt: rejectedAt ?? DateTime.now(),
        actionType: 'cccd_verification_rejected',
        rejectReason: reason,
      );
      final merged = [synthetic, ...items];
      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return merged;
    }
  } else if (profile.isCccdPending) {
    final submittedAt = profile.cccdSubmittedAt;
    final hasMatchingPending = items.any((item) {
      if (!item.isCccdPendingNotification) return false;
      if (submittedAt == null) return true;
      return !item.createdAt.isBefore(
        submittedAt.subtract(const Duration(seconds: 10)),
      );
    });
    if (!hasMatchingPending) {
      final synthetic = HostNotificationModel(
        id: 'live_cccd_pending_${profile.uid}',
        receiverId: profile.uid,
        senderId: profile.uid,
        type: HostNotificationType.pendingAction,
        title: 'Đã gửi yêu cầu xác thực CCCD Chủ trọ',
        message:
            'Hồ sơ xác thực CCCD chủ trọ của bạn đã được gửi sang Quản trị viên xem xét, đang chờ xác thực tài khoản để kích hoạt đầy đủ quyền tạo phòng và đăng bài.',
        statusId: 'pending',
        isRead: true,
        createdAt: submittedAt ?? DateTime.now(),
        actionType: 'cccd_verification_pending',
      );
      final merged = [synthetic, ...items];
      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return merged;
    }
  } else if (profile.isCccdVerified) {
    final verifiedAt = profile.cccdVerifiedAt;
    final hasAnyCccd = items.any((item) => item.isCccdNotification);
    final hasApproved = items.any((item) => item.isCccdApprovedNotification);
    if (hasAnyCccd && !hasApproved) {
      final synthetic = HostNotificationModel(
        id: 'live_cccd_approved_${profile.uid}',
        receiverId: profile.uid,
        senderId: 'admin',
        type: HostNotificationType.pendingAction,
        title: 'Xác thực CCCD thành công ✓',
        message:
            'Hồ sơ định danh CCCD của bạn đã được Quản trị viên phê duyệt thành công!',
        statusId: 'approved',
        isRead: true,
        createdAt: verifiedAt ?? DateTime.now(),
        actionType: 'cccd_verification_approved',
      );
      final merged = [synthetic, ...items];
      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return merged;
    }
  }

  return items;
}

/// StreamProvider lấy danh sách thông báo theo từng loại (Realtime từ Firestore)
final hostNotificationsProvider =
    StreamProvider.family<List<HostNotificationModel>, HostNotificationType>((
      ref,
      type,
    ) {
      // Ưu tiên UID từ currentUserProvider, nếu rỗng thì fallback từ userProfileProvider
      final authUser = ref.watch(currentUserProvider);
      final userProfile = ref.watch(userProfileProvider).asData?.value;
      final hostId = authUser?.uid ?? userProfile?.uid ?? 'host_current_user';

      final repo = ref.watch(hostNotificationRepositoryProvider);
      return repo.watchByType(hostId: hostId, type: type).map(
            (items) => mergeLiveCccdStatusNotification(
              items: items,
              profile: userProfile,
              type: type,
            ),
          );
    });

/// StreamProvider đếm số lượng thông báo theo từng loại để hiển thị badge số lượng
final hostNotificationCountsProvider =
    StreamProvider<Map<HostNotificationType, int>>((ref) {
      final authUser = ref.watch(currentUserProvider);
      final userProfile = ref.watch(userProfileProvider).asData?.value;
      final hostId = authUser?.uid ?? userProfile?.uid ?? 'host_current_user';

      final repo = ref.watch(hostNotificationRepositoryProvider);
      return repo.watchByType(
        hostId: hostId,
        type: HostNotificationType.pendingAction,
      ).asyncExpand((pendingItems) {
        final mergedPending = mergeLiveCccdStatusNotification(
          items: pendingItems,
          profile: userProfile,
          type: HostNotificationType.pendingAction,
        );
        return repo.watchCounts(hostId).map((counts) {
          return {
            ...counts,
            HostNotificationType.pendingAction: mergedPending.length,
          };
        });
      });
    });

/// StreamProvider đếm số lượng thông báo chưa đọc của chủ trọ
final hostUnreadNotificationCountProvider = StreamProvider<int>((ref) {
  final authUser = ref.watch(currentUserProvider);
  final userProfile = ref.watch(userProfileProvider).asData?.value;
  final hostId = authUser?.uid ?? userProfile?.uid ?? 'host_current_user';

  final repo = ref.watch(hostNotificationRepositoryProvider);
  return repo.getUnreadCount(hostId).map((count) {
    if (userProfile?.isCccdRejected == true && count == 0) {
      return 1;
    }
    return count;
  });
});

/// Provider lọc danh sách thông báo hiện tại kết hợp từ khóa tìm kiếm
final filteredHostNotificationsProvider =
    Provider<AsyncValue<List<HostNotificationModel>>>((ref) {
      final currentType = ref.watch(selectedHostNotificationTypeProvider);
      final asyncList = ref.watch(hostNotificationsProvider(currentType));
      final query = ref.watch(hostNotificationSearchQueryProvider);
      final filter = ref.watch(hostNotificationFilterProvider);

      return asyncList.whenData((list) {
        return applyHostNotificationFilters(
          notifications: list,
          query: query,
          filter: filter,
        );
      });
    });
