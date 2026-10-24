import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/admin_branded_title.dart';

/// 3 chế độ xem của trang Quản lý người dùng.
enum _UsersView { pendingReports, handledReports, allUsers }

/// Trang quản lý người dùng: duyệt báo cáo vi phạm, cảnh cáo, khóa / mở khóa tài khoản.
///
/// Giả định cấu trúc Firestore (sửa lại các key trong [_recompute] nếu khác):
///  - `reports/{id}`: reportedUserId, reportedUserName, reporterId, reporterName,
///    reason, description, status ('pending' | 'resolved' | 'dismissed'),
///    resolution ('banned' | 'warned' | 'dismissed'), adminNote, createdAt, handledAt
///  - `users/{id}`: fullName/name, email, phone, role, isBanned, bannedAt, banReason
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static const _primary = Color(0xFF398FC0);
  static const _textDark = Color(0xFF101828);
  static const _textGrey = Color(0xFF667085);
  static const _red = Color(0xFFD92D20);
  static const _green = Color(0xFF12B76A);
  static const _orange = Color(0xFFF79009);

  final TextEditingController _searchCtrl = TextEditingController();
  // Tìm kiếm dùng ValueNotifier để không setState khi gõ (giống trang Quản lý đơn).
  final ValueNotifier<String> _searchQuery = ValueNotifier<String>('');
  final DateFormat _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  StreamSubscription<QuerySnapshot>? _usersSub;
  StreamSubscription<QuerySnapshot>? _reportsSub;
  List<QueryDocumentSnapshot> _userDocs = [];
  List<QueryDocumentSnapshot> _reportDocs = [];

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  _UsersView _view = _UsersView.pendingReports;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => _searchQuery.value = _searchCtrl.text);

    _usersSub = FirebaseFirestore.instance.collection('users').snapshots().listen(
      (snap) {
        _userDocs = snap.docs;
        _recompute();
      },
      onError: (e) => debugPrint('Lỗi tải users: $e'),
    );

    _reportsSub = FirebaseFirestore.instance
        .collection('reports')
        .snapshots()
        .listen(
          (snap) {
            _reportDocs = snap.docs;
            _isLoading = false;
            _recompute();
          },
          onError: (e) {
            debugPrint('Lỗi tải reports: $e');
            if (mounted) setState(() => _isLoading = false);
          },
        );
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    _reportsSub?.cancel();
    _searchCtrl.dispose();
    _searchQuery.dispose();
    super.dispose();
  }

  // ───────────────────────── Helpers ─────────────────────────

  static String _removeAccents(String s) {
    var str = s.toLowerCase();
    const groups = {
      'a': 'áàảãạăắằẳẵặâấầẩẫậ',
      'd': 'đ',
      'e': 'éèẻẽẹêếềểễệ',
      'i': 'íìỉĩị',
      'o': 'óòỏõọôốồổỗộơớờởỡợ',
      'u': 'úùủũụưứừửữự',
      'y': 'ýỳỷỹỵ',
    };
    groups.forEach((base, chars) {
      for (final c in chars.split('')) {
        str = str.replaceAll(c, base);
      }
    });
    return str.trim();
  }

  static String _s(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString().trim();
    }
    return '';
  }

  static DateTime? _date(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static bool _matches(String query, List<String> fields) {
    final q = _removeAccents(query);
    if (q.isEmpty) return true;
    return fields.any((f) => _removeAccents(f).contains(q));
  }

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'host':
      case 'landlord':
      case 'chutro':
        return 'Chủ trọ';
      case 'admin':
        return 'Admin';
      case 'renter':
      case 'tenant':
        return 'Người thuê';
      default:
        return role.isEmpty ? 'Người dùng' : role;
    }
  }

  // ───────────────────────── Dữ liệu ─────────────────────────

  void _recompute() {
    final usersById = <String, Map<String, dynamic>>{};
    for (final d in _userDocs) {
      final data = Map<String, dynamic>.from(
        d.data() as Map<String, dynamic>? ?? {},
      );
      data['id'] = d.id;
      data['displayName'] = _s(data, ['fullName', 'name', 'displayName', 'email']);
      data['isBannedFlag'] = data['isBanned'] == true;
      usersById[d.id] = data;
    }

    final reportCount = <String, int>{};
    final pendingCount = <String, int>{};
    final reports = <Map<String, dynamic>>[];
    for (final d in _reportDocs) {
      final data = Map<String, dynamic>.from(
        d.data() as Map<String, dynamic>? ?? {},
      );
      data['id'] = d.id;
      final uid = _s(data, ['reportedUserId', 'targetUserId']);
      final status = _s(data, ['status']).toLowerCase();
      data['status'] = status.isEmpty ? 'pending' : status;
      data['reportedUserId'] = uid;
      data['createdAtDate'] = _date(data['createdAt']);
      reportCount[uid] = (reportCount[uid] ?? 0) + 1;
      if (data['status'] == 'pending') {
        pendingCount[uid] = (pendingCount[uid] ?? 0) + 1;
      }
      reports.add(data);
    }

    for (final r in reports) {
      final uid = r['reportedUserId'] as String;
      final u = usersById[uid];
      r['reportedName'] = _s(r, ['reportedUserName', 'targetUserName']).isNotEmpty
          ? _s(r, ['reportedUserName', 'targetUserName'])
          : (u?['displayName'] ?? 'Người dùng không xác định').toString();
      r['reportedRole'] = (u?['role'] ?? '').toString();
      r['reportedBanned'] = u?['isBanned'] == true;
      r['totalReports'] = reportCount[uid] ?? 1;
      r['reporterDisplay'] = _s(r, ['reporterName']).isNotEmpty
          ? _s(r, ['reporterName'])
          : (usersById[_s(r, ['reporterId'])]?['displayName'] ?? 'Ẩn danh')
                .toString();
    }

    reports.sort((a, b) {
      final da = a['createdAtDate'] as DateTime?;
      final db = b['createdAtDate'] as DateTime?;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    final users = usersById.values.toList();
    for (final u in users) {
      u['totalReports'] = reportCount[u['id']] ?? 0;
      u['pendingReports'] = pendingCount[u['id']] ?? 0;
    }
    users.sort((a, b) {
      final p = (b['pendingReports'] as int).compareTo(a['pendingReports'] as int);
      if (p != 0) return p;
      return (a['displayName'] as String).toLowerCase().compareTo(
        (b['displayName'] as String).toLowerCase(),
      );
    });

    if (!mounted) return;
    setState(() {
      _users = users;
      _reports = reports;
    });
  }

  // ───────────────────────── Hành động ─────────────────────────

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: error ? _red : _green, content: Text(msg)),
    );
  }

  /// Hộp thoại xác nhận có ô nhập ghi chú. Trả về null nếu huỷ.
  Future<String?> _askNote({
    required String title,
    required String message,
    required String hint,
    required String confirmLabel,
    required Color color,
    bool requireNote = false,
  }) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(fontSize: 13, color: _textGrey, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 3,
                onChanged: (_) => setLocal(() {}),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(fontSize: 12.5),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: requireNote && ctrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _audit(String action, String details, String target) {
    return FirebaseFirestore.instance.collection('audit_logs').add({
      'action': action,
      'actor': 'Admin',
      'category': 'nguoiDung',
      'details': details,
      'target': target,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _banUser({
    required String userId,
    required String userName,
    String? reportId,
  }) async {
    final reason = await _askNote(
      title: 'Khóa tài khoản?',
      message:
          'Tài khoản "$userName" sẽ bị khóa. Mọi báo cáo đang chờ về người này sẽ được đánh dấu đã xử lý.',
      hint: 'Lý do khóa (bắt buộc)...',
      confirmLabel: 'Khóa tài khoản',
      color: _red,
      requireNote: true,
    );
    if (reason == null) return;

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.set(db.collection('users').doc(userId), {
        'isBanned': true,
        'bannedAt': FieldValue.serverTimestamp(),
        'banReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final related = _reports.where(
        (r) =>
            r['reportedUserId'] == userId &&
            (r['status'] == 'pending' || r['id'] == reportId),
      );
      for (final r in related) {
        batch.set(db.collection('reports').doc(r['id'] as String), {
          'status': 'resolved',
          'resolution': 'banned',
          'adminNote': reason,
          'handledAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
      await _audit('Khóa tài khoản', 'Admin đã khóa "$userName". Lý do: $reason', 'User $userId');
      _snack('Đã khóa tài khoản $userName');
    } catch (e) {
      _snack('Lỗi khóa tài khoản: $e', error: true);
    }
  }

  Future<void> _unbanUser(Map<String, dynamic> user) async {
    final name = user['displayName'] as String;
    final note = await _askNote(
      title: 'Mở khóa tài khoản?',
      message: 'Tài khoản "$name" sẽ được hoạt động trở lại.',
      hint: 'Ghi chú (không bắt buộc)...',
      confirmLabel: 'Mở khóa',
      color: _green,
    );
    if (note == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user['id'] as String).set({
        'isBanned': false,
        'unbannedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _audit(
        'Mở khóa tài khoản',
        'Admin đã mở khóa "$name".${note.isEmpty ? '' : ' Ghi chú: $note'}',
        'User ${user['id']}',
      );
      _snack('Đã mở khóa tài khoản $name');
    } catch (e) {
      _snack('Lỗi mở khóa: $e', error: true);
    }
  }

  Future<void> _warnUser(Map<String, dynamic> report) async {
    final name = report['reportedName'] as String;
    final note = await _askNote(
      title: 'Gửi cảnh cáo?',
      message: 'Người dùng "$name" sẽ nhận thông báo cảnh cáo và báo cáo được đánh dấu đã xử lý.',
      hint: 'Nội dung cảnh cáo (bắt buộc)...',
      confirmLabel: 'Gửi cảnh cáo',
      color: _orange,
      requireNote: true,
    );
    if (note == null) return;
    try {
      final db = FirebaseFirestore.instance;
      final uid = report['reportedUserId'] as String;
      final batch = db.batch();
      batch.set(db.collection('reports').doc(report['id'] as String), {
        'status': 'resolved',
        'resolution': 'warned',
        'adminNote': note,
        'handledAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (uid.isNotEmpty) {
        batch.set(db.collection('notifications').doc(), {
          'recipientId': uid,
          'recipientRole': (report['reportedRole'] ?? '').toString(),
          'title': 'Cảnh báo vi phạm',
          'body': note,
          'notificationType': 'warning',
          'reportId': report['id'],
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      await _audit('Cảnh cáo người dùng', 'Admin cảnh cáo "$name". Nội dung: $note', 'User $uid');
      _snack('Đã gửi cảnh cáo tới $name');
    } catch (e) {
      _snack('Lỗi gửi cảnh cáo: $e', error: true);
    }
  }

  Future<void> _dismissReport(Map<String, dynamic> report) async {
    final note = await _askNote(
      title: 'Bỏ qua báo cáo?',
      message: 'Báo cáo được xem là không vi phạm và chuyển sang mục đã xử lý.',
      hint: 'Ghi chú (không bắt buộc)...',
      confirmLabel: 'Bỏ qua',
      color: _textGrey,
    );
    if (note == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(report['id'] as String)
          .set({
            'status': 'dismissed',
            'resolution': 'dismissed',
            'adminNote': note,
            'handledAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await _audit(
        'Bỏ qua báo cáo',
        'Admin bỏ qua báo cáo về "${report['reportedName']}".',
        'Report ${report['id']}',
      );
      _snack('Đã bỏ qua báo cáo');
    } catch (e) {
      _snack('Lỗi cập nhật: $e', error: true);
    }
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final cPending = _reports.where((r) => r['status'] == 'pending').length;
    final cHandled = _reports.length - cPending;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        toolbarHeight: 64,
        title: const AdminBrandedTitle(
          title: 'Quản lý người dùng',
          subtitle: 'Duyệt báo cáo vi phạm & quản lý tài khoản',
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên, email, SĐT, lý do...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF98A2B3)),
                prefixIcon: const Icon(Icons.search, size: 18, color: _textGrey),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: Row(
              children: [
                _pill('Chờ xử lý', cPending, _UsersView.pendingReports, _orange),
                const SizedBox(width: 8),
                _pill('Đã xử lý', cHandled, _UsersView.handledReports, _green),
                const SizedBox(width: 8),
                _pill('Người dùng', _users.length, _UsersView.allUsers, _primary),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFDCEAF5)),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ValueListenableBuilder<String>(
                    valueListenable: _searchQuery,
                    builder: (context, query, _) => _buildList(query),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, int count, _UsersView view, Color color) {
    final selected = _view == view;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _view = view),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : const Color(0xFFE2E8F0),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: selected ? color : _textDark,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : _textGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(String query) {
    if (_view == _UsersView.allUsers) {
      final items = _users.where((u) {
        return _matches(query, [
          u['displayName'] as String,
          _s(u, ['email']),
          _s(u, ['phone', 'phoneNumber']),
        ]);
      }).toList();
      if (items.isEmpty) return _empty('Không có người dùng phù hợp');
      return ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _userCard(items[i]),
      );
    }

    final pending = _view == _UsersView.pendingReports;
    final items = _reports.where((r) {
      if ((r['status'] == 'pending') != pending) return false;
      return _matches(query, [
        r['reportedName'] as String,
        r['reporterDisplay'] as String,
        _s(r, ['reason']),
        _s(r, ['description']),
      ]);
    }).toList();
    if (items.isEmpty) {
      return _empty(pending ? 'Không có báo cáo nào đang chờ xử lý 🎉' : 'Chưa có báo cáo nào được xử lý');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _reportCard(items[i]),
    );
  }

  Widget _empty(String text) => Center(
    child: Text(text, style: const TextStyle(color: _textGrey, fontSize: 13)),
  );

  BoxDecoration get _cardDeco => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFFDCEAF5)),
  );

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
    ),
  );

  Widget _avatar(String name, {bool banned = false}) {
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return CircleAvatar(
      radius: 20,
      backgroundColor: banned ? const Color(0xFFFEE4E2) : const Color(0xFFE9F5FC),
      child: Text(
        letter,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: banned ? _red : _primary,
        ),
      ),
    );
  }

  Widget _reportCard(Map<String, dynamic> r) {
    final pending = r['status'] == 'pending';
    final banned = r['reportedBanned'] == true;
    final name = r['reportedName'] as String;
    final date = r['createdAtDate'] as DateTime?;
    final resolution = _s(r, ['resolution']);
    final resolutionLabel = {
      'banned': 'Đã khóa tài khoản',
      'warned': 'Đã cảnh cáo',
      'dismissed': 'Đã bỏ qua',
    }[resolution];
    final adminNote = _s(r, ['adminNote']);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(name, banned: banned),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if ((r['reportedRole'] as String).isNotEmpty)
                          _chip(_roleLabel(r['reportedRole'] as String), _primary),
                        if (banned) _chip('Đã bị khóa', _red),
                        if ((r['totalReports'] as int) > 1)
                          _chip('${r['totalReports']} báo cáo', _orange),
                      ],
                    ),
                  ],
                ),
              ),
              if (!pending && resolutionLabel != null)
                _chip(resolutionLabel, resolution == 'dismissed' ? _textGrey : _green),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAEB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _s(r, ['reason']).isEmpty ? 'Không nêu lý do' : _s(r, ['reason']),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textDark),
                ),
                if (_s(r, ['description']).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _s(r, ['description']),
                    style: const TextStyle(fontSize: 12.5, color: _textGrey, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Người báo cáo: ${r['reporterDisplay']}${date == null ? '' : '  •  ${_dateFmt.format(date)}'}',
            style: const TextStyle(fontSize: 11.5, color: _textGrey),
          ),
          if (!pending && adminNote.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Ghi chú admin: $adminNote',
              style: const TextStyle(fontSize: 11.5, color: _textGrey, fontStyle: FontStyle.italic),
            ),
          ],
          if (pending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _dismissReport(r),
                    child: const Text('Bỏ qua', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _orange,
                      side: const BorderSide(color: _orange),
                    ),
                    onPressed: () => _warnUser(r),
                    child: const Text('Cảnh cáo', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _red),
                    onPressed: banned || (r['reportedUserId'] as String).isEmpty
                        ? null
                        : () => _banUser(
                            userId: r['reportedUserId'] as String,
                            userName: name,
                            reportId: r['id'] as String,
                          ),
                    child: const Text('Khóa TK', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _userCard(Map<String, dynamic> u) {
    final banned = u['isBanned'] == true;
    final name = u['displayName'] as String;
    final role = (u['role'] ?? '').toString();
    final isAdmin = role.toLowerCase() == 'admin';
    final contact = [
      _s(u, ['email']),
      _s(u, ['phone', 'phoneNumber']),
    ].where((e) => e.isNotEmpty).join('  •  ');
    final pendingReports = u['pendingReports'] as int;
    final totalReports = u['totalReports'] as int;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDeco,
      child: Row(
        children: [
          _avatar(name, banned: banned),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Chưa đặt tên' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _textDark,
                  ),
                ),
                if (contact.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      contact,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: _textGrey),
                    ),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _chip(_roleLabel(role), _primary),
                    if (banned) _chip('Đã bị khóa', _red),
                    if (pendingReports > 0)
                      _chip('$pendingReports báo cáo chờ', _orange)
                    else if (totalReports > 0)
                      _chip('$totalReports báo cáo', _textGrey),
                  ],
                ),
                if (banned && _s(u, ['banReason']).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Lý do khóa: ${_s(u, ['banReason'])}',
                      style: const TextStyle(fontSize: 11.5, color: _red),
                    ),
                  ),
              ],
            ),
          ),
          if (!isAdmin)
            banned
                ? OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: _green),
                    ),
                    onPressed: () => _unbanUser(u),
                    child: const Text('Mở khóa', style: TextStyle(fontSize: 12)),
                  )
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _red,
                      side: const BorderSide(color: _red),
                    ),
                    onPressed: () => _banUser(
                      userId: u['id'] as String,
                      userName: name,
                    ),
                    child: const Text('Khóa', style: TextStyle(fontSize: 12)),
                  ),
        ],
      ),
    );
  }
}