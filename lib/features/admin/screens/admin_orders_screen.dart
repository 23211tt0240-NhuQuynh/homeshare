import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../utils/booking_utils.dart';
import '../widgets/admin_branded_title.dart';
import '../widgets/admin_theme_toggle.dart';
import 'cancellation_invoice_screen.dart';
import 'settlement_invoice_screen.dart';
import '../../../core/utils/id_generator.dart';
import '../../host/notifications/notification_types.dart';
import '../theme/admin_colors.dart';

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
  String _selectedHostArea = 'Tất cả chủ trọ';
  DateTime? _selectedDate;
  DateTime get effectiveSelectedDate => _selectedDate ?? DateTime.now();

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
  List<String> _hostDropdownItems = ['Tất cả chủ trọ'];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _searchCtrl.addListener(() {
      _searchQuery.value = _searchCtrl.text;
    });
    _initFirestore();
  }

  void _initFirestore() {
    try {
      final firestore = FirebaseFirestore.instance;
      _usersSub = firestore.collection('users').snapshots().listen((snap) {
        _rawUserDocs = snap.docs;
        _recalculateOrders();
      }, onError: (err) => debugPrint('Lỗi tải users: $err'));

      _bookingsSub = firestore
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

      _checkinsSub = firestore.collection('checkins').snapshots().listen((
        snap,
      ) {
        _rawCheckinDocs = snap.docs;
        _recalculateOrders();
      }, onError: (err) => debugPrint('Lỗi tải checkins: $err'));
    } on FirebaseException catch (error) {
      _isLoading = false;
      debugPrint('Chưa thể khởi tạo dữ liệu đơn: ${error.code}');
    }
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
      item['roomTitle'],
      item['hostName'],
      item['id'],
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

  /// Sinh mã hiển thị theo phần định danh riêng của booking, không lấy mã người thuê làm đuôi.
  String _formatShortOrderCode(
    String hostPrefix,
    Map<String, dynamic> data,
    String docId,
  ) {
    final orderCode = (data['orderCode'] ?? '').toString().trim().toUpperCase();
    final userCodeParts = (data['userCode'] ?? '')
        .toString()
        .toUpperCase()
        .split(RegExp(r'[^A-Z0-9]+'))
        .where((part) => part.isNotEmpty)
        .toSet();
    final idParts = docId.toUpperCase().split('_');

    // ID kiểu DP_<ngày>_<mã ngẫu nhiên riêng của đơn>_<mã người thuê>.
    for (var i = 2; i < idParts.length - 1; i++) {
      final part = idParts[i];
      if (part.length >= 8 && !RegExp(r'^20\d{6}$').hasMatch(part)) {
        return '$hostPrefix-${part.substring(part.length - 4)}';
      }
    }

    // Nếu có orderCode riêng thì dùng mã đó, không dùng transferNote/userCode vì chúng thường thuộc về khách.
    if (orderCode.isNotEmpty &&
        orderCode != docId.toUpperCase() &&
        orderCode != (data['userCode'] ?? '').toString().toUpperCase()) {
      final codeParts = orderCode.split(RegExp(r'[_-]'));
      for (final part in codeParts.reversed) {
        if (part.length >= 3 &&
            !userCodeParts.contains(part) &&
            !RegExp(r'^20\d{6}$').hasMatch(part)) {
          final clean = part.replaceAll(RegExp(r'[^A-Z0-9]'), '');
          if (clean.isNotEmpty) {
            return '$hostPrefix-${clean.length > 5 ? clean.substring(clean.length - 4) : clean}';
          }
        }
      }
    }

    // Fallback ổn định cho ID cũ không có đoạn mã riêng đủ dài.
    var hash = 0x811C9DC5;
    for (final unit in docId.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
    }
    final suffix = hash
        .toRadixString(36)
        .toUpperCase()
        .padLeft(7, '0')
        .substring(3);
    return '$hostPrefix-$suffix';
  }

  /// Tính toán định dạng thời gian / hạn hiển thị chuẩn xác theo từng loại đơn
  String _formatOrderTimeInfo(Map<String, dynamic> data, String tab) {
    if (tab == 'cancelled') {
      final cancelledAt =
          data['cancelledAt'] ??
          data['ngayHuy'] ??
          data['updatedAt'] ??
          data['createdAt'];
      if (cancelledAt is Timestamp) {
        return 'Hủy: ${DateFormat('dd/MM').format(cancelledAt.toDate())}';
      }
      return 'Đã hủy';
    } else if (tab == 'pending') {
      // Đơn Chờ duyệt: Là hạn khách chuyển tiền / xác nhận
      final rawDeadline = (data['deadline'] ?? data['hanChuyen'] ?? '')
          .toString()
          .trim();
      if (rawDeadline.isNotEmpty && rawDeadline != '—') {
        return rawDeadline.startsWith('Hạn')
            ? rawDeadline
            : 'Hạn: $rawDeadline';
      }
      final createdAt = data['createdAt'] ?? data['ngayTao'];
      if (createdAt is Timestamp) {
        final expireTime = createdAt.toDate().add(const Duration(minutes: 15));
        final diff = expireTime.difference(DateTime.now());
        if (diff.isNegative) {
          return 'Hạn: Quá hạn';
        }
        return 'Hạn: Còn ${diff.inMinutes}p';
      }
      return 'Hạn: Còn 15p';
    } else {
      // Đơn Đã cọc / Đã trả hết: Khách ĐÃ CHUYỂN TIỀN XONG, hạn ở đây là HẸN NGÀY VÀO Ở (check-in)
      final checkIn =
          data['checkInDate'] ?? data['ngayNhanPhong'] ?? data['checkIn'];
      if (checkIn != null) {
        if (checkIn is Timestamp) {
          return 'Hẹn vào: ${DateFormat('dd/MM/yyyy').format(checkIn.toDate())}';
        }
        return 'Hẹn vào: $checkIn';
      }
      final createdAt = data['createdAt'] ?? data['ngayTao'];
      if (createdAt is Timestamp) {
        return 'Đặt ngày: ${DateFormat('dd/MM').format(createdAt.toDate())}';
      }
      return 'Chờ nhận phòng';
    }
  }

  /// Parse dữ liệu từ snapshot thành danh sách hoàn chỉnh (Chỉ chạy khi Firestore có event mới)
  void _recalculateOrders() {
    final Map<String, String> hostPrefixMap = {};
    final Map<String, String> hostOnlyPrefixMap = {};
    final List<String> dropdownItems = ['Tất cả chủ trọ'];
    int hostCounter = 1;

    // 1. Quét chủ trọ từ 'users'
    for (final uDoc in _rawUserDocs) {
      final uData = uDoc.data() as Map<String, dynamic>? ?? {};
      final role = (uData['role'] ?? '').toString().toLowerCase();
      if (role == 'host' || role == 'landlord' || role == 'chutro') {
        final hName = (uData['fullName'] ?? uData['name'] ?? '')
            .toString()
            .trim();
        if (hName.isEmpty || hName == 'Tất cả chủ trọ') continue;

        String cleanName = hName;
        if (RegExp(r'^\d+-').hasMatch(cleanName)) {
          cleanName = cleanName.replaceFirst(RegExp(r'^\d+-'), '').trim();
        }

        if (!hostPrefixMap.containsKey(cleanName) &&
            !hostPrefixMap.containsKey(hName)) {
          final prefix = '$hostCounter';
          final fullNameWithPrefix = '$prefix-$cleanName';
          hostPrefixMap[cleanName] = fullNameWithPrefix;
          hostPrefixMap[hName] = fullNameWithPrefix;
          hostOnlyPrefixMap[cleanName] = prefix;
          hostOnlyPrefixMap[hName] = prefix;
          dropdownItems.add(fullNameWithPrefix);
          hostCounter++;
        }
      }
    }

    // 2. Quét bổ sung từ 'bookings' nếu có chủ trọ chưa nằm trong users
    for (final bDoc in _rawBookingDocs) {
      final bData = bDoc.data() as Map<String, dynamic>? ?? {};
      final rawHName = (bData['hostName'] ?? bData['tenChuNha'] ?? '')
          .toString()
          .trim();
      if (rawHName.isEmpty || rawHName == 'Tất cả chủ trọ') continue;

      String cleanName = rawHName;
      if (RegExp(r'^\d+-').hasMatch(cleanName)) {
        cleanName = cleanName.replaceFirst(RegExp(r'^\d+-'), '').trim();
      }

      if (!hostPrefixMap.containsKey(cleanName) &&
          !hostPrefixMap.containsKey(rawHName)) {
        final prefix = '$hostCounter';
        final fullNameWithPrefix = '$prefix-$cleanName';
        hostPrefixMap[cleanName] = fullNameWithPrefix;
        hostPrefixMap[rawHName] = fullNameWithPrefix;
        hostOnlyPrefixMap[cleanName] = prefix;
        hostOnlyPrefixMap[rawHName] = prefix;
        dropdownItems.add(fullNameWithPrefix);
        hostCounter++;
      }
    }

    // 3. Quét tập hợp các bookingId đã check-in từ collection 'checkins'
    final Set<String> checkedInBookingIds = {};
    for (final cDoc in _rawCheckinDocs) {
      final cData = cDoc.data() as Map<String, dynamic>? ?? {};
      final bId = (cData['bookingId'] ?? cData['donId'] ?? '')
          .toString()
          .trim();
      if (bId.isNotEmpty) checkedInBookingIds.add(bId);
      checkedInBookingIds.add(cDoc.id);
    }

    // 4. Xây dựng danh sách đơn hoàn chỉnh
    final List<Map<String, dynamic>> orders = [];

    for (final doc in _rawBookingDocs) {
      final rawData = doc.data() as Map<String, dynamic>? ?? {};
      final data = BookingUtils.canonical(rawData);
      final docId = doc.id;
      final rawStatus = (data['status'] ?? '').toString().toLowerCase();

      // Bỏ qua đơn chưa bao giờ thanh toán
      if (rawStatus == 'pending_payment') {
        continue;
      }

      final rawHostName = (data['hostName'] ?? 'Chủ trọ').toString().trim();
      String cleanHostName = rawHostName;
      if (RegExp(r'^\d+-').hasMatch(cleanHostName)) {
        cleanHostName = cleanHostName.replaceFirst(RegExp(r'^\d+-'), '').trim();
      }

      final String hostPrefix =
          hostOnlyPrefixMap[cleanHostName] ??
          hostOnlyPrefixMap[rawHostName] ??
          (hostPrefixMap[rawHostName]?.split('-').first ?? '1');

      final formattedHostName =
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

      final isDisbursed = data['isDisbursed'] == true;
      final paymentOption = (data['paymentOption'] ?? 'deposit')
          .toString()
          .toLowerCase();
      final isFullPayment =
          paymentOption == 'full' ||
          paymentOption == 'toanbo' ||
          paymentOption == 'trahet' ||
          (data['isFullPayment'] == true);
      final isLocked = !isCheckIn;

      final amount = BookingUtils.amount(data);

      String targetTab;
      if (rawStatus == 'cancelled' ||
          rawStatus == 'canceled' ||
          rawStatus == 'rejected' ||
          rawStatus == 'dahuy') {
        targetTab = 'cancelled'; // Tab "Đơn hủy"
      } else if (rawStatus == 'pending') {
        targetTab = 'pending';
      } else if (isFullPayment) {
        targetTab = 'completed'; // Tab "Đã cọc hết"
      } else {
        targetTab = 'deposit_paid'; // Tab "Đã cọc" (1 phần)
      }

      final String finalOrderCode = _formatShortOrderCode(
        hostPrefix,
        data,
        docId,
      );
      final String timeInfo = _formatOrderTimeInfo(data, targetTab);

      orders.add({
        'id': docId,
        'orderCode': finalOrderCode,
        'rawOrderCode': (data['orderCode'] ?? '').toString(),
        'transferNote': (data['transferNote'] ?? '').toString(),
        'userCode': (data['userCode'] ?? '').toString(),
        'renterId': data['renterId'] ?? '',
        'hostId': (data['hostId'] ?? data['chuNhaId'] ?? '').toString(),
        'roomId': (data['roomId'] ?? data['phongId'] ?? '').toString(),
        'roomCode': (data['roomCode'] ?? data['maPhong'] ?? '').toString(),
        'roomFloorInfo': (data['roomFloorInfo'] ?? data['thongTinTang'] ?? '').toString(),
        'checkInDate': data['checkInDate'] ?? data['ngayNhanPhong'] ?? data['checkIn'],
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
        'status': targetTab,
        'isFullPayment': isFullPayment,
        'paymentOption': paymentOption,
        'note':
            data['note']?.toString() ??
            (targetTab == 'cancelled'
                ? 'Đơn đã hủy • Cần hoàn tiền'
                : (targetTab == 'pending'
                      ? (isFullPayment
                            ? 'Thanh toán toàn bộ'
                            : 'Đặt cọc giữ phòng')
                      : (isDisbursed
                            ? 'Đã quyết toán cho chủ trọ'
                            : (isLocked
                                  ? 'Chưa nhận phòng'
                                  : (isFullPayment
                                        ? 'Thanh toán đủ • Đã nhận phòng'
                                        : 'Đã cọc • Đã nhận phòng'))))),
        'deadline': timeInfo,
        'hostName': formattedHostName,
        'rawHostName': rawHostName,
        'isLocked': isLocked,
        'isCheckIn': isCheckIn,
        'isDisbursed': isDisbursed,
        'reconciliationDate': _orderReconciliationDate(data, targetTab),
      });
    }

    if (mounted) {
      setState(() {
        _allOrders = orders;
        _hostDropdownItems = dropdownItems;
        if (!_hostDropdownItems.contains(_selectedHostArea)) {
          _selectedHostArea = 'Tất cả chủ trọ';
        }
      });
    }
  }

  void _navigateToSettlementInvoice(List<Map<String, dynamic>> orders) {
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SettlementInvoiceScreen(selectedBookingIds: checkInOrderIds),
      ),
    );
  }

  void _navigateToCancellationInvoice(List<String> bookingIds) {
    if (bookingIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có đơn hủy nào để tạo hóa đơn!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CancellationInvoiceScreen(bookingIds: bookingIds),
      ),
    );
  }

  double _parseToDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  DateTime? _orderReconciliationDate(Map<String, dynamic> data, String status) {
    if (status == 'cancelled') {
      return _asDateTime(data['refundedAt']) ??
          _asDateTime(data['cancellationSettledAt']) ??
          _asDateTime(data['cancelledAt']) ??
          _asDateTime(data['updatedAt']) ??
          _asDateTime(data['createdAt']) ??
          _asDateTime(data['ngayTao']);
    }
    if (data['isDisbursed'] == true) {
      return _asDateTime(data['disbursedAt']) ??
          _asDateTime(data['updatedAt']) ??
          _asDateTime(data['createdAt']) ??
          _asDateTime(data['ngayTao']);
    }
    return _asDateTime(data['createdAt']) ??
        _asDateTime(data['ngayTao']) ??
        _asDateTime(data['bookingDate']);
  }

  @override
  Widget build(BuildContext context) {
    final visibleByHost = _selectedHostArea == 'Tất cả chủ trọ'
        ? _allOrders
        : _allOrders.where((e) => e['hostName'] == _selectedHostArea).toList();

    final selectedDay = DateTime(
      effectiveSelectedDate.year,
      effectiveSelectedDate.month,
      effectiveSelectedDate.day,
    );
    final visibleByDate = _selectedDate == null
        ? visibleByHost
        : visibleByHost.where((item) {
            final date = item['reconciliationDate'] as DateTime?;
            return date != null &&
                date.year == selectedDay.year &&
                date.month == selectedDay.month &&
                date.day == selectedDay.day;
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
        backgroundColor: AdminColors.card,
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
        actions: const [AdminThemeToggle()],
      ),
      body: Column(
        children: [
          // ── Khối 1: Chọn Chủ Trọ (Chuẩn theo ảnh mẫu) ──
          Container(
            color: AdminColors.card,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Chủ trọ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AdminColors.accentSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.real_estate_agent_outlined,
                        size: 22,
                        color: AdminColors.accent,
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
                      color: AdminColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdminColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedHostArea,
                        dropdownColor: AdminColors.card,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: AdminColors.ink,
                        ),
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AdminColors.muted,
                          size: 22,
                        ),
                        items: _hostDropdownItems.map((hName) {
                          return DropdownMenuItem<String>(
                            value: hName,
                            child: Text(
                              hName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: AdminColors.ink,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedHostArea = val;
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

          // ── Khối 2: Ô Tìm Kiếm & Ngày Đối Soát (Gõ mượt mà 100%, không lag/freeze) ──
          Container(
            color: AdminColors.card,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: TextField(
                      key: const ValueKey('admin_orders_search_input'),
                      controller: _searchCtrl,
                      focusNode: _searchFocusNode,
                      onChanged: (val) {
                        _searchQuery.value = val;
                      },
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AdminColors.ink,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Tìm theo Mã HĐ, tên khách, chủ trọ...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: AdminColors.muted,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 20,
                          color: AdminColors.muted,
                        ),
                        suffixIcon: ValueListenableBuilder<String>(
                          valueListenable: _searchQuery,
                          builder: (context, query, _) {
                            if (query.trim().isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return IconButton(
                              icon: Icon(
                                Icons.cancel,
                                size: 18,
                                color: AdminColors.muted,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                _searchQuery.value = '';
                              },
                            );
                          },
                        ),
                        filled: true,
                        fillColor: AdminColors.paper,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AdminColors.border,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AdminColors.border,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AdminColors.accent,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () async {
                    DateTime pickedDate = effectiveSelectedDate;
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => StatefulBuilder(
                        builder: (context, setDialogState) => AlertDialog(
                          title: Text('Ngày đối soát'),
                          contentPadding: const EdgeInsets.fromLTRB(
                            12,
                            8,
                            12,
                            0,
                          ),
                          content: SizedBox(
                            width: 330,
                            child: CalendarDatePicker(
                              initialDate: effectiveSelectedDate,
                              firstDate: DateTime(2025),
                              lastDate: DateTime(2028),
                              onDateChanged: (date) =>
                                  setDialogState(() => pickedDate = date),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: Text('Bỏ lọc'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: Text('Hủy'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: Text('Xong'),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (result != null) {
                      setState(
                        () => _selectedDate = result ? pickedDate : null,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AdminColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AdminColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_month_outlined,
                          size: 19,
                          color: AdminColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Text.rich(
                          TextSpan(
                            text: 'Đối soát: ',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AdminColors.muted,
                            ),
                            children: [
                              TextSpan(
                                text: _selectedDate == null
                                    ? 'Tất cả ngày'
                                    : DateFormat(
                                        'dd/MM/yyyy',
                                      ).format(effectiveSelectedDate),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AdminColors.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Khối 3: Tab Lọc Trạng Thái (Bao gồm Đơn Hủy) ──
          Container(
            color: AdminColors.card,
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: Row(
              children: [
                _buildStatusPill(
                  label: 'Đang xử lý',
                  count: cPending,
                  value: 'pending',
                  dotColor: AdminColors.warning,
                ),
                const SizedBox(width: 4),
                _buildStatusPill(
                  label: 'Đã cọc',
                  count: cDeposit,
                  value: 'deposit_paid',
                  dotColor: AdminColors.accent,
                ),
                const SizedBox(width: 4),
                _buildStatusPill(
                  label: 'Đã trả hết',
                  count: cCompleted,
                  value: 'completed',
                  dotColor: AdminColors.success,
                ),
                const SizedBox(width: 4),
                _buildStatusPill(
                  label: 'Đơn hủy',
                  count: cCancelled,
                  value: 'cancelled',
                  dotColor: AdminColors.danger,
                ),
              ],
            ),
          ),

          // ── Khối 4: Header Phụ Của Danh Sách ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: AdminColors.paper,
              border: Border(
                top: BorderSide(color: AdminColors.border),
                bottom: BorderSide(color: AdminColors.border),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _filter == 'cancelled'
                      ? 'MÃ GD / NGÀY HỦY'
                      : (_filter == 'pending'
                            ? 'MÃ GD / HẠN KHÁCH THUÊ CHUYỂN'
                            : 'MÃ GD / PHÂN LOẠI CỌC'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AdminColors.mutedStrong,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'TRẠNG THÁI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AdminColors.mutedStrong,
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
                final filteredList = visibleByDate.where((item) {
                  if (!_matchesQuery(item, queryText)) return false;
                  return item['status'] == _filter;
                }).toList();

                final checkInOrders = filteredList
                    .where(
                      (e) => e['isCheckIn'] == true && e['isDisbursed'] != true,
                    )
                    .toList();

                double autoCheckInAmount = 0.0;
                for (final item in checkInOrders) {
                  autoCheckInAmount += _parseToDouble(item['deposit']);
                }

                // Tính toán cho tab Đơn Hủy
                double totalCancelDeposit = 0.0;
                if (_filter == 'cancelled') {
                  for (final item in filteredList) {
                    totalCancelDeposit += _parseToDouble(item['deposit']);
                  }
                }
                final int totalRefund = (totalCancelDeposit * 0.85).round();
                final int totalHostComp = (totalCancelDeposit * 0.10).round();

                if (_isLoading && _allOrders.isEmpty) {
                  return Center(
                    child: CircularProgressIndicator(color: AdminColors.accent),
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
                            color: AdminColors.border,
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
                            style: TextStyle(
                              fontSize: 13.5,
                              color: AdminColors.muted,
                            ),
                          ),
                          if (otherMatches.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AdminColors.accentSoft,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AdminColors.border,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Tìm thấy ${otherMatches.length} đơn khớp từ khóa ở mục khác:',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: AdminColors.accentText,
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
                                          label: Text('Xem "Đang xử lý"'),
                                          backgroundColor: AdminColors.card,
                                          onPressed: () => setState(
                                            () => _filter = 'pending',
                                          ),
                                        ),
                                      if (otherMatches.any(
                                        (e) => e['status'] == 'deposit_paid',
                                      ))
                                        ActionChip(
                                          label: Text('Xem "Đã cọc"'),
                                          backgroundColor: AdminColors.card,
                                          onPressed: () => setState(
                                            () => _filter = 'deposit_paid',
                                          ),
                                        ),
                                      if (otherMatches.any(
                                        (e) => e['status'] == 'completed',
                                      ))
                                        ActionChip(
                                          label: Text('Xem "Đã trả hết"'),
                                          backgroundColor: AdminColors.card,
                                          onPressed: () => setState(
                                            () => _filter = 'completed',
                                          ),
                                        ),
                                      if (otherMatches.any(
                                        (e) => e['status'] == 'cancelled',
                                      ))
                                        ActionChip(
                                          label: Text('Xem "Đơn hủy"'),
                                          backgroundColor: AdminColors.card,
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
                              renterName: item['renterName'],
                              roomTitle: item['roomTitle'],
                              hostName: item['hostName'],
                              deposit: _parseToDouble(item['deposit']),
                              deadline: item['deadline'],
                            );
                          } else if (_filter == 'pending') {
                            return _buildPendingOrderCard(
                              id: id,
                              orderCode: item['orderCode'],
                              renterName: item['renterName'],
                              roomTitle: item['roomTitle'],
                              deposit: _parseToDouble(item['deposit']),
                              subTag: item['subTag'],
                              deadline: item['deadline'],
                              note: item['note'],
                              isFullPayment: item['isFullPayment'] == true,
                              onActionPressed: () => _confirmOrder(item),
                            );
                          } else {
                            return _buildDepositOrCompletedCard(
                              id: id,
                              orderCode: item['orderCode'],
                              subTag: item['subTag'],
                              renterName: item['renterName'],
                              roomTitle: item['roomTitle'],
                              hostName: item['hostName'],
                              deposit: _parseToDouble(item['deposit']),
                              status: item['status'],
                              note: item['note'],
                              deadline: item['deadline'],
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
                          color: AdminColors.card,
                          border: Border(
                            top: BorderSide(color: AdminColors.border),
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
                                            color: AdminColors.danger,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Đã tự lọc: ${filteredList.length} đơn hủy',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: AdminColors.dangerInk,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Hoàn khách 85%: ${currencyFormatter.format(totalRefund)}đ • Bồi thường chủ: ${currencyFormatter.format(totalHostComp)}đ',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: AdminColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () {
                                  final ids = filteredList
                                      .map((e) => e['id'] as String)
                                      .toList();
                                  _navigateToCancellationInvoice(ids);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AdminColors.danger,
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
                                  'HÓA ĐƠN HỦY (${filteredList.length})',
                                  style: TextStyle(
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
                          color: AdminColors.card,
                          border: Border(
                            top: BorderSide(color: AdminColors.border),
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
                                                ? AdminColors.success
                                                : AdminColors.warning,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Đã tự lọc: ${checkInOrders.length} đơn đã check-in',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: checkInOrders.isNotEmpty
                                                ? AdminColors.successInk
                                                : AdminColors.warningInk,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Text(
                                          'Tổng giải ngân: ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AdminColors.muted,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            '${currencyFormatter.format(autoCheckInAmount)} đ',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: AdminColors.accentText,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _navigateToSettlementInvoice(filteredList),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AdminColors.accent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
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
                                  'TẠO HÓA ĐƠN (${checkInOrders.length})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
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
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? AdminColors.accent
                : AdminColors.chipIdle,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSelected && dotColor != Colors.transparent) ...[
                      Container(
                        width: 5.5,
                        height: 5.5,
                        decoration: BoxDecoration(
                          color: Color(0xFFFDB022),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 3),
                    ] else if (dotColor == AdminColors.danger) ...[
                      Container(
                        width: 5.5,
                        height: 5.5,
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
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AdminColors.chipIdleLabel,
                      ),
                    ),
                    const SizedBox(width: 3.5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AdminColors.warning
                            : (dotColor == AdminColors.danger
                                  ? AdminColors.dangerContainer
                                  : AdminColors.disabledFill),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : (dotColor == AdminColors.danger
                                    ? AdminColors.dangerInk
                                    : AdminColors.mutedStrong),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Card Đơn Hàng Bị Hủy
  Widget _buildCancelledOrderCard({
    required String orderCode,
    required String renterName,
    required String roomTitle,
    required String hostName,
    required double deposit,
    required String deadline,
  }) {
    final split = BookingUtils.cancellationSplit(deposit);
    final renterRefund = split['refundAmount'] ?? (deposit * 0.85).round();
    final hostCompensation = split['hostAmount'] ?? (deposit * 0.10).round();

    return Container(
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.dangerContainer),
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
                // CỘT 1: Mã GD (tiết đầu tố) & Ngày hủy
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AdminColors.dangerContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminColors.dangerContainer),
                      ),
                      child: Text(
                        orderCode,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AdminColors.danger,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cancel_outlined,
                          size: 13,
                          color: AdminColors.danger,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          deadline,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AdminColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ],
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AdminColors.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.meeting_room_outlined,
                            size: 14,
                            color: AdminColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              roomTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AdminColors.muted,
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
                          style: TextStyle(
                            fontSize: 11,
                            color: AdminColors.muted,
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: AdminColors.dangerContainer,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AdminColors.dangerContainer),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 6, color: AdminColors.danger),
                          SizedBox(width: 4),
                          Text(
                            'Đã hủy',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AdminColors.dangerInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${currencyFormatter.format(deposit)}đ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AdminColors.ink,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Footer Card: Tỷ lệ phân bổ & Nút Hóa Đơn Hủy
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AdminColors.isDark
                  ? AdminColors.dangerContainer
                  : const Color(0xFFFFFBFB),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
              border: Border(top: BorderSide(color: AdminColors.dangerContainer)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: AdminColors.dangerContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Đơn hủy',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AdminColors.danger,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hoàn khách 85% (${currencyFormatter.format(renterRefund)}đ) • Bồi thường chủ 10% (${currencyFormatter.format(hostCompensation)}đ)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.dangerInk,
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
    required String deadline,
    required String note,
    required bool isFullPayment,
    required VoidCallback onActionPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.border),
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
                // CỘT 1: Mã GD (tiết đầu tố) & Hạn
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AdminColors.accentSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AdminColors.border),
                      ),
                      child: Text(
                        orderCode,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AdminColors.accentText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: AdminColors.warning,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          deadline,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AdminColors.warningInk,
                          ),
                        ),
                      ],
                    ),
                  ],
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AdminColors.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.meeting_room_outlined,
                            size: 14,
                            color: AdminColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              roomTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AdminColors.muted,
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
                        color: AdminColors.warningContainer,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AdminColors.warning),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 6, color: AdminColors.warning),
                          SizedBox(width: 4),
                          Text(
                            'Chờ xác nhận',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AdminColors.warningInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${currencyFormatter.format(deposit)}đ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AdminColors.ink,
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
              color: AdminColors.paper,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
              border: Border(top: BorderSide(color: AdminColors.border)),
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
                        ? AdminColors.successContainer
                        : AdminColors.accentSoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isFullPayment ? 'Trả hết' : 'Tiền cọc',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isFullPayment
                          ? AdminColors.successInk
                          : AdminColors.accentText,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note.isNotEmpty ? note : 'Khách đã gửi lệnh chuyển tiền',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AdminColors.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onActionPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColors.accent,
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
                    style: TextStyle(
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
    required String renterName,
    required String roomTitle,
    required String hostName,
    required double deposit,
    required String status,
    required String note,
    required String deadline,
    required bool isFullPayment,
    required bool isLocked,
    required bool isCheckIn,
    required bool isDisbursed,
    required VoidCallback onActionPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCheckIn ? AdminColors.border : AdminColors.border,
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
                // CỘT 1: Mã GD (tiết đầu tố) & Thông tin hẹn vào
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isFullPayment
                            ? AdminColors.successContainer
                            : AdminColors.accentSoft,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isFullPayment
                              ? AdminColors.success
                              : AdminColors.border,
                        ),
                      ),
                      child: Text(
                        orderCode,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isFullPayment
                              ? AdminColors.successInk
                              : AdminColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCheckIn
                              ? Icons.check_circle_outline_rounded
                              : Icons.calendar_today_rounded,
                          size: 13,
                          color: isCheckIn
                              ? AdminColors.success
                              : AdminColors.muted,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          deadline,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isCheckIn
                                ? AdminColors.successInk
                                : AdminColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AdminColors.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.meeting_room_outlined,
                            size: 14,
                            color: AdminColors.muted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              roomTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AdminColors.muted,
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
                          style: TextStyle(
                            fontSize: 11,
                            color: AdminColors.muted,
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
                          color: AdminColors.purpleContainer,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD6BBFB)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 7,
                              color: AdminColors.purple,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Đã giải ngân',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AdminColors.purple,
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
                          color: AdminColors.successContainer,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF6CE9A6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 6,
                              color: AdminColors.success,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Đã check-in',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AdminColors.successInk,
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
                          color: AdminColors.warningContainer,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AdminColors.warning),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 6,
                              color: AdminColors.warning,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Chờ nhận phòng',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AdminColors.warningInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${currencyFormatter.format(deposit)}đ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AdminColors.ink,
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
              color: isCheckIn
                  ? AdminColors.paper
                  : (AdminColors.isDark
                      ? AdminColors.warningContainer
                      : const Color(0xFFFEFBF0)),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(13),
              ),
              border: Border(
                top: BorderSide(
                  color: isCheckIn
                      ? AdminColors.border
                      : AdminColors.warningContainer,
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
                    color: isFullPayment
                        ? AdminColors.successContainer
                        : AdminColors.accentSoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isFullPayment ? 'Cọc hết (100%)' : 'Cọc 1 phần',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isFullPayment
                          ? AdminColors.successInk
                          : AdminColors.accentText,
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
                      color: isDisbursed
                          ? AdminColors.purple
                          : (isCheckIn
                                ? AdminColors.successInk
                                : AdminColors.warningInk),
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
      await FirebaseFirestore.instance.collection('bookings').doc(id).set({
        'status': targetStatus,
        'subTag': targetSubTag,
        'isPaid': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Lấy thông tin booking bổ sung nếu item thiếu hostId
      String hostId = (item['hostId'] ?? '').toString();
      String roomId = (item['roomId'] ?? '').toString();
      String roomCode = (item['roomCode'] ?? '').toString();
      String roomTitle = (item['roomTitle'] ?? 'Phòng trọ').toString();
      String roomFloorInfo = (item['roomFloorInfo'] ?? '').toString();
      dynamic checkInDate = item['checkInDate'];
      final renterId = (item['renterId'] ?? '').toString();

      if (hostId.isEmpty || roomId.isEmpty) {
        final bDoc = await FirebaseFirestore.instance
            .collection('bookings')
            .doc(id)
            .get();
        final bData = bDoc.data() ?? {};
        if (hostId.isEmpty) {
          hostId = (bData['hostId'] ?? bData['chuNhaId'] ?? '').toString();
        }
        if (roomId.isEmpty) {
          roomId = (bData['roomId'] ?? bData['phongId'] ?? '').toString();
        }
        if (roomCode.isEmpty) {
          roomCode = (bData['roomCode'] ?? bData['maPhong'] ?? '').toString();
        }
        if (roomTitle == 'Phòng trọ') {
          roomTitle = (bData['roomTitle'] ??
                  bData['tieuDePhong'] ??
                  'Phòng trọ')
              .toString();
        }
        if (roomFloorInfo.isEmpty) {
          roomFloorInfo =
              (bData['roomFloorInfo'] ?? bData['thongTinTang'] ?? '').toString();
        }
        checkInDate ??= bData['checkInDate'] ??
            bData['ngayNhanPhong'] ??
            bData['checkIn'];
      }

      // 1. Gửi thông báo đến người thuê
      if (renterId.isNotEmpty && renterId != 'guest') {
        await FirebaseFirestore.instance.collection('notifications').add({
          'recipientId': renterId,
          'recipientRole': 'renter',
          'title': isFull
              ? 'Thanh toán thành công'
              : 'Duyệt tiền cọc thành công',
          'body':
              'Admin đã xác nhận $actionText cho phòng "$roomTitle". Bạn có thể chuẩn bị dọn vào ở!',
          'message':
              'Admin đã xác nhận $actionText cho phòng "$roomTitle". Bạn có thể chuẩn bị dọn vào ở!',
          'notificationType': 'booking',
          'bookingId': id,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 2. Cập nhật và đồng bộ thông báo cho Chủ trọ (Role Host)
      final targetType = isFull
          ? HostNotificationType.paymentCompleted
          : HostNotificationType.deposit;
      final targetStatusId = isFull ? 'completed' : 'deposited';
      final hostTitle = isFull
          ? 'Khách đã thanh toán đủ toàn bộ'
          : 'Đã duyệt tiền cọc thành công';
      final hostMessage = isFull
          ? 'Admin đã xác nhận khách ${item['renterName']} thanh toán đủ cho phòng "$roomTitle". Sẵn sàng tiếp nhận check-in.'
          : 'Admin đã duyệt tiền cọc cho khách ${item['renterName']} tại phòng "$roomTitle". Khách sẵn sàng nhận phòng.';

      final hostNotifQuery = await FirebaseFirestore.instance
          .collection('notifications')
          .where('bookingId', isEqualTo: id)
          .get();

      bool hostNotifFound = false;
      for (final doc in hostNotifQuery.docs) {
        final dData = doc.data();
        final rRole = (dData['recipientRole'] ?? '').toString().toLowerCase();
        final recId = (dData['receiverId'] ?? '').toString();
        if (rRole == 'host' ||
            (hostId.isNotEmpty && recId == hostId) ||
            dData.containsKey('roomFloorInfo')) {
          await doc.reference.set({
            'notificationType': targetType.code,
            'type': targetType.code,
            'statusId': targetStatusId,
            'status': targetStatus,
            'title': hostTitle,
            'message': hostMessage,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          hostNotifFound = true;
        }
      }

      // Nếu chưa có thông báo nào cho host về booking này, tạo mới
      if (!hostNotifFound && hostId.isNotEmpty && hostId != 'guest') {
        final hostNotifId = IdGenerator.notification();
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(hostNotifId)
            .set({
              'id': hostNotifId,
              'notificationId': hostNotifId,
              'receiverId': hostId,
              'senderId': renterId,
              'recipientRole': 'host',
              'notificationType': targetType.code,
              'type': targetType.code,
              'title': hostTitle,
              'message': hostMessage,
              'bookingId': id,
              'bookingCode': item['rawOrderCode'] ?? id,
              'roomId': roomId,
              'roomCode': roomCode,
              'roomTitle': roomTitle,
              'roomFloorInfo': roomFloorInfo,
              'amount': item['deposit'] ?? 0.0,
              'statusId': targetStatusId,
              'status': targetStatus,
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
              'renterName': item['renterName'] ?? '',
              'renterAvatarUrl': '',
              'checkInDate': ?checkInDate,
              'paymentMethod': 'Chuyển khoản QR',
            });
      }

      await FirebaseFirestore.instance.collection('audit_logs').add({
        'action': 'Duyệt $actionText',
        'actor': 'Admin',
        'category': 'taiChinh',
        'details':
            'Admin đã xác nhận $actionText cho đơn ${item['orderCode']} của khách ${item['renterName']}. Chuyển vào mục "$targetTabName".',
        'target': 'Đơn $id',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AdminColors.success,
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
            backgroundColor: AdminColors.danger,
            content: Text('Không thể cập nhật đơn. Vui lòng thử lại.'),
          ),
        );
      }
    }
  }
}
