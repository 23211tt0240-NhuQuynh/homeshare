import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Xem lịch sử vi phạm và điều chỉnh điểm uy tín của một tài khoản.
/// Việc ghi vi phạm/áp dụng ngưỡng được xử lý ở Cloud Function để dùng giờ máy chủ.
class AdminUserReputationDialog extends StatefulWidget {
  final String userId;
  final String userName;

  const AdminUserReputationDialog({
    super.key,
    required this.userId,
    required this.userName,
  });

  static Future<void> show(
    BuildContext context, {
    required String userId,
    required String userName,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AdminUserReputationDialog(
        userId: userId,
        userName: userName,
      ),
    );
  }

  @override
  State<AdminUserReputationDialog> createState() =>
      _AdminUserReputationDialogState();
}

class _AdminUserReputationDialogState
    extends State<AdminUserReputationDialog> {
  static const _red = Color(0xFFD92D20);
  static const _green = Color(0xFF12B76A);
  static const _muted = Color(0xFF667085);

  final _deltaController = TextEditingController(text: '5');
  final _adjustReasonController = TextEditingController();
  final _violationReasonController = TextEditingController();
  final _penaltyController = TextEditingController(text: '5');
  bool _deduct = true;
  String _violationType = 'other';
  bool _busy = false;
  String? _message;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  HttpsCallable get _recordViolation => FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('recordUserViolation');
  HttpsCallable get _adjustReputation => FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('adjustUserReputation');

  @override
  void dispose() {
    _deltaController.dispose();
    _adjustReasonController.dispose();
    _violationReasonController.dispose();
    _penaltyController.dispose();
    super.dispose();
  }

  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Future<void> _adjustScore() async {
    final amount = int.tryParse(_deltaController.text.trim());
    final reason = _adjustReasonController.text.trim();
    if (amount == null || amount < 1 || amount > 100 || reason.isEmpty) {
      setState(() => _message = 'Nhập số điểm từ 1–100 và lý do điều chỉnh.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _adjustReputation.call({
        'userId': widget.userId,
        'delta': _deduct ? -amount : amount,
        'reason': reason,
      });
      if (!mounted) return;
      _adjustReasonController.clear();
      setState(() => _message = 'Đã cập nhật điểm uy tín.');
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _message = e.message ?? 'Không cập nhật được điểm.');
    } catch (e) {
      if (mounted) setState(() => _message = 'Không cập nhật được điểm: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmViolation() async {
    final reason = _violationReasonController.text.trim();
    final points = int.tryParse(_penaltyController.text.trim());
    if (reason.isEmpty || points == null || points < 0 || points > 100) {
      setState(() => _message = 'Nhập nội dung vi phạm và điểm trừ từ 0–100.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận vi phạm?'),
        content: Text(
          _violationType == 'scam'
              ? 'Vi phạm lừa đảo đã xác nhận sẽ trừ $points điểm và khóa tài khoản 7 ngày ngay.'
              : 'Ghi nhận vi phạm này, trừ $points điểm và tính vào các ngưỡng 30/90 ngày.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await _recordViolation.call({
        'userId': widget.userId,
        'userName': widget.userName,
        'requestId': '${widget.userId}_${DateTime.now().microsecondsSinceEpoch}',
        'type': _violationType,
        'reason': reason,
        'pointsDeducted': points,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      final deleted = data['accountDeleted'] == true;
      final suspended = data['suspendedUntil'];
      if (!mounted) return;
      _violationReasonController.clear();
      setState(() {
        _message = deleted
            ? 'Đã chạm ngưỡng 10 vi phạm/90 ngày; tài khoản đã bị xóa quyền đăng nhập.'
            : suspended is String
                ? 'Đã ghi nhận. Tài khoản bị khóa đến $suspended.'
                : 'Đã ghi nhận vi phạm và cập nhật điểm uy tín.';
      });
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _message = e.message ?? 'Không ghi nhận được vi phạm.');
    } catch (e) {
      if (mounted) setState(() => _message = 'Không ghi nhận được vi phạm: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userStream = _db.collection('users').doc(widget.userId).snapshots();
    final violationStream = _db
        .collection('violations')
        .where('userId', isEqualTo: widget.userId)
        .snapshots();

    return AlertDialog(
      scrollable: true,
      title: Text('Uy tín & vi phạm · ${widget.userName}'),
      content: SizedBox(
        width: MediaQuery.sizeOf(context).width > 560
            ? 500
            : MediaQuery.sizeOf(context).width * .82,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userStream,
          builder: (context, userSnapshot) {
            final user = userSnapshot.data?.data() ?? const <String, dynamic>{};
            final score = ((user['reputationScore'] ?? user['diemUyTin']) as num?)
                    ?.toInt() ??
                100;
            final accountDeleted = user['accountDeleted'] == true;
            final suspendedUntil = _date(user['suspendedUntil']);
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: violationStream,
              builder: (context, violationSnapshot) {
                final records = violationSnapshot.data?.docs ?? const [];
                final violations = records
                    .map((doc) => doc.data())
                    .where((data) => data['confirmed'] == true)
                    .toList()
                  ..sort((a, b) =>
                      (_date(b['createdAt']) ?? DateTime(1970)).compareTo(
                        _date(a['createdAt']) ?? DateTime(1970),
                      ));
                final now = DateTime.now();
                final monthCount = violations.where((item) {
                  final date = _date(item['createdAt']);
                  return date != null &&
                      !date.isAfter(now) &&
                      now.difference(date) <= const Duration(days: 30);
                }).length;
                final quarterCount = violations.where((item) {
                  final date = _date(item['createdAt']);
                  return date != null &&
                      !date.isAfter(now) &&
                      now.difference(date) <= const Duration(days: 90);
                }).length;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('Uy tín: $score/100')),
                        Chip(
                          label: Text('30 ngày: $monthCount/3'),
                          backgroundColor: monthCount >= 3
                              ? const Color(0xFFFEE4E2)
                              : null,
                        ),
                        Chip(
                          label: Text('90 ngày: $quarterCount/10'),
                          backgroundColor: quarterCount >= 10
                              ? const Color(0xFFFEE4E2)
                              : null,
                        ),
                      ],
                    ),
                    if (user['accountDeleted'] == true)
                      const Text(
                        'Tài khoản đã bị xóa quyền đăng nhập.',
                        style: TextStyle(color: _red, fontWeight: FontWeight.w700),
                      )
                    else if (suspendedUntil != null && suspendedUntil.isAfter(now))
                      Text(
                        'Đang khóa đến ${DateFormat('dd/MM/yyyy HH:mm').format(suspendedUntil)}',
                        style: const TextStyle(color: _red, fontWeight: FontWeight.w700),
                      ),
                    const SizedBox(height: 12),
                    const Text('Điều chỉnh điểm uy tín',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Trừ'),
                          selected: _deduct,
                          onSelected: _busy ? null : (_) => setState(() => _deduct = true),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Cộng'),
                          selected: !_deduct,
                          onSelected: _busy ? null : (_) => setState(() => _deduct = false),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 74,
                          child: TextField(
                            controller: _deltaController,
                            enabled: !_busy && !accountDeleted,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Điểm',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _adjustReasonController,
                      enabled: !_busy && !accountDeleted,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Lý do điều chỉnh',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _busy || accountDeleted ? null : _adjustScore,
                        icon: Icon(_deduct ? Icons.remove_circle_outline : Icons.add_circle_outline),
                        label: Text(_deduct ? 'Trừ điểm' : 'Cộng điểm'),
                      ),
                    ),
                    const Divider(height: 24),
                    const Text('Xác nhận vi phạm',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _violationType,
                      decoration: const InputDecoration(
                        labelText: 'Mức độ',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'other', child: Text('Vi phạm khác')),
                        DropdownMenuItem(value: 'scam', child: Text('Lừa đảo · nghiêm trọng nhất')),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() {
                                _violationType = value;
                                _penaltyController.text = value == 'scam' ? '20' : '5';
                              });
                            },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _violationReasonController,
                      enabled: !_busy && !accountDeleted,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Bằng chứng / nội dung vi phạm đã xác nhận',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _penaltyController,
                      enabled: !_busy && !accountDeleted,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Điểm uy tín cần trừ (0–100)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _busy || accountDeleted ? null : _confirmViolation,
                      style: FilledButton.styleFrom(backgroundColor: _red),
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.gavel_outlined),
                      label: const Text('Ghi nhận vi phạm'),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _message!,
                        style: TextStyle(
                          color: _message!.startsWith('Đã') ? _green : _muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const Divider(height: 24),
                    const Text('Lịch sử vi phạm đã xác nhận',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    if (violationSnapshot.hasError)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Không tải được lịch sử vi phạm.'),
                      )
                    else if (violations.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Chưa có vi phạm được xác nhận.'),
                      )
                    else
                      ...violations.take(8).map((item) {
                        final date = _date(item['createdAt']);
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            item['type'] == 'scam'
                                ? Icons.report_gmailerrorred_outlined
                                : Icons.warning_amber_rounded,
                            color: item['type'] == 'scam' ? _red : const Color(0xFFF79009),
                          ),
                          title: Text(
                            item['type'] == 'scam' ? 'Lừa đảo' : 'Vi phạm',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${item['reason'] ?? ''}\n${date == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(date)} · -${item['pointsDeducted'] ?? 0} điểm',
                          ),
                          isThreeLine: true,
                        );
                      }),
                  ],
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
