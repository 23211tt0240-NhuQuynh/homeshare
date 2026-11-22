import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/firestore_collections.dart';
import '../utils/host_reputation.dart';

/// Cấp phát số `hostIndex` cố định cho chủ trọ (1, 2, 3…).
///
/// - `counters/hostIndex.next`: số tiếp theo toàn hệ thống.
/// - `users/{uid}.hostIndex`: số gắn với từng chủ, gán một lần không đổi.
class HostIndexService {
  HostIndexService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String counterCollection = 'counters';
  static const String counterDocId = 'hostIndex';
  static const String fieldHostIndex = 'hostIndex';
  static const String fieldNext = 'next';

  DocumentReference<Map<String, dynamic>> get _counterRef =>
      _firestore.collection(counterCollection).doc(counterDocId);

  /// Đọc `hostIndex` đã có; nếu thiếu thì cấp số mới (không trùng).
  Future<int> ensureHostIndex(String hostId) async {
    final uid = hostId.trim();
    if (uid.isEmpty) {
      throw ArgumentError('Thiếu hostId khi cấp hostIndex.');
    }

    final userRef = _firestore.collection(FirestoreCollections.users).doc(uid);
    final existing = await userRef.get();
    final data = existing.data();
    final current = _readIndex(data);
    if (current != null) return current;

    final role = (data?['role'] ?? data?['vaiTro'] ?? '').toString();
    if (data != null &&
        data.isNotEmpty &&
        !HostReputation.isHostRole(role) &&
        role.trim().isNotEmpty) {
      throw StateError('Chỉ tài khoản chủ trọ mới được cấp hostIndex.');
    }

    try {
      return await _firestore.runTransaction((tx) async {
        final userSnap = await tx.get(userRef);
        final again = _readIndex(userSnap.data());
        if (again != null) return again;

        final counterSnap = await tx.get(_counterRef);
        final next = ((counterSnap.data()?[fieldNext] as num?)?.toInt() ?? 1);
        final assigned = next < 1 ? 1 : next;

        tx.set(_counterRef, {
          fieldNext: assigned + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        tx.set(userRef, {
          fieldHostIndex: assigned,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return assigned;
      });
    } catch (e, st) {
      debugPrint('[HostIndexService] Lỗi cấp hostIndex cho $uid: $e\n$st');
      rethrow;
    }
  }

  /// Đọc nhanh, không cấp mới. Trả null nếu chưa có.
  Future<int?> peekHostIndex(String hostId) async {
    final uid = hostId.trim();
    if (uid.isEmpty) return null;
    final doc =
        await _firestore.collection(FirestoreCollections.users).doc(uid).get();
    return _readIndex(doc.data());
  }

  /// Backfill mọi host chưa có `hostIndex` (host cũ trên Firebase).
  Future<int> ensureAllHostsHaveIndex() async {
    final snap = await _firestore.collection(FirestoreCollections.users).get();
    final hosts = snap.docs.where((doc) {
      final role = (doc.data()['role'] ?? doc.data()['vaiTro'] ?? '').toString();
      return HostReputation.isHostRole(role);
    }).toList()
      ..sort((a, b) {
        final aTime = _createdAt(a.data());
        final bTime = _createdAt(b.data());
        return aTime.compareTo(bTime);
      });

    var assignedCount = 0;
    for (final doc in hosts) {
      final before = _readIndex(doc.data());
      final after = await ensureHostIndex(doc.id);
      if (before == null && after > 0) assignedCount++;
    }
    return assignedCount;
  }

  static int? _readIndex(Map<String, dynamic>? data) {
    if (data == null) return null;
    final raw = data[fieldHostIndex] ?? data['soChuTro'];
    if (raw is num) {
      final value = raw.toInt();
      return value > 0 ? value : null;
    }
    final parsed = int.tryParse(raw?.toString().trim() ?? '');
    return (parsed != null && parsed > 0) ? parsed : null;
  }

  static DateTime _createdAt(Map<String, dynamic> data) {
    final value = data['createdAt'] ?? data['ngayTao'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

final hostIndexServiceProvider = Provider<HostIndexService>(
  (ref) => HostIndexService(),
);
