import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/admin_branded_title.dart';
import '../../renter/screens/room_detail_screen.dart';
import '../../../core/services/room_service.dart';
import '../../../core/services/violation_rules_service.dart';
import '../../../data/models/room_model.dart';
import '../../../data/models/violation_rule_model.dart';
import '../widgets/violation_rules_sheet.dart';
import '../widgets/admin_user_detail_sheet.dart';
import '../widgets/admin_create_user_dialog.dart';


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
  StreamSubscription<QuerySnapshot>? _reviewsSub;
  StreamSubscription<QuerySnapshot>? _bookingsSub;
  StreamSubscription<QuerySnapshot>? _repostSub;
  StreamSubscription<QuerySnapshot>? _repostsSub;
  List<QueryDocumentSnapshot> _userDocs = [];
  List<QueryDocumentSnapshot> _reviewDocs = [];
  List<QueryDocumentSnapshot> _bookingDocs = [];
  List<QueryDocumentSnapshot> _repostDocs = [];
  List<QueryDocumentSnapshot> _repostsPluralDocs = [];

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _repostItems = [];
  bool _isLoading = true;
  _UsersView _view = _UsersView.pendingReports;

  // Bộ lọc & Sắp xếp chuyên sâu
  String _userRoleFilter = 'all'; // 'all', 'host', 'renter', 'banned', 'low_rep'
  String _userSort = 'default'; // 'default', 'rep_asc', 'rep_desc', 'name_az', 'newest'
  int? _reviewStarFilter; // null = all, 1 = 1-2 sao, 3 = 3 sao, 4 = 4-5 sao
  String _repostStatusFilter = 'all'; // 'all', 'pending', 'approved', 'rejected'

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

      _reviewsSub = FirebaseFirestore.instance
          .collection('host_reviews')
          .snapshots()
          .listen(
            (snap) {
              _reviewDocs = snap.docs;
              _isLoading = false;
              _recompute();
            },
            onError: (e) {
              debugPrint('Lỗi tải host_reviews: $e');
              if (mounted) setState(() => _isLoading = false);
            },
          );

      _bookingsSub = FirebaseFirestore.instance
          .collection('bookings')
          .snapshots()
          .listen(
            (snap) {
              _bookingDocs = snap.docs;
              _recompute();
            },
            onError: (e) => debugPrint('Lỗi tải bookings: $e'),
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
    _reviewsSub?.cancel();
    _bookingsSub?.cancel();
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

  void _openUserDetail(Map<String, dynamic> u) {
    AdminUserDetailSheet.show(
      context,
      u,
      onUserUpdated: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _openUserDetailById(String uid) {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return;
    final u = _users.firstWhere(
      (element) => element['id'] == cleanUid,
      orElse: () => {
        'id': cleanUid,
        'displayName': 'Người dùng ($cleanUid)',
        'role': 'host',
      },
    );
    _openUserDetail(u);
  }

  bool _isHostRole(Map<String, dynamic> u) {
    final r = (u['role'] ?? '').toString().toLowerCase();
    return r == 'host' || r == 'landlord' || r == 'chutro';
  }

  bool _isRenterRole(Map<String, dynamic> u) {
    final r = (u['role'] ?? '').toString().toLowerCase();
    return r == 'renter' || r == 'tenant' || r.isEmpty;
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

    final bookingsById = <String, Map<String, dynamic>>{};
    for (final d in _bookingDocs) {
      final data = Map<String, dynamic>.from(
        d.data() as Map<String, dynamic>? ?? {},
      );
      data['id'] = d.id;
      bookingsById[d.id] = data;
    }

    final reportCount = <String, int>{};
    final pendingCount = <String, int>{};
    final reports = <Map<String, dynamic>>[];
    for (final d in _reviewDocs) {
      final data = Map<String, dynamic>.from(
        d.data() as Map<String, dynamic>? ?? {},
      );
      data['id'] = d.id;
      final uid = _s(data, [
        'hostId',
        'reportedUserId',
        'targetUserId',
        'chuNhaId',
        'userId',
        'targetId',
      ]);
      final status = _s(data, ['status', 'trangThai']).toLowerCase();
      data['status'] = status.isEmpty ? 'pending' : status;
      data['reportedUserId'] = uid;
      data['createdAtDate'] = _date(data['createdAt']);
      final rating = (data['rating'] as num?)?.toInt() ?? 5;
      data['rating'] = rating;
      data['comment'] = _s(data, ['comment', 'nhanXet', 'noiDung', 'detail']);
      data['reason'] = data['comment'].isNotEmpty
          ? data['comment']
          : 'Đánh giá $rating sao cho chủ trọ';

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
      final bookingId = _s(r, ['bookingId', 'id']);
      final b = bookingsById[bookingId];

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
          : (b?['hostName'] != null && b!['hostName'].toString().trim().isNotEmpty
              ? b['hostName'].toString().trim()
              : (u?['displayName'] ?? (uid.isNotEmpty ? 'Chủ trọ ($uid)' : 'Người dùng không xác định')).toString());
      r['reportedPhone'] = _s(r, [
        'hostPhone',
        'reportedPhone',
        'soDienThoai',
        'phone',
        'phoneNumber',
      ]).isNotEmpty
          ? _s(r, ['hostPhone', 'reportedPhone', 'soDienThoai', 'phone', 'phoneNumber'])
          : (b?['hostPhone'] != null && b!['hostPhone'].toString().trim().isNotEmpty
              ? b['hostPhone'].toString().trim()
              : (u?['phoneNumber'] ?? u?['phone'] ?? '').toString());
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
          : (u?['role'] ?? 'host').toString();
      r['reportedBanned'] = u?['isBanned'] == true;
      r['reportedReputationScore'] = (u?['reputationScore'] ?? u?['diemUyTin']);
      r['totalReports'] = uid.isNotEmpty ? (reportCount[uid] ?? 1) : 1;
      r['reporterDisplay'] = _s(r, ['reviewerName', 'reporterName', 'nguoiDanhGia', 'nguoiBaoCao']).isNotEmpty
          ? _s(r, ['reviewerName', 'reporterName', 'nguoiDanhGia', 'nguoiBaoCao'])
          : (b?['renterName'] != null && b!['renterName'].toString().trim().isNotEmpty
              ? b['renterName'].toString().trim()
              : (usersById[_s(r, ['reviewerId', 'reporterId'])]?['displayName'] ?? 'Khách thuê').toString());

      // Thông tin phòng trọ liên quan đến đánh giá
      r['roomId'] = _s(r, ['roomId', 'postId']).isNotEmpty ? _s(r, ['roomId', 'postId']) : (b?['roomId'] ?? '');
      r['roomTitle'] = _s(r, ['roomTitle', 'postTitle', 'title']).isNotEmpty ? _s(r, ['roomTitle', 'postTitle', 'title']) : (b?['roomTitle'] ?? '');
      r['roomPrice'] = r['roomPrice'] ?? b?['roomPrice'] ?? b?['price'] ?? b?['giaThue'] ?? 0;
      r['roomAddress'] = _s(r, ['roomAddress', 'address']).isNotEmpty ? _s(r, ['roomAddress', 'address']) : (b?['roomAddress'] ?? '');
      r['roomImages'] = _extractImages(r).isNotEmpty ? _extractImages(r) : _extractImages(b ?? {});
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
        batch.set(db.collection('host_reviews').doc(r['id'] as String), {
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
      batch.set(db.collection('host_reviews').doc(report['id'] as String), {
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

        final reportedRole = (report['reportedRole'] ?? 'host').toString().toLowerCase();
        final targetCol = (reportedRole == 'renter' || reportedRole == 'user') ? 'notification_user' : 'notifications';
        batch.set(db.collection(targetCol).doc(notifId), {
          'id': notifId,
          'recipientId': uid,
          'receiverId': uid,
          'userId': uid,
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
      title: 'Bỏ qua đánh giá?',
      message: 'Đánh giá này được xem là hợp lệ/bình thường và chuyển sang mục đã xử lý.',
      hint: 'Ghi chú (không bắt buộc)...',
      confirmLabel: 'Bỏ qua',
      color: _textGrey,
    );
    if (note == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('host_reviews')
          .doc(report['id'] as String)
          .set({
            'status': 'dismissed',
            'resolution': 'dismissed',
            'adminNote': note,
            'handledAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      await _audit(
        'Bỏ qua đánh giá',
        'Admin đã bỏ qua đánh giá #${report['id']} của ${report['reporterDisplay']}',
        'HostReview ${report['id']}',
      );
      _snack('Đã bỏ qua đánh giá');
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
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        toolbarHeight: 64,
        title: const AdminBrandedTitle(
          title: 'Quản lý người dùng',
          subtitle: 'Kiểm duyệt đánh giá, quản lý hồ sơ & duyệt repost',
        ),
        actions: [
          IconButton(
            tooltip: 'Thêm người dùng mới',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF8FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFB2DDFF)),
              ),
              child: const Icon(Icons.person_add_rounded, size: 18, color: _primary),
            ),
            onPressed: () async {
              final created = await AdminCreateUserDialog.show(context);
              if (created == true && mounted) {
                setState(() {});
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF006948),
                backgroundColor: const Color(0xFFE8F5E9),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text(
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
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: _view == _UsersView.allUsers
                    ? 'Tìm theo tên, email, SĐT...'
                    : (_view == _UsersView.reposts
                        ? 'Tìm bài repost theo tiêu đề, người đăng, địa chỉ...'
                        : 'Tìm theo người bị báo cáo, người báo cáo...'),
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
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
            child: Row(
              children: [
                _pill('Chờ xử lý', cPending, _UsersView.pendingReports, _orange),
                const SizedBox(width: 6),
                _pill('Đã xử lý', cHandled, _UsersView.handledReports, _green),
                const SizedBox(width: 6),
                _pill('Duyệt Repost', cPendingReposts, _UsersView.reposts, const Color(0xFF7C3AED)),
                const SizedBox(width: 6),
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
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
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
      var items = _repostItems.where((r) {
        return _matches(query, [
          r['title'] as String? ?? '',
          r['userName'] as String? ?? '',
          r['userPhone'] as String? ?? '',
          r['address'] as String? ?? '',
          r['rejectReason'] as String? ?? '',
          r['userNote'] as String? ?? '',
        ]);
      }).toList();

      if (_repostStatusFilter == 'pending') {
        items = items.where((r) => r['status'] == 'pending' || r['status'] == 'choduyet').toList();
      } else if (_repostStatusFilter == 'approved') {
        items = items.where((r) => r['status'] == 'approved' || r['status'] == 'daduyet').toList();
      } else if (_repostStatusFilter == 'rejected') {
        items = items.where((r) => r['status'] == 'rejected' || r['status'] == 'tuchoi').toList();
      }

      return Column(
        children: [
          _buildRepostFilterRow(),
          Expanded(
            child: items.isEmpty
                ? _empty('Không có bài đăng repost nào phù hợp 🎉')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _repostCard(items[i]),
                  ),
          ),
        ],
      );
    }

    if (_view == _UsersView.allUsers) {
      var items = _users.where((u) {
        return _matches(query, [
          u['displayName'] as String,
          _s(u, ['email']),
          _s(u, ['phone', 'phoneNumber']),
        ]);
      }).toList();

      if (_userRoleFilter == 'host') {
        items = items.where((u) => _isHostRole(u)).toList();
      } else if (_userRoleFilter == 'renter') {
        items = items.where((u) => _isRenterRole(u)).toList();
      } else if (_userRoleFilter == 'banned') {
        items = items.where((u) => u['isBanned'] == true).toList();
      } else if (_userRoleFilter == 'low_rep') {
        items = items.where((u) {
          final s = ((u['reputationScore'] ?? u['diemUyTin'] ?? 100) as num).toInt();
          return s < 80;
        }).toList();
      }

      if (_userSort == 'rep_asc') {
        items.sort((a, b) {
          final sa = ((a['reputationScore'] ?? a['diemUyTin'] ?? 100) as num).toInt();
          final sb = ((b['reputationScore'] ?? b['diemUyTin'] ?? 100) as num).toInt();
          return sa.compareTo(sb);
        });
      } else if (_userSort == 'rep_desc') {
        items.sort((a, b) {
          final sa = ((a['reputationScore'] ?? a['diemUyTin'] ?? 100) as num).toInt();
          final sb = ((b['reputationScore'] ?? b['diemUyTin'] ?? 100) as num).toInt();
          return sb.compareTo(sa);
        });
      } else if (_userSort == 'name_az') {
        items.sort((a, b) => (a['displayName'] as String).toLowerCase().compareTo((b['displayName'] as String).toLowerCase()));
      } else if (_userSort == 'newest') {
        items.sort((a, b) {
          final da = _date(a['createdAt']);
          final db = _date(b['createdAt']);
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da);
        });
      }

      return Column(
        children: [
          _buildUserMetricsRow(),
          _buildUserFiltersRow(),
          Expanded(
            child: items.isEmpty
                ? _empty('Không có người dùng phù hợp')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _userCard(items[i]),
                  ),
          ),
        ],
      );
    }

    final pending = _view == _UsersView.pendingReports;
    var items = _reports.where((r) {
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

    if (_reviewStarFilter == 1) {
      items = items.where((r) => (r['rating'] as int) <= 2).toList();
    } else if (_reviewStarFilter == 3) {
      items = items.where((r) => (r['rating'] as int) == 3).toList();
    } else if (_reviewStarFilter == 4) {
      items = items.where((r) => (r['rating'] as int) >= 4).toList();
    }

    return Column(
      children: [
        _buildStarFilterRow(),
        Expanded(
          child: items.isEmpty
              ? _empty(pending ? 'Không có đánh giá nào đang chờ xử lý 🎉' : 'Chưa có đánh giá nào được xử lý')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _reportCard(items[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildUserMetricsRow() {
    final total = _users.length;
    final hosts = _users.where((u) => _isHostRole(u)).length;
    final renters = _users.where((u) => _isRenterRole(u)).length;
    final banned = _users.where((u) => u['isBanned'] == true).length;
    final lowScore = _users.where((u) {
      final s = ((u['reputationScore'] ?? u['diemUyTin'] ?? 100) as num).toInt();
      return s < 80;
    }).length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _metricItem('Tổng user', '$total', _primary),
            _metricDivider(),
            _metricItem('Chủ trọ', '$hosts', const Color(0xFF027A48)),
            _metricDivider(),
            _metricItem('Người thuê', '$renters', const Color(0xFF026AA2)),
            _metricDivider(),
            _metricItem('Bị khóa', '$banned', _red),
            _metricDivider(),
            _metricItem('UT < 80', '$lowScore', _orange),
          ],
        ),
      ),
    );
  }

  Widget _metricItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: _textGrey, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _metricDivider() => Container(width: 1, height: 22, color: const Color(0xFFE2E8F0));

  Widget _buildUserFiltersRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChipItem('Tất cả', 'all', _userRoleFilter == 'all', (_) => setState(() => _userRoleFilter = 'all')),
                  const SizedBox(width: 6),
                  _filterChipItem('Chủ trọ', 'host', _userRoleFilter == 'host', (_) => setState(() => _userRoleFilter = 'host')),
                  const SizedBox(width: 6),
                  _filterChipItem('Người thuê', 'renter', _userRoleFilter == 'renter', (_) => setState(() => _userRoleFilter = 'renter')),
                  const SizedBox(width: 6),
                  _filterChipItem('Bị khóa', 'banned', _userRoleFilter == 'banned', (_) => setState(() => _userRoleFilter = 'banned')),
                  const SizedBox(width: 6),
                  _filterChipItem('Uy tín < 80đ', 'low_rep', _userRoleFilter == 'low_rep', (_) => setState(() => _userRoleFilter = 'low_rep')),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD0D5DD)),
              ),
              child: const Icon(Icons.sort_rounded, size: 16, color: _textDark),
            ),
            tooltip: 'Sắp xếp danh sách',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) => setState(() => _userSort = val),
            itemBuilder: (context) => [
              _sortMenuItem('default', 'Mặc định (Báo cáo chờ)', _userSort == 'default'),
              _sortMenuItem('rep_asc', 'Uy tín: Thấp ➔ Cao', _userSort == 'rep_asc'),
              _sortMenuItem('rep_desc', 'Uy tín: Cao ➔ Thấp', _userSort == 'rep_desc'),
              _sortMenuItem('name_az', 'Tên: A ➔ Z', _userSort == 'name_az'),
              _sortMenuItem('newest', 'Mới đăng ký nhất', _userSort == 'newest'),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _sortMenuItem(String value, String label, bool isSelected) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? _primary : _textDark,
              ),
            ),
          ),
          if (isSelected) const Icon(Icons.check, size: 16, color: _primary),
        ],
      ),
    );
  }

  Widget _filterChipItem(String label, String value, bool isSelected, Function(bool) onSelected) {
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? _primary : _textDark,
      ),
      selected: isSelected,
      selectedColor: _primary.withValues(alpha: 0.12),
      backgroundColor: const Color(0xFFF8FAFC),
      side: BorderSide(color: isSelected ? _primary : const Color(0xFFE2E8F0)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
      onSelected: onSelected,
    );
  }

  Widget _buildStarFilterRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChipItem('Tất cả sao', 'all', _reviewStarFilter == null, (_) => setState(() => _reviewStarFilter = null)),
            const SizedBox(width: 6),
            _filterChipItem('⭐ 1 - 2 sao (Cần can thiệp)', '1', _reviewStarFilter == 1, (_) => setState(() => _reviewStarFilter = 1)),
            const SizedBox(width: 6),
            _filterChipItem('⭐ 3 sao', '3', _reviewStarFilter == 3, (_) => setState(() => _reviewStarFilter = 3)),
            const SizedBox(width: 6),
            _filterChipItem('⭐ 4 - 5 sao', '4', _reviewStarFilter == 4, (_) => setState(() => _reviewStarFilter = 4)),
          ],
        ),
      ),
    );
  }

  Widget _buildRepostFilterRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChipItem('Tất cả', 'all', _repostStatusFilter == 'all', (_) => setState(() => _repostStatusFilter = 'all')),
            const SizedBox(width: 6),
            _filterChipItem('Chờ duyệt', 'pending', _repostStatusFilter == 'pending', (_) => setState(() => _repostStatusFilter = 'pending')),
            const SizedBox(width: 6),
            _filterChipItem('Đã duyệt', 'approved', _repostStatusFilter == 'approved', (_) => setState(() => _repostStatusFilter = 'approved')),
            const SizedBox(width: 6),
            _filterChipItem('Đã từ chối', 'rejected', _repostStatusFilter == 'rejected', (_) => setState(() => _repostStatusFilter = 'rejected')),
          ],
        ),
      ),
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

  Widget _avatar(String name, {bool banned = false, String avatarUrl = ''}) {
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    if (avatarUrl.isNotEmpty &&
        (avatarUrl.startsWith('http') || avatarUrl.startsWith('blob:') || avatarUrl.startsWith('data:'))) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: banned ? const Color(0xFFFEE4E2) : const Color(0xFFE9F5FC),
        backgroundImage: NetworkImage(avatarUrl),
      );
    }
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
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDCEAF5)),
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
                        color: const Color(0xFFE2E8F0),
                        child: const Icon(Icons.broken_image, size: 24, color: _textGrey),
                      ),
                    )
                  : Container(
                      width: 68,
                      height: 68,
                      color: const Color(0xFFE9F5FC),
                      child: const Icon(Icons.apartment_rounded, size: 28, color: _primary),
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
                          color: const Color(0xFFEFF8FF),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFB2DDFF)),
                        ),
                        child: const Text(
                          'PHÒNG LIÊN QUAN ĐẾN ĐÁNH GIÁ',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: _primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.open_in_new_rounded, size: 14, color: _primary),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  if (price is num && price > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatVnd(price),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF038048),
                      ),
                    ),
                  ],
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: _textGrey),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: _textGrey),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  const Row(
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
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textGrey),
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
                    color: const Color(0xFFF2F4F7),
                    child: const Icon(Icons.broken_image, size: 20, color: _textGrey),
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
          InkWell(
            onTap: () => _openUserDetailById((r['reportedUserId'] ?? '').toString()),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                _avatar(name, banned: banned, avatarUrl: avatarUrl),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Chủ trọ: $name',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: _textDark,
                              ),
                            ),
                          ),
                          const Icon(Icons.open_in_new_rounded, size: 14, color: _primary),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _chip('Đánh giá chủ trọ', const Color(0xFF027A48)),
                          _chip('⭐ ${r['rating'] ?? 5}/5 sao', (r['rating'] ?? 5) >= 4 ? _green : ((r['rating'] ?? 5) >= 3 ? _orange : _red)),
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
                            _chip('${r['totalReports']} đánh giá', _orange),
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
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFEDF89)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 16, color: _orange),
                    const SizedBox(width: 5),
                    Text(
                      'NỘI DUNG ĐÁNH GIÁ CHỦ TRỌ (${r['rating'] ?? 5}/5 SAO):',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB54708),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _s(r, ['comment', 'reason']).isEmpty
                      ? 'Đánh giá ${r['rating'] ?? 5} sao (không kèm lời nhận xét).'
                      : _s(r, ['comment', 'reason']),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textDark),
                ),
                if (_s(r, ['description', 'detail']).isNotEmpty && _s(r, ['description', 'detail']) != _s(r, ['comment', 'reason'])) ...[
                  const SizedBox(height: 4),
                  Text(
                    _s(r, ['description', 'detail']),
                    style: const TextStyle(fontSize: 12.5, color: _textGrey, height: 1.4),
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
          InkWell(
            onTap: () => _openUserDetailById((r['reviewerId'] ?? r['reporterId'] ?? '').toString()),
            child: Row(
              children: [
                const Icon(Icons.account_circle_outlined, size: 15, color: _primary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Người đánh giá: ${r['reporterDisplay']}${date == null ? '' : '  •  ${_dateFmt.format(date)}'}',
                    style: const TextStyle(fontSize: 11.5, color: _primary, fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.open_in_new_rounded, size: 12, color: _primary),
              ],
            ),
          ),
          if (!pending && resolution == 'warned') ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 16, color: _orange),
                      const SizedBox(width: 5),
                      Text(
                        'KẾT QUẢ CẢNH CÁO${penaltyPoints != null && (penaltyPoints is num) && penaltyPoints > 0 ? ' (TRỪ $penaltyPoints ĐIỂM UT)' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB54708),
                        ),
                      ),
                      const Spacer(),
                      if (r['previousScore'] != null && r['newScore'] != null)
                        Text(
                          '${r['previousScore']} ➔ ${r['newScore']}/100 đ',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB54708),
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          v.toString(),
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                        ),
                      )).toList(),
                    ),
                  ],
                  if (adminNote.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      adminNote,
                      style: const TextStyle(fontSize: 11.5, color: _textDark, height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (!pending && adminNote.isNotEmpty) ...[
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
    final name = (u['displayName'] ?? u['fullName'] ?? 'Chưa đặt tên').toString();
    final role = (u['role'] ?? '').toString();
    final isAdmin = role.toLowerCase() == 'admin';
    final contact = [
      _s(u, ['email']),
      _s(u, ['phone', 'phoneNumber']),
    ].where((e) => e.isNotEmpty).join('  •  ');
    final pendingReports = (u['pendingReports'] ?? 0) as int;
    final totalReports = (u['totalReports'] ?? 0) as int;
    final repScore = (u['reputationScore'] ?? u['diemUyTin']) as num?;
    final avatarUrl = (u['avatarUrl'] ?? u['photoUrl'] ?? '').toString();

    return InkWell(
      onTap: () => _openUserDetail(u),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDeco,
        child: Row(
          children: [
            _avatar(name, banned: banned, avatarUrl: avatarUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name.isEmpty ? 'Chưa đặt tên' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _textDark,
                          ),
                        ),
                      ),
                      if (banned)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE4E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Bị khóa',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _red),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Hoạt động',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _green),
                          ),
                        ),
                    ],
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
                      _chip(_roleLabel(role), isAdmin ? _red : (_isHostRole(u) ? const Color(0xFF027A48) : _primary)),
                      if (repScore != null)
                        _chip(
                          '⭐ UT: ${repScore.toInt()}/100',
                          repScore >= 80 ? _green : (repScore >= 50 ? _orange : _red),
                        ),
                      if (pendingReports > 0)
                        _chip('$pendingReports đánh giá chờ', _orange)
                      else if (totalReports > 0)
                        _chip('$totalReports đánh giá', _textGrey),
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
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Xem hồ sơ chi tiết',
                  icon: const Icon(Icons.visibility_outlined, size: 20, color: _primary),
                  onPressed: () => _openUserDetail(u),
                ),
                if (!isAdmin)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20, color: _textGrey),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) {
                      if (val == 'detail') {
                        _openUserDetail(u);
                      } else if (val == 'toggle_ban') {
                        if (banned) {
                          _unbanUser(u);
                        } else {
                          _banUser(userId: u['id'] as String, userName: name);
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'detail',
                        child: Row(
                          children: [
                            Icon(Icons.person_search_outlined, size: 16, color: _primary),
                            SizedBox(width: 8),
                            Text('Xem chi tiết', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle_ban',
                        child: Row(
                          children: [
                            Icon(banned ? Icons.lock_open : Icons.lock_outline, size: 16, color: banned ? _green : _red),
                            SizedBox(width: 8),
                            Text(banned ? 'Mở khóa tài khoản' : 'Khóa tài khoản',
                                style: TextStyle(fontSize: 13, color: banned ? _green : _red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
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
          InkWell(
            onTap: () => _openUserDetailById((r['userId'] ?? '').toString()),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                _avatar(userName),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _textDark,
                              ),
                            ),
                          ),
                          const Icon(Icons.open_in_new_rounded, size: 14, color: _primary),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _chip('Repost', const Color(0xFF7C3AED)),
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
                    style: const TextStyle(fontSize: 11, color: _textGrey),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Thông tin bài đăng
          InkWell(
            onTap: () => _openReportedPostDetail(r),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
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
                          color: const Color(0xFFF2F4F7),
                          child: const Icon(Icons.broken_image, size: 24, color: _textGrey),
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
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatVnd(price),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF038048),
                          ),
                        ),
                        if (address.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 13, color: _textGrey),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.5, color: _textGrey),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        const Row(
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
                color: const Color(0xFFFEF3F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECDCA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: _red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
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
                          style: const TextStyle(fontSize: 12, color: _textDark, height: 1.3),
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
                color: const Color(0xFFEFF8FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFB2DDFF)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.edit_note_rounded, size: 18, color: _primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
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
                          style: const TextStyle(fontSize: 12, color: _textDark, height: 1.3),
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
                label: const Text('Xem chi tiết', style: TextStyle(fontSize: 12)),
              ),
              const Spacer(),
              if (isPending) ...[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _red,
                    side: const BorderSide(color: _red),
                  ),
                  onPressed: () => _rejectRepost(r),
                  child: const Text('Từ chối', style: TextStyle(fontSize: 12.5)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                  ),
                  onPressed: () => _approveRepost(r),
                  child: const Text('Phê duyệt', style: TextStyle(fontSize: 12.5)),
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
                            color: const Color(0xFFF2F4F7),
                            child: const Icon(Icons.broken_image, size: 28, color: _textGrey),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Giá thuê: ${_formatVnd(price)}${deposit != null && (deposit is num ? deposit > 0 : deposit.toString().isNotEmpty) ? '  •  Cọc: ${_formatVnd(deposit)}' : ''}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF038048)),
                ),
                const SizedBox(height: 6),
                Text('Địa chỉ: $address', style: const TextStyle(fontSize: 12.5, color: _textDark)),
                const SizedBox(height: 6),
                Text('Người đăng: $userName ($userPhone)', style: const TextStyle(fontSize: 12.5, color: _textGrey)),
                const SizedBox(height: 10),
                if (rejectReason.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECDCA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Lý do từng vi phạm:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _red)),
                        const SizedBox(height: 2),
                        Text(rejectReason, style: const TextStyle(fontSize: 12, color: _textDark)),
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
                      color: const Color(0xFFEFF8FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFB2DDFF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nội dung sửa đổi của người dùng:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _primary)),
                        const SizedBox(height: 2),
                        Text(userNote, style: const TextStyle(fontSize: 12, color: _textDark)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const Text('Mô tả bài đăng:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 12, color: _textGrey, height: 1.4)),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new_rounded, size: 14),
            label: const Text('Xem bài đăng'),
            onPressed: () {
              Navigator.pop(ctx);
              _openReportedPostDetail(r);
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          if (isPending) ...[
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: _red, side: const BorderSide(color: _red)),
              onPressed: () {
                Navigator.pop(ctx);
                _rejectRepost(r);
              },
              child: const Text('Từ chối'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _green),
              onPressed: () {
                Navigator.pop(ctx);
                _approveRepost(r);
              },
              child: const Text('Phê duyệt'),
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
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFAEB),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFEDF89)),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFB54708), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cảnh cáo & Trừ điểm Uy tín',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1D2939),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Chủ trọ: $hostName  •  Điểm hiện tại: ${widget.currentScore}/100 đ',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF667085), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF006948),
                      backgroundColor: const Color(0xFFE8F5E9),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 14),
                    label: const Text('Khung phạt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    onPressed: () async {
                      await ViolationRulesSheet.show(context);
                      _loadRules();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF98A2B3)),
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
                                    ? [const Color(0xFFFEF3F2), const Color(0xFFFEE4E2)]
                                    : [const Color(0xFFF8FAFC), const Color(0xFFEFF8FF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDanger ? const Color(0xFFFECDCA) : const Color(0xFFB2DDFF),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildScoreCol('Hiện tại', '${widget.currentScore}', const Color(0xFF475467)),
                                    const Icon(Icons.remove, size: 18, color: Color(0xFFB54708)),
                                    _buildScoreCol('Trừ điểm', '-$_penaltyPoints', const Color(0xFFD92D20)),
                                    const Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF667085)),
                                    _buildScoreCol(
                                      'Còn lại',
                                      '$remainingScore/100',
                                      remainingScore >= 80
                                          ? const Color(0xFF039855)
                                          : (remainingScore >= 50 ? const Color(0xFFB54708) : const Color(0xFFD92D20)),
                                    ),
                                  ],
                                ),
                                if (isDanger) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.info_outline, size: 13, color: Color(0xFFD92D20)),
                                        SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            'Uy tín dưới 50 điểm: Tài khoản sẽ rơi vào danh sách hạn chế/khóa!',
                                            style: TextStyle(fontSize: 10.5, color: Color(0xFFD92D20), fontWeight: FontWeight.w600),
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
                              const Icon(Icons.checklist_rounded, size: 16, color: Color(0xFF026AA2)),
                              const SizedBox(width: 6),
                              const Text(
                                'QUY ĐỊNH KHUNG PHẠT (TỪ FIREBASE):',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF026AA2),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Đã chọn: ${_selectedRuleIds.length}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF667085), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _rules.length,
                              separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
                                              activeColor: const Color(0xFF026AA2),
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
                                                        color: isSelected ? const Color(0xFF1D2939) : const Color(0xFF344054),
                                                      ),
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isSelected ? const Color(0xFFFEE4E2) : const Color(0xFFF2F4F7),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      '-${rule.defaultPoints}đ UT',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w700,
                                                        color: isSelected ? const Color(0xFFD92D20) : const Color(0xFF667085),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (rule.description.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  rule.description,
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF667085), height: 1.3),
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
                                color: const Color(0xFFFFFAEB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _applyReportedReason ? const Color(0xFFF79009) : const Color(0xFFFEDF89),
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
                                          activeColor: const Color(0xFFB54708),
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
                                                color: _applyReportedReason ? const Color(0xFF7A271A) : const Color(0xFFB54708),
                                              ),
                                            ),
                                            if (_reportDesc.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                _reportDesc,
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF667085), height: 1.3),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (_applyReportedReason) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFFEDF89)),
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
                                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFD92D20)),
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
                              color: _applyCustomOtherViolation ? const Color(0xFFFDF2FA) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _applyCustomOtherViolation ? const Color(0xFFF670C7) : const Color(0xFFE2E8F0),
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
                                    const Expanded(
                                      child: Text(
                                        'Áp dụng lỗi vi phạm khác (Admin tự nhập)',
                                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF344054)),
                                      ),
                                    ),
                                    if (_applyCustomOtherViolation)
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFD92D20)),
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
                                    style: const TextStyle(fontSize: 12.5),
                                    onChanged: (_) => _recalcPoints(),
                                    decoration: InputDecoration(
                                      hintText: 'Nhập tên lỗi vi phạm phát sinh (ví dụ: Tự ý khóa cửa phòng trọ)...',
                                      hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF98A2B3)),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
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
                                            activeColor: const Color(0xFF006948),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                            onChanged: (val) => setState(() => _saveCustomToSystemRules = val == true),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Expanded(
                                          child: Text(
                                            '💾 Lưu lỗi này vào khung phạt hệ thống Firebase để dùng cho các báo cáo sau',
                                            style: TextStyle(fontSize: 11, color: Color(0xFF006948), fontWeight: FontWeight.w600),
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
                              const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF475467)),
                              const SizedBox(width: 6),
                              const Text(
                                'ĐIỀU CHỈNH TỔNG ĐIỂM TRỪ:',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF344054),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F4F7),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFD0D5DD)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: _penaltyPoints > 0 ? () => _adjustPoints(-5) : null,
                                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        child: Icon(Icons.remove, size: 16, color: Color(0xFF344054)),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Text(
                                        '$_penaltyPoints đ',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFD92D20)),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: _penaltyPoints < widget.currentScore ? () => _adjustPoints(5) : null,
                                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        child: Icon(Icons.add, size: 16, color: Color(0xFF344054)),
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
                                    color: isSelected ? Colors.white : const Color(0xFF344054),
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: const Color(0xFFD92D20),
                                backgroundColor: const Color(0xFFF8FAFC),
                                side: BorderSide(
                                  color: isSelected ? const Color(0xFFD92D20) : const Color(0xFFE2E8F0),
                                ),
                                onSelected: (_) => _setPoints(pts),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          // Section 5: Admin Note
                          const Row(
                            children: [
                              Icon(Icons.edit_note_rounded, size: 17, color: Color(0xFF475467)),
                              SizedBox(width: 6),
                              Text(
                                'LỜI NHẮN / GHI CHÚ GỬI CHỦ TRỌ:',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF344054),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _noteCtrl,
                            maxLines: 3,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: InputDecoration(
                              hintText: 'Nhập yêu cầu khắc phục vi phạm hoặc nhắc nhở chủ trọ...',
                              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF98A2B3)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy', style: TextStyle(fontSize: 13)),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD92D20),
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
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF667085), fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }
}
