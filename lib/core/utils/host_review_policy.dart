import '../../data/models/booking_model.dart';
import '../../data/models/resident_model.dart';

/// Điều kiện gửi đánh giá chủ trọ. Rules Firestore phải kiểm tra lại, không tin client.
abstract final class HostReviewPolicy {
  static const maxCommentLength = 500;

  /// Đã nhận phòng (kể cả sau khi bị đuổi / trả phòng).
  static const reviewableStatuses = {
    'active',
    'dango',
    'dang_o',
    'danhanphong',
    'checked_out',
    'checkout',
    'traphong',
    'daketthuc',
    'daroi',
    'ended',
    'moved_out',
  };

  static bool isReviewableStatus(String status) {
    return reviewableStatuses.contains(status.toLowerCase().trim());
  }

  static bool isReviewableResidentStatus(String status) {
    final normalized = status.toLowerCase().trim().replaceAll(RegExp(r'[\s_-]+'), '');
    return normalized == 'dango' ||
        normalized == 'active' ||
        normalized == 'daroi' ||
        normalized == 'movedout';
  }

  static bool isValidRating(int rating) => rating >= 1 && rating <= 5;

  static bool canReviewOwnHost(String reviewerId, String hostId) {
    if (reviewerId.isEmpty || hostId.isEmpty) return false;
    return reviewerId != hostId;
  }

  static bool isReviewableBooking(BookingRequestModel booking) {
    if (booking.id.isEmpty || booking.hostId.isEmpty || booking.renterId.isEmpty) {
      return false;
    }
    if (booking.isCancelled) return false;
    return booking.isActive || booking.isEnded;
  }

  static bool isReviewableResident(ResidentModel resident) {
    if (resident.id.isEmpty || resident.userId.isEmpty) return false;
    return isReviewableResidentStatus(resident.statusId);
  }

  static BookingRequestModel stayFromResident(
    ResidentModel resident, {
    required String hostId,
  }) {
    return BookingRequestModel(
      id: resident.id,
      renterId: resident.userId,
      renterName: resident.fullName,
      renterPhone: resident.phone,
      roomId: resident.roomId,
      roomTitle: '',
      roomAddress: '',
      roomPrice: 0,
      hostId: hostId,
      hostName: '',
      status: resident.moveOutDate != null ? 'checked_out' : 'dangO',
      moveInDate: resident.moveInDate,
      moveOutDate: resident.moveOutDate,
      createdAt: resident.moveInDate,
    );
  }

  static BookingRequestModel? firstEligibleBooking({
    required String reviewerId,
    required String hostId,
    required List<BookingRequestModel> bookings,
    required Set<String> reviewedBookingIds,
  }) {
    if (!canReviewOwnHost(reviewerId, hostId)) return null;
    final matches = bookings.where((booking) {
      if (booking.renterId != reviewerId) return false;
      if (booking.hostId != hostId) return false;
      if (!isReviewableBooking(booking)) return false;
      if (reviewedBookingIds.contains(booking.id)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (matches.isEmpty) return null;
    return matches.first;
  }

  /// Người ở ghép không có đơn `bookings` riêng; dùng bản ghi `residents`.
  static BookingRequestModel? firstEligibleResident({
    required String reviewerId,
    required String hostId,
    required List<ResidentModel> residents,
    required Map<String, String> roomHostByRoomId,
    required Set<String> reviewedBookingIds,
  }) {
    if (!canReviewOwnHost(reviewerId, hostId)) return null;
    final matches = residents.where((resident) {
      if (resident.userId != reviewerId) return false;
      if (!isReviewableResident(resident)) return false;
      if (reviewedBookingIds.contains(resident.id)) return false;
      final roomHost = roomHostByRoomId[resident.roomId] ?? '';
      return roomHost == hostId;
    }).toList()
      ..sort((a, b) => b.moveInDate.compareTo(a.moveInDate));
    if (matches.isEmpty) return null;
    return stayFromResident(matches.first, hostId: hostId);
  }
}
