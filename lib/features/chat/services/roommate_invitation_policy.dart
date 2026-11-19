import '../../auth/services/role_resolver.dart';

/// Quy tắc nghiệp vụ thuần cho lời mời ở ghép trong tin nhắn.
///
/// Mặc định chặn (fail-closed): chỉ khi xác định được cả hai bên đều là
/// người thuê và người gửi có một phòng đang hoạt động thì mới cho phép.
abstract final class RoommateInvitationPolicy {
  static const Set<String> _activeBookingStatuses = {
    'approved',
    'depositpaid',
    'paid',
    'completed',
    'active',
    'rented',
    'dango',
    'danhanphong',
    'dacoc',
    'daduyet',
    'chonhanphong',
  };

  static const Set<String> _activeResidentStatuses = {'active', 'dango'};

  static bool canInvite({
    required String? senderRole,
    required String? receiverRole,
    required bool hasActiveRoom,
    bool roomHasFreeCapacity = true,
  }) {
    return RoleResolver.normalizeRole(senderRole) == RoleResolver.renter &&
        RoleResolver.normalizeRole(receiverRole) == RoleResolver.renter &&
        hasActiveRoom &&
        roomHasFreeCapacity;
  }

  static bool isActiveBookingStatus(dynamic status) {
    return _activeBookingStatuses.contains(_normalizeStatus(status));
  }

  static bool isActiveResidentStatus(dynamic status) {
    return _activeResidentStatuses.contains(_normalizeStatus(status));
  }

  /// Đúng phòng người thuê đang ở, cùng điều kiện tab "Nhà đang ở".
  /// Đơn chỉ mới duyệt, đã cọc hoặc đã trả phòng không được mời ở ghép.
  static bool isCurrentOccupancyStatus(dynamic status) {
    final normalized = _normalizeStatus(status);
    if (normalized.isEmpty) return false;
    const left = {
      'completed',
      'checkedout',
      'checkout',
      'movedout',
      'daroi',
      'daketthuc',
      'traphong',
      'dacheckout',
      'ended',
    };
    const cancelled = {
      'cancelled',
      'dahuy',
      'rejected',
      'tuchoi',
      'bituchoi',
    };
    if (left.contains(normalized) || cancelled.contains(normalized)) {
      return false;
    }
    const staying = {
      'active',
      'dango',
      'danhanphong',
      'checkin',
      'checkedin',
      'dacheckin',
      'staying',
      'occupied',
    };
    return staying.contains(normalized);
  }

  static String _normalizeStatus(dynamic raw) {
    return raw.toString().trim().toLowerCase().replaceAll(
      RegExp(r'[\s_-]+'),
      '',
    );
  }
}
