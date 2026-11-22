import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/admin_audit_identity.dart';
import '../widgets/admin_branded_title.dart';

/// 4 chế độ xem của trang Quản lý người dùng.
enum _UsersView { pendingReports, handledReports, allUsers, userApprovals }

/// Trang quản lý người dùng: duyệt báo cáo vi phạm / đánh giá xấu, cảnh cáo,
/// điều chỉnh & khôi phục điểm uy tín, khóa / mở khóa tài khoản.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  // Bảng màu Xanh Pastel chủ đạo của Admin
  static const _primary = Color(0xFF398FC0);
  static const _primaryDark = Color(0xFF1E6A96);
  static const _pastelBg = Color(0xFFF4F9FF);
  static const _pastelBlueSoft = Color(0xFFE9F5FC);
  static const _pastelBorder = Color(0xFFDCEAF5);
  static const _textDark = Color(0xFF101828);
  static const _textGrey = Color(0xFF667085);
  static const _red = Color(0xFFD92D20);
  static const _green = Color(0xFF12B76A);
  static const _teal = Color(0xFF0E9384);
  static const _orange = Color(0xFFF79009);

  final TextEditingController _searchCtrl = TextEditingController();
  // Tìm kiếm dùng ValueNotifier để không setState khi gõ (giống trang Quản lý đơn).
  final ValueNotifier<String> _searchQuery = ValueNotifier<String>('');
  final DateFormat _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  StreamSubscription<QuerySnapshot>? _usersSub;
  StreamSubscription<QuerySnapshot>? _reportsSub;
  StreamSubscription<QuerySnapshot>? _reviewsSub;
  StreamSubscription<QuerySnapshot>? _bookingsSub;

  List<QueryDocumentSnapshot> _userDocs = [];
  List<QueryDocumentSnapshot> _reportDocs = [];
  List<QueryDocumentSnapshot> _reviewDocs = [];
  List<QueryDocumentSnapshot> _bookingDocs = [];

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  _UsersView _view = _UsersView.pendingReports;

  // Bộ lọc chuyên sâu
  String _userRoleFilter = 'all'; // 'all', 'host', 'renter', 'banned', 'low_rep'
  int? _reviewStarFilter; // null = tất cả, 1 = đánh giá 1-2 sao, 0 = báo cáo trực tiếp

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => _searchQuery.value = _searchCtrl.text);

    final db = FirebaseFirestore.instance;

    _usersSub = db.collection('users').snapshots().listen(
      (snap) {
        _userDocs = snap.docs;
        _isLoading = false;
        _recompute();
      },
      onError: (e) {
        debugPrint('Lỗi tải users: $e');
        if (mounted) setState(() => _isLoading = false);
      },
    );

    _reportsSub = db.collection('reports').snapshots().listen(
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

    _reviewsSub = db.collection('host_reviews').snapshots().listen(
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

    _bookingsSub = db.collection('bookings').snapshots().listen(
      (snap) {
        _bookingDocs = snap.docs;
        _recompute();
      },
      onError: (e) {
        debugPrint('Lỗi tải bookings: $e');
      },
    );
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    _reportsSub?.cancel();
    _reviewsSub?.cancel();
    _bookingsSub?.cancel();
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
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
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

  bool _isAdminRole(Map<String, dynamic> u) {
    final r = (u['role'] ?? '').toString().toLowerCase().trim();
    return r == 'admin' || r == 'quantri' || r == 'quan tri vien';
  }

  bool _isHostRole(Map<String, dynamic> u) {
    final r = (u['role'] ?? '').toString().toLowerCase().trim();
    return r == 'host' || r == 'landlord' || r == 'chutro' || r == 'chu tro';
  }

  bool _isRenterRole(Map<String, dynamic> u) {
    if (_isAdminRole(u) || _isHostRole(u)) return false;
    return true;
  }

  bool _isUserVerified(Map<String, dynamic> u) {
    if (u['isCccdVerified'] == true || u['daXacThucCccd'] == true) {
      return true;
    }
    final status =
        _s(u, ['trangThaiXacMinh', 'trangThaiXacMinh_id']).toLowerCase();
    return status == 'daxacthuc' ||
        status == 'verified' ||
        status == 'approved';
  }

  bool _isCccdRejected(Map<String, dynamic> u) {
    return _s(u, ['cccdVerificationStatus']).toLowerCase() == 'rejected';
  }

  String _roleLabel(String role) {
    switch (role.toLowerCase().trim()) {
      case 'host':
      case 'landlord':
      case 'chutro':
      case 'chu tro':
        return 'Chủ trọ';
      case 'admin':
      case 'quantri':
        return 'Admin';
      case 'renter':
      case 'tenant':
        return 'Người thuê';
      default:
        return role.isEmpty ? 'Người thuê' : role;
    }
  }

  String _resolveUserCode(Map<String, dynamic> u) {
    final raw = _s(u, ['userCode', 'maNguoiDung', 'idNguoiDung', 'hostCode'])
        .toUpperCase();
    final isHost = _isHostRole(u);
    final isAdmin = _isAdminRole(u);
    if (isAdmin) return raw.isNotEmpty ? raw : 'ADMIN';

    final prefix = isHost ? 'CT' : 'NT';
    final match = RegExp(r'(CT|NT)(\d{2,5})').firstMatch(raw);
    if (match != null) {
      return '$prefix${match.group(2)!}';
    }
    final uid = (u['id'] ?? '').toString().trim();
    if (uid.isNotEmpty) {
      var hash = 0;
      for (var i = 0; i < uid.length; i++) {
        hash = (hash * 31 + uid.codeUnitAt(i)) & 0x7FFFFFFF;
      }
      final val = (hash % 900) + 100;
      return '$prefix$val';
    }
    return prefix;
  }

  static String _extractShortBookingCode(String bookingId) {
    final clean = bookingId.trim();
    if (clean.isEmpty) return '';
    final match =
        RegExp(r'(CT|NT)\d{2,5}', caseSensitive: false).firstMatch(clean);
    if (match != null) return match.group(0)!.toUpperCase();
    if (clean.length <= 6) return clean.toUpperCase();
    return clean.substring(clean.length - 6).toUpperCase();
  }

  static int _int(dynamic v, [int fallback = 100]) {
    if (v is num) return v.toInt();
    if (v != null) {
      final parsed = num.tryParse(v.toString().trim());
      if (parsed != null) return parsed.toInt();
    }
    return fallback;
  }

  static int? _intOrNull(dynamic v) {
    if (v is num) return v.toInt();
    if (v != null) {
      final parsed = num.tryParse(v.toString().trim());
      if (parsed != null) return parsed.toInt();
    }
    return null;
  }

  static bool _isCancelledBookingStatus(String status) {
    final s = status.toLowerCase().trim();
    return s.contains('cancel') ||
        s.contains('huy') ||
        s.contains('tu_choi') ||
        s.contains('tuchoi') ||
        s.contains('reject');
  }

  // ───────────────────────── Dữ liệu ─────────────────────────

  void _recompute() {
    // 1. Map danh sách người dùng
    final usersById = <String, Map<String, dynamic>>{};
    for (final d in _userDocs) {
      final data = Map<String, dynamic>.from(
        d.data() as Map<String, dynamic>? ?? {},
      );
      data['id'] = d.id;
      data['displayName'] = _s(data, [
        'fullName',
        'name',
        'displayName',
        'cccdFullName',
        'userName',
        'email',
      ]);
      data['resolvedAvatarUrl'] = _s(data, [
        'avatarUrl',
        'anhDaiDien',
        'photoUrl',
        'photoURL',
        'avatar',
        'imageUrl',
        'profileImage',
        'profilePicture',
        'picture',
        'avatarBase64',
      ]);
      final isBanned = data['isBanned'] == true || _int(data['statusId'], 1) == 2;
      data['isBanned'] = isBanned;
      data['isBannedFlag'] = isBanned;
      usersById[d.id] = data;
    }

    // 2. Thống kê hoạt động từ bookings (Activity Snapshot) + hỗ trợ tra cứu tên chủ trọ/người thuê
    final hostBookingCount = <String, int>{};
    final renterBookingCount = <String, int>{};
    final renterCancelledCount = <String, int>{};
    final hostNamesFromBookings = <String, String>{};

    for (final d in _bookingDocs) {
      final b = d.data() as Map<String, dynamic>? ?? {};
      final hostId = _s(b, ['hostId', 'chuNhaId', 'landlordId', 'ownerId']);
      final renterId = _s(
        b,
        ['renterId', 'userId', 'nguoiDung_Id', 'nguoiDungId', 'tenantId'],
      );
      final status = _s(b, ['status', 'trangThai', 'bookingStatus']);

      if (hostId.isNotEmpty) {
        hostBookingCount[hostId] = (hostBookingCount[hostId] ?? 0) + 1;
        final hName = _s(b, ['hostName', 'tenChuNha', 'landlordName']);
        if (hName.isNotEmpty) {
          hostNamesFromBookings[hostId] = hName;
        }
      }
      if (renterId.isNotEmpty) {
        renterBookingCount[renterId] = (renterBookingCount[renterId] ?? 0) + 1;
        if (_isCancelledBookingStatus(status)) {
          renterCancelledCount[renterId] =
              (renterCancelledCount[renterId] ?? 0) + 1;
        }
      }
    }

    // 3. Đọc bảng reports (gồm cả báo cáo trực tiếp & kết quả xử lý đánh giá host_reviews)
    final reportsById = <String, Map<String, dynamic>>{};
    for (final d in _reportDocs) {
      final data = Map<String, dynamic>.from(
        d.data() as Map<String, dynamic>? ?? {},
      );
      data['id'] = d.id;
      data['sourceCollection'] = 'reports';
      reportsById[d.id] = data;
    }

    // 4. Đọc bảng host_reviews:
    //    - Tính điểm sao trung bình (avgRating, reviewCount) cho từng Chủ trọ
    //    - Lưu lịch sử đánh giá cho từng User (Idea 4)
    //    - Đưa các đánh giá 1-2 sao (hoặc đánh giá đã được Admin xử lý lưu trong reports) vào danh sách cần duyệt (Idea 1)
    final hostRatingSum = <String, int>{};
    final hostReviewCount = <String, int>{};
    final userHistoryByUid = <String, List<Map<String, dynamic>>>{};

    void addHistoryItem(String uid, Map<String, dynamic> item) {
      if (uid.isEmpty) return;
      userHistoryByUid.putIfAbsent(uid, () => []).add(item);
    }

    for (final d in _reviewDocs) {
      final rev = Map<String, dynamic>.from(
        d.data() as Map<String, dynamic>? ?? {},
      );
      rev['id'] = d.id;
      final hostId = _s(rev, ['hostId', 'chuNhaId', 'targetUserId', 'reportedUserId']);
      final rating = _intOrNull(rev['rating']);
      final comment = _s(rev, ['comment', 'nhanXet', 'noiDung', 'reason']);
      final bookingId = _s(rev, ['bookingId', 'maDon']);
      final reviewerName = _s(rev, ['reviewerName', 'reporterName', 'nguoiDanhGia']);
      final createdAtDate = _date(rev['createdAt']);

      if (hostId.isNotEmpty && rating != null && rating >= 1 && rating <= 5) {
        hostRatingSum[hostId] = (hostRatingSum[hostId] ?? 0) + rating;
        hostReviewCount[hostId] = (hostReviewCount[hostId] ?? 0) + 1;
      }

      // Kiểm tra xem đánh giá này đã có bản ghi xử lý trong `reports/{d.id}` chưa
      final existingMod = reportsById[d.id];
      final effectiveStatus = existingMod != null
          ? _s(existingMod, ['status', 'trangThai']).toLowerCase()
          : 'pending';

      addHistoryItem(hostId, {
        'id': d.id,
        'isReview': true,
        'rating': rating,
        'comment': comment.isNotEmpty
            ? comment
            : (rating != null ? 'Đánh giá $rating sao' : 'Đánh giá'),
        'reviewerName': reviewerName.isNotEmpty ? reviewerName : 'Khách thuê',
        'bookingCode': _extractShortBookingCode(bookingId.isNotEmpty ? bookingId : d.id),
        'createdAtDate': createdAtDate,
        'status': existingStatusOrDefault(
          existingMod != null ? effectiveStatus : (rating != null && rating <= 2 ? 'pending' : 'normal'),
        ),
        'resolution': existingMod != null ? _s(existingMod, ['resolution']) : '',
      });

      // Tự động đưa đánh giá xấu (1 - 2 sao) hoặc đánh giá đã xử lý vào danh sách Báo cáo
      final isLowStar = rating != null && rating <= 2;
      if (isLowStar || existingMod != null) {
        final merged = <String, dynamic>{
          ...rev,
          ...?existingMod,
          'id': d.id,
          'isHostReview': true,
          'bookingId': bookingId.isNotEmpty ? bookingId : d.id,
          'shortBookingCode': _extractShortBookingCode(
            bookingId.isNotEmpty ? bookingId : d.id,
          ),
          'reportedUserId': hostId,
          'rating': rating,
        };
        if (_s(merged, ['status', 'trangThai']).isEmpty) {
          merged['status'] = 'pending';
        }
        reportsById[d.id] = merged;
      }
    }

    // 5. Chuẩn hóa danh sách reports để hiển thị ở tab Chờ xử lý / Đã xử lý
    final reportCount = <String, int>{};
    final pendingCount = <String, int>{};
    final reports = <Map<String, dynamic>>[];

    for (final data in reportsById.values) {
      final uid = _s(data, [
        'reportedUserId',
        'targetUserId',
        'hostId',
        'chuNhaId',
        'userId',
        'targetId',
      ]);
      final status = _s(data, ['status', 'trangThai']).toLowerCase();
      data['status'] = status.isEmpty ? 'pending' : status;
      data['reportedUserId'] = uid;
      data['createdAtDate'] = _date(data['createdAt']);

      final rating = _intOrNull(data['rating']);
      data['rating'] = rating;
      final comment = _s(data, ['comment', 'nhanXet', 'noiDung', 'detail']);
      final reason = _s(data, ['reason']);
      data['reason'] = reason.isNotEmpty
          ? reason
          : (comment.isNotEmpty
                ? comment
                : (rating != null ? 'Đánh giá $rating sao' : ''));

      final bookingId = _s(data, ['bookingId', 'maDon']);
      if (bookingId.isNotEmpty && _s(data, ['shortBookingCode']).isEmpty) {
        data['shortBookingCode'] = _extractShortBookingCode(bookingId);
      }

      if (uid.isNotEmpty) {
        reportCount[uid] = (reportCount[uid] ?? 0) + 1;
        if (data['status'] == 'pending') {
          pendingCount[uid] = (pendingCount[uid] ?? 0) + 1;
        }
      }

      // Nếu đây là báo cáo trực tiếp từ bảng reports (không nằm trong _reviewDocs), thêm vào lịch sử của User
      final isFromReviewDocs = _reviewDocs.any((doc) => doc.id == data['id']);
      if (!isFromReviewDocs && uid.isNotEmpty) {
        addHistoryItem(uid, {
          'id': data['id'],
          'isReview': rating != null,
          'rating': rating,
          'comment': data['reason'] as String,
          'reviewerName': _s(data, [
            'reporterName',
            'reviewerName',
            'nguoiBaoCao',
            'nguoiDanhGia',
          ]).isNotEmpty
              ? _s(data, [
                  'reporterName',
                  'reviewerName',
                  'nguoiBaoCao',
                  'nguoiDanhGia',
                ])
              : 'Người báo cáo',
          'bookingCode': _s(data, ['shortBookingCode']),
          'createdAtDate': data['createdAtDate'] as DateTime?,
          'status': data['status'] as String,
          'resolution': _s(data, ['resolution']),
        });
      }

      reports.add(data);
    }

    for (final r in reports) {
      final uid = r['reportedUserId'] as String;
      final u = usersById[uid];

      final explicitName = _s(r, [
        'reportedUserName',
        'targetUserName',
        'hostName',
        'tenChuNha',
        'userName',
        'fullName',
        'name',
      ]);
      final bookingFallbackName = hostNamesFromBookings[uid] ?? '';
      final resolvedUserCode = u != null
          ? _resolveUserCode(u)
          : (uid.isNotEmpty ? 'CT${(uid.hashCode.abs() % 900) + 100}' : '');

      r['reportedName'] = (u?['displayName'] != null &&
              u!['displayName'].toString().trim().isNotEmpty)
          ? u['displayName'].toString().trim()
          : (explicitName.isNotEmpty
                ? explicitName
                : (bookingFallbackName.isNotEmpty
                      ? bookingFallbackName
                      : (resolvedUserCode.isNotEmpty
                            ? 'Chủ trọ #$resolvedUserCode'
                            : 'Chủ trọ / Người dùng')));
      r['reportedUserCode'] = resolvedUserCode;
      r['reportedPhone'] = _s(r, [
        'hostPhone',
        'reportedPhone',
        'soDienThoai',
        'phone',
        'phoneNumber',
      ]).isNotEmpty
          ? _s(r, [
              'hostPhone',
              'reportedPhone',
              'soDienThoai',
              'phone',
              'phoneNumber',
            ])
          : _s(u ?? {}, ['phone', 'phoneNumber']);
      r['reportedRole'] = _s(r, ['reportedRole', 'role']).isNotEmpty
          ? _s(r, ['reportedRole', 'role'])
          : (u?['role'] ?? (r['isHostReview'] == true ? 'host' : '')).toString();
      r['reportedBanned'] = u?['isBanned'] == true;
      r['reportedAvatarUrl'] = _s(u ?? {}, [
        'resolvedAvatarUrl',
        'avatarUrl',
        'anhDaiDien',
        'photoUrl',
        'avatar',
      ]).isNotEmpty
          ? _s(u ?? {}, [
              'resolvedAvatarUrl',
              'avatarUrl',
              'anhDaiDien',
              'photoUrl',
              'avatar',
            ])
          : _s(r, ['reportedAvatarUrl', 'avatarUrl', 'anhDaiDien']);
      r['reportedReputationScore'] =
          u?['reputationScore'] ?? u?['diemUyTin'] ?? r['reportedReputationScore'];
      r['totalReports'] = uid.isNotEmpty ? (reportCount[uid] ?? 1) : 1;
      r['reporterDisplay'] = _s(r, [
        'reporterName',
        'reviewerName',
        'nguoiDanhGia',
        'nguoiBaoCao',
      ]).isNotEmpty
          ? _s(r, [
              'reporterName',
              'reviewerName',
              'nguoiDanhGia',
              'nguoiBaoCao',
            ])
          : (usersById[_s(r, ['reporterId', 'reviewerId'])]?['displayName'] ??
                    'Ẩn danh')
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

    // 6. Gắn thống kê Activity Snapshot & lịch sử đánh giá cho từng User
    final users = usersById.values.toList();
    for (final u in users) {
      final uid = u['id'] as String;
      u['totalReports'] = reportCount[uid] ?? 0;
      u['pendingReports'] = pendingCount[uid] ?? 0;
      u['resolvedUserCode'] = _resolveUserCode(u);

      final revCount = hostReviewCount[uid] ?? 0;
      final revSum = hostRatingSum[uid] ?? 0;
      u['reviewCount'] = revCount;
      u['avgRating'] = revCount > 0 ? (revSum / revCount) : null;
      u['hostBookingCount'] = hostBookingCount[uid] ?? 0;
      u['renterBookingCount'] = renterBookingCount[uid] ?? 0;
      u['renterCancelledCount'] = renterCancelledCount[uid] ?? 0;

      final history = List<Map<String, dynamic>>.from(
        userHistoryByUid[uid] ?? const [],
      );
      history.sort((a, b) {
        final da = a['createdAtDate'] as DateTime?;
        final db = b['createdAtDate'] as DateTime?;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });
      u['historyItems'] = history;
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

  static String existingStatusOrDefault(String s) => s.isEmpty ? 'pending' : s;

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
                  fillColor: _pastelBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _pastelBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _pastelBorder),
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
    return AdminAuditIdentity.currentActorFields().then(
      (actorFields) => FirebaseFirestore.instance.collection('audit_logs').add({
        ...actorFields,
        'action': action,
        'category': 'nguoiDung',
        'details': details,
        'target': target,
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  Map<String, dynamic> _reportModerationPayload(
    Map<String, dynamic> r, {
    required String status,
    required String resolution,
    required String adminNote,
    int? penaltyPoints,
  }) {
    return {
      'status': status,
      'resolution': resolution,
      'adminNote': adminNote,
      'penaltyPoints': ?penaltyPoints,
      'reportedUserId': _s(r, ['reportedUserId', 'hostId']),
      'reportedUserName': _s(r, ['reportedName', 'reportedUserName']),
      'reportedRole': _s(r, ['reportedRole', 'role']),
      'reporterId': _s(r, ['reporterId', 'reviewerId']),
      'reporterName': _s(r, ['reporterDisplay', 'reviewerName', 'reporterName']),
      if (r['rating'] != null) 'rating': r['rating'],
      if (_s(r, ['reason']).isNotEmpty) 'reason': _s(r, ['reason']),
      if (_s(r, ['bookingId']).isNotEmpty) 'bookingId': _s(r, ['bookingId']),
      if (r['isHostReview'] == true) 'fromHostReview': true,
      'createdAt': r['createdAt'] ?? FieldValue.serverTimestamp(),
      'handledAt': FieldValue.serverTimestamp(),
    };
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
        'statusId': 2,
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
        // Luôn lưu trạng thái xử lý vào bảng `reports` để tương thích với firestore.rules
        batch.set(
          db.collection('reports').doc(r['id'] as String),
          _reportModerationPayload(
            r,
            status: 'resolved',
            resolution: 'banned',
            adminNote: reason,
          ),
          SetOptions(merge: true),
        );
      }

      batch.set(db.collection('notifications').doc(), {
        'recipientId': userId,
        'title': 'Tài khoản bị khóa',
        'body': 'Tài khoản của bạn đã bị khóa. Lý do: $reason',
        'notificationType': 'account_banned',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      await _audit(
        'Khóa tài khoản',
        'Admin đã khóa "$userName". Lý do: $reason',
        'User $userId',
      );
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
      final uid = user['id'] as String;
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.set(db.collection('users').doc(uid), {
        'isBanned': false,
        'statusId': 1,
        'unbannedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(db.collection('notifications').doc(), {
        'recipientId': uid,
        'title': 'Tài khoản đã được mở khóa',
        'body': note.isEmpty
            ? 'Tài khoản của bạn đã được Admin mở khóa và hoạt động bình thường trở lại.'
            : 'Tài khoản của bạn đã được mở khóa. Ghi chú: $note',
        'notificationType': 'account_unbanned',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      await _audit(
        'Mở khóa tài khoản',
        'Admin đã mở khóa "$name".${note.isEmpty ? '' : ' Ghi chú: $note'}',
        'User $uid',
      );
      _snack('Đã mở khóa tài khoản $name');
    } catch (e) {
      _snack('Lỗi mở khóa: $e', error: true);
    }
  }

  /// Hộp thoại Cảnh cáo & Trừ điểm uy tín trực tiếp dành cho Admin (Idea 3).
  Future<void> _warnUser(Map<String, dynamic> report) async {
    final name = report['reportedName'] as String;
    final uid = (report['reportedUserId'] ?? '').toString();
    final userDoc = _users.where((u) => u['id'] == uid).firstOrNull;
    final currentScore = _int(
      userDoc?['reputationScore'] ??
          userDoc?['diemUyTin'] ??
          report['reportedReputationScore'],
      100,
    );

    final ctrl = TextEditingController(
      text: _s(report, ['reason']).isNotEmpty
          ? 'Nhắc nhở về phản ánh: "${_s(report, ['reason'])}"'
          : '',
    );
    var penalty = 10; // Mặc định: Cảnh cáo (-10đ)
    var lockImmediately = (currentScore - penalty).clamp(0, 100) <= 49;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final nextScore = (currentScore - penalty).clamp(0, 100);
          final isCritical = nextScore <= 49;

          void selectPenalty(int p) {
            setLocal(() {
              penalty = p;
              final updated = (currentScore - p).clamp(0, 100);
              lockImmediately = updated <= 49;
            });
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text(
              'Cảnh cáo & Xử lý uy tín',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đối tượng: $name',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Chọn mức xử lý:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _textGrey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: [
                      _penaltyCheckTile(
                        label: 'Nhắc nhở (-5đ)',
                        selected: penalty == 5,
                        color: _primary,
                        onTap: () => selectPenalty(5),
                      ),
                      _penaltyCheckTile(
                        label: 'Cảnh cáo (-10đ)',
                        selected: penalty == 10,
                        color: _orange,
                        onTap: () => selectPenalty(10),
                      ),
                      _penaltyCheckTile(
                        label: 'Vi phạm nặng (-20đ)',
                        selected: penalty == 20,
                        color: _red,
                        onTap: () => selectPenalty(20),
                      ),
                      _penaltyCheckTile(
                        label: 'Chỉ gửi nhắc nhở (0đ)',
                        selected: penalty == 0,
                        color: _textGrey,
                        onTap: () => selectPenalty(0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isCritical
                          ? const Color(0xFFFEF3F2)
                          : _pastelBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCritical
                            ? const Color(0xFFFECDCA)
                            : _pastelBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Điểm hiện tại: $currentScore/100',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _textGrey,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: _textGrey,
                            ),
                            Text(
                              'Sau xử lý: $nextScore/100',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: nextScore >= 80
                                    ? _teal
                                    : (nextScore > 49 ? _orange : _red),
                              ),
                            ),
                          ],
                        ),
                        if (isCritical) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => setLocal(
                              () => lockImmediately = !lockImmediately,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: lockImmediately,
                                    activeColor: _red,
                                    onChanged: (v) => setLocal(
                                      () => lockImmediately = v ?? false,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '⚠️ Uy tín ≤ 49đ ($nextScore/100): Gợi ý khóa tài khoản ngay',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    maxLines: 3,
                    onChanged: (_) => setLocal(() {}),
                    decoration: InputDecoration(
                      hintText: 'Nội dung cảnh cáo gửi tới người dùng (bắt buộc)...',
                      hintStyle: const TextStyle(fontSize: 12.5),
                      filled: true,
                      fillColor: _pastelBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _pastelBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _pastelBorder),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: lockImmediately ? _red : _orange,
                ),
                onPressed: ctrl.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(ctx, {
                        'note': ctrl.text.trim(),
                        'penalty': penalty,
                        'nextScore': nextScore,
                        'lockImmediately': lockImmediately,
                      }),
                child: Text(
                  lockImmediately ? 'Cảnh cáo & Khóa TK' : 'Xác nhận cảnh cáo',
                ),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;
    final note = result['note'] as String;
    final deducted = result['penalty'] as int;
    final nextScore = result['nextScore'] as int;
    final lockNow = result['lockImmediately'] == true;

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // Lưu trạng thái đã xử lý vào `reports/{id}` (an toàn tuyệt đối với firestore.rules)
      batch.set(
        db.collection('reports').doc(report['id'] as String),
        _reportModerationPayload(
          report,
          status: 'resolved',
          resolution: lockNow ? 'banned' : 'warned',
          adminNote: note,
          penaltyPoints: deducted,
        ),
        SetOptions(merge: true),
      );

      if (uid.isNotEmpty) {
        final userUpdate = <String, dynamic>{
          'reputationScore': nextScore,
          'diemUyTin': nextScore,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (lockNow) {
          userUpdate['isBanned'] = true;
          userUpdate['statusId'] = 2;
          userUpdate['bannedAt'] = FieldValue.serverTimestamp();
          userUpdate['banReason'] = note;
        }
        batch.set(
          db.collection('users').doc(uid),
          userUpdate,
          SetOptions(merge: true),
        );

        batch.set(db.collection('notifications').doc(), {
          'recipientId': uid,
          'recipientRole': (report['reportedRole'] ?? '').toString(),
          'title': deducted > 0
              ? 'Cảnh báo vi phạm (-$deductedđ uy tín)'
              : 'Nhắc nhở từ Admin',
          'body': '$note (Điểm uy tín hiện tại: $nextScore/100)',
          'notificationType': 'warning',
          'reportId': report['id'],
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      await _audit(
        lockNow ? 'Cảnh cáo & Khóa TK' : 'Cảnh cáo người dùng',
        'Admin cảnh cáo "$name" (-$deductedđ, còn $nextScore/100). Nội dung: $note',
        'User $uid',
      );
      _snack(
        deducted > 0
            ? 'Đã cảnh cáo $name (-$deductedđ, còn $nextScore/100)'
            : 'Đã gửi nhắc nhở tới $name',
      );
    } catch (e) {
      _snack('Lỗi gửi cảnh cáo: $e', error: true);
    }
  }

  /// Hộp thoại Khôi phục / Điều chỉnh điểm uy tín trực tiếp trong Hồ sơ User (Idea 3).
  Future<void> _showAdjustReputationDialog(Map<String, dynamic> user) async {
    final uid = user['id'] as String;
    final name = (user['displayName'] ?? 'Người dùng').toString();
    final currentScore = _int(user['reputationScore'] ?? user['diemUyTin'], 100);
    final ctrl = TextEditingController();

    // Mặc định: nếu điểm < 100 thì chọn chế độ Khôi phục (+10đ), nếu đang 100 thì chọn Trừ điểm (-5đ)
    var delta = currentScore < 100 ? 10 : -5;
    var lockImmediately = delta < 0 && (currentScore + delta).clamp(0, 100) <= 49;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final nextScore = (currentScore + delta).clamp(0, 100);
          final isRestore = delta >= 0;
          final isCritical = !isRestore && nextScore <= 49;

          void selectDelta(int d) {
            setLocal(() {
              delta = d;
              final updated = (currentScore + d).clamp(0, 100);
              lockImmediately = d < 0 && updated <= 49;
            });
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text(
              'Điều chỉnh & Khôi phục uy tín',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Người dùng: $name',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (currentScore < 100) ...[
                    const Text(
                      'Khôi phục điểm uy tín (tối đa 100đ):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _teal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _penaltyOptionChip(
                          label: '+5đ',
                          selected: delta == 5,
                          color: _teal,
                          onTap: () => selectDelta(5),
                        ),
                        _penaltyOptionChip(
                          label: '+10đ',
                          selected: delta == 10,
                          color: _teal,
                          onTap: () => selectDelta(10),
                        ),
                        _penaltyOptionChip(
                          label: '+20đ',
                          selected: delta == 20,
                          color: _teal,
                          onTap: () => selectDelta(20),
                        ),
                        _penaltyOptionChip(
                          label: 'Khôi phục 100đ',
                          selected: delta == (100 - currentScore),
                          color: _green,
                          onTap: () => selectDelta(100 - currentScore),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  const Text(
                    'Hoặc trừ điểm vi phạm:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _textGrey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _penaltyOptionChip(
                        label: '-5đ (Nhắc nhở)',
                        selected: delta == -5,
                        color: _primary,
                        onTap: () => selectDelta(-5),
                      ),
                      _penaltyOptionChip(
                        label: '-10đ (Cảnh cáo)',
                        selected: delta == -10,
                        color: _orange,
                        onTap: () => selectDelta(-10),
                      ),
                      _penaltyOptionChip(
                        label: '-20đ (Vi phạm nặng)',
                        selected: delta == -20,
                        color: _red,
                        onTap: () => selectDelta(-20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isCritical
                          ? const Color(0xFFFEF3F2)
                          : _pastelBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCritical
                            ? const Color(0xFFFECDCA)
                            : _pastelBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Hiện tại: $currentScore/100',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _textGrey,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: _textGrey,
                            ),
                            Text(
                              'Mới: $nextScore/100',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: nextScore >= 80
                                    ? _teal
                                    : (nextScore > 49 ? _orange : _red),
                              ),
                            ),
                          ],
                        ),
                        if (isCritical) ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => setLocal(
                              () => lockImmediately = !lockImmediately,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: lockImmediately,
                                    activeColor: _red,
                                    onChanged: (v) => setLocal(
                                      () => lockImmediately = v ?? false,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '⚠️ Uy tín ≤ 49đ ($nextScore/100): Gợi ý khóa tài khoản ngay',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _red,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    maxLines: 3,
                    onChanged: (_) => setLocal(() {}),
                    decoration: InputDecoration(
                      hintText: isRestore
                          ? 'Lý do khôi phục uy tín (ví dụ: Đã xác minh nhầm lẫn / khiếu nại hợp lệ)...'
                          : 'Lý do trừ điểm uy tín (bắt buộc)...',
                      hintStyle: const TextStyle(fontSize: 12.5),
                      filled: true,
                      fillColor: _pastelBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _pastelBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _pastelBorder),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: isRestore
                      ? _teal
                      : (lockImmediately ? _red : _orange),
                ),
                onPressed: ctrl.text.trim().isEmpty || nextScore == currentScore
                    ? null
                    : () => Navigator.pop(ctx, {
                        'reason': ctrl.text.trim(),
                        'nextScore': nextScore,
                        'delta': nextScore - currentScore,
                        'lockImmediately': !isRestore && lockImmediately,
                      }),
                child: Text(
                  isRestore
                      ? 'Khôi phục uy tín'
                      : (lockImmediately
                            ? 'Trừ điểm & Khóa TK'
                            : 'Cập nhật điểm'),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return;
    final reason = result['reason'] as String;
    final nextScore = result['nextScore'] as int;
    final effectiveDelta = result['delta'] as int;
    final isRestore = effectiveDelta > 0;
    final lockNow = result['lockImmediately'] == true;

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final userUpdate = <String, dynamic>{
        'reputationScore': nextScore,
        'diemUyTin': nextScore,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (lockNow) {
        userUpdate['isBanned'] = true;
        userUpdate['statusId'] = 2;
        userUpdate['bannedAt'] = FieldValue.serverTimestamp();
        userUpdate['banReason'] = reason;
      }
      batch.set(
        db.collection('users').doc(uid),
        userUpdate,
        SetOptions(merge: true),
      );

      batch.set(db.collection('notifications').doc(), {
        'recipientId': uid,
        'recipientRole': (user['role'] ?? '').toString(),
        'title': isRestore
            ? 'Khôi phục điểm uy tín (+$effectiveDeltađ)'
            : 'Điều chỉnh điểm uy tín ($effectiveDeltađ)',
        'body': '$reason (Điểm uy tín mới: $nextScore/100)',
        'notificationType': isRestore ? 'reputation_restored' : 'warning',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      await _audit(
        isRestore ? 'Khôi phục điểm uy tín' : 'Trừ điểm uy tín',
        'Admin điều chỉnh điểm của "$name": $currentScore ➔ $nextScore/100 (${effectiveDelta > 0 ? '+$effectiveDelta' : '$effectiveDelta'}đ). Lý do: $reason',
        'User $uid',
      );
      _snack(
        isRestore
            ? 'Đã khôi phục uy tín cho $name ($nextScore/100)'
            : 'Đã cập nhật điểm uy tín của $name ($nextScore/100)',
      );
    } catch (e) {
      _snack('Lỗi cập nhật điểm uy tín: $e', error: true);
    }
  }

  Widget _penaltyCheckTile({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : const Color(0xFFE4E7EC),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 20,
                color: selected ? color : const Color(0xFF98A2B3),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? color : _textDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _penaltyOptionChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.14) : _pastelBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : _pastelBorder,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded, size: 14, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? color : _textDark,
              ),
            ),
          ],
        ),
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
      // Luôn lưu trạng thái xử lý vào `reports/{id}` để không vi phạm rule `allow update: if false` của `host_reviews`
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(report['id'] as String)
          .set(
            _reportModerationPayload(
              report,
              status: 'dismissed',
              resolution: 'dismissed',
              adminNote: note,
            ),
            SetOptions(merge: true),
          );
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

  void _openUserDetailById(String uid) {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return;
    final found = _users.where((u) => u['id'] == cleanUid).toList();
    if (found.isNotEmpty) {
      _showUserDetailSheet(found.first);
    }
  }

  void _showUserDetailSheet(Map<String, dynamic> u) {
    final name = (u['displayName'] ?? 'Chưa đặt tên').toString();
    final role = (u['role'] ?? '').toString();
    final isAdmin = _isAdminRole(u);
    final isHost = _isHostRole(u);
    final banned = u['isBanned'] == true;
    final accountDeleted = u['accountDeleted'] == true;
    final userCode = (u['resolvedUserCode'] ?? _resolveUserCode(u)).toString();
    final email = _s(u, ['email']);
    final phone = _s(u, ['phone', 'phoneNumber', 'soDienThoai']);
    final createdAt = _date(u['createdAt']);
    final repScore = _int(u['reputationScore'] ?? u['diemUyTin'], 100);
    final pendingReports = _int(u['pendingReports'], 0);
    final totalReports = _int(u['totalReports'], 0);
    final banReason = _s(u, ['banReason']);

    // Activity Snapshot (Idea 2)
    final avgRating = u['avgRating'] as double?;
    final reviewCount = _int(u['reviewCount'], 0);
    final hostBookingCount = _int(u['hostBookingCount'], 0);
    final renterBookingCount = _int(u['renterBookingCount'], 0);
    final renterCancelledCount = _int(u['renterCancelledCount'], 0);

    // Lịch sử đánh giá & báo cáo (Idea 4)
    final historyItems =
        (u['historyItems'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.86,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0D5DD),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_pastelBg, _pastelBlueSoft],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _pastelBorder),
                  ),
                  child: Row(
                    children: [
                      _avatar(
                        name,
                        banned: banned,
                        avatarUrl: (u['resolvedAvatarUrl'] ?? '').toString(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name.isEmpty ? 'Chưa đặt tên' : name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: _textDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: _pastelBorder),
                                  ),
                                  child: Text(
                                    '#$userCode',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: _primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _chip(_roleLabel(role), _primary),
                                _chip(
                                  'Uy tín: $repScore/100',
                                  repScore >= 80
                                      ? _teal
                                      : (repScore > 49 ? _orange : _red),
                                ),
                                if (!banned && !accountDeleted && repScore <= 49)
                                  _chip('⚠️ Gợi ý khóa TK', _red),
                                if (avgRating != null && reviewCount > 0)
                                  _chip(
                                    '★ ${avgRating.toStringAsFixed(1)} ($reviewCount ĐG)',
                                    avgRating >= 4.0
                                        ? _teal
                                        : (avgRating >= 3.0 ? _orange : _red),
                                  ),
                                if (accountDeleted)
                                  _chip('Đã xóa quyền đăng nhập', _red)
                                else if (banned)
                                  _chip('Đã bị khóa', _red)
                                else
                                  _chip('Đang hoạt động', _green),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _pastelBorder),
                  ),
                  child: Column(
                    children: [
                      _detailRow(
                        Icons.badge_outlined,
                        'Mã định danh',
                        '#$userCode',
                      ),
                      const Divider(height: 16, color: _pastelBorder),
                      _detailRow(
                        Icons.email_outlined,
                        'Email',
                        email.isEmpty ? 'Chưa cập nhật' : email,
                      ),
                      const Divider(height: 16, color: _pastelBorder),
                      _detailRow(
                        Icons.phone_outlined,
                        'Số điện thoại',
                        phone.isEmpty ? 'Chưa cập nhật' : phone,
                      ),
                      const Divider(height: 16, color: _pastelBorder),
                      _detailRow(
                        Icons.calendar_today_outlined,
                        'Ngày tham gia',
                        createdAt == null
                            ? 'Chưa rõ'
                            : _dateFmt.format(createdAt),
                      ),
                      const Divider(height: 16, color: _pastelBorder),
                      _detailRow(
                        Icons.insights_rounded,
                        'Hoạt động giao dịch',
                        isHost
                            ? '$hostBookingCount đơn đặt cọc • $reviewCount lượt đánh giá'
                            : '$renterBookingCount đơn đã đặt • $renterCancelledCount đơn đã hủy',
                        valueColor: !isHost && renterCancelledCount >= 2
                            ? _orange
                            : _textDark,
                      ),
                      const Divider(height: 16, color: _pastelBorder),
                      _detailRow(
                        Icons.flag_outlined,
                        'Phản ánh cần duyệt',
                        '$totalReports phản ánh ($pendingReports đang chờ)',
                      ),
                      if (banned && banReason.isNotEmpty) ...[
                        const Divider(height: 16, color: _pastelBorder),
                        _detailRow(
                          Icons.lock_outline_rounded,
                          'Lý do khóa',
                          banReason,
                          valueColor: _red,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Giấy tờ tùy thân (CCCD)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                      ),
                    ),
                    _chip(
                      _isUserVerified(u) ? 'Đã xác thực' : 'Chưa xác thực',
                      _isUserVerified(u) ? _green : _orange,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildCccdRowButton(
                  label: 'Căn cước mặt trước',
                  icon: Icons.credit_card_rounded,
                  onTap: () => _showCccdImageDialog(u, isFront: true),
                ),
                const SizedBox(height: 8),
                _buildCccdRowButton(
                  label: 'Căn cước mặt sau',
                  icon: Icons.contact_mail_outlined,
                  onTap: () => _showCccdImageDialog(u, isFront: false),
                ),
                // Idea 4: Lịch sử đánh giá & phản ánh gần đây
                if (historyItems.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Lịch sử đánh giá & phản ánh gần đây',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                        ),
                      ),
                      Text(
                        '${historyItems.length} mục',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _textGrey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...historyItems.take(4).map((h) {
                    final hRating = h['rating'] as int?;
                    final hDate = h['createdAtDate'] as DateTime?;
                    final hBookingCode = (h['bookingCode'] ?? '').toString();
                    final hComment = (h['comment'] ?? '').toString();
                    final hReviewer = (h['reviewerName'] ?? 'Ẩn danh').toString();
                    final isLow = hRating != null && hRating <= 2;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isLow
                            ? const Color(0xFFFFFAEB)
                            : _pastelBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isLow
                              ? const Color(0xFFFDE68A)
                              : _pastelBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  hReviewer,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _textDark,
                                  ),
                                ),
                              ),
                              if (hBookingCode.isNotEmpty) ...[
                                _chip('Đơn #$hBookingCode', _primaryDark),
                                const SizedBox(width: 4),
                              ],
                              if (hRating != null)
                                _chip(
                                  '★ $hRating/5',
                                  hRating >= 4
                                      ? _teal
                                      : (hRating == 3 ? _orange : _red),
                                ),
                            ],
                          ),
                          if (hComment.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              hComment,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _textDark,
                              ),
                            ),
                          ],
                          if (hDate != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              _dateFmt.format(hDate),
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: _textGrey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ],
                if (!isAdmin && !accountDeleted) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: repScore < 100 ? _teal : _primaryDark,
                            backgroundColor: _pastelBlueSoft,
                            side: const BorderSide(color: _pastelBorder),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showAdjustReputationDialog(u);
                          },
                          icon: Icon(
                            repScore < 100
                                ? Icons.restore_rounded
                                : Icons.verified_user_outlined,
                            size: 18,
                          ),
                          label: Text(
                            repScore < 100 ? 'Khôi phục UT' : 'Điểm uy tín',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: banned ? _green : _red,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            if (banned) {
                              _unbanUser(u);
                            } else {
                              _banUser(
                                userId: u['id'] as String,
                                userName: name,
                              );
                            }
                          },
                          icon: Icon(
                            banned
                                ? Icons.lock_open_rounded
                                : Icons.lock_outline_rounded,
                            size: 18,
                          ),
                          label: Text(
                            banned ? 'Mở khóa TK' : 'Khóa tài khoản',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _pastelBlueSoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: _primary),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: _textGrey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: valueColor ?? _textDark,
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final cPending = _reports.where((r) => r['status'] == 'pending').length;
    final cHandled = _reports.length - cPending;
    final nonAdminUsers = _users.where((u) => !_isAdminRole(u)).toList();
    final verifiedUsersCount = nonAdminUsers.where(_isUserVerified).length;
    final unverifiedUsersCount = nonAdminUsers
        .where((u) => !_isUserVerified(u) && !_isCccdRejected(u))
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
                hintText: _view == _UsersView.allUsers ||
                        _view == _UsersView.userApprovals
                    ? 'Tìm theo tên, UID, mã CT/NT, số CCCD, email, SĐT...'
                    : 'Tìm theo người bị phản ánh, người gửi, mã đơn, lý do...',
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF98A2B3),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: _primary,
                ),
                filled: true,
                fillColor: _pastelBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _pastelBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _pastelBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _primary, width: 1.3),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _pill(
                    'Duyệt người dùng',
                    unverifiedUsersCount,
                    _UsersView.userApprovals,
                    _primaryDark,
                    Icons.badge_outlined,
                  ),
                  const SizedBox(width: 8),
                  _pill(
                    'Chờ xử lý',
                    cPending,
                    _UsersView.pendingReports,
                    _orange,
                    Icons.pending_actions_rounded,
                  ),
                  const SizedBox(width: 8),
                  _pill(
                    'Đã xử lý',
                    cHandled,
                    _UsersView.handledReports,
                    _teal,
                    Icons.task_alt_rounded,
                  ),
                  const SizedBox(width: 8),
                  _pill(
                    'Người dùng',
                    verifiedUsersCount,
                    _UsersView.allUsers,
                    _primary,
                    Icons.people_alt_outlined,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: _pastelBorder),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _primary),
                  )
                : ValueListenableBuilder<String>(
                    valueListenable: _searchQuery,
                    builder: (context, query, _) => _buildList(query),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _pill(
    String label,
    int count,
    _UsersView view,
    Color color,
    IconData icon,
  ) {
    final selected = _view == view;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _view = view),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints: const BoxConstraints(minWidth: 92),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.11) : _pastelBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : _pastelBorder,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: selected ? color : _textGrey,
                ),
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: selected ? color : _textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : _textGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(String query) {
    if (_view == _UsersView.userApprovals) {
      var items = _users.where((u) {
        if (_isAdminRole(u)) return false;
        if (_isUserVerified(u) || _isCccdRejected(u)) return false;
        return _matches(query, [
          u['displayName'] as String,
          (u['id'] ?? '').toString(),
          (u['resolvedUserCode'] ?? '').toString(),
          _s(u, ['cccdFullName', 'hoTenCccd']),
          _s(u, ['cccdNumber', 'soCccd', 'soGiayTo']),
          _s(u, ['email']),
          _s(u, ['phone', 'phoneNumber']),
        ]);
      }).toList();

      items.sort((a, b) {
        final da = _date(a['createdAt'] ?? a['ngayTao'] ?? a['updatedAt']);
        final db = _date(b['createdAt'] ?? b['ngayTao'] ?? b['updatedAt']);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

      return items.isEmpty
          ? _empty('Không có người dùng chưa xác thực nào')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _userApprovalCard(items[i]),
            );
    }

    if (_view == _UsersView.allUsers) {
      var items = _users.where((u) {
        if (_isAdminRole(u) || !_isUserVerified(u)) return false;
        return _matches(query, [
          u['displayName'] as String,
          (u['resolvedUserCode'] ?? '').toString(),
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
          final s = _int(u['reputationScore'] ?? u['diemUyTin'], 100);
          return s < 80;
        }).toList();
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
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
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
        (r['reportedUserCode'] ?? '').toString(),
        r['reporterDisplay'] as String,
        _s(r, ['shortBookingCode', 'bookingId']),
        _s(r, ['reason']),
        _s(r, ['description', 'detail']),
      ]);
    }).toList();

    if (_reviewStarFilter == 1) {
      items = items
          .where((r) => r['rating'] is int && (r['rating'] as int) <= 2)
          .toList();
    } else if (_reviewStarFilter == 0) {
      items = items.where((r) => r['rating'] == null).toList();
    }

    final hasAnyStarRating = _reports.any((r) => r['rating'] != null);

    return Column(
      children: [
        if (hasAnyStarRating) _buildStarFilterRow(),
        Expanded(
          child: items.isEmpty
              ? _empty(
                  pending
                      ? 'Không có báo cáo hay đánh giá xấu nào đang chờ xử lý 🎉'
                      : 'Chưa có báo cáo nào được xử lý',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (_, i) => _reportCard(items[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildUserMetricsRow() {
    final nonAdmins =
        _users.where((u) => !_isAdminRole(u) && _isUserVerified(u)).toList();
    final total = nonAdmins.length;
    final hosts = nonAdmins.where((u) => _isHostRole(u)).length;
    final renters = nonAdmins.where((u) => _isRenterRole(u)).length;
    final banned = nonAdmins.where((u) => u['isBanned'] == true).length;
    final lowScore = nonAdmins.where((u) {
      final s = _int(u['reputationScore'] ?? u['diemUyTin'], 100);
      return s < 80;
    }).length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_pastelBg, _pastelBlueSoft],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _pastelBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _metricItem('Tổng user', '$total', _primaryDark),
            _metricDivider(),
            _metricItem('Chủ trọ', '$hosts', _teal),
            _metricDivider(),
            _metricItem('Người thuê', '$renters', _primary),
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
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: _textGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _metricDivider() =>
      Container(width: 1, height: 22, color: _pastelBorder);

  Widget _buildUserFiltersRow() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChipItem(
              'Tất cả',
              _userRoleFilter == 'all',
              Icons.groups_outlined,
              (_) => setState(() => _userRoleFilter = 'all'),
            ),
            const SizedBox(width: 6),
            _filterChipItem(
              'Chủ trọ',
              _userRoleFilter == 'host',
              Icons.real_estate_agent_outlined,
              (_) => setState(() => _userRoleFilter = 'host'),
            ),
            const SizedBox(width: 6),
            _filterChipItem(
              'Người thuê',
              _userRoleFilter == 'renter',
              Icons.person_outline_rounded,
              (_) => setState(() => _userRoleFilter = 'renter'),
            ),
            const SizedBox(width: 6),
            _filterChipItem(
              'Bị khóa',
              _userRoleFilter == 'banned',
              Icons.lock_outline_rounded,
              (_) => setState(() => _userRoleFilter = 'banned'),
            ),
            const SizedBox(width: 6),
            _filterChipItem(
              'Uy tín < 80đ',
              _userRoleFilter == 'low_rep',
              Icons.shield_outlined,
              (_) => setState(() => _userRoleFilter = 'low_rep'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChipItem(
    String label,
    bool isSelected,
    IconData icon,
    Function(bool) onSelected,
  ) {
    return ChoiceChip(
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? _primaryDark : _textGrey,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? _primaryDark : _textDark,
      ),
      selected: isSelected,
      selectedColor: _pastelBlueSoft,
      backgroundColor: _pastelBg,
      side: BorderSide(color: isSelected ? _primary : _pastelBorder),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      visualDensity: VisualDensity.compact,
      onSelected: onSelected,
    );
  }

  Widget _buildStarFilterRow() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChipItem(
              'Tất cả phản ánh',
              _reviewStarFilter == null,
              Icons.filter_list_rounded,
              (_) => setState(() => _reviewStarFilter = null),
            ),
            const SizedBox(width: 6),
            _filterChipItem(
              'Đánh giá 1 - 2 ★',
              _reviewStarFilter == 1,
              Icons.warning_amber_rounded,
              (_) => setState(() => _reviewStarFilter = 1),
            ),
            const SizedBox(width: 6),
            _filterChipItem(
              'Báo cáo vi phạm',
              _reviewStarFilter == 0,
              Icons.flag_outlined,
              (_) => setState(() => _reviewStarFilter = 0),
            ),
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
    border: Border.all(color: _pastelBorder),
    boxShadow: [
      BoxShadow(
        color: _primary.withValues(alpha: 0.04),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.11),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
    ),
  );

  final Map<String, Future<Uint8List?>> _storageBytesFutures = {};

  Future<Uint8List?> _fetchFirebaseStorageBytes(String url) {
    return _storageBytesFutures.putIfAbsent(url, () async {
      try {
        return await FirebaseStorage.instance
            .refFromURL(url)
            .getData(5 * 1024 * 1024)
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        return null;
      }
    });
  }

  Widget _avatar(
    String name, {
    bool banned = false,
    String? avatarUrl,
    double radius = 20,
  }) {
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final url = (avatarUrl ?? '').trim();
    final bgColor = banned ? const Color(0xFFFEE4E2) : _pastelBlueSoft;

    Widget fallbackLetter() => Center(
      child: Text(
        letter,
        style: TextStyle(
          fontSize: radius * 0.78,
          fontWeight: FontWeight.w800,
          color: banned ? _red : _primaryDark,
        ),
      ),
    );

    Widget storageSdkFallback(String storageUrl) => FutureBuilder<Uint8List?>(
      future: _fetchFirebaseStorageBytes(storageUrl),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes != null && bytes.isNotEmpty) {
          return Image.memory(
            bytes,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallbackLetter(),
          );
        }
        return fallbackLetter();
      },
    );

    Widget networkCircle(String resolvedUrl) => CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: ClipOval(
        child: Image.network(
          resolvedUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return fallbackLetter();
          },
          errorBuilder: (context, error, stackTrace) {
            if (resolvedUrl.contains('firebasestorage.googleapis.com')) {
              return storageSdkFallback(resolvedUrl);
            }
            return fallbackLetter();
          },
        ),
      ),
    );

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return networkCircle(url);
    }

    if (url.startsWith('data:image')) {
      try {
        final commaIdx = url.indexOf(',');
        if (commaIdx != -1) {
          final bytes = base64Decode(url.substring(commaIdx + 1));
          return CircleAvatar(
            radius: radius,
            backgroundColor: bgColor,
            child: ClipOval(
              child: Image.memory(
                bytes,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallbackLetter(),
              ),
            ),
          );
        }
      } catch (_) {}
    }

    if (url.startsWith('gs://')) {
      return FutureBuilder<String>(
        future: FirebaseStorage.instance.refFromURL(url).getDownloadURL(),
        builder: (context, snapshot) {
          final resolved = snapshot.data;
          if (resolved != null && resolved.isNotEmpty) {
            return networkCircle(resolved);
          }
          return CircleAvatar(
            radius: radius,
            backgroundColor: bgColor,
            child: fallbackLetter(),
          );
        },
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: fallbackLetter(),
    );
  }

  Widget _buildEvidenceImage(
    String rawUrl, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    bool isFullView = false,
  }) {
    final url = rawUrl.trim();

    Widget fallbackBox() => Container(
      width: width,
      height: height ?? (isFullView ? 220 : 54),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(12),
      color: _pastelBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: isFullView ? 36 : 20,
            color: _textGrey,
          ),
          if (isFullView) ...[
            const SizedBox(height: 8),
            const Text(
              'Không tải được ảnh minh chứng trên Firebase.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _textDark,
              ),
            ),
          ],
        ],
      ),
    );

    if (url.startsWith('data:image')) {
      try {
        final commaIdx = url.indexOf(',');
        if (commaIdx != -1) {
          final bytes = base64Decode(url.substring(commaIdx + 1));
          return Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => fallbackBox(),
          );
        }
      } catch (_) {}
      return fallbackBox();
    }

    if (url.startsWith('gs://')) {
      return FutureBuilder<String>(
        future: FirebaseStorage.instance.refFromURL(url).getDownloadURL(),
        builder: (context, snapshot) {
          final resolved = snapshot.data;
          if (resolved != null && resolved.isNotEmpty) {
            return Image.network(
              resolved,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (context, error, stackTrace) => fallbackBox(),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: width,
              height: height ?? (isFullView ? 220 : 54),
              color: _pastelBg,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _primary,
                ),
              ),
            );
          }
          return fallbackBox();
        },
      );
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height ?? (isFullView ? 220 : 54),
            color: _pastelBg,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _primary,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          if (url.contains('firebasestorage.googleapis.com')) {
            return FutureBuilder<Uint8List?>(
              future: _fetchFirebaseStorageBytes(url),
              builder: (context, snap) {
                final bytes = snap.data;
                if (bytes != null && bytes.isNotEmpty) {
                  return Image.memory(
                    bytes,
                    width: width,
                    height: height,
                    fit: fit,
                    errorBuilder: (context, error, stackTrace) => fallbackBox(),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return Container(
                    width: width,
                    height: height ?? (isFullView ? 220 : 54),
                    color: _pastelBg,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _primary,
                      ),
                    ),
                  );
                }
                return fallbackBox();
              },
            );
          }
          return fallbackBox();
        },
      );
    }

    return fallbackBox();
  }

  Widget _buildEvidencePreview(List<dynamic> evidenceUrls) {
    final list = evidenceUrls
        .map((e) => e.toString().trim())
        .where(
          (e) =>
              e.startsWith('http') ||
              e.startsWith('gs://') ||
              e.startsWith('blob:') ||
              e.startsWith('data:'),
        )
        .toList();
    if (list.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Ảnh minh chứng (${list.length}):',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _textGrey,
          ),
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
                borderRadius: BorderRadius.circular(8),
                child: _buildEvidenceImage(
                  list[i],
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showFullImageDialog(String url) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Ảnh minh chứng',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: _textDark,
                      size: 22,
                    ),
                    onPressed: () => Navigator.pop(dialogCtx),
                  ),
                ],
              ),
              const Divider(height: 10, color: _pastelBorder),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 200,
                  maxHeight: 420,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 3.5,
                    child: _buildEvidenceImage(
                      url,
                      fit: BoxFit.contain,
                      isFullView: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reportCard(Map<String, dynamic> r) {
    final pending = r['status'] == 'pending';
    final banned = r['reportedBanned'] == true;
    final name = r['reportedName'] as String;
    final userCode = (r['reportedUserCode'] ?? '').toString();
    final shortBookingCode = _s(r, ['shortBookingCode']);
    final date = r['createdAtDate'] as DateTime?;
    final resolution = _s(r, ['resolution']);
    final penaltyPoints = _intOrNull(r['penaltyPoints']);
    final resolutionLabel = {
      'banned': 'Đã khóa tài khoản',
      'warned': penaltyPoints != null && penaltyPoints > 0
          ? 'Đã cảnh cáo (-$penaltyPointsđ UT)'
          : 'Đã nhắc nhở',
      'dismissed': 'Đã bỏ qua',
    }[resolution];
    final adminNote = _s(r, ['adminNote']);
    final rating = _intOrNull(r['rating']);
    final evidenceUrls =
        (r['evidenceUrls'] is List) ? r['evidenceUrls'] as List : const [];
    final hostScore = _intOrNull(
      r['reportedReputationScore'] ?? r['reputationScore'],
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () =>
                _openUserDetailById((r['reportedUserId'] ?? '').toString()),
            child: Row(
              children: [
                _avatar(
                  name,
                  banned: banned,
                  avatarUrl: (r['reportedAvatarUrl'] ?? '').toString(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _textDark,
                              ),
                            ),
                          ),
                          if (userCode.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: _pastelBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _pastelBorder),
                              ),
                              child: Text(
                                '#$userCode',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _primaryDark,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: _primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if ((r['reportedRole'] as String).isNotEmpty)
                            _chip(
                              _roleLabel(r['reportedRole'] as String),
                              _primary,
                            ),
                          if (rating != null)
                            _chip(
                              '★ $rating/5 sao',
                              rating >= 4
                                  ? _teal
                                  : (rating == 3 ? _orange : _red),
                            ),
                          if (shortBookingCode.isNotEmpty)
                            _chip('Đơn #$shortBookingCode', _primaryDark),
                          if (_s(r, ['postTitle', 'roomTitle']).isNotEmpty)
                            _chip(
                              _s(r, ['targetType']) == 'post'
                                  ? 'Bài đăng: ${_s(r, ['postTitle', 'roomTitle'])}'
                                  : 'Phòng: ${_s(r, ['postTitle', 'roomTitle'])}',
                              _primaryDark,
                            ),
                          if (hostScore != null)
                            _chip(
                              'UT: $hostScore/100',
                              hostScore >= 80
                                  ? _teal
                                  : (hostScore > 49 ? _orange : _red),
                            ),
                          if (!banned && hostScore != null && hostScore <= 49)
                            _chip('⚠️ Gợi ý khóa TK', _red),
                          if (banned) _chip('Đã bị khóa', _red),
                          if (_int(r['totalReports'], 0) > 1)
                            _chip('${r['totalReports']} phản ánh', _orange),
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
                        : (resolution == 'banned' ? _red : _teal),
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
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _s(r, ['reason']).isEmpty
                      ? 'Không nêu lý do'
                      : _s(r, ['reason']),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                if (_s(r, ['description']).isNotEmpty &&
                    _s(r, ['description']) != _s(r, ['reason'])) ...[
                  const SizedBox(height: 4),
                  Text(
                    _s(r, ['description']),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: _textGrey,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (evidenceUrls.isNotEmpty) _buildEvidencePreview(evidenceUrls),
          const SizedBox(height: 8),
          Text(
            'Người gửi: ${r['reporterDisplay']}${date == null ? '' : '  •  ${_dateFmt.format(date)}'}',
            style: const TextStyle(fontSize: 11.5, color: _textGrey),
          ),
          if (!pending && adminNote.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Ghi chú admin: $adminNote',
              style: const TextStyle(
                fontSize: 11.5,
                color: _textGrey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (pending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textGrey,
                      side: const BorderSide(color: _pastelBorder),
                    ),
                    onPressed: () => _dismissReport(r),
                    child: const Text(
                      'Bỏ qua',
                      style: TextStyle(fontSize: 12.5),
                    ),
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
                    child: const Text(
                      'Cảnh cáo',
                      style: TextStyle(fontSize: 12.5),
                    ),
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
                    child: const Text(
                      'Khóa TK',
                      style: TextStyle(fontSize: 12.5),
                    ),
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
    final accountDeleted = u['accountDeleted'] == true;
    final name = u['displayName'] as String;
    final role = (u['role'] ?? '').toString();
    final isAdmin = _isAdminRole(u);
    final isHost = _isHostRole(u);
    final userCode = (u['resolvedUserCode'] ?? _resolveUserCode(u)).toString();
    final contact = [
      _s(u, ['email']),
      _s(u, ['phone', 'phoneNumber']),
    ].where((e) => e.isNotEmpty).join('  •  ');
    final pendingReports = _int(u['pendingReports'], 0);
    final totalReports = _int(u['totalReports'], 0);
    final reputationScore = _int(u['reputationScore'] ?? u['diemUyTin'], 100);

    // Activity Snapshot (Idea 2)
    final avgRating = u['avgRating'] as double?;
    final reviewCount = _int(u['reviewCount'], 0);
    final hostBookingCount = _int(u['hostBookingCount'], 0);
    final renterBookingCount = _int(u['renterBookingCount'], 0);
    final renterCancelledCount = _int(u['renterCancelledCount'], 0);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showUserDetailSheet(u),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDeco,
        child: Row(
          children: [
            _avatar(
              name,
              banned: banned,
              avatarUrl: (u['resolvedAvatarUrl'] ?? '').toString(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
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
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: _pastelBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _pastelBorder),
                        ),
                        child: Text(
                          '#$userCode',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _primaryDark,
                          ),
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
                      _chip(
                        _roleLabel(role),
                        isHost ? _teal : _primary,
                      ),
                      _chip(
                        'Uy tín: $reputationScore',
                        reputationScore <= 49
                            ? _red
                            : (reputationScore < 80 ? _orange : _teal),
                      ),
                      if (!banned && !accountDeleted && reputationScore <= 49)
                        _chip('⚠️ Gợi ý khóa TK', _red),
                      if (isHost && avgRating != null && reviewCount > 0)
                        _chip(
                          '★ ${avgRating.toStringAsFixed(1)} ($reviewCount)',
                          avgRating >= 4.0
                              ? _teal
                              : (avgRating >= 3.0 ? _orange : _red),
                        ),
                      if (isHost && hostBookingCount > 0)
                        _chip('$hostBookingCount đơn cọc', _primaryDark),
                      if (!isHost && renterBookingCount > 0)
                        _chip(
                          renterCancelledCount > 0
                              ? '$renterBookingCount đơn • $renterCancelledCount hủy'
                              : '$renterBookingCount đơn đặt',
                          renterCancelledCount >= 2 ? _orange : _primaryDark,
                        ),
                      if (accountDeleted)
                        _chip('Đã xóa quyền đăng nhập', _red)
                      else if (banned)
                        _chip('Đã bị khóa', _red),
                      if (pendingReports > 0)
                        _chip('$pendingReports chờ xử lý', _orange)
                      else if (totalReports > 0)
                        _chip('$totalReports phản ánh', _textGrey),
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
            if (!isAdmin && !accountDeleted)
              banned
                  ? OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _green,
                        side: const BorderSide(color: _green),
                      ),
                      onPressed: () => _unbanUser(u),
                      child: const Text(
                        'Mở khóa',
                        style: TextStyle(fontSize: 12),
                      ),
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
      ),
    );
  }

  /// Thẻ trong tab "Duyệt người dùng":
  /// - Hàng 1 (trên cùng): Tên người dùng (kèm Avatar thật)
  /// - Hàng 2: UID
  /// - Hàng 3: Căn cước mặt trước (bấm vào mở dialog)
  /// - Hàng 4: Căn cước mặt sau (bấm vào mở dialog)
  Widget _userApprovalCard(Map<String, dynamic> u) {
    final banned = u['isBanned'] == true;
    final uid = (u['id'] ?? u['uid'] ?? '').toString();
    final cccdName = _s(u, ['cccdFullName', 'hoTenCccd', 'ho_ten_cccd']);
    final displayName = _s(u, ['displayName', 'fullName', 'name']);
    final name = cccdName.isNotEmpty
        ? cccdName
        : (displayName.isNotEmpty ? displayName : 'Chưa đặt tên');
    final role = (u['role'] ?? '').toString();
    final isHost = _isHostRole(u);
    final userCode = (u['resolvedUserCode'] ?? _resolveUserCode(u)).toString();
    final avatarUrl = (u['resolvedAvatarUrl'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hàng 1 (trên cùng): Avatar + Tên + Mã + Badge (không tràn trên mobile)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(name, banned: banned, avatarUrl: avatarUrl, radius: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: _pastelBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _pastelBorder),
                          ),
                          child: Text(
                            '#$userCode',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _chip(_roleLabel(role), isHost ? _teal : _primary),
                        _chip('Chưa xác thực', _orange),
                        if ((u['cccdVerificationStatus'] ?? '') == 'rejected')
                          _chip('Đã từ chối', _red),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Hàng 2: UID
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: _pastelBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _pastelBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.fingerprint_rounded,
                  size: 15,
                  color: _primaryDark,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'UID: $uid',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Hàng 3: Căn cước mặt trước
          _buildCccdRowButton(
            label: 'Căn cước mặt trước',
            icon: Icons.credit_card_rounded,
            onTap: () => _showCccdImageDialog(u, isFront: true),
          ),
          const SizedBox(height: 8),

          // Hàng 4: Căn cước mặt sau
          _buildCccdRowButton(
            label: 'Căn cước mặt sau',
            icon: Icons.contact_mail_outlined,
            onTap: () => _showCccdImageDialog(u, isFront: false),
          ),
          const SizedBox(height: 12),

          // Hàng 5: Nút Duyệt / Từ chối (đồng bộ style bên Quản lý bài đăng)
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: uid.isEmpty ? null : () => _approveUserVerification(u),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF398FC0),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '✓ Duyệt',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: uid.isEmpty ? null : () => _rejectUserVerification(u),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFDA29B)),
                    foregroundColor: const Color(0xFFD92D20),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '✕ Từ chối',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _queueCccdNotification({
    required WriteBatch batch,
    required FirebaseFirestore db,
    required Map<String, dynamic> user,
    required String uid,
    required String displayTarget,
    required String title,
    required String body,
    required bool isApproved,
    String reason = '',
  }) {
    final isHost = _isHostRole(user);
    final status = isApproved ? 'approved' : 'rejected';

    if (isHost) {
      batch.set(db.collection('notifications').doc(), {
        'hostId': uid,
        'hostName': displayTarget,
        'title': title,
        'body': body,
        'type': 'cccd_verification',
        'status': status,
        'reason': !isApproved && reason.isNotEmpty ? reason : null,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    batch.set(db.collection('notification_user').doc(), {
      'userId': uid,
      'recipientRole': 'renter',
      'title': title,
      'body': body,
      'type': 'cccd_verification',
      'status': status,
      if (!isApproved && reason.isNotEmpty) 'reason': reason,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _approveUserVerification(Map<String, dynamic> u) async {
    final uid = (u['id'] ?? u['uid'] ?? '').toString().trim();
    if (uid.isEmpty) return;
    final name = _s(u, ['cccdFullName', 'hoTenCccd', 'displayName', 'name']);
    final displayTarget = name.isNotEmpty ? name : uid;

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final isHost = _isHostRole(u);
      final hasReputation =
          u['reputationScore'] != null || u['diemUyTin'] != null;
      batch.set(
        db.collection('users').doc(uid),
        {
          'isCccdVerified': true,
          'cccdVerificationStatus': 'approved',
          'cccdVerifiedAt': FieldValue.serverTimestamp(),
          'cccdRejectReason': FieldValue.delete(),
          'cccdRejectedReason': FieldValue.delete(),
          'cccdRejectedAt': FieldValue.delete(),
          if (isHost && !hasReputation) 'reputationScore': 100,
        },
        SetOptions(merge: true),
      );
      _queueCccdNotification(
        batch: batch,
        db: db,
        user: u,
        uid: uid,
        displayTarget: displayTarget,
        title: 'Xác thực danh tính thành công',
        body: 'Admin đã phê duyệt hồ sơ xác thực CCCD của bạn.',
        isApproved: true,
      );
      await batch.commit();
      await _audit(
        'Duyệt người dùng',
        'Đã phê duyệt xác thực CCCD cho $displayTarget',
        uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã duyệt người dùng $displayTarget!'),
            backgroundColor: _primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi duyệt người dùng: $e')),
        );
      }
    }
  }

  Future<void> _rejectUserVerification(Map<String, dynamic> u) async {
    final uid = (u['id'] ?? u['uid'] ?? '').toString().trim();
    if (uid.isEmpty) return;
    final name = _s(u, ['cccdFullName', 'hoTenCccd', 'displayName', 'name']);
    final displayTarget = name.isNotEmpty ? name : uid;

    var reasonInput = 'Ảnh CCCD chưa rõ hoặc thông tin chưa khớp';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Từ chối duyệt $displayTarget',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _textDark,
          ),
        ),
        content: TextFormField(
          initialValue: reasonInput,
          maxLines: 3,
          onChanged: (value) => reasonInput = value,
          decoration: InputDecoration(
            labelText: 'Lý do từ chối',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận từ chối'),
          ),
        ],
      ),
    );
    final reason = reasonInput.trim().isEmpty
        ? 'Ảnh CCCD chưa rõ hoặc thông tin chưa khớp'
        : reasonInput.trim();
    if (confirmed != true) return;

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.set(
        db.collection('users').doc(uid),
        {
          'isCccdVerified': false,
          'cccdVerificationStatus': 'rejected',
          'cccdRejectReason': reason,
          'cccdRejectedReason': reason,
          'cccdRejectedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _queueCccdNotification(
        batch: batch,
        db: db,
        user: u,
        uid: uid,
        displayTarget: displayTarget,
        title: 'Xác thực CCCD bị từ chối',
        body: 'Hồ sơ xác thực CCCD chưa được duyệt. Lý do: $reason',
        isApproved: false,
        reason: reason,
      );
      await batch.commit();
      await _audit(
        'Từ chối người dùng',
        'Từ chối xác thực CCCD cho $displayTarget: $reason',
        uid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã từ chối hồ sơ của $displayTarget'),
            backgroundColor: _red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi từ chối người dùng: $e')),
        );
      }
    }
  }

  Widget _buildCccdRowButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _pastelBorder, width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _pastelBlueSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: _primaryDark),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
              ),
              const Text(
                'Xem ảnh',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: _primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Dialog hiển thị ảnh Căn cước mặt trước / mặt sau:
  /// - Trên cùng: Thông tin (Tên) + dấu X đóng dialog
  /// - Ở giữa: Ảnh căn cước (Image View)
  /// - Dưới cùng: Button Close
  void _showCccdImageDialog(Map<String, dynamic> u, {required bool isFront}) {
    final cccdName = _s(u, ['cccdFullName', 'hoTenCccd', 'ho_ten_cccd']);
    final displayName = _s(u, ['displayName', 'fullName', 'name']);
    final name = cccdName.isNotEmpty
        ? cccdName
        : (displayName.isNotEmpty ? displayName : 'Người dùng');
    final sideTitle = isFront ? 'Căn cước mặt trước' : 'Căn cước mặt sau';
    final imagePath = isFront
        ? _s(u, [
            'cccdFrontImageUrl',
            'anhMatTruoc',
            'anh_mat_truoc',
            'frontImageUrl',
          ])
        : _s(u, [
            'cccdBackImageUrl',
            'anhMatSau',
            'anh_mat_sau',
            'backImageUrl',
          ]);

    final uid = _s(u, ['uid', 'id']);
    final cccdNumber = _s(u, ['cccdNumber', 'soCccd', 'soGiayTo']);
    final cccdFullName = _s(u, ['cccdFullName', 'hoTenCccd', 'displayName', 'name']);
    final hometown = _s(u, ['cccdHometown', 'hometown', 'queQuanCccd', 'address', 'diaChi']);
    final issueDate = _s(u, ['cccdIssueDate', 'ngayCap']);
    final gender = _s(u, ['gender', 'gioiTinh']);
    final phone = _s(u, ['phoneNumber', 'soDienThoai', 'phone']);
    final email = _s(u, ['email']);
    final roleLabel = _roleLabel(_s(u, ['role', 'vaiTro']));
    final birthDateDt = _date(u['birthDate'] ?? u['ngaySinh']);
    final birthDateStr = birthDateDt != null
        ? DateFormat('dd/MM/yyyy').format(birthDateDt)
        : _s(u, ['birthDate', 'ngaySinh']);

    Future<String> resolvePhotoFuture() async {
      final direct = imagePath.trim();
      if (_isRemoteOrDataImage(direct)) return direct;
      if (uid.isNotEmpty) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('id_verifications')
              .orderBy('createdAt', descending: true)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            final d = snap.docs.first.data();
            final subUrl = isFront
                ? _s(d, [
                    'cccdFrontImageUrl',
                    'frontImageUrl',
                    'anhMatTruoc',
                    'frontUrl',
                  ])
                : _s(d, [
                    'cccdBackImageUrl',
                    'backImageUrl',
                    'anhMatSau',
                    'backUrl',
                  ]);
            if (_isRemoteOrDataImage(subUrl)) return subUrl;
          }
        } catch (_) {}
      }
      return direct;
    }

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header: Thông tin (Tên) + dấu X đóng dialog
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sideTitle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: _textDark,
                      size: 22,
                    ),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
              const Divider(height: 12, color: _pastelBorder),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 4, top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 2. Image View (Ảnh căn cước thật từ Firebase)
                      FutureBuilder<String>(
                        future: resolvePhotoFuture(),
                        builder: (context, snapshot) {
                          final resolvedPath = snapshot.data ?? imagePath;
                          final isLoadingSub =
                              snapshot.connectionState == ConnectionState.waiting &&
                              !_isRemoteOrDataImage(imagePath);
                          return Container(
                            constraints: const BoxConstraints(
                              minHeight: 190,
                              maxHeight: 280,
                            ),
                            decoration: BoxDecoration(
                              color: _pastelBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _pastelBorder,
                                width: 1.2,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: isLoadingSub
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: CircularProgressIndicator(
                                        color: _primary,
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                  )
                                : InteractiveViewer(
                                    minScale: 1.0,
                                    maxScale: 3.5,
                                    child: _buildCccdImageViewContent(
                                      u,
                                      imagePath: resolvedPath,
                                      isFront: isFront,
                                    ),
                                  ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // 3. Thông tin đầy đủ của người dùng & CCCD
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _pastelBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _pastelBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Thông tin xác thực đầy đủ',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: _primaryDark,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _cccdDetailLine(
                              'Họ và tên CCCD',
                              cccdFullName.isNotEmpty ? cccdFullName : name,
                            ),
                            _cccdDetailLine(
                              'Số CCCD',
                              cccdNumber.isNotEmpty ? cccdNumber : 'Chưa cập nhật',
                            ),
                            _cccdDetailLine(
                              'Ngày sinh',
                              birthDateStr.isNotEmpty ? birthDateStr : 'Chưa cập nhật',
                            ),
                            _cccdDetailLine(
                              'Giới tính',
                              gender.isNotEmpty ? gender : 'Chưa cập nhật',
                            ),
                            _cccdDetailLine(
                              'Quê quán / Địa chỉ',
                              hometown.isNotEmpty ? hometown : 'Chưa cập nhật',
                            ),
                            _cccdDetailLine(
                              'Ngày cấp CCCD',
                              issueDate.isNotEmpty ? issueDate : 'Chưa cập nhật',
                            ),
                            _cccdDetailLine(
                              'Số điện thoại',
                              phone.isNotEmpty ? phone : 'Chưa cập nhật',
                            ),
                            _cccdDetailLine(
                              'Email',
                              email.isNotEmpty ? email : 'Chưa cập nhật',
                            ),
                            _cccdDetailLine('Vai trò', roleLabel),
                            _cccdDetailLine(
                              'UID',
                              uid.isNotEmpty ? uid : '—',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 4. Button Close dưới cùng
              Center(
                child: SizedBox(
                  width: 140,
                  height: 42,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isRemoteOrDataImage(String path) {
    final p = path.trim();
    return p.startsWith('http://') ||
        p.startsWith('https://') ||
        p.startsWith('data:image');
  }

  Widget _cccdDetailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _textGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _textDark,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCccdImageViewContent(
    Map<String, dynamic> u, {
    required String imagePath,
    required bool isFront,
  }) {
    final path = imagePath.trim();
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                color: _primary,
                strokeWidth: 2.5,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            _buildMissingFirebasePhotoPlaceholder(
          message: 'Không tải được ảnh từ Firebase Storage.',
          storedValue: path,
        ),
      );
    }

    if (path.startsWith('data:image')) {
      try {
        final commaIdx = path.indexOf(',');
        if (commaIdx != -1) {
          final bytes = base64Decode(path.substring(commaIdx + 1));
          return Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                _buildMissingFirebasePhotoPlaceholder(
              message: 'Ảnh Base64 trên Firestore không hợp lệ.',
            ),
          );
        }
      } catch (_) {}
    }

    if (path.isNotEmpty) {
      return _buildMissingFirebasePhotoPlaceholder(
        message:
            'Chưa có dữ liệu ảnh trên Firestore (hiện chỉ lưu đường dẫn nội bộ trên máy người dùng).',
        storedValue: path,
      );
    }

    return _buildMissingFirebasePhotoPlaceholder(
      message: 'Người dùng chưa có ảnh căn cước trên Firestore.',
    );
  }

  Widget _buildMissingFirebasePhotoPlaceholder({
    required String message,
    String? storedValue,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.image_not_supported_outlined,
              size: 40,
              color: _textGrey,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _textDark,
                height: 1.35,
              ),
            ),
            if (storedValue != null && storedValue.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                storedValue,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: _textGrey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
