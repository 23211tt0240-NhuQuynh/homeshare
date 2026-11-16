import '../models/host_notification_model.dart';

enum HostNotificationReadFilter { all, unread, read }

enum HostNotificationSortOrder { newest, oldest }

class HostNotificationFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final HostNotificationReadFilter readFilter;
  final HostNotificationSortOrder sortOrder;

  const HostNotificationFilter({
    this.startDate,
    this.endDate,
    this.readFilter = HostNotificationReadFilter.all,
    this.sortOrder = HostNotificationSortOrder.newest,
  });

  bool get hasDateRange => startDate != null || endDate != null;

  bool get isActive =>
      hasDateRange ||
      readFilter != HostNotificationReadFilter.all ||
      sortOrder != HostNotificationSortOrder.newest;

  int get activeCount =>
      (hasDateRange ? 1 : 0) +
      (readFilter != HostNotificationReadFilter.all ? 1 : 0) +
      (sortOrder != HostNotificationSortOrder.newest ? 1 : 0);

  HostNotificationFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    HostNotificationReadFilter? readFilter,
    HostNotificationSortOrder? sortOrder,
    bool clearDateRange = false,
  }) {
    return HostNotificationFilter(
      startDate: clearDateRange ? null : (startDate ?? this.startDate),
      endDate: clearDateRange ? null : (endDate ?? this.endDate),
      readFilter: readFilter ?? this.readFilter,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

List<HostNotificationModel> applyHostNotificationFilters({
  required Iterable<HostNotificationModel> notifications,
  String query = '',
  HostNotificationFilter filter = const HostNotificationFilter(),
}) {
  final normalizedQuery = _normalizeForSearch(query.trim());
  final start = filter.startDate == null
      ? null
      : DateTime(
          filter.startDate!.year,
          filter.startDate!.month,
          filter.startDate!.day,
        );
  final endExclusive = filter.endDate == null
      ? null
      : DateTime(
          filter.endDate!.year,
          filter.endDate!.month,
          filter.endDate!.day + 1,
        );

  final result = notifications.where((item) {
    if (normalizedQuery.isNotEmpty) {
      final searchableText = _normalizeForSearch(
        [
          item.displayBookingCode,
          item.bookingCode,
          item.bookingId,
          item.title,
          item.message,
          item.roomTitle,
          item.roomCode,
          item.roomId,
          item.renterName,
          item.statusId,
        ].join(' '),
      );
      if (!searchableText.contains(normalizedQuery)) return false;
    }

    if (start != null && item.createdAt.isBefore(start)) return false;
    if (endExclusive != null && !item.createdAt.isBefore(endExclusive)) {
      return false;
    }

    switch (filter.readFilter) {
      case HostNotificationReadFilter.all:
        break;
      case HostNotificationReadFilter.unread:
        if (item.isRead) return false;
      case HostNotificationReadFilter.read:
        if (!item.isRead) return false;
    }

    return true;
  }).toList();

  result.sort((a, b) {
    final comparison = a.createdAt.compareTo(b.createdAt);
    return filter.sortOrder == HostNotificationSortOrder.oldest
        ? comparison
        : -comparison;
  });
  return result;
}

String _normalizeForSearch(String value) {
  var normalized = value.toLowerCase();
  const replacements = <String, String>{
    'à': 'a',
    'á': 'a',
    'ạ': 'a',
    'ả': 'a',
    'ã': 'a',
    'â': 'a',
    'ầ': 'a',
    'ấ': 'a',
    'ậ': 'a',
    'ẩ': 'a',
    'ẫ': 'a',
    'ă': 'a',
    'ằ': 'a',
    'ắ': 'a',
    'ặ': 'a',
    'ẳ': 'a',
    'ẵ': 'a',
    'è': 'e',
    'é': 'e',
    'ẹ': 'e',
    'ẻ': 'e',
    'ẽ': 'e',
    'ê': 'e',
    'ề': 'e',
    'ế': 'e',
    'ệ': 'e',
    'ể': 'e',
    'ễ': 'e',
    'ì': 'i',
    'í': 'i',
    'ị': 'i',
    'ỉ': 'i',
    'ĩ': 'i',
    'ò': 'o',
    'ó': 'o',
    'ọ': 'o',
    'ỏ': 'o',
    'õ': 'o',
    'ô': 'o',
    'ồ': 'o',
    'ố': 'o',
    'ộ': 'o',
    'ổ': 'o',
    'ỗ': 'o',
    'ơ': 'o',
    'ờ': 'o',
    'ớ': 'o',
    'ợ': 'o',
    'ở': 'o',
    'ỡ': 'o',
    'ù': 'u',
    'ú': 'u',
    'ụ': 'u',
    'ủ': 'u',
    'ũ': 'u',
    'ư': 'u',
    'ừ': 'u',
    'ứ': 'u',
    'ự': 'u',
    'ử': 'u',
    'ữ': 'u',
    'ỳ': 'y',
    'ý': 'y',
    'ỵ': 'y',
    'ỷ': 'y',
    'ỹ': 'y',
    'đ': 'd',
  };
  replacements.forEach((source, target) {
    normalized = normalized.replaceAll(source, target);
  });
  return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
}
