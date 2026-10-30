import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads the history screen's commission setting and resolves the rate that
/// was effective when a booking was created.
class CommissionRateService {
  CommissionRateService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<double> currentRate({double fallback = 0.10}) async {
    try {
      final config = await _db
          .collection('system_configs')
          .doc('platform_settings')
          .get();
      final value = config.data()?['commission_rate'];
      if (value is num) return value.toDouble().clamp(0, 50) / 100;
    } catch (_) {}
    return fallback;
  }

  static Future<double> rateAt(
    DateTime? effectiveDate, {
    double fallback = 0.10,
  }) async {
    final current = await currentRate(fallback: fallback);
    if (effectiveDate == null) return current;

    final events = <_RateEvent>[];
    try {
      final history = await _db.collection('commission_rate_history').get();
      for (final doc in history.docs) {
        final data = doc.data();
        final rate = data['rate'];
        final previousRate = data['previousRate'];
        final at = _date(data['effectiveAt'] ?? data['createdAt']);
        if (rate is num && at != null) {
          events.add(
            _RateEvent(
              at,
              previousRate is num ? previousRate.toDouble() / 100 : null,
              rate.toDouble() / 100,
            ),
          );
        }
      }
    } catch (_) {}

    // Older revisions were only stored as History audit log entries.
    try {
      final logs = await _db
          .collection('audit_logs')
          .where('category', isEqualTo: 'system')
          .get();
      final pattern = RegExp(
        r'Thay đổi mức phí từ\s*([0-9]+(?:[.,][0-9]+)?)%.*?([0-9]+(?:[.,][0-9]+)?)%',
        caseSensitive: false,
      );
      for (final doc in logs.docs) {
        final data = doc.data();
        final text = (data['subtitle'] ?? '').toString();
        if (!text.toLowerCase().contains('hoa hồng')) continue;
        final match = pattern.firstMatch(text);
        final at = _date(data['timestamp'] ?? data['createdAt']);
        if (match == null || at == null) continue;
        final before = double.tryParse(match.group(1)!.replaceAll(',', '.'));
        final after = double.tryParse(match.group(2)!.replaceAll(',', '.'));
        if (before != null && after != null) {
          events.add(_RateEvent(at, before / 100, after / 100));
        }
      }
    } catch (_) {}

    if (events.isEmpty) return current;
    events.sort((a, b) => a.effectiveAt.compareTo(b.effectiveAt));

    var rate = events.first.previousRate ?? current;
    for (final event in events) {
      if (event.effectiveAt.isAfter(effectiveDate)) break;
      rate = event.rate;
    }
    return rate.clamp(0, 0.5).toDouble();
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

class _RateEvent {
  const _RateEvent(this.effectiveAt, this.previousRate, this.rate);

  final DateTime effectiveAt;
  final double? previousRate;
  final double rate;
}
