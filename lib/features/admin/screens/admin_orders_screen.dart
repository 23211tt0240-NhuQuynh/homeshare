import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../utils/booking_utils.dart';
import '../services/admin_audit_identity.dart';
import '../utils/commission_rate_service.dart';
import '../widgets/admin_branded_title.dart';
import 'cancellation_invoice_screen.dart';
import 'settlement_invoice_screen.dart';

/// Thông tin chủ trọ phục vụ sắp xếp và đồng bộ hostIndex (1, 2, 3...)
class _AdminHostItem {
  final String uid;
  final String name;
  final String cleanName;
  final String phone;
  int? hostIndex;
  DateTime createdAt;
  final List<DocumentReference> refs;
  final List<String> uids;

  _AdminHostItem({
    required this.uid,
    required this.name,
    required this.cleanName,
    this.phone = '',
    this.hostIndex,
    required this.createdAt,
    List<DocumentReference>? refs,
    List<String>? uids,
    DocumentReference? ref,
  })  : refs = refs ?? (ref != null ? [ref] : []),
        uids = uids ?? [uid];
}

/// Lựa chọn lọc theo chủ trọ trong Dropdown: Lọc theo UID duy nhất, an toàn 100% khi trùng tên
class _HostFilterOption {
  final String id;
  final String label;

