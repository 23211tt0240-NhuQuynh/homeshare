import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../../core/utils/host_reputation.dart';

final hostReputationScoreProvider =
    StreamProvider.autoDispose.family<int, String>((ref, hostId) {
  if (hostId.trim().isEmpty) {
    return Stream.value(HostReputation.defaultScore);
  }
  try {
    return FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(hostId)
        .snapshots()
        .map((doc) {
      final data = doc.data();
      final raw = data?['reputationScore'] ?? HostReputation.defaultScore;
      if (raw is num) return HostReputation.clampScore(raw.toInt());
      return HostReputation.defaultScore;
    });
  } catch (_) {
    return Stream.value(HostReputation.defaultScore);
  }
});

/// Sao uy tín chủ trọ: icon sao + số (vd. 4.5). Không hiện 100/100.
class HostReputationStarLabel extends ConsumerWidget {
  final String hostId;
  final double iconSize;
  final TextStyle? textStyle;

  const HostReputationStarLabel({
    super.key,
    required this.hostId,
    this.iconSize = 14,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = ref.watch(hostReputationScoreProvider(hostId)).maybeWhen(
          data: (value) => value,
          orElse: () => HostReputation.defaultScore,
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: iconSize, color: Colors.amber),
        const SizedBox(width: 2),
        Text(
          HostReputation.starsText(score),
          style: textStyle ??
              const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
