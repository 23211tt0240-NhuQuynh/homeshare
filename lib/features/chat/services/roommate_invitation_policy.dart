import '../../auth/services/role_resolver.dart';

/// Quy tắc nghiệp vụ thuần cho lời mời ở ghép trong tin nhắn.
///
/// Mặc định chặn (fail-closed): chỉ khi xác định được cả hai bên đều là
/// người thuê và người gửi có một phòng đang hoạt động thì mới cho phép.
abstract final class RoommateInvitationPolicy {
  // Chỉ chấp nhận các trạng thái thực tế đã nhận phòng và đang ở trong trọ
  static const Set<String> _activeBookingStatuses = {
    'active',
    'rented',
    'dango',
    'danhanphong',
    'completed',
  };

  static const Set<String> _activeResidentStatuses = {'active', 'dango'};

  static bool canInvite({
    required String? senderRole,
    required String? receiverRole,
    required bool hasActiveRoom,
  }) {
    return RoleResolver.normalizeRole(senderRole) == RoleResolver.renter &&
        RoleResolver.normalizeRole(receiverRole) == RoleResolver.renter &&
        hasActiveRoom;
  }

  static bool isActiveBookingStatus(dynamic status) {
    return _activeBookingStatuses.contains(_normalizeStatus(status));
  }

  static bool isActiveResidentStatus(dynamic status) {
    return _activeResidentStatuses.contains(_normalizeStatus(status));
  }

  static String _normalizeStatus(dynamic raw) {
    return raw.toString().trim().toLowerCase().replaceAll(
      RegExp(r'[\s_-]+'),
      '',
    );
  }
}