  const _HostFilterOption({required this.id, required this.label});
}

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Dùng ValueNotifier cho tìm kiếm: KHÔNG gọi setState khi gõ, tránh đứng hình / mất focus trên Flutter Web
  final ValueNotifier<String> _searchQuery = ValueNotifier<String>('');

  String _filter =
      'deposit_paid'; // 'pending', 'deposit_paid', 'completed', 'cancelled'
  String _selectedHostId = 'all';
  DateTime? _selectedDate;

  final currencyFormatter = NumberFormat('#,###', 'vi_VN');

  // Lắng nghe dữ liệu Firestore real-time và cache sẵn trong memory
  StreamSubscription<QuerySnapshot>? _usersSub;
  StreamSubscription<QuerySnapshot>? _bookingsSub;
  StreamSubscription<QuerySnapshot>? _checkinsSub;
  List<QueryDocumentSnapshot> _rawUserDocs = [];
  List<QueryDocumentSnapshot> _rawBookingDocs = [];
  List<QueryDocumentSnapshot> _rawCheckinDocs = [];

  // Dữ liệu đã parse sẵn để UI đọc tức thì, không tính toán lại mỗi frame
  List<Map<String, dynamic>> _allOrders = [];
  List<_HostFilterOption> _hostFilterOptions = [
    const _HostFilterOption(id: 'all', label: 'Tất cả chủ trọ'),
  ];
  bool _isLoading = true;

  // Quản lý đồng bộ hostIndex lên Firestore
  Set<String> _syncedHostUids = <String>{};
  Set<String> _syncedBookingIds = <String>{};
  bool _isSyncingHostData = false;

  Future<void> _pickReconciliationDate() async {
    var draftDate = _selectedDate ?? DateTime.now();
    var clearReconciliation = false;
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: StatefulBuilder(
          builder: (context, setDialogState) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chọn ngày đối soát',
                        style: TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        DateFormat('EEE, MMM d').format(draftDate),
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 32,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                CalendarDatePicker(
                  initialDate: draftDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  onDateChanged: (date) {
                    setDialogState(() => draftDate = date);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          clearReconciliation = true;
                          Navigator.pop(dialogContext);
                        },
                        child: const Text('Hủy đối soát'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(dialogContext, draftDate),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted && (clearReconciliation || selected != null)) {
      setState(() => _selectedDate = clearReconciliation ? null : selected);
    }
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      _searchQuery.value = _searchCtrl.text;
    });
    _initFirestore();
  }

  void _initFirestore() {
    _usersSub = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snap) {
          _rawUserDocs = snap.docs;
          _recalculateOrders();
        }, onError: (err) => debugPrint('Lỗi tải users: $err'));

    _bookingsSub = FirebaseFirestore.instance
        .collection('bookings')
        .snapshots()
        .listen(
          (snap) {
            _rawBookingDocs = snap.docs;
            _isLoading = false;
            _recalculateOrders();
          },
          onError: (err) {
            debugPrint('Lỗi tải bookings: $err');
            if (mounted) setState(() => _isLoading = false);
          },
        );

    _checkinsSub = FirebaseFirestore.instance
        .collection('checkins')
        .snapshots()
        .listen((snap) {
          _rawCheckinDocs = snap.docs;
          _recalculateOrders();
        }, onError: (err) => debugPrint('Lỗi tải checkins: $err'));
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    _bookingsSub?.cancel();
    _checkinsSub?.cancel();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _searchQuery.dispose();
    super.dispose();
  }

  /// Hàm loại bỏ dấu tiếng Việt để tìm kiếm không dấu / có dấu đều ra kết quả
  static String _removeAccents(String s) {
    var str = s.toLowerCase();
    const a = 'áàảãạăắằẳẵặâấầẩẫậ';
    const d = 'đ';
    const e = 'éèẻẽẹêếềểễệ';
    const i = 'íìỉĩị';
    const o = 'óòỏõọôốồổỗộơớờởỡợ';
    const u = 'úùủũụưứừửữự';
    const y = 'ýỳỷỹỵ';

    for (var c in a.split('')) {
      str = str.replaceAll(c, 'a');
    }
    str = str.replaceAll(d, 'd');
    for (var c in e.split('')) {
      str = str.replaceAll(c, 'e');
    }
    for (var c in i.split('')) {
      str = str.replaceAll(c, 'i');
    }
    for (var c in o.split('')) {
      str = str.replaceAll(c, 'o');
    }
    for (var c in u.split('')) {
      str = str.replaceAll(c, 'u');
    }
    for (var c in y.split('')) {
      str = str.replaceAll(c, 'y');
    }
    return str.trim();
  }

  /// Kiểm tra đơn hàng có khớp với từ khóa tìm kiếm (hỗ trợ có dấu, không dấu, viết hoa/thường)
  static bool _matchesQuery(Map<String, dynamic> item, String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return true;

    final qNoAccent = _removeAccents(rawQuery);

    final candidates = [
      item['orderCode'],
      item['rawOrderCode'],
      item['transferNote'],
      item['userCode'],
      item['renterName'],
      item['renterPhone'],
      item['roomTitle'],
      item['hostName'],
      item['id'],
      item['deposit'],
      item['formattedDeposit'],
      item['note'],
      item['subTag'],
      item['deadline'],
    ];

    for (final c in candidates) {
      if (c == null) continue;
      final str = c.toString().toLowerCase();
      if (str.contains(q)) return true;
      final strNoAccent = _removeAccents(str);
      if (strNoAccent.contains(qNoAccent)) return true;
    }

    return false;
  }

  /// Sinh mã hiển thị: <tiết đầu tố>-<4 ký tự đuôi trên mã đơn> (ví dụ: 1-KbE1), không cần lưu orderCode trên Firestore.
  String _formatShortOrderCode(
    String hostPrefix,
    Map<String, dynamic> data,
    String docId,
  ) {
    final suffix = BookingUtils.shortCode(data, docId);
    return '$hostPrefix-$suffix';
  }

  /// Tính toán định dạng thời gian / hạn hiển thị chuẩn xác theo từng loại đơn
  String _formatOrderTimeInfo(Map<String, dynamic> data, String tab) {
    if (tab == 'cancelled') {
      final cancelledAt =
          asDateTime(data['cancelledAt']) ??
          asDateTime(data['ngayHuy']) ??
          asDateTime(data['updatedAt']) ??
          asDateTime(data['createdAt']);
      if (cancelledAt != null) {
        return 'Hủy: ${DateFormat('dd/MM').format(cancelledAt)}';
      }
      return 'Đã hủy';
    } else if (tab == 'pending') {
      // 1. Kiểm tra nếu có trường thời hạn chót kiểu Timestamp / DateTime / chuỗi
      final deadlineDt =
          asDateTime(data['deadline']) ??
          asDateTime(data['hanChuyen']) ??
          asDateTime(data['expireAt']) ??
          asDateTime(data['expiresAt']);
      if (deadlineDt != null) {
        final now = DateTime.now();
        final diff = deadlineDt.difference(now);
        if (diff.isNegative) {
          return 'Hạn: Quá hạn';
        }
        if (diff.inMinutes < 60) {
          return 'Hạn: Còn ${diff.inMinutes}p';
        }
        if (diff.inHours < 24) {
          return 'Hạn: ${DateFormat('HH:mm').format(deadlineDt)}';
        }
        return 'Hạn: ${DateFormat('HH:mm dd/MM').format(deadlineDt)}';
      }

      // 2. Kiểm tra nếu có chuỗi mô tả thời gian (ví dụ durationText: "Còn 14:59")
      final durationText = (data['durationText'] ?? '').toString().trim();
      if (durationText.isNotEmpty &&
          durationText != '—' &&
          !durationText.contains('Timestamp(')) {
        return durationText.startsWith('Hạn')
            ? durationText
            : 'Hạn: $durationText';
      }

      final rawDeadline = (data['deadline'] ?? data['hanChuyen'] ?? '')
          .toString()
          .trim();
      if (rawDeadline.isNotEmpty &&
          rawDeadline != '—' &&
          !rawDeadline.contains('Timestamp(')) {
        return rawDeadline.startsWith('Hạn')
            ? rawDeadline
            : 'Hạn: $rawDeadline';
      }

      // 3. Fallback: Dùng createdAt + 15 phút đếm ngược
      final createdAt =
          asDateTime(data['createdAt']) ?? asDateTime(data['ngayTao']);
      if (createdAt != null) {
        final expireTime = createdAt.add(const Duration(minutes: 15));
        final diff = expireTime.difference(DateTime.now());
        if (diff.isNegative) {
          return 'Hạn: Quá hạn';
        }
        return 'Hạn: Còn ${diff.inMinutes}p';
      }
      return 'Hạn: Còn 15p';
    } else {
      // Đơn Đã cọc / Đã trả hết: ưu tiên thời gian tạo đơn, không hiển thị "Hẹn vào"
      final createdAt =
          asDateTime(data['createdAt']) ?? asDateTime(data['ngayTao']);
      if (createdAt != null) {
        return DateFormat('dd/MM/yyyy HH:mm').format(createdAt);
      }

      final checkIn =
          asDateTime(data['checkInDate']) ??
          asDateTime(data['ngayNhanPhong']) ??
          asDateTime(data['checkIn']) ??
          asDateTime(data['moveInDate']);
      if (checkIn != null) {
        return 'Hẹn vào: ${DateFormat('dd/MM/yyyy').format(checkIn)}';
      }

      final rawCheckIn =
          (data['checkInDate'] ??
                  data['ngayNhanPhong'] ??
                  data['checkIn'] ??
                  data['moveInDate'] ??
                  '')
              .toString()
              .trim();
      if (rawCheckIn.isNotEmpty &&
          rawCheckIn != '—' &&
          !rawCheckIn.contains('Timestamp(')) {
        return rawCheckIn.startsWith('Hẹn vào')
            ? rawCheckIn
            : 'Hẹn vào: $rawCheckIn';
      }

      return 'Chờ nhận phòng';
    }
  }

  /// Hàm dọn sạch tiền tố số/gạch nối bị lặp ở tên chủ trọ
  static String _sanitizeHostName(String name) {
    var s = name.trim();
    while (RegExp(r'^\d+[\s\-\–\—\.]*').hasMatch(s)) {
      final next = s.replaceFirst(RegExp(r'^\d+[\s\-\–\—\.]*'), '').trim();
      if (next == s || next.isEmpty) break;
      s = next;
    }
    return s.isEmpty ? 'Chủ trọ' : s;
  }

  /// Tự động đồng bộ hostIndex chưa có cho các chủ trọ lên Firestore
  Future<void> _autoSyncHostsToFirestore(
    List<_AdminHostItem> hosts, {
    required int nextCounterValue,
  }) async {
    if (_isSyncingHostData || hosts.isEmpty) return;
    _isSyncingHostData = true;
    try {
      final batch = FirebaseFirestore.instance.batch();
      var count = 0;
      for (final host in hosts) {
        for (final uid in host.uids) {
          if (_syncedHostUids.contains(uid)) continue;
          _syncedHostUids.add(uid);
          final ref = FirebaseFirestore.instance.collection('users').doc(uid);
          batch.set(ref, {
            'hostIndex': host.hostIndex,
          }, SetOptions(merge: true));
          count++;
        }
      }
      if (count > 0) {
        final counterRef = FirebaseFirestore.instance
            .collection('counters')
            .doc('hostIndex');
        batch.set(counterRef, {
          'next': nextCounterValue,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await batch.commit();
        debugPrint('AdminOrdersScreen: Đã tự động đồng bộ hostIndex cho $count chủ trọ lên Firestore (next=$nextCounterValue)');
      }
    } catch (e) {
      debugPrint('AdminOrdersScreen: Lỗi auto-sync hosts: $e');
    } finally {
      _isSyncingHostData = false;
    }
  }

  /// Tự động đồng bộ hostIndex và orderCode vào các booking cũ
  Future<void> _autoSyncBookingsToFirestore(Map<String, Map<String, dynamic>> updates) async {
    if (updates.isEmpty) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      var count = 0;
      for (final entry in updates.entries) {
        if (_syncedBookingIds.contains(entry.key)) continue;
        _syncedBookingIds.add(entry.key);
        batch.set(
          FirebaseFirestore.instance.collection('bookings').doc(entry.key),
          entry.value,
          SetOptions(merge: true),
        );
        count++;
        if (count >= 400) break; // Giới hạn tối đa 500 writes/batch của Firestore
      }
      if (count > 0) {
        await batch.commit();
        debugPrint('AdminOrdersScreen: Đã tự động đồng bộ hostIndex cho $count đơn booking lên Firestore');
      }
    } catch (e) {
      debugPrint('AdminOrdersScreen: Lỗi auto-sync bookings: $e');
    }
  }

  /// Nút bấm đồng bộ thủ công cho Admin: Quét và ghi trực tiếp lên Firebase
  Future<void> _manualSyncAllHostIndexes() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đang quét và đồng bộ hostIndex & orderCode lên Firebase...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final db = FirebaseFirestore.instance;

      // 1. Quét toàn bộ chủ trọ từ collection 'users' theo từng UID riêng biệt
      final userSnap = await db.collection('users').get();
      final Map<String, _AdminHostItem> hostMapByUid = {};

      for (final doc in userSnap.docs) {
        final d = doc.data();
        final role = (d['role'] ?? '').toString().toLowerCase().trim();
        if (role == 'host' || role == 'landlord' || role == 'chutro') {
          final hName = (d['fullName'] ?? d['displayName'] ?? d['name'] ?? d['hostName'] ?? '').toString().trim();
          if (hName.isEmpty || hName == 'Tất cả chủ trọ') continue;

          final cleanName = _sanitizeHostName(hName);
          final createdAt = asDateTime(d['createdAt']) ?? asDateTime(d['ngayTao']) ?? DateTime(2020);
          final existingIndex = (d['hostIndex'] as num?)?.toInt();

          hostMapByUid[doc.id] = _AdminHostItem(
            uid: doc.id,
            name: hName,
            cleanName: cleanName,
            phone: (d['phoneNumber'] ?? d['phone'] ?? '').toString().trim(),
            hostIndex: existingIndex,
            createdAt: createdAt,
            ref: doc.reference,
          );
        }
      }

      // 2. Sắp xếp danh sách chủ trọ theo thời gian tạo tăng dần và cấp số 1, 2, 3, 4, 5... dứt khoát
      final uniqueHosts = hostMapByUid.values.toList();
      uniqueHosts.sort((a, b) {
        final c = a.createdAt.compareTo(b.createdAt);
        return c != 0 ? c : a.cleanName.compareTo(b.cleanName);
      });

      final Map<String, int> hostIndexByUid = {};
      final Map<String, int> hostIndexByName = {};
      var hostUpdates = 0;

      WriteBatch hostBatch = db.batch();
      var hostBatchCount = 0;

      for (var i = 0; i < uniqueHosts.length; i++) {
        final assignedIndex = i + 1; // 1, 2, 3, 4, 5... chuẩn xác 100% không trùng lặp
        final host = uniqueHosts[i];
        host.hostIndex = assignedIndex;
        hostIndexByUid[host.uid] = assignedIndex;
        hostIndexByName[host.cleanName] = assignedIndex;
        hostIndexByName[host.name] = assignedIndex;

        for (final ref in host.refs) {
          hostBatch.set(ref, {'hostIndex': assignedIndex}, SetOptions(merge: true));
          hostUpdates++;
          hostBatchCount++;
          if (hostBatchCount >= 400) {
            await hostBatch.commit();
            hostBatch = db.batch();
            hostBatchCount = 0;
          }
        }
      }

      hostBatch.set(db.collection('counters').doc('hostIndex'), {
        'next': uniqueHosts.length + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      hostBatchCount++;

      if (hostBatchCount > 0) {
        await hostBatch.commit();
      }

      // 3. Quét bookings và cập nhật hostIndex theo đúng chỉ số chủ trọ (xóa orderCode thừa trên Firestore)
      final bookingSnap = await db.collection('bookings').get();
      var bookingUpdates = 0;
      WriteBatch bookingBatch = db.batch();
      var bookingBatchCount = 0;

      for (final doc in bookingSnap.docs) {
        final d = doc.data();
        final hId = (d['hostId'] ?? d['landlordId'] ?? d['ownerId'] ?? d['chuNhaId'] ?? d['hostUid'] ?? '').toString().trim();
        final rawHName = (d['hostName'] ?? d['tenChuNha'] ?? '').toString().trim();
        final cleanHName = _sanitizeHostName(rawHName);

        final idx = hostIndexByUid[hId] ?? hostIndexByName[cleanHName] ?? hostIndexByName[rawHName] ?? 1;

        if (d['hostIndex'] != idx || d.containsKey('orderCode')) {
          bookingBatch.set(doc.reference, {
            'hostIndex': idx,
            if (d.containsKey('orderCode')) 'orderCode': FieldValue.delete(),
          }, SetOptions(merge: true));
          bookingUpdates++;
          bookingBatchCount++;
          if (bookingBatchCount >= 400) {
            await bookingBatch.commit();
            bookingBatch = db.batch();
            bookingBatchCount = 0;
          }
        }
      }

      if (bookingBatchCount > 0) {
        await bookingBatch.commit();
      }

      _syncedHostUids = <String>{};
      _syncedBookingIds = <String>{};
      _recalculateOrders();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã đồng bộ xong! ($hostUpdates chủ trọ, $bookingUpdates đơn đã lưu lên Firebase)'),
            backgroundColor: const Color(0xFF12B76A),
          ),
        );
      }
    } catch (e) {
      debugPrint('Lỗi đồng bộ Firebase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi đồng bộ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Parse dữ liệu từ snapshot thành danh sách hoàn chỉnh (Chỉ chạy khi Firestore có event mới)
  void _recalculateOrders() {
    final Map<String, String> hostPrefixById = {};
    final Map<String, String> hostPrefixMap = {};
    final Map<String, String> hostOnlyPrefixMap = {};
    final Map<String, int> hostIndexById = {};
    final Map<String, int> hostIndexByName = {};
    final Map<String, String> userNamesById = {};

    String extractBookingHostId(Map<String, dynamic> map) {
      return (map['hostId'] ??
              map['landlordId'] ??
              map['hostUserId'] ??
              map['landlordUserId'] ??
              map['ownerId'] ??
              map['propertyOwnerId'] ??
              map['chuNhaId'] ??
              '')
          .toString()
          .trim();
    }

    // Quét trước tên chủ trọ từ 'bookings' làm fallback nếu 'users' chưa có fullName
    final Map<String, String> bookingHostNamesById = {};
    for (final bDoc in _rawBookingDocs) {
      final bData = bDoc.data() as Map<String, dynamic>? ?? {};
      final bHostId = extractBookingHostId(bData);
      final bHName = (bData['hostName'] ?? bData['tenChuNha'] ?? '').toString().trim();
      if (bHostId.isNotEmpty && bHName.isNotEmpty && bHName != 'Tất cả chủ trọ') {
        bookingHostNamesById[bHostId] = _sanitizeHostName(bHName);
      }
    }

    // 1. Quét tên từ 'users' (đồng thời lưu map uid -> tên mới nhất)
    for (final uDoc in _rawUserDocs) {
      final uData = uDoc.data() as Map<String, dynamic>? ?? {};
      final hName = (uData['fullName'] ??
              uData['displayName'] ??
              uData['name'] ??
              uData['hostName'] ??
              '')
          .toString()
          .trim();
      if (hName.isNotEmpty && hName != 'Tất cả chủ trọ') {
        userNamesById[uDoc.id] = hName;
      }
    }

    // 2. Thu thập danh sách chủ trọ từ 'users' (quản lý theo UID duy nhất để chống nhầm lẫn khi trùng tên)
    final Map<String, _AdminHostItem> hostMapByUid = {};
    final List<({DocumentReference ref, bool isGhost})> invalidRenterRefs = [];

    for (final uDoc in _rawUserDocs) {
      final uData = uDoc.data() as Map<String, dynamic>? ?? {};
      final role = (uData['role'] ?? uData['vaiTro'] ?? '').toString().toLowerCase().trim();
      if (role == 'host' || role == 'landlord' || role == 'chutro' || role == 'chu_tro') {
        var hName = (uData['fullName'] ??
                uData['displayName'] ??
                uData['name'] ??
                uData['hostName'] ??
                bookingHostNamesById[uDoc.id] ??
                (uData['phoneNumber'] != null && uData['phoneNumber'].toString().trim().isNotEmpty
                    ? 'Chủ trọ ${uData['phoneNumber']}'
                    : 'Chủ trọ ${uDoc.id.substring(0, 4)}'))
            .toString()
            .trim();
        if (hName.isEmpty || hName == 'Tất cả chủ trọ') {
          hName = (uData['phoneNumber'] != null && uData['phoneNumber'].toString().trim().isNotEmpty)
              ? 'Chủ trọ ${uData['phoneNumber']}'
              : 'Chủ trọ ${uDoc.id.substring(0, 4)}';
        }

        final cleanName = _sanitizeHostName(hName);
        int? existingIndex = (uData['hostIndex'] as num?)?.toInt();
        if (existingIndex == null && uData['hostIndex'] is String) {
          existingIndex = int.tryParse(uData['hostIndex'] as String);
        }

        final phone = (uData['phoneNumber'] ?? uData['phone'] ?? '').toString().trim();
        final createdAt = asDateTime(uData['createdAt']) ??
            asDateTime(uData['ngayTao']) ??
            DateTime(2020);

        hostMapByUid[uDoc.id] = _AdminHostItem(
          uid: uDoc.id,
          name: hName,
          cleanName: cleanName,
          phone: phone,
          hostIndex: existingIndex,
          createdAt: createdAt,
          ref: uDoc.reference,
        );
      } else {
        // Tài khoản renter hoặc document rác bị dính hostIndex
        if (uData.containsKey('hostIndex') && !_syncedHostUids.contains('del_${uDoc.id}')) {
          final isGhostDoc = !uData.containsKey('role') && !uData.containsKey('email') && !uData.containsKey('phoneNumber');
          invalidRenterRefs.add((ref: uDoc.reference, isGhost: isGhostDoc));
        }
      }
    }

    // Tự động làm sạch Firestore: Xóa doc ma hoặc xóa trường hostIndex thừa trên renter
    if (invalidRenterRefs.isNotEmpty) {
      for (final item in invalidRenterRefs) {
        _syncedHostUids.add('del_${item.ref.id}');
        if (item.isGhost) {
          item.ref.delete().catchError((_) {}); // Xóa hẳn document rác
        } else {
          item.ref.update({'hostIndex': FieldValue.delete()}).catchError((_) {}); // Xóa field thừa của renter
        }
      }
    }

    // 3. Quét liên kết từ 'bookings': gán vào chủ trọ có sẵn trong 'users', không sinh thêm chủ trọ ảo
    for (final bDoc in _rawBookingDocs) {
      final bData = bDoc.data() as Map<String, dynamic>? ?? {};
      final bHostId = extractBookingHostId(bData);
      final profileName = bHostId.isNotEmpty ? (userNamesById[bHostId] ?? '') : '';
      final rawHName = profileName.isNotEmpty
          ? profileName
          : (bData['hostName'] ?? bData['tenChuNha'] ?? '').toString().trim();
      if (rawHName.isEmpty || rawHName == 'Tất cả chủ trọ') continue;

      final cleanName = _sanitizeHostName(rawHName);

      // Nếu đơn có bHostId nằm trong users, thêm alias nếu cần
      if (bHostId.isNotEmpty && hostMapByUid.containsKey(bHostId)) {
        continue;
      }

      // Nếu không khớp bHostId nhưng cleanName khớp với 1 chủ trọ trong users -> gộp vào chủ trọ đó
      final matchingHost = hostMapByUid.values.firstWhere(
        (h) => h.cleanName.toLowerCase() == cleanName.toLowerCase() ||
               h.name.toLowerCase() == rawHName.toLowerCase(),
        orElse: () => _AdminHostItem(
          uid: '',
          name: '',
          cleanName: '',
          createdAt: DateTime(2020),
        ),
      );

      if (matchingHost.uid.isNotEmpty) {
        if (bHostId.isNotEmpty && !matchingHost.uids.contains(bHostId)) {
          matchingHost.uids.add(bHostId);
        }
      }
    }

    // 4. Đánh số hostIndex tuần tự 1, 2, 3, 4... chuẩn xác 100% không trùng lặp
    final uniqueHosts = hostMapByUid.values.toList();
    uniqueHosts.sort((a, b) {
      final c = a.createdAt.compareTo(b.createdAt);
      return c != 0 ? c : a.cleanName.compareTo(b.cleanName);
    });

    final List<_AdminHostItem> hostsNeedSync = [];
    for (var i = 0; i < uniqueHosts.length; i++) {
      final assignedIndex = i + 1; // Đánh số 1, 2, 3, 4... dứt khoát không bao giờ trùng
      if (uniqueHosts[i].hostIndex != assignedIndex) {
        uniqueHosts[i].hostIndex = assignedIndex;
        hostsNeedSync.add(uniqueHosts[i]);
      }
    }

    // Tự động đồng bộ hostIndex chuẩn hóa lên Firestore 'users' & cập nhật counters/hostIndex.next
    final int nextCounterValue = uniqueHosts.length + 1;
    if (hostsNeedSync.isNotEmpty && !_isSyncingHostData) {
      _autoSyncHostsToFirestore(hostsNeedSync, nextCounterValue: nextCounterValue);
    } else if (uniqueHosts.isNotEmpty &&
        !_syncedHostUids.contains('counter_next_$nextCounterValue')) {
      _syncedHostUids.add('counter_next_$nextCounterValue');
      FirebaseFirestore.instance
          .collection('counters')
          .doc('hostIndex')
          .set({
            'next': nextCounterValue,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .catchError((_) {});
    }

    // 5. Sắp xếp danh sách chủ trọ theo hostIndex tăng dần để hiển thị Dropdown
    uniqueHosts.sort((a, b) => (a.hostIndex ?? 9999).compareTo(b.hostIndex ?? 9999));

    final List<_HostFilterOption> filterOptions = [
      const _HostFilterOption(id: 'all', label: 'Tất cả chủ trọ'),
    ];

    // Đếm số lần xuất hiện của cleanName để biết có chủ trọ nào trùng tên không
    final Map<String, int> nameOccurrences = {};
    for (final host in uniqueHosts) {
      nameOccurrences[host.cleanName] = (nameOccurrences[host.cleanName] ?? 0) + 1;
    }

    for (final host in uniqueHosts) {
      final idx = host.hostIndex ?? 1;
      final prefix = '$idx';
      final bool hasDuplicateName = (nameOccurrences[host.cleanName] ?? 0) > 1;
      final shortUid = host.uid.length >= 4 ? host.uid.substring(host.uid.length - 4) : host.uid;
      final String disambiguator = hasDuplicateName ? ' (..$shortUid)' : '';
      final fullNameWithPrefix = '$prefix-${host.cleanName}$disambiguator';

      filterOptions.add(_HostFilterOption(id: host.uid, label: fullNameWithPrefix));
      hostPrefixById[host.uid] = fullNameWithPrefix;
      for (final uid in host.uids) {
        hostPrefixById[uid] = fullNameWithPrefix;
        hostIndexById[uid] = idx;
      }
      hostPrefixMap[host.cleanName] = fullNameWithPrefix;
      hostPrefixMap[host.name] = fullNameWithPrefix;
      hostOnlyPrefixMap[host.cleanName] = prefix;
      hostOnlyPrefixMap[host.name] = prefix;
      hostIndexById[host.uid] = idx;
      hostIndexByName[host.cleanName] = idx;
      hostIndexByName[host.name] = idx;
    }

    // 6. Quét tập hợp các bookingId đã check-in từ collection 'checkins'
    final Set<String> checkedInBookingIds = {};
    for (final cDoc in _rawCheckinDocs) {
      final cData = cDoc.data() as Map<String, dynamic>? ?? {};
      final bId = (cData['bookingId'] ?? cData['donId'] ?? '')
          .toString()
          .trim();
      if (bId.isNotEmpty) checkedInBookingIds.add(bId);
      checkedInBookingIds.add(cDoc.id);
    }

    // 7. Xây dựng danh sách đơn hoàn chỉnh
    final List<Map<String, dynamic>> orders = [];
    final Map<String, Map<String, dynamic>> bookingsNeedSync = {};

    for (final doc in _rawBookingDocs) {
      final rawData = doc.data() as Map<String, dynamic>? ?? {};
      final data = BookingUtils.canonical(rawData);
      final docId = doc.id;
      final rawStatus = (data['status'] ?? '').toString().toLowerCase();

      // Bỏ qua đơn chưa bao giờ thanh toán
      if (rawStatus == 'pending_payment') {
        continue;
      }

      final bookingHostId = extractBookingHostId(data);
      final latestProfileHostName = bookingHostId.isNotEmpty
          ? (userNamesById[bookingHostId] ?? '')
          : '';
      final rawHostName = latestProfileHostName.isNotEmpty
          ? latestProfileHostName
          : (data['hostName'] ?? 'Chủ trọ').toString().trim();
      String cleanHostName = _sanitizeHostName(rawHostName);

      final int hostIndex = hostIndexById[bookingHostId] ??
          hostIndexByName[cleanHostName] ??
          hostIndexByName[rawHostName] ??
          (data['hostIndex'] as num?)?.toInt() ??
          (int.tryParse(hostOnlyPrefixMap[cleanHostName] ?? '') ?? 1);

      final String hostPrefix = '$hostIndex';

      final formattedHostName =
          hostPrefixById[bookingHostId] ??
          hostPrefixMap[cleanHostName] ??
          hostPrefixMap[rawHostName] ??
          '$hostPrefix-$cleanHostName';

      final bool isDocCheckedIn =
          checkedInBookingIds.contains(docId) ||
          checkedInBookingIds.contains((data['bookingId'] ?? '').toString()) ||
          checkedInBookingIds.contains((data['orderCode'] ?? '').toString());

      final isCheckIn =
          data['isCheckIn'] == true ||
          data['daNhanPhong'] == true ||
          rawStatus == 'dango' ||
          rawStatus == 'danhanphong' ||
          rawStatus == 'active' ||
          isDocCheckedIn;

      final paymentOption = (data['paymentOption'] ?? 'deposit')
          .toString()
          .toLowerCase();
      final isFullPayment =
          paymentOption == 'full' ||
          paymentOption == 'toanbo' ||
          paymentOption == 'trahet' ||
          (data['isFullPayment'] == true);

      bool isTruthy(dynamic v) {
        if (v == null) return false;
        if (v is bool) return v;
        if (v is num) return v != 0;
        if (v is String) {
          final s = v.trim().toLowerCase();
          return s == 'true' || s == '1' || s == 'yes';
        }
        return false;
      }

      final isDisbursed = BookingUtils.isDisbursed(data);
      final isRefunded = isTruthy(data['isRefunded']) ||
          data['refundedAt'] != null ||
          data['daHoanTien'] == true ||
          data['daTatToan'] == true;
      final cancellationHostPaid = isTruthy(data['cancellationHostPaid']) ||
          data['cancellationHostPaidAt'] != null ||
          data['hostPaid'] == true ||
          data['daBoiThuong'] == true;
      final cancellationRenterRefunded = isTruthy(data['cancellationRenterRefunded']) ||
          data['cancellationRenterRefundedAt'] != null ||
          data['renterRefunded'] == true;
      final isCancellationSettled = BookingUtils.isCancellationSettled(data) ||
          isRefunded ||
          (!isFullPayment && cancellationHostPaid) ||
          (cancellationHostPaid && cancellationRenterRefunded);
      final isLocked = !isCheckIn;

      final amount = BookingUtils.amount(data);

      // Dùng cùng quy tắc trạng thái chuẩn với dashboard, để đơn đã thanh toán
      // hoặc giải ngân không bị rơi sang tab khác chỉ vì tên status cũ/mới.
      final isCancelled = rawStatus == 'cancelled' ||
          rawStatus == 'canceled' ||
          rawStatus == 'rejected' ||
          rawStatus == 'dahuy';
      final targetTab = isCancelled
          ? 'cancelled'
          : (rawStatus == 'pending'
                ? 'pending'
                : (isFullPayment ? 'completed' : 'deposit_paid'));

      final String shortSuffix = BookingUtils.shortCode(data, docId);
      final String finalOrderCode = '$hostPrefix-$shortSuffix';
      final String timeInfo = _formatOrderTimeInfo(data, targetTab);

      final String rawTransferNote = (rawData['transferNote'] ?? '').toString().trim();
      final bool hasValidTransferNote =
          RegExp(r'^\d+\s*-\s*[A-Za-z0-9]{3,6}$').hasMatch(rawTransferNote);

      // Đồng bộ chuẩn theo cấu trúc mới: lưu hostIndex + transferNote ("hostIndex-4chars") cho đơn cũ, xóa orderCode thừa
      if ((rawData['hostIndex'] != hostIndex ||
              !hasValidTransferNote ||
              rawData.containsKey('orderCode')) &&
          !_syncedBookingIds.contains(docId)) {
        bookingsNeedSync[docId] = {
          'hostIndex': hostIndex,
          if (!hasValidTransferNote) 'transferNote': finalOrderCode,
          if (rawData.containsKey('orderCode')) 'orderCode': FieldValue.delete(),
        };
      }

      orders.add({
        'id': docId,
        'orderCode': hasValidTransferNote ? rawTransferNote.replaceAll(' ', '') : finalOrderCode,
        'rawOrderCode': shortSuffix,
        'transferNote': hasValidTransferNote ? rawTransferNote.replaceAll(' ', '') : finalOrderCode,
        'userCode': (data['userCode'] ?? '').toString(),
        'renterId': data['renterId'] ?? '',
        'renterPhone': (data['renterPhone'] ?? data['phoneNumber'] ?? '')
            .toString(),
        'hostId': bookingHostId,
        'hostIndex': hostIndex,
        'hostPrefix': hostPrefix,
        'subTag':
            data['subTag']?.toString() ??
            (targetTab == 'cancelled'
                ? 'Đã hủy'
                : (targetTab == 'pending'
                      ? 'Chờ xác nhận'
                      : (isDisbursed
                            ? 'Đã giải ngân'
                            : (isCheckIn ? 'Đã check-in' : 'Chờ nhận phòng')))),
        'renterName': (data['renterName'] ?? 'Khách thuê').toString(),
        'roomTitle': (data['roomTitle'] ?? 'Phòng trọ').toString(),
        'deposit': amount,
        'formattedDeposit': currencyFormatter.format(amount),
        'status': targetTab,
        'isFullPayment': isFullPayment,
        'paymentOption': paymentOption,
        'note': targetTab == 'cancelled'
            ? (data['note']?.toString() ?? 'Đơn đã hủy • Cần hoàn tiền')
            : (isFullPayment ? 'Cọc đảm bảo nhận phòng' : 'Cọc giữ phòng'),
        'deadline': timeInfo,
        'hostName': formattedHostName,
        'rawHostName': rawHostName,
        'isLocked': isLocked,
        'isCheckIn': isCheckIn,
        'isDisbursed': isDisbursed,
        'isRefunded': isRefunded,
        'cancellationHostPaid': cancellationHostPaid,
        'cancellationRenterRefunded': cancellationRenterRefunded,
        'isCancellationSettled': isCancellationSettled,
        'reconciliationDate': _orderReconciliationDate(data, targetTab),
        'sortDate': isCancelled
            ? (asDateTime(data['cancelledAt']) ??
                asDateTime(data['ngayHuy']) ??
                asDateTime(data['updatedAt']) ??
                asDateTime(data['createdAt']) ??
                asDateTime(data['ngayTao']) ??
                DateTime.fromMillisecondsSinceEpoch(0))
            : (asDateTime(data['createdAt']) ??
                asDateTime(data['ngayTao']) ??
                asDateTime(data['bookingDate']) ??
                DateTime.fromMillisecondsSinceEpoch(0)),
      });
    }

    if (bookingsNeedSync.isNotEmpty && !_isSyncingHostData) {
      _autoSyncBookingsToFirestore(bookingsNeedSync);
    }

    orders.sort(_compareOrders);

    if (mounted) {
      setState(() {
        _allOrders = orders;
        _hostFilterOptions = filterOptions;
        if (!_hostFilterOptions.any((opt) => opt.id == _selectedHostId)) {
          _selectedHostId = 'all';
        }
      });
    }
  }

  /// Kiểm tra xem đơn hàng đã được xử lý xong hay chưa
  static bool _isOrderHandled(Map<String, dynamic> order) {
    final status = (order['status'] ?? '').toString();
    if (status == 'cancelled') {
      final isRefunded = order['isRefunded'] == true;
      final isCancellationSettled = order['isCancellationSettled'] == true;
      final hostPaid = order['cancellationHostPaid'] == true;
      final renterRefunded = order['cancellationRenterRefunded'] == true;
      return isRefunded ||
          isCancellationSettled ||
          hostPaid ||
          renterRefunded;
    }
    // Đối với 'deposit_paid' (Đã cọc) và 'completed' (Đã trả hết):
    // Đã xử lý là đơn đã được giải ngân thành công cho chủ trọ
    return order['isDisbursed'] == true;
  }

  /// Sắp xếp: Đơn chưa xử lý (cần xử lý) lên đầu, đơn đã xử lý nằm bên dưới hết.
  /// Trong cùng nhóm: đơn mới nhất lên đầu.
  static int _compareOrders(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aHandled = _isOrderHandled(a);
    final bHandled = _isOrderHandled(b);

    // 1. Đơn chưa xử lý luôn nằm TRÊN, đơn đã xử lý nằm BÊN DƯỚI HẾT
    if (aHandled != bHandled) {
      return aHandled ? 1 : -1;
    }

    // 2. Trong cùng nhóm (chưa xử lý hoặc đã xử lý): đơn mới nhất lên đầu
    final aDate =
        a['sortDate'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate =
        b['sortDate'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0);
    final byDate = bDate.compareTo(aDate);
    if (byDate != 0) return byDate;

    return (b['id'] as String? ?? '').compareTo(a['id'] as String? ?? '');
  }

  Future<void> _navigateToSettlementInvoice(
    List<Map<String, dynamic>> orders,
  ) async {
    final checkInOrderIds = orders
        .where(
          (order) => order['isCheckIn'] == true && order['isDisbursed'] != true,
        )
        .map((order) => order['id'] as String)
        .toList();

    if (checkInOrderIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chưa có đơn nào đã check-in để tạo hóa đơn giải ngân!',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final groups = <String, List<String>>{};
    final groupLabels = <String, String>{};
    for (final order in orders.where(
      (o) => checkInOrderIds.contains(o['id']),
    )) {
      final hostKey = _hostGroupKey(order);
      groups.putIfAbsent(hostKey, () => []).add(order['id'] as String);
      groupLabels.putIfAbsent(hostKey, () => _hostGroupLabel(order));
    }
    await _chooseInvoiceGroup(
      groups,
      cancellation: false,
      groupLabels: groupLabels,
    );
  }

  String _hostGroupKey(Map<String, dynamic> order) {
    final hostId = (order['hostId'] ?? '').toString().trim();
    if (hostId.isNotEmpty) return 'id:$hostId';
    final hostName = (order['rawHostName'] ?? order['hostName'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return 'name:$hostName';
  }

  String _hostGroupLabel(Map<String, dynamic> order) {
    var hostName = (order['rawHostName'] ?? order['hostName'] ?? '')
        .toString()
        .trim();
    hostName = _sanitizeHostName(hostName);
    if (hostName.isEmpty) hostName = 'Chủ trọ';
    final hostId = (order['hostId'] ?? '').toString().trim();
    if (hostId.isNotEmpty) {
      final matchingHostIds = _allOrders
          .where((o) {
            var n = _sanitizeHostName(
              (o['rawHostName'] ?? o['hostName'] ?? '').toString().trim(),
            );
            if (n.isEmpty) n = 'Chủ trọ';
            return n.toLowerCase() == hostName.toLowerCase();
          })
          .map((o) => (o['hostId'] ?? '').toString().trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      if (matchingHostIds.length > 1) {
        final shortUid = hostId.length >= 4
            ? hostId.substring(hostId.length - 4)
            : hostId;
        return '$hostName (..$shortUid)';
      }
    }
    return hostName;
  }

  Future<void> _chooseInvoiceGroup(
    Map<String, List<String>> groups, {
    required bool cancellation,
    Map<String, String> groupLabels = const {},
  }) async {
    if (groups.isEmpty) return;
    String? selected;
    if (groups.length == 1) {
      selected = groups.keys.first;
    } else {
      selected = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  'Chọn nhóm hóa đơn',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              for (final key in groups.keys)
                ListTile(
                  leading: const Icon(
                    Icons.account_balance_outlined,
                    color: Color(0xFF398FC0),
                  ),
                  title: Text(groupLabels[key] ?? key),
                  subtitle: Text('${groups[key]!.length} đơn'),
                  onTap: () => Navigator.pop(ctx, key),
                ),
            ],
          ),
        ),
      );
    }
    if (!mounted || selected == null) return;
    if (cancellation) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CancellationInvoiceScreen(bookingIds: groups[selected]!),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SettlementInvoiceScreen(selectedBookingIds: groups[selected]!),
        ),
      );
    }
  }

  Future<void> _navigateToCancellationInvoice(
    List<Map<String, dynamic>> orders,
  ) async {
    // Chỉ lấy các đơn hủy chưa được xử lý chuyển khoản
    final pendingOrders = orders.where((order) {
      if (order['status'] != 'cancelled') return false;
      if (order['isRefunded'] == true ||
          order['isCancellationSettled'] == true ||
          order['cancellationHostPaid'] == true ||
          order['cancellationRenterRefunded'] == true) {
        return false;
      }
      return true;
    }).toList();

    if (pendingOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tất cả đơn hủy đã được thanh toán / tất toán xong!'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    final groups = <String, List<String>>{};
    final groupLabels = <String, String>{};
    for (final order in pendingOrders) {
      final hostPaid = order['cancellationHostPaid'] == true;
      final kind = order['isFullPayment'] == true ? 'Trả hết' : 'Chỉ cọc';

      // Nếu đơn trả hết mà chủ trọ đã nhận tiền rồi -> Đây là nhóm hoàn tiền cho khách thuê
      if (order['isFullPayment'] == true && hostPaid) {
        final renterKey = 'renter:${order['renterId'] ?? order['id']}';
        groups.putIfAbsent(renterKey, () => []).add(order['id'] as String);
        final rName = (order['renterName'] ?? 'Khách thuê').toString();
        groupLabels.putIfAbsent(
          renterKey,
          () => '$rName • Hoàn tiền khách',
        );
      } else {
        final ownerKey = _hostGroupKey(order);
        final hostKey = '$ownerKey::$kind';
        groups.putIfAbsent(hostKey, () => []).add(order['id'] as String);
        groupLabels.putIfAbsent(
          hostKey,
          () => '${_hostGroupLabel(order)} • $kind',
        );
      }
    }
    await _chooseInvoiceGroup(
      groups,
      cancellation: true,
      groupLabels: groupLabels,
    );
  }

  double _parseToDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  DateTime? asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
    }
    if (value is String) {
      final s = value.trim();
      if (s.isEmpty || s == '—') return null;
      // Nếu chuỗi chứa "Timestamp(seconds=123456789, ...)"
      if (s.contains('seconds=')) {
        final match = RegExp(r'seconds=(\d+)').firstMatch(s);
        if (match != null) {
          final sec = int.tryParse(match.group(1)!);
          if (sec != null) {
            return DateTime.fromMillisecondsSinceEpoch(sec * 1000);
          }
        }
      }
      return DateTime.tryParse(s);
    }
    return null;
  }

  DateTime? _orderReconciliationDate(Map<String, dynamic> data, String status) {
    if (status == 'cancelled') {
      return asDateTime(data['refundedAt']) ??
          asDateTime(data['cancellationSettledAt']) ??
          asDateTime(data['cancelledAt']) ??
          asDateTime(data['updatedAt']) ??
          asDateTime(data['createdAt']) ??
          asDateTime(data['ngayTao']);
    }
    if (data['isDisbursed'] == true) {
      return asDateTime(data['disbursedAt']) ??
          asDateTime(data['updatedAt']) ??
          asDateTime(data['createdAt']) ??
          asDateTime(data['ngayTao']);
    }
    return asDateTime(data['createdAt']) ??
        asDateTime(data['ngayTao']) ??
        asDateTime(data['bookingDate']);
  }

  @override
  Widget build(BuildContext context) {
    final visibleByHost = _selectedHostId == 'all'
        ? _allOrders
        : _allOrders
            .where((e) => (e['hostId'] ?? '').toString() == _selectedHostId)
            .toList();

    final selectedDate = _selectedDate;
    final visibleByDate = selectedDate == null
        ? visibleByHost
        : visibleByHost.where((item) {
            final date = item['reconciliationDate'] as DateTime?;
            return date != null &&
                date.year == selectedDate.year &&
                date.month == selectedDate.month &&
                date.day == selectedDate.day;
          }).toList();

    final cPending = visibleByDate
        .where((e) => e['status'] == 'pending')
        .length;
    final cDeposit = visibleByDate
        .where((e) => e['status'] == 'deposit_paid')
        .length;
    final cCompleted = visibleByDate
        .where((e) => e['status'] == 'completed')
        .length;
    final cCancelled = visibleByDate
        .where((e) => e['status'] == 'cancelled')
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
          title: 'Quản lý đơn thuê phòng',
          subtitle: 'Theo dõi cọc, nhận phòng & giải ngân',
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // ── Khối 1: Chọn Chủ Trọ (Chuẩn theo ảnh mẫu) ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Chủ trọ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE9F5FC),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.real_estate_agent_outlined,
                        size: 22,
                        color: Color(0xFF398FC0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD0D5DD)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedHostId,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF667085),
                          size: 22,
                        ),
                        items: _hostFilterOptions.map((opt) {
                          return DropdownMenuItem<String>(
                            value: opt.id,
                            child: Text(
                              opt.label,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF101828),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedHostId = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Search & Date Filter Row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() {}),
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo Mã HĐ, Tên khách...',
                      hintStyle: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF98A2B3),
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 18,
                        color: Color(0xFF667085),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 10,
                      ),
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
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _pickReconciliationDate,
                  icon: const Icon(Icons.calendar_today_outlined, size: 15),
                  label: Text(
                    _selectedDate == null
                        ? 'Tất cả ngày'
                        : 'Đối soát: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475467),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    side: const BorderSide(color: Color(0xFFD0D5DD)),
                  ),
                ),
              ],
            ),
          ),

          // ── Khối 3: Tab Lọc Trạng Thái (Bao gồm Đơn Hủy) ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: Row(
              children: [
                _buildStatusPill(
                  label: 'Đang xử lý',
                  count: cPending,
                  value: 'pending',
                  dotColor: const Color(0xFFF79009),
                ),
                const SizedBox(width: 6),
                _buildStatusPill(
                  label: 'Đã cọc',
                  count: cDeposit,
                  value: 'deposit_paid',
                  dotColor: const Color(0xFF398FC0),
                ),
                const SizedBox(width: 6),
                _buildStatusPill(
                  label: 'Đã trả hết',
                  count: cCompleted,
                  value: 'completed',
                  dotColor: const Color(0xFF12B76A),
                ),
                const SizedBox(width: 6),
                _buildStatusPill(
                  label: 'Đơn hủy',
                  count: cCancelled,
                  value: 'cancelled',
                  dotColor: const Color(0xFFD92D20),
                ),
              ],
            ),
          ),

          // ── Khối 4: Header Phụ Của Danh Sách ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: const BoxDecoration(
              color: Color(0xFFF4F9FF),
              border: Border(
                top: BorderSide(color: Color(0xFFDCEAF5)),
                bottom: BorderSide(color: Color(0xFFDCEAF5)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _filter == 'cancelled'
                      ? 'MÃ GD / NGÀY HỦY'
                      : (_filter == 'pending' ? 'MÃ GD' : 'MÃ GD / NGÀY VÀO Ở'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF475467),
                    letterSpacing: 0.3,
                  ),
                ),
                const Text(
                  'TRẠNG THÁI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF475467),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          // ── Khối 5 & 6: Danh Sách & Bottom Bar lắng nghe từ ValueNotifier mượt mà ──
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: _searchQuery,
              builder: (context, queryText, _) {
                // Lọc danh sách tức thì theo từ khóa (hỗ trợ có dấu, không dấu, viết hoa/thường)
                final filteredList = visibleByDate
                    .where((item) {
                      if (!_matchesQuery(item, queryText)) return false;
                      return item['status'] == _filter;
                    })
                    .toList()
                  ..sort(_compareOrders);

                final checkInOrders = filteredList
                    .where(
                      (e) => e['isCheckIn'] == true && e['isDisbursed'] != true,
                    )
                    .toList();

                double autoCheckInAmount = 0.0;
                for (final item in checkInOrders) {
                  autoCheckInAmount += _parseToDouble(item['deposit']);
                }

                final pendingCancelledOrders = filteredList.where((item) {
                  if (item['status'] != 'cancelled') return false;
                  if (item['isRefunded'] == true ||
                      item['isCancellationSettled'] == true ||
                      item['cancellationHostPaid'] == true ||
                      item['cancellationRenterRefunded'] == true) {
                    return false;
                  }
                  return true;
                }).toList();

                final fullCancelledCount = pendingCancelledOrders
                    .where((item) => item['isFullPayment'] == true)
                    .length;

                if (_isLoading && _allOrders.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF398FC0)),
                  );
                }

                if (filteredList.isEmpty) {
                  // Kiểm tra xem có đơn nào khớp từ khóa ở các tab khác không
                  final otherMatches = queryText.trim().isNotEmpty
                      ? visibleByDate
                            .where(
                              (item) =>
                                  _matchesQuery(item, queryText) &&
                                  item['status'] != _filter,
                            )
                            .toList()
                      : <Map<String, dynamic>>[];

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            queryText.trim().isEmpty
                                ? (_filter == 'cancelled'
                                      ? 'Không có đơn hủy nào'
                                      : (_filter == 'pending'
                                            ? 'Không có đơn nào đang xử lý'
                                            : (_filter == 'deposit_paid'
                                                  ? 'Không có đơn nào đã cọc 1 phần'
                                                  : 'Không có đơn nào đã cọc hết 100%')))
                                : 'Không tìm thấy đơn nào khớp với "$queryText" trong mục này',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF667085),
                            ),
                          ),
                          if (otherMatches.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9F5FC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFB2DDFF),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Tìm thấy ${otherMatches.length} đơn khớp từ khóa ở mục khác:',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF175CD3),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      if (otherMatches.any(
                                        (e) => e['status'] == 'pending',
                                      ))
                                        ActionChip(
                                          label: const Text('Xem "Đang xử lý"'),
                                          backgroundColor: Colors.white,
                                          onPressed: () => setState(
                                            () => _filter = 'pending',
                                          ),
                                        ),
                                      if (otherMatches.any(
                                        (e) => e['status'] == 'deposit_paid',
                                      ))
                                        ActionChip(
                                          label: const Text('Xem "Đã cọc"'),
                                          backgroundColor: Colors.white,
                                          onPressed: () => setState(
                                            () => _filter = 'deposit_paid',
                                          ),
                                        ),
                                      if (otherMatches.any(
                                        (e) => e['status'] == 'completed',
                                      ))
                                        ActionChip(
                                          label: const Text('Xem "Đã trả hết"'),
                                          backgroundColor: Colors.white,
                                          onPressed: () => setState(
                                            () => _filter = 'completed',
                                          ),
                                        ),
                                      if (otherMatches.any(
                                        (e) => e['status'] == 'cancelled',
                                      ))
                                        ActionChip(
                                          label: const Text('Xem "Đơn hủy"'),
                                          backgroundColor: Colors.white,
                                          onPressed: () => setState(
                                            () => _filter = 'cancelled',
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: filteredList.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = filteredList[index];
                          final id = item['id'] as String;

                          if (_filter == 'cancelled') {
                            return _buildCancelledOrderCard(
                              orderCode: item['orderCode'],
                              deadline: (item['deadline'] ?? '').toString(),
                              renterName: item['renterName'],
                              roomTitle: item['roomTitle'],
                              hostName: item['hostName'],
                              deposit: _parseToDouble(item['deposit']),
                              isFullPayment: item['isFullPayment'] == true,
                              isRefunded: item['isRefunded'] == true,
                              isCancellationSettled:
                                  item['isCancellationSettled'] == true,
                              cancellationHostPaid:
                                  item['cancellationHostPaid'] == true,
                              cancellationRenterRefunded:
                                  item['cancellationRenterRefunded'] == true,
                            );
                          } else if (_filter == 'pending') {
                            return _buildPendingOrderCard(
                              id: id,
                              orderCode: item['orderCode'],
                              renterName: item['renterName'],
                              roomTitle: item['roomTitle'],
                              deposit: _parseToDouble(item['deposit']),
                              subTag: item['subTag'],
                              note: item['note'],
                              isFullPayment: item['isFullPayment'] == true,
                              onActionPressed: () => _confirmOrder(item),
                            );
                          } else {
                            return _buildDepositOrCompletedCard(
                              id: id,
                              orderCode: item['orderCode'],
                              subTag: item['subTag'],
                              deadline: (item['deadline'] ?? '').toString(),
                              renterName: item['renterName'],
                              roomTitle: item['roomTitle'],
                              hostName: item['hostName'],
                              deposit: _parseToDouble(item['deposit']),
                              status: item['status'],
                              note: item['note'],
                              isFullPayment: item['isFullPayment'] == true,
                              isLocked: item['isLocked'] == true,
                              isCheckIn: item['isCheckIn'] == true,
                              isDisbursed: item['isDisbursed'] == true,
                              onActionPressed: () =>
                                  _navigateToSettlementInvoice([item]),
                            );
                          }
                        },
                      ),
                    ),

                    // Bottom Bar Nút Tạo Hóa Đơn Tự Động
                    if (_filter == 'cancelled')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: const Border(
                            top: BorderSide(color: Color(0xFFDCEAF5)),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, -3),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFD92D20),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Cần xử lý: ${pendingCancelledOrders.length} đơn',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFB42318),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () {
                                  _navigateToCancellationInvoice(pendingCancelledOrders);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD92D20),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.receipt_long_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  'TẠO HÓA ĐƠN HỦY',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_filter != 'pending')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: const Border(
                            top: BorderSide(color: Color(0xFFDCEAF5)),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, -3),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: checkInOrders.isNotEmpty
                                                ? const Color(0xFF12B76A)
                                                : const Color(0xFFF79009),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Đã tự lọc: ${checkInOrders.length} đơn đã check-in',
                                              maxLines: 1,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: checkInOrders.isNotEmpty
                                                    ? const Color(0xFF027A48)
                                                    : const Color(0xFFB54708),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Tổng giải ngân: ',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF475467),
                                            ),
                                          ),
                                          Text(
                                            '${currencyFormatter.format(autoCheckInAmount)} đ',
                                            style: const TextStyle(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF398FC0),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _navigateToSettlementInvoice(filteredList),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF398FC0),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.receipt_long_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  'TẠO HÓA ĐƠN (${checkInOrders.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Nút Tab lọc hình capsule chuẩn mẫu ảnh
  Widget _buildStatusPill({
    required String label,
    required int count,
    required String value,
    required Color dotColor,
  }) {
    final isSelected = _filter == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filter = value),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF398FC0)
                : const Color(0xFFEAF4FA),
            borderRadius: BorderRadius.circular(22),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected && dotColor != Colors.transparent) ...[
                  Container(
                    width: 6.5,
                    height: 6.5,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFDB022),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 3),
                ] else if (dotColor == const Color(0xFFD92D20)) ...[
                  Container(
                    width: 6.5,
                    height: 6.5,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 3),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF344054),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFF79009)
                        : (dotColor == const Color(0xFFD92D20)
                              ? const Color(0xFFFEE4E2)
                              : const Color(0xFFE4E7EC)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : (dotColor == const Color(0xFFD92D20)
                                ? const Color(0xFFB42318)
                                : const Color(0xFF344054)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Card Đơn Hàng Bị Hủy
  Widget _buildCancelledOrderCard({
    required String orderCode,
    required String deadline,
    required String renterName,
    required String roomTitle,
    required String hostName,
    required double deposit,
    required bool isFullPayment,
    required bool isRefunded,
    required bool isCancellationSettled,
    required bool cancellationHostPaid,
    required bool cancellationRenterRefunded,
  }) {
    final bool isCompleted = isRefunded ||
        isCancellationSettled ||
        cancellationHostPaid ||
        cancellationRenterRefunded;
    final bool isHostPaidOnly = false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFFD1FADF)
              : (isHostPaidOnly
                    ? const Color(0xFFD1E9FF)
                    : const Color(0xFFFECDCA)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CỘT 1: Mã GD (tiết đầu tố) & Thời gian hủy
                SizedBox(
                  width: 88,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECDCA)),
                        ),
                        child: Text(
                          orderCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFD92D20),
                          ),
                        ),
                      ),
                      if (deadline.isNotEmpty && deadline != '—') ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.event_busy_rounded,
                              size: 11,
                              color: Color(0xFFD92D20),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                deadline,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB42318),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // CỘT 2: Tên khách thuê & Tên phòng
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        renterName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF101828),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.meeting_room_outlined,
                            size: 14,
                            color: Color(0xFF667085),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              roomTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF475467),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (hostName.isNotEmpty &&
                          hostName != 'Tất cả chủ trọ') ...[
                        const SizedBox(height: 3),
                        Text(
                          'Chủ trọ: $hostName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF667085),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // CỘT 3: Trạng thái Đã hủy & Tiền cọc gốc
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isCompleted) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF3),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF6CE9A6)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 7,
                              color: Color(0xFF12B76A),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Đã tất toán',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF027A48),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isHostPaidOnly) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF8FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFB2DDFF)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 7,
                              color: Color(0xFF175CD3),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Đã trả chủ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF175CD3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFECDCA)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 6, color: Color(0xFFD92D20)),
                            SizedBox(width: 4),
                            Text(
                              'Chờ xử lý',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB42318),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${currencyFormatter.format(deposit)}đ',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF101828),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Footer Card: Tỷ lệ phân bổ & Trạng thái tất toán
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isCompleted
                  ? const Color(0xFFF6FEF9)
                  : (isHostPaidOnly
                        ? const Color(0xFFF5FAFF)
                        : const Color(0xFFFFFBFB)),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(13)),
              border: Border(
                top: BorderSide(
                  color: isCompleted
                      ? const Color(0xFFD1FADF)
                      : (isHostPaidOnly
                            ? const Color(0xFFD1E9FF)
                            : const Color(0xFFFECDCA)),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFFECFDF3)
                        : (isHostPaidOnly
                              ? const Color(0xFFEFF8FF)
                              : const Color(0xFFFEF3F2)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isCompleted
                        ? 'Đã xong'
                        : (isHostPaidOnly ? 'Đã trả chủ' : 'Đơn hủy'),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isCompleted
                          ? const Color(0xFF027A48)
                          : (isHostPaidOnly
                                ? const Color(0xFF175CD3)
                                : const Color(0xFFD92D20)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isCompleted
                        ? 'Đã bồi thường chủ trọ và hoàn tiền đầy đủ'
                        : (isHostPaidOnly
                              ? 'Đã bồi thường chủ trọ • Chờ hoàn tiền khách'
                              : (isFullPayment
                                    ? 'Hoàn khách 50% cọc • Chủ trọ nhận 50% còn lại sau hoa hồng'
                                    : 'Khách mất cọc • Chủ trọ nhận cọc sau hoa hồng sàn')),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isCompleted
                          ? const Color(0xFF027A48)
                          : (isHostPaidOnly
                                ? const Color(0xFF175CD3)
                                : const Color(0xFFB42318)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card Đơn Hàng Chờ Duyệt (Layout 3 cột thoáng, đẹp đều, chuẩn ảnh mẫu)
  Widget _buildPendingOrderCard({
    required String id,
    required String orderCode,
    required String renterName,
    required String roomTitle,
    required double deposit,
    required String subTag,
    required String note,
    required bool isFullPayment,
    required VoidCallback onActionPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCEAF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CỘT 1: Mã GD (tiết đầu tố)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F5FC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFB2DDFF)),
                  ),
                  child: Text(
                    orderCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF398FC0),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // CỘT 2: Tên khách thuê & Tên phòng
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        renterName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF101828),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.meeting_room_outlined,
                            size: 14,
                            color: Color(0xFF667085),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              roomTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF475467),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // CỘT 3: Trạng thái & Số tiền
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF0C7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFEDF89)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 6, color: Color(0xFFF79009)),
                          SizedBox(width: 4),
                          Text(
                            'Chờ xác nhận',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB54708),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${currencyFormatter.format(deposit)}đ',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF101828),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Footer Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF4F9FF),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
              border: Border(top: BorderSide(color: Color(0xFFDCEAF5))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: isFullPayment
                        ? const Color(0xFFECFDF3)
                        : const Color(0xFFE9F5FC),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isFullPayment ? 'Trả hết' : 'Tiền cọc',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isFullPayment
                          ? const Color(0xFF027A48)
                          : const Color(0xFF175CD3),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note.isNotEmpty ? note : 'Khách đã gửi lệnh chuyển tiền',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF667085),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onActionPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF398FC0),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isFullPayment ? 'Xác nhận cọc hết' : 'Xác nhận tiền cọc',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card Đơn Hàng Đã Cọc / Đã Cọc Hết (Layout 3 cột thoáng, đẹp đều, chuẩn ảnh mẫu)
  Widget _buildDepositOrCompletedCard({
    required String id,
    required String orderCode,
    required String subTag,
    required String deadline,
    required String renterName,
    required String roomTitle,
    required String hostName,
    required double deposit,
    required String status,
    required String note,
    required bool isFullPayment,
    required bool isLocked,
    required bool isCheckIn,
    required bool isDisbursed,
    required VoidCallback onActionPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCheckIn ? const Color(0xFFD0D5DD) : const Color(0xFFDCEAF5),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CỘT 1: Mã GD (tiết đầu tố) & Ngày hẹn vào ở
                SizedBox(
                  width: 92,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9F5FC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFB2DDFF),
                          ),
                        ),
                        child: Text(
                          orderCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF398FC0),
                          ),
                        ),
                      ),
                      if (deadline.isNotEmpty && deadline != '—') ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 11,
                              color: const Color(0xFF175CD3),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                deadline,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF175CD3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // CỘT 2: Tên khách thuê & Tên phòng
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        renterName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF101828),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.meeting_room_outlined,
                            size: 14,
                            color: Color(0xFF667085),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              roomTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF475467),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (hostName.isNotEmpty &&
                          hostName != 'Tất cả chủ trọ') ...[
                        const SizedBox(height: 3),
                        Text(
                          'Chủ trọ: $hostName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF667085),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // CỘT 3: Trạng thái Check-in & Số tiền
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isDisbursed) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                        color: const Color(0xFFE9F5FC),
                          borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFB2DDFF)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 7,
                              color: Color(0xFF398FC0),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Đã giải ngân',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF398FC0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isCheckIn) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF3),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF6CE9A6)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 6,
                              color: Color(0xFF12B76A),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Đã check-in',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF027A48),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                        color: const Color(0xFFE9F5FC),
                          borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFB2DDFF)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 6,
                              color: Color(0xFF398FC0),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Chờ nhận phòng',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF398FC0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${currencyFormatter.format(deposit)}đ',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF101828),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Footer Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F9FF),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(13),
              ),
              border: Border(
                top: BorderSide(
                  color: const Color(0xFFDCEAF5),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F5FC),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isFullPayment ? 'Cọc hết (100%)' : 'Cọc 1 phần',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF175CD3),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isDisbursed
                        ? 'Đã giải ngân tiền cọc cho chủ trọ'
                        : (isCheckIn
                              ? 'Đã nhận phòng • Sẵn sàng tạo hóa đơn'
                              : 'Khóa giải ngân • Chờ khách đến nhận phòng'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isCheckIn
                          ? const Color(0xFF027A48)
                          : const Color(0xFF398FC0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmOrder(Map<String, dynamic> item) async {
    final id = item['id'] as String;
    final isFull = item['isFullPayment'] == true;
    final targetStatus = isFull ? 'paid' : 'approved';
    final targetSubTag = isFull ? 'Đã trả hết' : 'Đã cọc';
    final targetTabName = isFull ? 'Đã trả hết' : 'Đã cọc';
    final actionText = isFull ? 'thanh toán đủ' : 'tiền cọc';

    try {
      final createdAt = item['sortDate'] as DateTime?;
      final rateAtBooking = await CommissionRateService.rateAt(
        createdAt != null && createdAt.millisecondsSinceEpoch > 0
            ? createdAt
            : null,
      );
      await FirebaseFirestore.instance.collection('bookings').doc(id).set({
        'status': targetStatus,
        'subTag': targetSubTag,
        'isPaid': true,
        'commissionRateAtBooking': rateAtBooking * 100,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final renterId = (item['renterId'] ?? '').toString();
      if (renterId.isNotEmpty && renterId != 'guest') {
        await FirebaseFirestore.instance.collection('notifications').add({
          'recipientId': renterId,
          'recipientRole': 'renter',
          'title': isFull
              ? 'Thanh toán thành công'
              : 'Duyệt tiền cọc thành công',
          'body':
              'Admin đã xác nhận $actionText cho phòng "${item['roomTitle']}". Bạn có thể chuẩn bị dọn vào ở!',
          'notificationType': 'booking',
          'bookingId': id,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await FirebaseFirestore.instance.collection('audit_logs').add({
        'action': 'Duyệt $actionText',
        ...await AdminAuditIdentity.currentActorFields(),
        'category': 'taiChinh',
        'details':
            'Admin đã xác nhận $actionText cho đơn ${item['orderCode']} của khách ${item['renterName']}. Chuyển vào mục "$targetTabName".',
        'target': 'Đơn $id',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF12B76A),
            content: Text(
              'Đã xác nhận $actionText cho đơn ${item['orderCode']}! Đã chuyển vào mục "$targetTabName".',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD92D20),
            content: Text('Lỗi cập nhật: $e'),
          ),
        );
      }
    }
  }
}
