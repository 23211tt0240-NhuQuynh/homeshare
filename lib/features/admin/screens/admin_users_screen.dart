import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/admin_branded_title.dart';
import '../widgets/admin_theme_toggle.dart';
import '../../renter/screens/room_detail_screen.dart';
import '../../../core/services/room_service.dart';
import '../../../core/services/violation_rules_service.dart';
import '../../../data/models/room_model.dart';
import '../../../data/models/violation_rule_model.dart';
import '../widgets/violation_rules_sheet.dart';
import '../theme/admin_colors.dart';

/// 3 chế độ xem của trang Quản lý người dùng.
enum _UsersView { pendingReports, handledReports, reposts, allUsers }

/// Trang quản lý người dùng: duyệt báo cáo vi phạm, cảnh cáo, duyệt repost, khóa / mở khóa tài khoản.
///
/// Giả định cấu trúc Firestore:
///  - `reports/{id}`: reportedUserId, reportedUserName, reporterId, reporterName,
///    reason, description, status ('pending' | 'resolved' | 'dismissed'),
///    resolution ('banned' | 'warned' | 'dismissed'), adminNote, createdAt, handledAt
///  - `users/{id}`: fullName/name, email, phone, role, isBanned, bannedAt, banReason
///  - `repost/{id}` & `reposts/{id}`: postId, title, price, address, userId, userName,
///    userPhone, reason (lý do từng vi phạm), note (nội dung sửa), status, createdAt, images
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static Color get _primary => AdminColors.accent;
  static Color get _textDark => AdminColors.ink;
  static Color get _textGrey => AdminColors.muted;
  static Color get _red => AdminColors.danger;
  static Color get _green => AdminColors.success;
  static Color get _orange => AdminColors.warning;

  final TextEditingController _searchCtrl = TextEditingController();
  // Tìm kiếm dùng ValueNotifier để không setState khi gõ (giống trang Quản lý đơn).
  final ValueNotifier<String> _searchQuery = ValueNotifier<String>('');
  final DateFormat _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  StreamSubscription<QuerySnapshot>? _usersSub;
  StreamSubscription<QuerySnapshot>? _reportsSub;
  StreamSubscription<QuerySnapshot>? _repostSub;
  StreamSubscription<QuerySnapshot>? _repostsSub;
  List<QueryDocumentSnapshot> _userDocs = [];
  List<QueryDocumentSnapshot> _reportDocs = [];
  List<QueryDocumentSnapshot> _repostDocs = [];
  List<QueryDocumentSnapshot> _repostsPluralDocs = [];

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _repostItems = [];
  bool _isLoading = true;
  _UsersView _view = _UsersView.pendingReports;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => _searchQuery.value = _searchCtrl.text);

    try {
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

      _repostSub = FirebaseFirestore.instance
          .collection('repost')
          .snapshots()
          .listen(
            (snap) {
              _repostDocs = snap.docs;
              _recompute();
            },
            onError: (e) => debugPrint('Lỗi tải repost: $e'),
          );

      _repostsSub = FirebaseFirestore.instance
          .collection('reposts')
          .snapshots()
          .listen(
            (snap) {
              _repostsPluralDocs = snap.docs;
              _recompute();
            },
            onError: (e) => debugPrint('Lỗi tải reposts: $e'),
          );
    } catch (e) {
      debugPrint('Chưa thể khởi tạo Firestore trong AdminUsersScreen: $e');
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    _reportsSub?.cancel();
    _repostSub?.cancel();
    _repostsSub?.cancel();
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
      // CHỈ LẤY BÁO CÁO / ĐÁNH GIÁ CHỦ TRỌ & NGƯỜI DÙNG (KHÔNG LẤY BÁO CÁO BÀI VIẾT)
      // Các báo cáo bài viết (targetType == 'post' hoặc id 'BCB_') không thuộc phạm vi duyệt tài khoản người dùng
      final targetType = (data['targetType'] ?? data['reportType'] ?? '').toString().toLowerCase();
      final isPostReport = targetType == 'post' ||
          d.id.startsWith('BCB_') ||
          (data['isPostReport'] == true);
      if (isPostReport) {
        continue;
      }

      final uid = _s(data, [
        'reportedUserId',
        'targetUserId',
        'hostId',
        'chuNhaId',
        'userId',
        'targetId',
      ]);
      final status = _s(data, ['status']).toLowerCase();
      data['status'] = status.isEmpty ? 'pending' : status;
      data['reportedUserId'] = uid;
      data['createdAtDate'] = _date(data['createdAt']);
      if (uid.isNotEmpty) {
        reportCount[uid] = (reportCount[uid] ?? 0) + 1;
        if (data['status'] == 'pending') {
          pendingCount[uid] = (pendingCount[uid] ?? 0) + 1;
        }
      }
      reports.add(data);
    }

    for (final r in reports) {
      final uid = r['reportedUserId'] as String;
      final u = usersById[uid];
      final explicitHost = _s(r, [
        'hostName',
        'tenChuNha',
        'reportedUserName',
        'targetUserName',
        'userName',
        'fullName',
        'name',
      ]);
      r['reportedName'] = explicitHost.isNotEmpty
          ? explicitHost
          : (u?['displayName'] ?? (uid.isNotEmpty ? 'Chủ trọ ($uid)' : 'Người dùng không xác định')).toString();
      r['reportedPhone'] = _s(r, [
        'hostPhone',
        'reportedPhone',
        'soDienThoai',
        'phone',
        'phoneNumber',
      ]).isNotEmpty
          ? _s(r, ['hostPhone', 'reportedPhone', 'soDienThoai', 'phone', 'phoneNumber'])
          : (u?['phoneNumber'] ?? u?['phone'] ?? '').toString();
      r['reportedAvatar'] = _s(r, [
        'hostAvatar',
        'reportedAvatar',
        'avatarUrl',
        'photoUrl',
      ]).isNotEmpty
          ? _s(r, ['hostAvatar', 'reportedAvatar', 'avatarUrl', 'photoUrl'])
          : (u?['avatarUrl'] ?? u?['photoUrl'] ?? '').toString();
      r['reportedRole'] = _s(r, ['reportedRole', 'role']).isNotEmpty
          ? _s(r, ['reportedRole', 'role'])
          : (u?['role'] ?? (_s(r, ['hostId', 'roomId']).isNotEmpty ? 'host' : '')).toString();
      r['reportedBanned'] = u?['isBanned'] == true;
      r['reportedReputationScore'] = (u?['reputationScore'] ?? u?['diemUyTin']);
      r['totalReports'] = uid.isNotEmpty ? (reportCount[uid] ?? 1) : 1;
      r['reporterDisplay'] = _s(r, ['reporterName', 'nguoiBaoCao']).isNotEmpty
          ? _s(r, ['reporterName', 'nguoiBaoCao'])
          : (usersById[_s(r, ['reporterId', 'nguoiBaoCaoId'])]?['displayName'] ?? 'Ẩn danh')
                .toString();

      // Thông tin bài đăng phòng trọ liên quan
      r['roomId'] = _s(r, ['roomId', 'postId', 'maPhong', 'phongId', 'baiDangId']);
      r['roomTitle'] = _s(r, ['roomTitle', 'postTitle', 'title', 'tieuDe', 'roomName']);
      r['roomPrice'] = r['roomPrice'] ?? r['price'] ?? r['giaThue'] ?? 0;
      r['roomAddress'] = _s(r, ['roomAddress', 'address', 'diaChi']);
      r['roomImages'] = _extractImages(r);
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

    // Xử lý dữ liệu bảng repost / reposts
    final repostItems = <Map<String, dynamic>>[];
    final seenRepostIds = <String>{};
    for (final d in [..._repostDocs, ..._repostsPluralDocs]) {
      if (seenRepostIds.contains(d.id)) continue;
      seenRepostIds.add(d.id);
      final data = Map<String, dynamic>.from(
        d.data() as Map<String, dynamic>? ?? {},
      );
      // Bỏ qua các tài liệu là báo cáo người dùng / chủ trọ lọt vào bảng repost
      if (data['isReport'] == true ||
          data['reportId'] != null ||
          d.id.startsWith('BC_') ||
          d.id.startsWith('REP_')) {
        continue;
      }
      data['id'] = d.id;
      data['sourceCollection'] = d.reference.parent.id;

      final uid = _s(data, ['userId', 'hostId', 'authorId', 'senderId', 'chuNhaId']);
      final u = usersById[uid];
      data['userId'] = uid;
      data['userRole'] = _s(data, ['userRole', 'role']).isNotEmpty
          ? _s(data, ['userRole', 'role'])
          : (u?['role'] ?? 'host');
      data['userName'] = _s(data, ['userName', 'hostName', 'authorName', 'fullName', 'hoTen', 'name']).isNotEmpty
          ? _s(data, ['userName', 'hostName', 'authorName', 'fullName', 'hoTen', 'name'])
          : (u?['displayName'] ?? 'Người dùng').toString();
      data['userPhone'] = _s(data, ['userPhone', 'hostPhone', 'phoneNumber', 'phone', 'soDienThoai']).isNotEmpty
          ? _s(data, ['userPhone', 'hostPhone', 'phoneNumber', 'phone', 'soDienThoai'])
          : (_s(u ?? {}, ['phone', 'phoneNumber'])).toString();

      data['title'] = _s(data, ['title', 'tieuDe', 'roomTitle', 'name']).isNotEmpty
          ? _s(data, ['title', 'tieuDe', 'roomTitle', 'name'])
          : 'Bài đăng phòng trọ';
      data['price'] = data['price'] ?? data['rentalPrice'] ?? data['gia'] ?? data['giaThue'] ?? 0;
      data['deposit'] = data['deposit'] ?? data['depositAmount'] ?? data['tienCoc'] ?? 0;
      data['address'] = _s(data, ['address', 'diaChi', 'fullAddress', 'location']);
      data['description'] = _s(data, ['description', 'moTa', 'detail']);

      data['postId'] = _s(data, ['postId', 'roomId', 'maBaiDang', 'id']);
      data['roomId'] = _s(data, ['roomId', 'maPhong']);

      final status = _s(data, ['status', 'trangThai']).toLowerCase();
      data['status'] = status.isEmpty ? 'pending' : status;

      data['rejectReason'] = _s(data, [
        'rejectReason',
        'reason',
        'lyDoTuChoi',
        'violationReason',
        'lyDoViPham',
        'previousViolation',
      ]);
      data['userNote'] = _s(data, [
        'userNote',
        'note',
        'noiDungSua',
        'noiDungChinhSua',
        'ghiChu',
        'changeLog',
        'editSummary',
      ]);

      data['images'] = _extractImages(data);
      data['createdAtDate'] = _date(
        data['repostedAt'] ?? data['createdAt'] ?? data['updatedAt'] ?? data['timestamp'],
      );

      repostItems.add(data);
    }

    repostItems.sort((a, b) {
      final da = a['createdAtDate'] as DateTime?;
      final db = b['createdAtDate'] as DateTime?;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    if (!mounted) return;
    setState(() {
      _users = users;
      _reports = reports;
      _repostItems = repostItems;
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
          backgroundColor: AdminColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            title,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(fontSize: 13, color: _textGrey, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 3,
                onChanged: (_) => setLocal(() {}),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(fontSize: 12.5),
                  filled: true,
                  fillColor: AdminColors.paper,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AdminColors.border),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Huỷ'),
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
    final name = (report['reportedName'] ?? 'Chủ trọ').toString();
    final uid = (report['reportedUserId'] ?? '').toString();

    // Lấy điểm uy tín hiện tại của user từ users collection
    int currentScore = 100;
    if (uid.isNotEmpty) {
      try {
        final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (snap.exists) {
          final data = snap.data() ?? {};
          currentScore = ((data['reputationScore'] ?? data['diemUyTin']) as num?)?.toInt() ?? 100;
        }
      } catch (e) {
        debugPrint('Lỗi đọc điểm uy tín user $uid: $e');
        final u = _users.firstWhere((element) => element['id'] == uid, orElse: () => {});
        currentScore = ((u['reputationScore'] ?? u['diemUyTin']) as num?)?.toInt() ?? 100;
      }
    }

    final result = await _showWarningDialog(
      report: report,
      currentScore: currentScore,
    );
    if (result == null) return;

    // Lưu lỗi mới vào khung phạt hệ thống Firebase nếu Admin yêu cầu
    if (result.newRuleToPersist != null) {
      try {
        await ViolationRulesService().addOrUpdateRule(result.newRuleToPersist!);
      } catch (e) {
        debugPrint('Lỗi lưu quy định vi phạm mới vào Firebase: $e');
      }
    }

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final penalty = result.penaltyPoints;
      final newScore = (currentScore - penalty).clamp(0, 100);
      final violationsStr = result.violations.join('; ');
      final fullNote = [
        if (result.violations.isNotEmpty) 'Các lỗi vi phạm: $violationsStr',
        'Hình thức xử lý: Cảnh cáo, trừ $penalty điểm uy tín (còn $newScore/100 điểm).',
        if (result.note.isNotEmpty) 'Lời nhắn Admin: ${result.note}',
      ].join('\n');

      // 1. Cập nhật báo cáo trong collection 'reports'
      batch.set(db.collection('reports').doc(report['id'] as String), {
        'status': 'resolved',
        'resolution': 'warned',
        'penaltyPoints': penalty,
        'violations': result.violations,
        'previousScore': currentScore,
        'newScore': newScore,
        'adminNote': fullNote,
        'handledAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Cập nhật điểm uy tín trong collection 'users'
      if (uid.isNotEmpty) {
        final userRef = db.collection('users').doc(uid);
        batch.set(userRef, {
          'reputationScore': newScore,
          'diemUyTin': newScore,
          'warningCount': FieldValue.increment(1),
          'lastWarningAt': FieldValue.serverTimestamp(),
          'lastWarningReason': violationsStr,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 3. Ghi vào collection 'violations' để lưu vết lịch sử vi phạm
        final violationId = 'VP_${DateTime.now().millisecondsSinceEpoch}';
        batch.set(db.collection('violations').doc(violationId), {
          'id': violationId,
          'userId': uid,
          'userName': name,
          'reportId': report['id'],
          'violations': result.violations,
          'penaltyPoints': penalty,
          'previousScore': currentScore,
          'newScore': newScore,
          'adminNote': result.note,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 4. Gửi thông báo tới người dùng / chủ trọ
        final notifId = 'TB_${DateTime.now().millisecondsSinceEpoch}';
        final roomTitle = _s(report, ['roomTitle', 'postTitle', 'title']);
        final notifMsg = [
          'Bạn nhận cảnh cáo từ Ban Quản Trị HomeShare.',
          if (roomTitle.isNotEmpty) 'Bài đăng liên quan: "$roomTitle".',
          'Lỗi vi phạm: $violationsStr.',
          'Bạn bị trừ $penalty điểm uy tín. Điểm uy tín hiện tại: $newScore/100.',
          if (result.note.isNotEmpty) 'Ghi chú: ${result.note}',
        ].join('\n');

        batch.set(db.collection('notifications').doc(notifId), {
          'id': notifId,
          'recipientId': uid,
          'recipientRole': (report['reportedRole'] ?? 'host').toString(),
          'title': 'Cảnh báo vi phạm & Trừ điểm uy tín',
          'message': notifMsg,
          'body': notifMsg,
          'notificationType': 'warning',
          'reportId': report['id'],
          'penaltyPoints': penalty,
          'currentScore': newScore,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      await _audit(
        'Cảnh cáo người dùng',
        'Admin cảnh cáo "$name". Lỗi: $violationsStr. Trừ $penalty điểm uy tín (còn $newScore/100). Ghi chú: ${result.note}',
        'User $uid',
      );

      _snack('Đã gửi cảnh cáo tới $name và trừ $penalty điểm uy tín (còn $newScore điểm)');
    } catch (e) {
      _snack('Lỗi gửi cảnh cáo: $e', error: true);
    }
  }

  Future<_WarningResult?> _showWarningDialog({
    required Map<String, dynamic> report,
    required int currentScore,
  }) {
    return showDialog<_WarningResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WarningDialog(
        report: report,
        currentScore: currentScore,
      ),
    );
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
    final cPendingReposts = _repostItems
        .where((r) => r['status'] == 'pending' || r['status'] == 'choduyet')
        .length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AdminColors.card,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        toolbarHeight: 64,
        title: const AdminBrandedTitle(
          title: 'Quản lý người dùng',
          subtitle: 'Duyệt báo cáo vi phạm & duyệt bài đăng repost',
        ),
        actions: [
          const AdminThemeToggle(padding: EdgeInsets.only(right: 8)),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AdminColors.successInk,
                backgroundColor: AdminColors.successContainer,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: Text(
                'Khung phạt',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              onPressed: () => ViolationRulesSheet.show(context),
            ),
          ),
        ],
        centerTitle: false,
      ),
      body: Column(
        children: [
          Container(
            color: AdminColors.card,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: _view == _UsersView.allUsers
                    ? 'Tìm theo tên, email, SĐT...'
                    : (_view == _UsersView.reposts
                        ? 'Tìm bài repost theo tiêu đề, người đăng, địa chỉ...'
                        : 'Tìm theo người bị báo cáo, người báo cáo...'),
                hintStyle: TextStyle(fontSize: 12, color: AdminColors.muted),
                prefixIcon: Icon(Icons.search, size: 18, color: _textGrey),
                filled: true,
                fillColor: AdminColors.paper,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AdminColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AdminColors.border),
                ),
              ),
            ),
          ),
          Container(
            color: AdminColors.card,
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
            child: Row(
              children: [
                _pill('Chờ xử lý', cPending, _UsersView.pendingReports, _orange),
                const SizedBox(width: 6),
                _pill('Đã xử lý', cHandled, _UsersView.handledReports, _green),
                const SizedBox(width: 6),
                _pill('Duyệt Repost', cPendingReposts, _UsersView.reposts, AdminColors.purple),
                const SizedBox(width: 6),
                _pill('Người dùng', _users.length, _UsersView.allUsers, _primary),
              ],
            ),
          ),
          Divider(height: 1, color: AdminColors.border),
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
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : AdminColors.paper,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : AdminColors.border,
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
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? color : _textGrey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(String query) {
    if (_view == _UsersView.reposts) {
      final items = _repostItems.where((r) {
        return _matches(query, [
          r['title'] as String? ?? '',
          r['userName'] as String? ?? '',
          r['userPhone'] as String? ?? '',
          r['address'] as String? ?? '',
          r['rejectReason'] as String? ?? '',
          r['userNote'] as String? ?? '',
        ]);
      }).toList();
      if (items.isEmpty) {
        return _empty('Không có bài đăng repost nào cần duyệt 🎉');
      }
      return ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _repostCard(items[i]),
      );
    }

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
        _s(r, ['description', 'detail']),
        _s(r, ['roomTitle', 'postTitle', 'title']),
        _s(r, ['roomId', 'postId']),
        _s(r, ['roomAddress', 'address']),
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
    child: Text(text, style: TextStyle(color: _textGrey, fontSize: 13)),
  );

  BoxDecoration get _cardDeco => BoxDecoration(
    color: AdminColors.card,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AdminColors.border),
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

  Widget _avatar(String name, {bool banned = false, String avatarUrl = ''}) {
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    if (avatarUrl.isNotEmpty &&
        (avatarUrl.startsWith('http') || avatarUrl.startsWith('blob:') || avatarUrl.startsWith('data:'))) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: banned ? AdminColors.dangerContainer : AdminColors.accentSoft,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: banned ? AdminColors.dangerContainer : AdminColors.accentSoft,
      child: Text(
        letter,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: banned ? _red : _primary,
        ),
      ),
    );
  }

  bool _hasReportedPost(Map<String, dynamic> r) {
    return _s(r, ['roomId', 'postId']).isNotEmpty ||
        _s(r, ['roomTitle', 'postTitle', 'title']).isNotEmpty;
  }

  Future<void> _openReportedPostDetail(Map<String, dynamic> r) async {
    final roomId = _s(r, ['roomId', 'postId']);
    final roomTitle = _s(r, ['roomTitle', 'postTitle', 'title']).isNotEmpty
        ? _s(r, ['roomTitle', 'postTitle', 'title'])
        : 'Bài đăng phòng trọ';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    RoomModel? room;
    try {
      if (roomId.isNotEmpty) {
        room = await RoomService().resolveRentedRoom(roomId: roomId);
      }
    } catch (e) {
      debugPrint('Lỗi tải phòng $roomId: $e');
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // Đóng loading

    // Nếu không tìm thấy trong DB (hoặc đã bị ẩn), tạo RoomModel fallback từ dữ liệu đã lưu trong report
    if (room == null) {
      final images = _extractImages(r);
      final rawEvidence = r['evidenceUrls'] ?? r['evidencePaths'];
      if (images.isEmpty && rawEvidence is List) {
        images.addAll(rawEvidence.map((e) => e.toString()).where((e) => e.isNotEmpty));
      }
      final price = (r['roomPrice'] is num)
          ? (r['roomPrice'] as num).toDouble()
          : (r['price'] is num ? (r['price'] as num).toDouble() : 0.0);
      final address = _s(r, ['roomAddress', 'address']);
      final hostId = (r['reportedUserId'] ?? '').toString();
      final hostName = (r['reportedName'] ?? 'Chủ trọ').toString();
      final hostPhone = (r['reportedPhone'] ?? '').toString();

      room = RoomModel(
        id: roomId.isNotEmpty ? roomId : (r['id'] ?? 'reported_post').toString(),
        title: roomTitle,
        description: _s(r, ['description', 'detail', 'reason']).isNotEmpty
            ? _s(r, ['description', 'detail', 'reason'])
            : 'Bài đăng được báo cáo bởi người dùng.',
        price: price,
        deposit: price > 0 ? price : 0.0,
        address: address.isNotEmpty ? address : 'Đang cập nhật địa chỉ',
        district: '',
        city: '',
        area: 0.0,
        roomType: 'Phòng trọ',
        amenities: const [],
        images: images,
        hostId: hostId,
        hostName: hostName,
        hostPhone: hostPhone,
        status: 'reported',
        isAvailable: true,
        createdAt: (r['createdAtDate'] as DateTime?) ?? DateTime.now(),
      );
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoomDetailScreen(room: room!),
      ),
    );
  }

  Widget _buildReportedPostCard(Map<String, dynamic> r) {
    final title = _s(r, ['roomTitle', 'postTitle', 'title']).isNotEmpty
        ? _s(r, ['roomTitle', 'postTitle', 'title'])
        : 'Bài đăng phòng trọ';
    final price = r['roomPrice'] ?? r['price'] ?? 0;
    final address = _s(r, ['roomAddress', 'address']);
    final images = _extractImages(r);

    return InkWell(
      onTap: () => _openReportedPostDetail(r),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AdminColors.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AdminColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: images.isNotEmpty
                  ? Image.network(
                      images.first,
                      width: 68,
                      height: 68,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 68,
                        height: 68,
                        color: AdminColors.border,
                        child: Icon(Icons.broken_image, size: 24, color: _textGrey),
                      ),
                    )
                  : Container(
                      width: 68,
                      height: 68,
                      color: AdminColors.accentSoft,
                      child: Icon(Icons.apartment_rounded, size: 28, color: _primary),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AdminColors.accentSoft,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AdminColors.border),
                        ),
                        child: Text(
                          'PHÒNG LIÊN QUAN ĐẾN BÁO CÁO',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: _primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.open_in_new_rounded, size: 14, color: _primary),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  if (price is num && price > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatVnd(price),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.successInk,
                      ),
                    ),
                  ],
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 12, color: _textGrey),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: _textGrey),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Nhấn để xem chi tiết bài viết',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _primary,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_ios_rounded, size: 9, color: _primary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidencePreview(List<dynamic> evidenceUrls) {
    final list = evidenceUrls
        .map((e) => e.toString())
        .where((e) => e.startsWith('http') || e.startsWith('blob:') || e.startsWith('data:'))
        .toList();
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Ảnh minh chứng vi phạm (${list.length}):',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textGrey),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 54,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _showFullImageDialog(list[i]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  list[i],
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 54,
                    height: 54,
                    color: AdminColors.accentSoft,
                    child: Icon(Icons.broken_image, size: 20, color: _textGrey),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showFullImageDialog(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportCard(Map<String, dynamic> r) {
    final pending = r['status'] == 'pending';
    final banned = r['reportedBanned'] == true;
    final name = r['reportedName'] as String;
    final phone = (r['reportedPhone'] ?? '').toString();
    final avatarUrl = (r['reportedAvatar'] ?? '').toString();
    final date = r['createdAtDate'] as DateTime?;
    final resolution = _s(r, ['resolution']);
    final penaltyPoints = r['penaltyPoints'];
    final resolutionLabel = {
      'banned': 'Đã khóa tài khoản',
      'warned': (penaltyPoints != null && (penaltyPoints is num) && penaltyPoints > 0)
          ? 'Đã cảnh cáo (-$penaltyPoints đ UT)'
          : 'Đã cảnh cáo',
      'dismissed': 'Đã bỏ qua',
    }[resolution];
    final adminNote = _s(r, ['adminNote']);
    final hasRoom = _hasReportedPost(r);
    final evidenceUrls = (r['evidenceUrls'] is List) ? r['evidenceUrls'] as List : [];
    final hostScore = (r['reportedReputationScore'] ?? r['reputationScore'] ?? r['diemUyTin']) as num?;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(name, banned: banned, avatarUrl: avatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chủ trọ: $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _chip('Báo cáo chủ trọ', _red),
                        if ((r['reportedRole'] as String).isNotEmpty)
                          _chip(_roleLabel(r['reportedRole'] as String), _primary),
                        if (hostScore != null)
                          _chip(
                            'UT: ${hostScore.toInt()}/100',
                            hostScore >= 80 ? _green : (hostScore >= 50 ? _orange : _red),
                          ),
                        if (phone.isNotEmpty)
                          _chip(phone, _textGrey),
                        if (banned) _chip('Đã bị khóa', _red),
                        if ((r['totalReports'] as int) > 1)
                          _chip('${r['totalReports']} báo cáo', _orange),
                      ],
                    ),
                  ],
                ),
              ),
              if (!pending && resolutionLabel != null)
                _chip(
                  resolutionLabel,
                  resolution == 'dismissed'
                      ? _textGrey
                      : (resolution == 'banned' ? _red : _orange),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AdminColors.warningContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminColors.warning),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.report_problem_outlined, size: 15, color: _orange),
                    SizedBox(width: 5),
                    Text(
                      'LÝ DO BÁO CÁO CHỦ TRỌ:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.warningInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _s(r, ['reason']).isEmpty ? 'Không nêu lý do' : _s(r, ['reason']),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textDark),
                ),
                if (_s(r, ['description', 'detail']).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _s(r, ['description', 'detail']),
                    style: TextStyle(fontSize: 12.5, color: _textGrey, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          if (evidenceUrls.isNotEmpty) ...[
            _buildEvidencePreview(evidenceUrls),
          ],
          if (hasRoom) ...[
            const SizedBox(height: 10),
            _buildReportedPostCard(r),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.account_circle_outlined, size: 15, color: _textGrey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Người báo cáo: ${r['reporterDisplay']}${date == null ? '' : '  •  ${_dateFmt.format(date)}'}',
                  style: TextStyle(fontSize: 11.5, color: _textGrey, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          if (!pending && resolution == 'warned') ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AdminColors.warningContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AdminColors.warning),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: _orange),
                      const SizedBox(width: 5),
                      Text(
                        'KẾT QUẢ CẢNH CÁO${penaltyPoints != null && (penaltyPoints is num) && penaltyPoints > 0 ? ' (TRỪ $penaltyPoints ĐIỂM UT)' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AdminColors.warningInk,
                        ),
                      ),
                      const Spacer(),
                      if (r['previousScore'] != null && r['newScore'] != null)
                        Text(
                          '${r['previousScore']} ➔ ${r['newScore']}/100 đ',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AdminColors.warningInk,
                          ),
                        ),
                    ],
                  ),
                  if (r['violations'] is List && (r['violations'] as List).isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: (r['violations'] as List).map((v) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AdminColors.card,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AdminColors.warning),
                        ),
                        child: Text(
                          v.toString(),
                          style: TextStyle(fontSize: 10.5, color: AdminColors.warningInk, fontWeight: FontWeight.w600),
                        ),
                      )).toList(),
                    ),
                  ],
                  if (adminNote.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      adminNote,
                      style: TextStyle(fontSize: 11.5, color: _textDark, height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (!pending && adminNote.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Ghi chú admin: $adminNote',
              style: TextStyle(fontSize: 11.5, color: _textGrey, fontStyle: FontStyle.italic),
            ),
          ],
          if (pending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _dismissReport(r),
                    child: Text('Bỏ qua', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _orange,
                      side: BorderSide(color: _orange),
                    ),
                    onPressed: () => _warnUser(r),
                    child: Text('Cảnh cáo', style: TextStyle(fontSize: 12.5)),
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
                    child: Text('Khóa TK', style: TextStyle(fontSize: 12.5)),
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
    final repScore = (u['reputationScore'] ?? u['diemUyTin']) as num?;

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
                  style: TextStyle(
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
                      style: TextStyle(fontSize: 11.5, color: _textGrey),
                    ),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _chip(_roleLabel(role), _primary),
                    if (repScore != null)
                      _chip(
                        'UT: ${repScore.toInt()}/100',
                        repScore >= 80 ? _green : (repScore >= 50 ? _orange : _red),
                      ),
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
                      style: TextStyle(fontSize: 11.5, color: _red),
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
                      side: BorderSide(color: _green),
                    ),
                    onPressed: () => _unbanUser(u),
                    child: Text('Mở khóa', style: TextStyle(fontSize: 12)),
                  )
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _red,
                      side: BorderSide(color: _red),
                    ),
                    onPressed: () => _banUser(
                      userId: u['id'] as String,
                      userName: name,
                    ),
                    child: Text('Khóa', style: TextStyle(fontSize: 12)),
                  ),
        ],
      ),
    );
  }

  // ───────────────────────── Repost Helpers & UI ─────────────────────────

  List<String> _extractImages(Map<String, dynamic> data) {
    final raw = data['roomImages'] ??
        data['images'] ??
        data['imageUrls'] ??
        data['photos'] ??
        data['anhPhong'] ??
        data['hinhAnh'] ??
        data['imageUrl'];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.startsWith('http') || e.startsWith('blob:') || e.startsWith('data:'))
          .toList();
    }
    if (raw is String &&
        (raw.trim().startsWith('http') || raw.trim().startsWith('blob:') || raw.trim().startsWith('data:'))) {
      return [raw.trim()];
    }
    return [];
  }

  String _formatVnd(dynamic amount) {
    if (amount is num) {
      return "${amount.toStringAsFixed(0).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.')} đ/tháng";
    }
    return "$amount đ/tháng";
  }

  Widget _repostCard(Map<String, dynamic> r) {
    final status = (r['status'] ?? 'pending').toString().toLowerCase();
    final isPending = status == 'pending' || status == 'choduyet';
    final isApproved = status == 'approved' || status == 'daduyet';
    final isRejected = status == 'rejected' || status == 'tuchoi';
    final date = r['createdAtDate'] as DateTime?;
    final title = (r['title'] ?? 'Bài đăng').toString();
    final price = r['price'];
    final address = (r['address'] ?? '').toString();
    final userName = (r['userName'] ?? 'Người dùng').toString();
    final userPhone = (r['userPhone'] ?? '').toString();
    final rejectReason = (r['rejectReason'] ?? '').toString();
    final userNote = (r['userNote'] ?? '').toString();
    final images = r['images'] as List<String>? ?? [];

    Color statusColor = _orange;
    String statusLabel = 'Chờ duyệt repost';
    if (isApproved) {
      statusColor = _green;
      statusLabel = 'Đã duyệt';
    } else if (isRejected) {
      statusColor = _red;
      statusLabel = 'Đã từ chối';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(userName),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
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
                        _chip('Repost', AdminColors.purple),
                        _chip(statusLabel, statusColor),
                        if (userPhone.isNotEmpty) _chip(userPhone, _primary),
                      ],
                    ),
                  ],
                ),
              ),
              if (date != null)
                Text(
                  _dateFmt.format(date),
                  style: TextStyle(fontSize: 11, color: _textGrey),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Thông tin bài đăng
          InkWell(
            onTap: () => _openReportedPostDetail(r),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AdminColors.paper,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AdminColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (images.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        images.first,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 72,
                          height: 72,
                          color: AdminColors.accentSoft,
                          child: Icon(Icons.broken_image, size: 24, color: _textGrey),
                        ),
                      ),
                    ),
                  if (images.isNotEmpty) const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatVnd(price),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AdminColors.successInk,
                          ),
                        ),
                        if (address.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 13, color: _textGrey),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11.5, color: _textGrey),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Nhấn để xem bài viết',
                              style: TextStyle(fontSize: 11, color: _primary, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.arrow_forward_ios_rounded, size: 9, color: _primary),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (rejectReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AdminColors.dangerContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AdminColors.dangerContainer),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: _red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lý do từng bị từ chối / cảnh cáo trước đó:',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _red,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rejectReason,
                          style: TextStyle(fontSize: 12, color: _textDark, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (userNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AdminColors.accentSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AdminColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.edit_note_rounded, size: 18, color: _primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nội dung người dùng đã sửa đổi:',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: _primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userNote,
                          style: TextStyle(fontSize: 12, color: _textDark, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _showRepostDetailDialog(r),
                icon: const Icon(Icons.visibility_outlined, size: 15),
                label: Text('Xem chi tiết', style: TextStyle(fontSize: 12)),
              ),
              const Spacer(),
              if (isPending) ...[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _red,
                    side: BorderSide(color: _red),
                  ),
                  onPressed: () => _rejectRepost(r),
                  child: Text('Từ chối', style: TextStyle(fontSize: 12.5)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                  ),
                  onPressed: () => _approveRepost(r),
                  child: Text('Phê duyệt', style: TextStyle(fontSize: 12.5)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showRepostDetailDialog(Map<String, dynamic> r) {
    final title = (r['title'] ?? 'Bài đăng').toString();
    final price = r['price'];
    final deposit = r['deposit'];
    final address = (r['address'] ?? 'Đang cập nhật').toString();
    final description = (r['description'] ?? 'Chưa có mô tả').toString();
    final userName = (r['userName'] ?? 'Người dùng').toString();
    final userPhone = (r['userPhone'] ?? 'Chưa có').toString();
    final rejectReason = (r['rejectReason'] ?? '').toString();
    final userNote = (r['userNote'] ?? '').toString();
    final images = r['images'] as List<String>? ?? [];
    final status = (r['status'] ?? 'pending').toString().toLowerCase();
    final isPending = status == 'pending' || status == 'choduyet';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (images.isNotEmpty) ...[
                  SizedBox(
                    height: 140,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          images[i],
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 140,
                            height: 140,
                            color: AdminColors.accentSoft,
                            child: Icon(Icons.broken_image, size: 28, color: _textGrey),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Giá thuê: ${_formatVnd(price)}${deposit != null && (deposit is num ? deposit > 0 : deposit.toString().isNotEmpty) ? '  •  Cọc: ${_formatVnd(deposit)}' : ''}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AdminColors.successInk),
                ),
                const SizedBox(height: 6),
                Text('Địa chỉ: $address', style: TextStyle(fontSize: 12.5, color: _textDark)),
                const SizedBox(height: 6),
                Text('Người đăng: $userName ($userPhone)', style: TextStyle(fontSize: 12.5, color: _textGrey)),
                const SizedBox(height: 10),
                if (rejectReason.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AdminColors.dangerContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminColors.dangerContainer),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lý do từng vi phạm:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _red)),
                        const SizedBox(height: 2),
                        Text(rejectReason, style: TextStyle(fontSize: 12, color: _textDark)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (userNote.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AdminColors.accentSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AdminColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nội dung sửa đổi của người dùng:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _primary)),
                        const SizedBox(height: 2),
                        Text(userNote, style: TextStyle(fontSize: 12, color: _textDark)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text('Mô tả bài đăng:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(fontSize: 12, color: _textGrey, height: 1.4)),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new_rounded, size: 14),
            label: Text('Xem bài đăng'),
            onPressed: () {
              Navigator.pop(ctx);
              _openReportedPostDetail(r);
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Đóng'),
          ),
          if (isPending) ...[
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: _red, side: BorderSide(color: _red)),
              onPressed: () {
                Navigator.pop(ctx);
                _rejectRepost(r);
              },
              child: Text('Từ chối'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _green),
              onPressed: () {
                Navigator.pop(ctx);
                _approveRepost(r);
              },
              child: Text('Phê duyệt'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _approveRepost(Map<String, dynamic> item) async {
    final title = (item['title'] ?? 'Bài đăng').toString();
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final collectionName = (item['sourceCollection'] ?? 'reposts').toString();
      final repostRef = db.collection(collectionName).doc(item['id'] as String);

      batch.set(repostRef, {
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': 'Admin',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final postId = (item['postId'] ?? '').toString();
      if (postId.isNotEmpty) {
        batch.set(db.collection('posts').doc(postId), {
          'status': 'active',
          'isAvailable': true,
          'rejectReason': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
          'reviewedBy': 'Admin',
          'reviewedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      final roomId = (item['roomId'] ?? '').toString();
      if (roomId.isNotEmpty) {
        for (final col in const ['rooms', 'host_rooms']) {
          batch.set(db.collection(col).doc(roomId), {
            'status': 'available',
            'isAvailable': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      final userId = (item['userId'] ?? '').toString();
      if (userId.isNotEmpty) {
        batch.set(db.collection('notifications').doc(), {
          'recipientId': userId,
          'recipientRole': (item['userRole'] ?? 'host').toString(),
          'title': 'Bài đăng repost đã được phê duyệt',
          'body': 'Bài đăng "$title" của bạn đã được Admin phê duyệt sau khi chỉnh sửa.',
          'notificationType': 'post_approved',
          'targetId': postId.isNotEmpty ? postId : item['id'],
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      await _audit('Duyệt bài đăng repost', 'Admin đã duyệt bài "$title" sau khi sửa đổi.', 'Repost ${item['id']}');
      _snack('Đã phê duyệt bài đăng repost thành công!');
    } catch (e) {
      _snack('Lỗi phê duyệt: $e', error: true);
    }
  }

  Future<void> _rejectRepost(Map<String, dynamic> item) async {
    final title = (item['title'] ?? 'Bài đăng').toString();
    final reason = await _askNote(
      title: 'Từ chối bài đăng repost?',
      message: 'Bài đăng "$title" vẫn chưa đạt yêu cầu kiểm duyệt.',
      hint: 'Lý do từ chối (bắt buộc)...',
      confirmLabel: 'Từ chối bài đăng',
      color: _red,
      requireNote: true,
    );
    if (reason == null) return;

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final collectionName = (item['sourceCollection'] ?? 'reposts').toString();
      final repostRef = db.collection(collectionName).doc(item['id'] as String);

      batch.set(repostRef, {
        'status': 'rejected',
        'rejectReason': reason,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': 'Admin',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final postId = (item['postId'] ?? '').toString();
      if (postId.isNotEmpty) {
        batch.set(db.collection('posts').doc(postId), {
          'status': 'rejected',
          'isAvailable': false,
          'rejectReason': reason,
          'updatedAt': FieldValue.serverTimestamp(),
          'reviewedBy': 'Admin',
          'reviewedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      final userId = (item['userId'] ?? '').toString();
      if (userId.isNotEmpty) {
        final userRef = db.collection('users').doc(userId);
        final userSnap = await userRef.get();
        if (userSnap.exists) {
          final currentScore = (userSnap.data()?['diemUyTin'] ?? userSnap.data()?['reputationScore'] ?? 100) as num;
          final newScore = (currentScore.toInt() - 1).clamp(0, 100);
          batch.set(userRef, {
            'diemUyTin': newScore,
            'reputationScore': newScore,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        batch.set(db.collection('notifications').doc(), {
          'recipientId': userId,
          'recipientRole': (item['userRole'] ?? 'host').toString(),
          'title': 'Bài đăng repost bị từ chối',
          'body': 'Bài đăng "$title" tiếp tục bị từ chối kiểm duyệt. Lý do: $reason',
          'notificationType': 'post_rejected',
          'targetId': postId.isNotEmpty ? postId : item['id'],
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      await _audit('Từ chối bài đăng repost', 'Admin từ chối bài "$title". Lý do: $reason', 'Repost ${item['id']}');
      _snack('Đã từ chối bài đăng repost');
    } catch (e) {
      _snack('Lỗi từ chối bài: $e', error: true);
    }
  }
}

// ───────────────────────── Phạt vi phạm & Trừ điểm Uy tín ─────────────────────────

class _WarningResult {
  final List<String> violations;
  final int penaltyPoints;
  final String note;
  final ViolationRuleModel? newRuleToPersist;

  const _WarningResult({
    required this.violations,
    required this.penaltyPoints,
    required this.note,
    this.newRuleToPersist,
  });
}

class _WarningDialog extends StatefulWidget {
  final Map<String, dynamic> report;
  final int currentScore;

  const _WarningDialog({
    required this.report,
    required this.currentScore,
  });

  @override
  State<_WarningDialog> createState() => _WarningDialogState();
}

class _WarningDialogState extends State<_WarningDialog> {
  final ViolationRulesService _rulesService = ViolationRulesService();
  List<ViolationRuleModel> _rules = [];
  bool _isLoadingRules = true;

  final Set<String> _selectedRuleIds = {};
  late int _penaltyPoints;
  late final TextEditingController _noteCtrl;

  // Lỗi phản ánh theo báo cáo người dùng
  late final String _reportReason;
  late final String _reportDesc;
  bool _applyReportedReason = false;
  int _reportedReasonPoints = 10;

  // Lỗi khác tự nhập
  bool _applyCustomOtherViolation = false;
  final TextEditingController _customViolationCtrl = TextEditingController();
  int _customViolationPoints = 10;
  bool _saveCustomToSystemRules = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController();
    _penaltyPoints = 0;

    _reportReason = (widget.report['reason'] ?? '').toString().trim();
    _reportDesc = (widget.report['description'] ?? widget.report['detail'] ?? '').toString().trim();

    _loadRules();
  }

  Future<void> _loadRules() async {
    try {
      final loaded = await _rulesService.getRules();
      if (!mounted) return;
      setState(() {
        _rules = loaded.where((r) => r.isActive).toList();
        _isLoadingRules = false;

        // Tự động nhận diện lỗi từ lý do báo cáo
        final combined = '$_reportReason $_reportDesc'.toLowerCase();
        for (final rule in _rules) {
          final titleLower = rule.title.toLowerCase();
          final idLower = rule.id.toLowerCase();
          if ((idLower == 'scam' && (combined.contains('lừa') || combined.contains('cọc') || combined.contains('chiếm đoạt') || combined.contains('chuyển khoản'))) ||
              (idLower == 'fake_info' && (combined.contains('ảnh') || combined.contains('giả') || combined.contains('sai') || combined.contains('không đúng'))) ||
              (idLower == 'harassment' && (combined.contains('thái độ') || combined.contains('chửi') || combined.contains('đe dọa') || combined.contains('quấy rối'))) ||
              (idLower == 'price_mismatch' && (combined.contains('giá') || combined.contains('tăng giá') || combined.contains('tiền'))) ||
              (idLower == 'safety_fire' && (combined.contains('cháy') || combined.contains('pccc') || combined.contains('bẩn') || combined.contains('vệ sinh'))) ||
              (idLower == 'not_removed' && (combined.contains('đã thuê') || combined.contains('hết phòng') || combined.contains('ảo'))) ||
              (combined.contains(titleLower) && titleLower.length > 4)) {
            _selectedRuleIds.add(rule.id);
          }
        }

        // Nếu báo cáo có lý do riêng biệt không trùng với tên các rule chuẩn, bật checkbox lỗi người dùng phản ánh
        final matchesAnyStandard = _rules.any((r) => r.title.toLowerCase() == _reportReason.toLowerCase());
        if (_reportReason.isNotEmpty && !matchesAnyStandard && _selectedRuleIds.isEmpty) {
          _applyReportedReason = true;
        }

        _penaltyPoints = _computeTotalPoints();
      });
    } catch (e) {
      debugPrint('Lỗi tải violation_rules: $e');
      if (mounted) setState(() => _isLoadingRules = false);
    }
  }

  int _computeTotalPoints() {
    int sum = 0;
    for (final rule in _rules) {
      if (_selectedRuleIds.contains(rule.id)) {
        sum += rule.defaultPoints;
      }
    }
    if (_applyReportedReason && _reportReason.isNotEmpty) {
      sum += _reportedReasonPoints;
    }
    if (_applyCustomOtherViolation && _customViolationCtrl.text.trim().isNotEmpty) {
      sum += _customViolationPoints;
    }
    return sum.clamp(0, widget.currentScore);
  }

  void _recalcPoints() {
    setState(() {
      _penaltyPoints = _computeTotalPoints();
    });
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _customViolationCtrl.dispose();
    super.dispose();
  }

  void _toggleRule(String id) {
    setState(() {
      if (_selectedRuleIds.contains(id)) {
        _selectedRuleIds.remove(id);
      } else {
        _selectedRuleIds.add(id);
      }
      _penaltyPoints = _computeTotalPoints();
    });
  }

  void _adjustPoints(int delta) {
    setState(() {
      _penaltyPoints = (_penaltyPoints + delta).clamp(0, widget.currentScore);
    });
  }

  void _setPoints(int pts) {
    setState(() {
      _penaltyPoints = pts.clamp(0, widget.currentScore);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hostName = (widget.report['reportedName'] ?? 'Chủ trọ').toString();
    final remainingScore = (widget.currentScore - _penaltyPoints).clamp(0, 100);
    final isDanger = remainingScore < 50;

    return Dialog(
      backgroundColor: AdminColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AdminColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AdminColors.warningContainer,
                      shape: BoxShape.circle,
                      border: Border.all(color: AdminColors.warning),
                    ),
                    child: Icon(Icons.warning_amber_rounded, color: AdminColors.warningInk, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cảnh cáo & Trừ điểm Uy tín',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AdminColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Chủ trọ: $hostName  •  Điểm hiện tại: ${widget.currentScore}/100 đ',
                          style: TextStyle(fontSize: 11.5, color: AdminColors.muted, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AdminColors.successInk,
                      backgroundColor: AdminColors.successContainer,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 14),
                    label: Text('Khung phạt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    onPressed: () async {
                      await ViolationRulesSheet.show(context);
                      _loadRules();
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: AdminColors.muted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoadingRules
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Score preview card
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDanger
                                    ? [AdminColors.dangerContainer, AdminColors.dangerContainer]
                                    : [AdminColors.paper, AdminColors.accentSoft],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDanger ? AdminColors.dangerContainer : AdminColors.border,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildScoreCol('Hiện tại', '${widget.currentScore}', AdminColors.muted),
                                    Icon(Icons.remove, size: 18, color: AdminColors.warningInk),
                                    _buildScoreCol('Trừ điểm', '-$_penaltyPoints', AdminColors.danger),
                                    Icon(Icons.arrow_forward_rounded, size: 18, color: AdminColors.muted),
                                    _buildScoreCol(
                                      'Còn lại',
                                      '$remainingScore/100',
                                      remainingScore >= 80
                                          ? AdminColors.success
                                          : (remainingScore >= 50 ? AdminColors.warningInk : AdminColors.danger),
                                    ),
                                  ],
                                ),
                                if (isDanger) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AdminColors.card.withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline, size: 13, color: AdminColors.danger),
                                        SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            'Uy tín dưới 50 điểm: Tài khoản sẽ rơi vào danh sách hạn chế/khóa!',
                                            style: TextStyle(fontSize: 10.5, color: AdminColors.danger, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Section 1: Standard rules from Firebase
                          Row(
                            children: [
                              Icon(Icons.checklist_rounded, size: 16, color: AdminColors.accentDark),
                              const SizedBox(width: 6),
                              Text(
                                'QUY ĐỊNH KHUNG PHẠT (TỪ FIREBASE):',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: AdminColors.accentDark,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Đã chọn: ${_selectedRuleIds.length}',
                                style: TextStyle(fontSize: 11, color: AdminColors.muted, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: AdminColors.paper,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AdminColors.border),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _rules.length,
                              separatorBuilder: (context, index) => Divider(height: 1, color: AdminColors.border),
                              itemBuilder: (context, index) {
                                final rule = _rules[index];
                                final isSelected = _selectedRuleIds.contains(rule.id);
                                return InkWell(
                                  onTap: () => _toggleRule(rule.id),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: Checkbox(
                                              value: isSelected,
                                              activeColor: AdminColors.accentDark,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                              onChanged: (_) => _toggleRule(rule.id),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      rule.title,
                                                      style: TextStyle(
                                                        fontSize: 12.5,
                                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                                        color: isSelected ? AdminColors.ink : AdminColors.mutedStrong,
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isSelected ? AdminColors.dangerContainer : AdminColors.accentSoft,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      '-${rule.defaultPoints}đ UT',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w700,
                                                        color: isSelected ? AdminColors.danger : AdminColors.muted,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (rule.description.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  rule.description,
                                                  style: TextStyle(fontSize: 11, color: AdminColors.muted, height: 1.3),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Section 2: Lỗi theo phản ánh của người thuê
                          if (_reportReason.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AdminColors.warningContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _applyReportedReason ? AdminColors.warning : AdminColors.warning,
                                  width: _applyReportedReason ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: Checkbox(
                                          value: _applyReportedReason,
                                          activeColor: AdminColors.warningInk,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                          onChanged: (val) {
                                            setState(() {
                                              _applyReportedReason = val == true;
                                              _recalcPoints();
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Lỗi theo báo cáo người thuê: "$_reportReason"',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: _applyReportedReason ? AdminColors.warningInk : AdminColors.warningInk,
                                              ),
                                            ),
                                            if (_reportDesc.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                _reportDesc,
                                                style: TextStyle(fontSize: 11, color: AdminColors.muted, height: 1.3),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (_applyReportedReason) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: AdminColors.card,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AdminColors.warning),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              InkWell(
                                                onTap: _reportedReasonPoints > 1
                                                    ? () {
                                                        setState(() {
                                                          _reportedReasonPoints = (_reportedReasonPoints - 5).clamp(1, 50);
                                                          _recalcPoints();
                                                        });
                                                      }
                                                    : null,
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  child: Icon(Icons.remove, size: 14),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                                child: Text(
                                                  '-$_reportedReasonPoints đ',
                                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AdminColors.danger),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: _reportedReasonPoints < 50
                                                    ? () {
                                                        setState(() {
                                                          _reportedReasonPoints = (_reportedReasonPoints + 5).clamp(1, 50);
                                                          _recalcPoints();
                                                        });
                                                      }
                                                    : null,
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  child: Icon(Icons.add, size: 14),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Section 3: Lỗi vi phạm khác (Admin tự nhập linh hoạt)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _applyCustomOtherViolation
                                  ? (AdminColors.isDark
                                      ? const Color(0xFF3A1528)
                                      : const Color(0xFFFDF2FA))
                                  : AdminColors.paper,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _applyCustomOtherViolation ? Color(0xFFF670C7) : AdminColors.border,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: Checkbox(
                                        value: _applyCustomOtherViolation,
                                        activeColor: const Color(0xFFC11574),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        onChanged: (val) {
                                          setState(() {
                                            _applyCustomOtherViolation = val == true;
                                            _recalcPoints();
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Áp dụng lỗi vi phạm khác (Admin tự nhập)',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AdminColors.mutedStrong),
                                      ),
                                    ),
                                    if (_applyCustomOtherViolation)
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AdminColors.card,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AdminColors.border),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              onTap: _customViolationPoints > 1
                                                  ? () {
                                                      setState(() {
                                                        _customViolationPoints = (_customViolationPoints - 5).clamp(1, 50);
                                                        _recalcPoints();
                                                      });
                                                    }
                                                  : null,
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                child: Icon(Icons.remove, size: 14),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 4),
                                              child: Text(
                                                '-$_customViolationPoints đ',
                                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AdminColors.danger),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: _customViolationPoints < 50
                                                  ? () {
                                                      setState(() {
                                                        _customViolationPoints = (_customViolationPoints + 5).clamp(1, 50);
                                                        _recalcPoints();
                                                      });
                                                    }
                                                  : null,
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                child: Icon(Icons.add, size: 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                if (_applyCustomOtherViolation) ...[
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _customViolationCtrl,
                                    style: TextStyle(fontSize: 12.5),
                                    onChanged: (_) => _recalcPoints(),
                                    decoration: InputDecoration(
                                      hintText: 'Nhập tên lỗi vi phạm phát sinh (ví dụ: Tự ý khóa cửa phòng trọ)...',
                                      hintStyle: TextStyle(fontSize: 11.5, color: AdminColors.muted),
                                      filled: true,
                                      fillColor: AdminColors.paper,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AdminColors.border)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AdminColors.border)),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () => setState(() => _saveCustomToSystemRules = !_saveCustomToSystemRules),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: Checkbox(
                                            value: _saveCustomToSystemRules,
                                            activeColor: AdminColors.successInk,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                            onChanged: (val) => setState(() => _saveCustomToSystemRules = val == true),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '💾 Lưu lỗi này vào khung phạt hệ thống Firebase để dùng cho các báo cáo sau',
                                            style: TextStyle(fontSize: 11, color: AdminColors.successInk, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Section 4: Quick Adjust Points
                          Row(
                            children: [
                              Icon(Icons.tune_rounded, size: 16, color: AdminColors.muted),
                              const SizedBox(width: 6),
                              Text(
                                'ĐIỀU CHỈNH TỔNG ĐIỂM TRỪ:',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: AdminColors.mutedStrong,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                decoration: BoxDecoration(
                                  color: AdminColors.accentSoft,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AdminColors.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: _penaltyPoints > 0 ? () => _adjustPoints(-5) : null,
                                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        child: Icon(Icons.remove, size: 16, color: AdminColors.mutedStrong),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Text(
                                        '$_penaltyPoints đ',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AdminColors.danger),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: _penaltyPoints < widget.currentScore ? () => _adjustPoints(5) : null,
                                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        child: Icon(Icons.add, size: 16, color: AdminColors.mutedStrong),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [0, 5, 10, 15, 20, 30].map((pts) {
                              final isSelected = _penaltyPoints == pts;
                              return ChoiceChip(
                                label: Text(
                                  pts == 0 ? 'Không trừ' : '-$pts điểm',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? Colors.white : AdminColors.mutedStrong,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: AdminColors.danger,
                                backgroundColor: AdminColors.paper,
                                side: BorderSide(
                                  color: isSelected ? AdminColors.danger : AdminColors.border,
                                ),
                                onSelected: (_) => _setPoints(pts),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          // Section 5: Admin Note
                          Row(
                            children: [
                              Icon(Icons.edit_note_rounded, size: 17, color: AdminColors.muted),
                              SizedBox(width: 6),
                              Text(
                                'LỜI NHẮN / GHI CHÚ GỬI CHỦ TRỌ:',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: AdminColors.mutedStrong,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _noteCtrl,
                            maxLines: 3,
                            style: TextStyle(fontSize: 12.5),
                            decoration: InputDecoration(
                              hintText: 'Nhập yêu cầu khắc phục vi phạm hoặc nhắc nhở chủ trọ...',
                              hintStyle: TextStyle(fontSize: 12, color: AdminColors.muted),
                              filled: true,
                              fillColor: AdminColors.paper,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AdminColors.border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AdminColors.border)),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AdminColors.border)),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('Hủy', style: TextStyle(fontSize: 13)),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminColors.danger,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _selectedRuleIds.isEmpty &&
                            !_applyReportedReason &&
                            (!_applyCustomOtherViolation || _customViolationCtrl.text.trim().isEmpty) &&
                            _penaltyPoints <= 0 &&
                            _noteCtrl.text.trim().isEmpty
                        ? null
                        : () {
                            final chosenTitles = <String>[];
                            for (final rule in _rules) {
                              if (_selectedRuleIds.contains(rule.id)) {
                                chosenTitles.add(rule.title);
                              }
                            }
                            if (_applyReportedReason && _reportReason.isNotEmpty) {
                              chosenTitles.add('Phản ánh từ người thuê: $_reportReason');
                            }
                            ViolationRuleModel? newRuleToPersist;
                            if (_applyCustomOtherViolation && _customViolationCtrl.text.trim().isNotEmpty) {
                              final customTitle = _customViolationCtrl.text.trim();
                              chosenTitles.add(customTitle);
                              if (_saveCustomToSystemRules) {
                                newRuleToPersist = ViolationRuleModel(
                                  id: 'rule_${DateTime.now().millisecondsSinceEpoch}',
                                  title: customTitle,
                                  description: 'Lỗi vi phạm bổ sung được Admin lưu từ xử lý báo cáo',
                                  defaultPoints: _customViolationPoints,
                                  isActive: true,
                                  createdAt: DateTime.now(),
                                );
                              }
                            }
                            if (chosenTitles.isEmpty) {
                              chosenTitles.add('Vi phạm quy định dịch vụ');
                            }

                            Navigator.pop(
                              context,
                              _WarningResult(
                                violations: chosenTitles,
                                penaltyPoints: _penaltyPoints,
                                note: _noteCtrl.text.trim(),
                                newRuleToPersist: newRuleToPersist,
                              ),
                            );
                          },
                    icon: const Icon(Icons.warning_amber_rounded, size: 18),
                    label: Text(
                      'Xác nhận cảnh cáo (${_penaltyPoints > 0 ? "-$_penaltyPoints đ" : "0đ"})',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AdminColors.muted, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }
}
