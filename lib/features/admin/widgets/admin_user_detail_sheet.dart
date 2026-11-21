import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../data/models/room_model.dart';
import '../../renter/screens/room_detail_screen.dart';

/// Modal chi tiết toàn diện thông tin & quản trị người dùng.
class AdminUserDetailSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback? onUserUpdated;

  const AdminUserDetailSheet({
    super.key,
    required this.user,
    this.onUserUpdated,
  });

  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> user, {
    VoidCallback? onUserUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminUserDetailSheet(
        user: user,
        onUserUpdated: onUserUpdated,
      ),
    );
  }

  @override
  State<AdminUserDetailSheet> createState() => _AdminUserDetailSheetState();
}

class _AdminUserDetailSheetState extends State<AdminUserDetailSheet>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF398FC0);
  static const _textDark = Color(0xFF101828);
  static const _textGrey = Color(0xFF667085);
  static const _red = Color(0xFFD92D20);
  static const _green = Color(0xFF12B76A);
  static const _orange = Color(0xFFF79009);

  late TabController _tabController;
  late Map<String, dynamic> _currentUser;
  bool _isLoading = false;
  Map<String, dynamic>? _bankAccount;

  final DateFormat _dateFmt = DateFormat('dd/MM/yyyy HH:mm');
  final DateFormat _dayFmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _currentUser = Map<String, dynamic>.from(widget.user);
    _tabController = TabController(length: 4, vsync: this);
    _loadExtraData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _uid => (_currentUser['id'] ?? _currentUser['uid'] ?? '').toString();

  bool get _isHost {
    final role = (_currentUser['role'] ?? '').toString().toLowerCase();
    return role == 'host' || role == 'landlord' || role == 'chutro';
  }

  bool get _isAdmin {
    final role = (_currentUser['role'] ?? '').toString().toLowerCase();
    return role == 'admin';
  }

  Future<void> _loadExtraData() async {
    if (_uid.isEmpty) return;
    try {
      // 1. Đồng bộ lại dữ liệu user mới nhất từ Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
      if (userDoc.exists && mounted) {
        final data = Map<String, dynamic>.from(userDoc.data() ?? {});
        data['id'] = userDoc.id;
        setState(() => _currentUser = data);
      }

      // 2. Tải thông tin tài khoản ngân hàng
      final bankDoc = await FirebaseFirestore.instance.collection('bank_accounts').doc(_uid).get();
      if (bankDoc.exists && mounted) {
        setState(() => _bankAccount = bankDoc.data());
      }
    } catch (e) {
      debugPrint('Lỗi tải dữ liệu chi tiết user: $e');
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? _red : _green,
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _audit(String action, String details) {
    return FirebaseFirestore.instance.collection('audit_logs').add({
      'action': action,
      'actor': 'Admin',
      'category': 'nguoiDung',
      'details': details,
      'target': 'User $_uid',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ───────────────────────── Quản trị Thao tác ─────────────────────────

  Future<void> _toggleBan() async {
    final isBanned = _currentUser['isBanned'] == true;
    final name = (_currentUser['displayName'] ?? _currentUser['fullName'] ?? 'Người dùng').toString();

    if (isBanned) {
      // Mở khóa
      final noteCtrl = TextEditingController();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Mở khóa tài khoản?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tài khoản "$name" sẽ được khôi phục quyền truy cập bình thường.'),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  hintText: 'Ghi chú mở khóa (không bắt buộc)...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _green),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Mở khóa'),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance.collection('users').doc(_uid).set({
          'isBanned': false,
          'unbannedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await _audit('Mở khóa tài khoản', 'Admin đã mở khóa "$name". ${noteCtrl.text.trim()}');
        _currentUser['isBanned'] = false;
        widget.onUserUpdated?.call();
        _snack('Đã mở khóa tài khoản thành công!');
      } catch (e) {
        _snack('Lỗi mở khóa: $e', error: true);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      // Khóa tài khoản
      final reasonCtrl = TextEditingController();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Khóa tài khoản?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tài khoản "$name" sẽ bị chặn đăng nhập và mọi hoạt động sẽ bị đình chỉ.'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Lý do khóa tài khoản (bắt buộc)...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _red),
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Khóa tài khoản'),
            ),
          ],
        ),
      );
      if (confirm != true || reasonCtrl.text.trim().isEmpty) return;

      setState(() => _isLoading = true);
      try {
        final reason = reasonCtrl.text.trim();
        await FirebaseFirestore.instance.collection('users').doc(_uid).set({
          'isBanned': true,
          'bannedAt': FieldValue.serverTimestamp(),
          'banReason': reason,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await _audit('Khóa tài khoản', 'Admin khóa "$name". Lý do: $reason');
        _currentUser['isBanned'] = true;
        _currentUser['banReason'] = reason;
        widget.onUserUpdated?.call();
        _snack('Đã khóa tài khoản $name');
      } catch (e) {
        _snack('Lỗi khóa tài khoản: $e', error: true);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _approveCccd() async {
    final name = (_currentUser['displayName'] ?? _currentUser['hoTen'] ?? 'người dùng').toString();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Phê duyệt CCCD?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text('Xác nhận thông tin và ảnh CCCD của "$name" hợp lệ và phê duyệt định danh (eKYC)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Phê duyệt'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final fs = FirebaseFirestore.instance;
      final role = (_currentUser['role'] ?? '').toString().toLowerCase();
      final isHost = role == 'host' || role == 'landlord' || role == 'chutro';
      final existingRep =
          _currentUser['reputationScore'] ?? _currentUser['diemUyTin'];
      await fs.collection('users').doc(_uid).set({
        'isCccdVerified': true,
        'cccdVerificationStatus': 'approved',
        'cccdVerifiedAt': FieldValue.serverTimestamp(),
        if (isHost && existingRep == null) 'reputationScore': 100,
      }, SetOptions(merge: true));

      // Gửi thông báo cho user theo đúng role (renter -> notification_user, host -> notifications)
      final targetCol = isHost ? 'notifications' : 'notification_user';
      final notifRef = fs.collection(targetCol).doc();
      final notifData = {
        'id': notifRef.id,
        'userId': _uid,
        'recipientId': _uid,
        'receiverId': _uid,
        'type': 'cccd_verification_approved',
        'title': 'Xác thực CCCD thành công ✓',
        'body': 'Hồ sơ định danh CCCD của bạn đã được Quản trị viên phê duyệt thành công!',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await notifRef.set(notifData);

      await _audit('Phê duyệt CCCD', 'Admin đã phê duyệt xác thực CCCD cho "$name"');
      _currentUser['isCccdVerified'] = true;
      _currentUser['cccdVerificationStatus'] = 'approved';
      widget.onUserUpdated?.call();
      _snack('Đã phê duyệt CCCD thành công cho $name!');
    } catch (e) {
      _snack('Lỗi phê duyệt: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _rejectCccd() async {
    final name = (_currentUser['displayName'] ?? _currentUser['hoTen'] ?? 'người dùng').toString();
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Từ chối xác thực CCCD?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nhập lý do từ chối hồ sơ CCCD của "$name":'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Ví dụ: Ảnh mờ, bị che góc, không khớp thông tin...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final reason = reasonCtrl.text.trim().isNotEmpty
        ? reasonCtrl.text.trim()
        : 'Ảnh chụp không đạt tiêu chuẩn hoặc thông tin không trùng khớp';

    setState(() => _isLoading = true);
    try {
      final fs = FirebaseFirestore.instance;
      await fs.collection('users').doc(_uid).set({
        'isCccdVerified': false,
        'cccdVerificationStatus': 'rejected',
        'cccdRejectReason': reason,
      }, SetOptions(merge: true));

      // Gửi thông báo cho user theo đúng role (renter -> notification_user, host -> notifications)
      final role = (_currentUser['role'] ?? 'renter').toString().toLowerCase();
      final isHost = role == 'host' || role == 'landlord' || role == 'chutro';
      final targetCol = isHost ? 'notifications' : 'notification_user';
      final notifRef = fs.collection(targetCol).doc();
      final notifData = {
        'id': notifRef.id,
        'userId': _uid,
        'recipientId': _uid,
        'receiverId': _uid,
        'type': 'cccd_verification_rejected',
        'title': 'Yêu cầu xác thực CCCD bị từ chối',
        'body': 'Hồ sơ CCCD của bạn chưa được duyệt. Lý do: $reason. Vui lòng chụp lại ảnh rõ nét.',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await notifRef.set(notifData);

      await _audit('Từ chối CCCD', 'Admin từ chối CCCD của "$name". Lý do: $reason');
      _currentUser['isCccdVerified'] = false;
      _currentUser['cccdVerificationStatus'] = 'rejected';
      widget.onUserUpdated?.call();
      _snack('Đã từ chối hồ sơ CCCD của $name');
    } catch (e) {
      _snack('Lỗi từ chối CCCD: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _adjustReputation() async {
    final currentScore = ((_currentUser['reputationScore'] ?? _currentUser['diemUyTin']) as num?)?.toInt() ?? 100;
    int pointsDelta = 5;
    bool isAdd = true;
    final reasonCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Điều chỉnh điểm Uy tín', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Điểm hiện tại: $currentScore/100 điểm', style: const TextStyle(fontSize: 13, color: _textGrey)),
              const SizedBox(height: 12),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Cộng điểm (+)'),
                    selected: isAdd,
                    selectedColor: const Color(0xFFE8F5E9),
                    onSelected: (val) => setDialogState(() => isAdd = true),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Trừ điểm (-)'),
                    selected: !isAdd,
                    selectedColor: const Color(0xFFFEE4E2),
                    onSelected: (val) => setDialogState(() => isAdd = false),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Số điểm:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: pointsDelta > 1 ? () => setDialogState(() => pointsDelta -= 1) : null,
                  ),
                  Text('$pointsDelta đ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isAdd ? _green : _red)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    onPressed: pointsDelta < 50 ? () => setDialogState(() => pointsDelta += 1) : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Lý do điều chỉnh (khen thưởng, giải quyết khiếu nại...)...',
                  hintStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: isAdd ? _green : _red),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isAdd ? 'Cộng $pointsDelta điểm' : 'Trừ $pointsDelta điểm'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    setState(() => _isLoading = true);

    try {
      final newScore = (isAdd ? currentScore + pointsDelta : currentScore - pointsDelta).clamp(0, 100);
      final reason = reasonCtrl.text.trim().isNotEmpty
          ? reasonCtrl.text.trim()
          : (isAdd ? 'Admin cộng điểm thưởng uy tín' : 'Admin trừ điểm vi phạm uy tín');

      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // Cập nhật users
      batch.set(db.collection('users').doc(_uid), {
        'reputationScore': newScore,
        'diemUyTin': newScore,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Ghi lịch sử vi phạm / điều chỉnh
      final vid = 'UT_${DateTime.now().millisecondsSinceEpoch}';
      batch.set(db.collection('violations').doc(vid), {
        'id': vid,
        'userId': _uid,
        'userName': _currentUser['displayName'] ?? _currentUser['fullName'] ?? '',
        'type': isAdd ? 'bonus' : 'penalty',
        'penaltyPoints': isAdd ? -pointsDelta : pointsDelta,
        'previousScore': currentScore,
        'newScore': newScore,
        'adminNote': reason,
        'violations': [reason],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Gửi thông báo tới user
      final nid = 'TB_${DateTime.now().millisecondsSinceEpoch}';
      final role = (_currentUser['role'] ?? 'renter').toString().toLowerCase();
      final targetCol = (role == 'renter' || role == 'user') ? 'notification_user' : 'notifications';
      batch.set(db.collection(targetCol).doc(nid), {
        'id': nid,
        'recipientId': _uid,
        'receiverId': _uid,
        'userId': _uid,
        'recipientRole': _currentUser['role'] ?? 'renter',
        'title': isAdd ? 'Điểm uy tín được cộng thêm' : 'Cảnh báo: Bị trừ điểm uy tín',
        'body': 'Điểm uy tín của bạn đã thay đổi từ $currentScore sang $newScore/100. Lý do: $reason',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      await _audit('Điều chỉnh uy tín', 'Thay đổi điểm uy tín $_uid: $currentScore ➔ $newScore. Lý do: $reason');

      _currentUser['reputationScore'] = newScore;
      _currentUser['diemUyTin'] = newScore;
      widget.onUserUpdated?.call();
      _snack('Đã cập nhật điểm uy tín thành $newScore/100 điểm');
    } catch (e) {
      _snack('Lỗi điều chỉnh uy tín: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeRole() async {
    final currentRole = (_currentUser['role'] ?? 'renter').toString().toLowerCase();
    String selectedRole = currentRole;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Thay đổi vai trò người dùng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                tileColor: selectedRole == 'renter' ? _primary.withValues(alpha: 0.1) : null,
                leading: Icon(Icons.person_outline, color: selectedRole == 'renter' ? _primary : _textGrey),
                title: const Text('Người thuê (Renter)', style: TextStyle(fontSize: 14)),
                trailing: selectedRole == 'renter' ? const Icon(Icons.check, color: _primary) : null,
                onTap: () => setLocal(() => selectedRole = 'renter'),
              ),
              const SizedBox(height: 6),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                tileColor: selectedRole == 'host' ? const Color(0xFF027A48).withValues(alpha: 0.1) : null,
                leading: Icon(Icons.apartment_rounded, color: selectedRole == 'host' ? const Color(0xFF027A48) : _textGrey),
                title: const Text('Chủ trọ (Host / Landlord)', style: TextStyle(fontSize: 14)),
                trailing: selectedRole == 'host' ? const Icon(Icons.check, color: Color(0xFF027A48)) : null,
                onTap: () => setLocal(() => selectedRole = 'host'),
              ),
              const SizedBox(height: 6),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                tileColor: selectedRole == 'admin' ? _red.withValues(alpha: 0.1) : null,
                leading: Icon(Icons.admin_panel_settings_outlined, color: selectedRole == 'admin' ? _red : _textGrey),
                title: const Text('Quản trị viên (Admin)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _red)),
                trailing: selectedRole == 'admin' ? const Icon(Icons.check, color: _red) : null,
                onTap: () => setLocal(() => selectedRole = 'admin'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _primary),
              onPressed: () => Navigator.pop(ctx, selectedRole),
              child: const Text('Xác nhận đổi'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result == currentRole) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(_uid).set({
        'role': result,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _audit('Đổi vai trò', 'Admin đổi vai trò của $_uid từ $currentRole sang $result');
      _currentUser['role'] = result;
      widget.onUserUpdated?.call();
      _snack('Đã cập nhật vai trò người dùng thành ${_roleLabel(result)}');
    } catch (e) {
      _snack('Lỗi đổi vai trò: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendNotification() async {
    final titleCtrl = TextEditingController(text: 'Thông báo từ Ban Quản Trị HomeShare');
    final msgCtrl = TextEditingController();

    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Gửi thông báo cá nhân', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: 'Tiêu đề thông báo',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: msgCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Nội dung thông báo',
                hintText: 'Nhập nội dung nhắc nhở hoặc hướng dẫn...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _primary),
            onPressed: () {
              if (msgCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Gửi ngay'),
          ),
        ],
      ),
    );

    if (send != true || msgCtrl.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final nid = 'TB_${DateTime.now().millisecondsSinceEpoch}';
      final role = (_currentUser['role'] ?? 'renter').toString().toLowerCase();
      final targetCol = (role == 'renter' || role == 'user') ? 'notification_user' : 'notifications';
      await FirebaseFirestore.instance.collection(targetCol).doc(nid).set({
        'id': nid,
        'recipientId': _uid,
        'receiverId': _uid,
        'userId': _uid,
        'recipientRole': _currentUser['role'] ?? 'renter',
        'title': titleCtrl.text.trim(),
        'message': msgCtrl.text.trim(),
        'body': msgCtrl.text.trim(),
        'notificationType': 'system_admin',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _audit('Gửi thông báo', 'Admin gửi thông báo tới $_uid: ${titleCtrl.text.trim()}');
      _snack('Đã gửi thông báo thành công tới người dùng!');
    } catch (e) {
      _snack('Lỗi gửi thông báo: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = (_currentUser['email'] ?? '').toString().trim();
    if (email.isEmpty) {
      _snack('Người dùng này chưa có email để gửi đặt lại mật khẩu!', error: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Gửi email đặt lại mật khẩu?'),
        content: Text('Hệ thống sẽ gửi liên kết khôi phục mật khẩu đến địa chỉ email:\n\n$email'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gửi email'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      await _audit('Reset mật khẩu', 'Gửi email đặt lại mật khẩu tới $email (UID: $_uid)');
      _snack('Đã gửi email đặt lại mật khẩu tới $email');
    } catch (e) {
      _snack('Lỗi gửi email: $e', error: true);
    }
  }

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'host':
      case 'landlord':
      case 'chutro':
        return 'Chủ trọ';
      case 'admin':
        return 'Quản trị viên';
      case 'renter':
      case 'tenant':
        return 'Người thuê';
      default:
        return role.isEmpty ? 'Người dùng' : role;
    }
  }

  // ───────────────────────── UI RENDER ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final name = (_currentUser['displayName'] ?? _currentUser['fullName'] ?? _currentUser['name'] ?? 'Chưa đặt tên').toString();
    final email = (_currentUser['email'] ?? '').toString();
    final phone = (_currentUser['phoneNumber'] ?? _currentUser['phone'] ?? '').toString();
    final role = (_currentUser['role'] ?? 'renter').toString();
    final isBanned = _currentUser['isBanned'] == true;
    final repScore = ((_currentUser['reputationScore'] ?? _currentUser['diemUyTin']) as num?)?.toInt() ?? 100;
    final avatarUrl = (_currentUser['avatarUrl'] ?? _currentUser['photoUrl'] ?? '').toString();

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFD0D5DD),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header Profile
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                _avatar(name, avatarUrl: avatarUrl, banned: isBanned),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark),
                            ),
                          ),
                          if (isBanned)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE4E2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ĐÃ KHÓA',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _red),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'HOẠT ĐỘNG',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _green),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          _chip(_roleLabel(role), _isAdmin ? _red : (_isHost ? const Color(0xFF027A48) : _primary)),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: _uid));
                              _snack('Đã sao chép ID: $_uid');
                            },
                            child: Row(
                              children: [
                                Text('ID: ${_uid.length > 8 ? '${_uid.substring(0, 8)}...' : _uid}',
                                    style: const TextStyle(fontSize: 11, color: _textGrey)),
                                const SizedBox(width: 2),
                                const Icon(Icons.copy_rounded, size: 12, color: _textGrey),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: _textGrey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Reputation bar card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: repScore >= 80
                    ? [const Color(0xFFECFDF3), const Color(0xFFD1FADF)]
                    : (repScore >= 50
                        ? [const Color(0xFFFFFAEB), const Color(0xFFFEF0C7)]
                        : [const Color(0xFFFEF3F2), const Color(0xFFFEE4E2)]),
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: repScore >= 80
                    ? const Color(0xFFA6F4C5)
                    : (repScore >= 50 ? const Color(0xFFFEDF89) : const Color(0xFFFECDCA)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            repScore >= 80 ? Icons.verified_rounded : Icons.warning_amber_rounded,
                            size: 16,
                            color: repScore >= 80 ? _green : (repScore >= 50 ? _orange : _red),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Điểm uy tín hệ thống: $repScore/100',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: repScore >= 80 ? const Color(0xFF027A48) : (repScore >= 50 ? const Color(0xFFB54708) : _red),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (repScore / 100).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.6),
                          color: repScore >= 80 ? _green : (repScore >= 50 ? _orange : _red),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFD0D5DD)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 14),
                  label: const Text('Chỉnh điểm', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  onPressed: _adjustReputation,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Action Toolbar for Admin
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _actionChip(
                    icon: isBanned ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                    label: isBanned ? 'Mở khóa' : 'Khóa tài khoản',
                    color: isBanned ? _green : _red,
                    onTap: _toggleBan,
                  ),
                  const SizedBox(width: 8),
                  _actionChip(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Đổi vai trò',
                    color: _primary,
                    onTap: _changeRole,
                  ),
                  const SizedBox(width: 8),
                  _actionChip(
                    icon: Icons.notifications_active_outlined,
                    label: 'Gửi thông báo',
                    color: _orange,
                    onTap: _sendNotification,
                  ),
                  const SizedBox(width: 8),
                  _actionChip(
                    icon: Icons.lock_reset_rounded,
                    label: 'Reset mật khẩu',
                    color: const Color(0xFF7C3AED),
                    onTap: _resetPassword,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // TabBar
          TabBar(
            controller: _tabController,
            labelColor: _primary,
            unselectedLabelColor: _textGrey,
            labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            indicatorColor: _primary,
            indicatorWeight: 2.5,
            tabs: const [
              Tab(text: 'Hồ sơ'),
              Tab(text: 'Vi phạm'),
              Tab(text: 'Phòng trọ'),
              Tab(text: 'Đánh giá'),
            ],
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // TabView Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildProfileTab(email, phone),
                      _buildViolationsTab(),
                      _buildRoomsTab(),
                      _buildReviewsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── TAB 1: HỒ SƠ ─────────────────────────

  Widget _buildProfileTab(String email, String phone) {
    final gender = (_currentUser['gender'] ?? _currentUser['gioiTinh'] ?? 'Chưa rõ').toString();
    final hometown = (_currentUser['hometown'] ?? _currentUser['queQuan'] ?? 'Chưa cập nhật').toString();
    final occupation = (_currentUser['occupation'] ?? _currentUser['ngheNghiep'] ?? 'Chưa cập nhật').toString();
    final createdAt = _currentUser['createdAt'] is Timestamp
        ? (_parseDate(_currentUser['createdAt']))
        : null;

    final warningCount = (_currentUser['warningCount'] ?? 0) as int;
    final lastReason = (_currentUser['lastWarningReason'] ?? '').toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('THÔNG TIN LIÊN HỆ & CÁ NHÂN',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _primary, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          _infoTile(Icons.email_outlined, 'Email', email.isNotEmpty ? email : 'Chưa liên kết email'),
          _infoTile(Icons.phone_outlined, 'Số điện thoại', phone.isNotEmpty ? phone : 'Chưa cập nhật SĐT'),
          _infoTile(Icons.person_outline, 'Giới tính', gender),
          _infoTile(Icons.home_outlined, 'Quê quán', hometown),
          _infoTile(Icons.work_outline, 'Nghề nghiệp', occupation),
          if (createdAt != null)
            _infoTile(Icons.calendar_today_outlined, 'Ngày tham gia', _dayFmt.format(createdAt)),

          const SizedBox(height: 16),
          const Text('TÀI KHOẢN NGÂN HÀNG (GIẢI NGÂN / CỌC)',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _primary, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          if (_bankAccount != null && (_bankAccount!['accountNumber'] != null || _bankAccount!['bankName'] != null)) ...[
            _infoTile(Icons.account_balance_outlined, 'Ngân hàng', (_bankAccount!['bankName'] ?? 'Chưa rõ').toString()),
            _infoTile(Icons.credit_card_outlined, 'Số tài khoản', (_bankAccount!['accountNumber'] ?? 'Chưa rõ').toString()),
            _infoTile(Icons.badge_outlined, 'Chủ tài khoản', (_bankAccount!['accountHolder'] ?? 'Chưa rõ').toString()),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: _textGrey),
                  SizedBox(width: 8),
                  Text('Người dùng chưa liên kết tài khoản ngân hàng.', style: TextStyle(fontSize: 12, color: _textGrey)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('XÁC THỰC DANH TÍNH (CCCD / EKYC)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _primary, letterSpacing: 0.5)),
              _buildCccdStatusBadge(),
            ],
          ),
          const SizedBox(height: 8),
          _buildCccdSection(),

          if (warningCount > 0) ...[
            const SizedBox(height: 16),
            const Text('THỐNG KÊ CẢNH CÁO & KỶ LUẬT',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _red, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECDCA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tài khoản đã nhận $warningCount lần cảnh cáo từ BQT.',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _red)),
                  if (lastReason.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Lý do gần nhất: $lastReason',
                        style: const TextStyle(fontSize: 11.5, color: _textDark, height: 1.3)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCccdStatusBadge() {
    final status = (_currentUser['cccdVerificationStatus'] ??
            _currentUser['trangThaiXacMinh'] ??
            (_currentUser['isCccdVerified'] == true ? 'approved' : 'unverified'))
        .toString();
    final isVerified = status == 'approved' || status == 'daXacThuc' || _currentUser['isCccdVerified'] == true;
    final isPending = status == 'pending' || status == 'choDuyet';
    final isRejected = status == 'rejected' || status == 'tuChoi';

    Color bg;
    Color fg;
    String label;

    if (isVerified) {
      bg = const Color(0xFFD1FAE5);
      fg = _green;
      label = 'ĐÃ XÁC THỰC ✓';
    } else if (isPending) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
      label = 'ĐANG CHỜ DUYỆT ⏳';
    } else if (isRejected) {
      bg = const Color(0xFFFEE2E2);
      fg = _red;
      label = 'BỊ TỪ CHỐI ✕';
    } else {
      bg = const Color(0xFFF1F5F9);
      fg = _textGrey;
      label = 'CHƯA XÁC THỰC';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _buildCccdSection() {
    final cccdNumber = (_currentUser['cccdNumber'] ?? _currentUser['soCccd'] ?? _currentUser['soGiayTo'] ?? '').toString();
    final cccdFullName = (_currentUser['cccdFullName'] ?? _currentUser['hoTenCccd'] ?? '').toString();
    final cccdIssueDate = (_currentUser['cccdIssueDate'] ?? _currentUser['ngayCap'] ?? '').toString();
    final cccdHometown = (_currentUser['cccdHometown'] ?? _currentUser['queQuanCccd'] ?? '').toString();
    final frontUrl = (_currentUser['cccdFrontImageUrl'] ?? _currentUser['anhMatTruoc'] ?? '').toString();
    final backUrl = (_currentUser['cccdBackImageUrl'] ?? _currentUser['anhMatSau'] ?? '').toString();

    final status = (_currentUser['cccdVerificationStatus'] ??
            _currentUser['trangThaiXacMinh'] ??
            (_currentUser['isCccdVerified'] == true ? 'approved' : 'unverified'))
        .toString();
    final isPending = status == 'pending' || status == 'choDuyet';

    if (cccdNumber.isEmpty && frontUrl.isEmpty && backUrl.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.shield_outlined, size: 16, color: _textGrey),
            SizedBox(width: 8),
            Text('Người dùng chưa nộp hồ sơ CCCD / eKYC.', style: TextStyle(fontSize: 12, color: _textGrey)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isPending ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0), width: isPending ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cccdNumber.isNotEmpty) _infoTile(Icons.credit_card, 'Số CCCD', cccdNumber),
          if (cccdFullName.isNotEmpty) _infoTile(Icons.person, 'Họ tên CCCD', cccdFullName),
          if (cccdIssueDate.isNotEmpty) _infoTile(Icons.calendar_today, 'Ngày cấp', cccdIssueDate),
          if (cccdHometown.isNotEmpty) _infoTile(Icons.location_on_outlined, 'Quê quán', cccdHometown),

          const SizedBox(height: 10),
          const Text('Ảnh chụp CCCD từ Storage:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _textDark)),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _buildCccdImageThumb(
                  label: 'Mặt trước',
                  imageUrl: frontUrl,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCccdImageThumb(
                  label: 'Mặt sau',
                  imageUrl: backUrl,
                ),
              ),
            ],
          ),

          if (isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _red,
                      side: const BorderSide(color: _red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: _isLoading ? null : _rejectCccd,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Từ chối CCCD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: _isLoading ? null : _approveCccd,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Phê duyệt CCCD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCccdImageThumb({required String label, required String imageUrl}) {
    final hasUrl = imageUrl.isNotEmpty;
    return InkWell(
      onTap: hasUrl ? () => _showImagePreviewDialog(label, imageUrl) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD0D5DD)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            if (hasUrl)
              (imageUrl.startsWith('data:image')
                  ? Image.memory(
                      base64Decode(imageUrl.split(',').last),
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image_outlined, color: _textGrey),
                      ),
                    ))
            else
              const Center(
                child: Icon(Icons.image_not_supported_outlined, color: _textGrey),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(vertical: 3),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePreviewDialog(String title, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              title: Text(title, style: const TextStyle(fontSize: 16)),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxHeight: 450),
              color: Colors.black,
              child: InteractiveViewer(
                child: imageUrl.startsWith('data:image')
                    ? Image.memory(
                        base64Decode(imageUrl.split(',').last),
                        fit: BoxFit.contain,
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image, color: Colors.white, size: 48),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _textGrey),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12.5, color: _textGrey)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textDark),
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  // ───────────────────────── TAB 2: VI PHẠM ─────────────────────────

  Widget _buildViolationsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('violations')
          .where('userId', isEqualTo: _uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text('Không có ghi nhận vi phạm nào 🎉',
                style: TextStyle(fontSize: 13, color: _textGrey)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final pts = (data['penaltyPoints'] as num?)?.toInt() ?? 0;
            final isBonus = pts < 0 || data['type'] == 'bonus';
            final note = (data['adminNote'] ?? data['reason'] ?? '').toString();
            final date = _parseDate(data['createdAt']);
            final violations = (data['violations'] is List) ? (data['violations'] as List) : [];

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isBonus ? const Color(0xFFF6FEF9) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isBonus ? const Color(0xFFB4F3CC) : const Color(0xFFFEDF89)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isBonus ? Icons.add_circle_outline : Icons.warning_amber_rounded,
                          size: 16, color: isBonus ? _green : _orange),
                      const SizedBox(width: 6),
                      Text(
                        isBonus ? 'Thưởng uy tín (+${pts.abs()}đ)' : 'Cảnh cáo vi phạm (-$pts đ)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isBonus ? _green : const Color(0xFFB54708),
                        ),
                      ),
                      const Spacer(),
                      if (date != null)
                        Text(_dateFmt.format(date), style: const TextStyle(fontSize: 11, color: _textGrey)),
                    ],
                  ),
                  if (violations.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: violations.map((v) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFEDF89)),
                        ),
                        child: Text(v.toString(), style: const TextStyle(fontSize: 10.5, color: Color(0xFF92400E))),
                      )).toList(),
                    ),
                  ],
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(note, style: const TextStyle(fontSize: 12, color: _textDark, height: 1.3)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ───────────────────────── TAB 3: PHÒNG TRỌ (CHỦ TRỌ) ─────────────────────────

  Widget _buildRoomsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('host_rooms')
          .where('hostId', isEqualTo: _uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text(
              _isHost ? 'Chủ trọ này chưa đăng bài phòng nào' : 'Người dùng này chưa có bài đăng phòng',
              style: const TextStyle(fontSize: 13, color: _textGrey),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            data['id'] = docs[index].id;
            final title = (data['title'] ?? 'Phòng trọ').toString();
            final price = (data['price'] as num?)?.toDouble() ?? 0.0;
            final address = (data['address'] ?? '').toString();
            final status = (data['status'] ?? 'available').toString();
            final images = (data['images'] is List)
                ? (data['images'] as List).map((e) => e.toString()).toList()
                : <String>[];

            return InkWell(
              onTap: () {
                final room = RoomModel(
                  id: docs[index].id,
                  title: title,
                  description: (data['description'] ?? '').toString(),
                  price: price,
                  deposit: (data['deposit'] as num?)?.toDouble() ?? price,
                  address: address,
                  district: (data['district'] ?? '').toString(),
                  city: (data['city'] ?? '').toString(),
                  area: (data['area'] as num?)?.toDouble() ?? 0.0,
                  roomType: (data['roomType'] ?? 'Phòng trọ').toString(),
                  amenities: const [],
                  images: images,
                  hostId: _uid,
                  hostName: _currentUser['displayName'] ?? '',
                  hostPhone: _currentUser['phoneNumber'] ?? '',
                  status: status,
                  isAvailable: data['isAvailable'] == true,
                  createdAt: DateTime.now(),
                );
                Navigator.push(context, MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room)));
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: images.isNotEmpty
                          ? Image.network(
                              images.first,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 60,
                                height: 60,
                                color: const Color(0xFFE2E8F0),
                                child: const Icon(Icons.broken_image, size: 20, color: _textGrey),
                              ),
                            )
                          : Container(
                              width: 60,
                              height: 60,
                              color: const Color(0xFFE9F5FC),
                              child: const Icon(Icons.apartment_rounded, size: 24, color: _primary),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textDark)),
                          const SizedBox(height: 2),
                          Text('${NumberFormat('#,###', 'vi_VN').format(price)} đ/tháng',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF038048))),
                          if (address.isNotEmpty)
                            Text(address, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: _textGrey)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _textGrey),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ───────────────────────── TAB 4: ĐÁNH GIÁ ─────────────────────────

  Widget _buildReviewsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('host_reviews')
          .where('hostId', isEqualTo: _uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text('Chưa có đánh giá nào cho chủ trọ này',
                style: TextStyle(fontSize: 13, color: _textGrey)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final rating = (data['rating'] as num?)?.toInt() ?? 5;
            final comment = (data['comment'] ?? '').toString();
            final reviewer = (data['reviewerName'] ?? 'Người thuê').toString();
            final date = _parseDate(data['createdAt']);
            final status = (data['status'] ?? 'pending').toString();

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDCEAF5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('⭐ $rating/5 sao',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: rating >= 4 ? _green : (rating >= 3 ? _orange : _red),
                          )),
                      const SizedBox(width: 8),
                      _chip(
                        status == 'pending' ? 'Chờ xử lý' : 'Đã duyệt/xử lý',
                        status == 'pending' ? _orange : _green,
                      ),
                      const Spacer(),
                      if (date != null)
                        Text(_dateFmt.format(date), style: const TextStyle(fontSize: 11, color: _textGrey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    comment.isNotEmpty ? comment : 'Đánh giá $rating sao (không kèm nhận xét).',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textDark),
                  ),
                  const SizedBox(height: 4),
                  Text('Người gửi: $reviewer', style: const TextStyle(fontSize: 11, color: _textGrey)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ───────────────────────── Helpers ─────────────────────────

  Widget _avatar(String name, {required String avatarUrl, bool banned = false}) {
    final letter = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    if (avatarUrl.isNotEmpty &&
        (avatarUrl.startsWith('http') || avatarUrl.startsWith('blob:') || avatarUrl.startsWith('data:'))) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: banned ? const Color(0xFFFEE4E2) : const Color(0xFFE9F5FC),
        backgroundImage: NetworkImage(avatarUrl),
      );
    }
    return CircleAvatar(
      radius: 26,
      backgroundColor: banned ? const Color(0xFFFEE4E2) : const Color(0xFFE9F5FC),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: banned ? _red : _primary,
        ),
      ),
    );
  }

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
}
