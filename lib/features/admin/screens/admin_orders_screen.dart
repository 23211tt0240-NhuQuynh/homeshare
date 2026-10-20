<<<<<<< HEAD
import 'dart:async';
=======
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
<<<<<<< HEAD
import '../utils/booking_utils.dart';
import '../widgets/admin_branded_title.dart';
import 'cancellation_invoice_screen.dart';
=======
import '../services/admin_service.dart';
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
import 'settlement_invoice_screen.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
<<<<<<< HEAD
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
          if (clean.isNotEmpty)
            return '$hostPrefix-${clean.length > 5 ? clean.substring(clean.length - 4) : clean}';
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
=======
  String _filter = 'all'; // 'all', 'disburse', 'deposit_paid', 'completed'
  String _selectedHostArea = '1-Chủ trọ A (Khu Bình Thạnh)';
  final Set<String> _selectedOrderIds = {'1-X92F'}; // Selected for batch invoice
  final currencyFormatter = NumberFormat('#,###', 'vi_VN');

  // Lưu trạng thái giải ngân tạm thời cho dữ liệu mẫu (Mock Data)
  final Map<String, String> _localStatusOverrides = {};

  final List<Map<String, dynamic>> _mockOrderList = [
    {
      'id': '1-X92F',
      'orderCode': '1-X92F',
      'subTag': 'Đã check-in (12/09)',
      'renterName': 'Lê Hoàng Long',
      'roomTitle': 'Căn Studio 302',
      'deposit': 2000000.0,
      'status': 'deposit_paid',
      'statusLabel': 'Đã thanh toán',
      'note': 'Tiền cọc: Thanh toán đủ tháng 9',
      'hostName': 'Chủ trọ A (Khu Bình Thạnh)',
    },
    {
      'id': '1-7315',
      'orderCode': '1-7315',
      'subTag': 'Chờ check-in',
      'renterName': 'Hoàng Thị Bích Ngọc',
      'roomTitle': 'Gác lửng 205',
      'deposit': 800000.0,
      'status': 'disburse',
      'statusLabel': 'Chờ nhận phòng',
      'note': 'Khách chưa check-in nhận phòng',
      'hostName': 'Chủ trọ A (Khu Bình Thạnh)',
    },
    {
      'id': '1-0482',
      'orderCode': '1-0482',
      'subTag': 'Chờ xác nhận',
      'renterName': 'Nguyễn Văn Nam',
      'roomTitle': 'Phòng 201 - Bình Thạnh',
      'deposit': 1000000.0,
      'status': 'disburse',
      'statusLabel': 'Xác nhận tiền cọc',
      'note': 'Tiền cọc: Đặt cọc giữ chỗ',
      'hostName': 'Chủ trọ A (Khu Bình Thạnh)',
    },
    {
      'id': '1-5821',
      'orderCode': '1-5821',
      'subTag': 'Chờ xác nhận',
      'renterName': 'Trần Thị Mai',
      'roomTitle': 'Phòng 104 - Bình Thạnh',
      'deposit': 500000.0,
      'status': 'deposit_paid',
      'statusLabel': 'Đã thanh toán',
      'note': 'Tiền cọc: Cọc bảo đảm nhận phòng',
      'hostName': 'Chủ trọ A (Khu Bình Thạnh)',
    },
    {
      'id': '1-0490',
      'orderCode': '1-0490',
      'subTag': 'Hạn 23:59',
      'renterName': 'Phạm Minh Tuấn',
      'roomTitle': 'Phòng 402 - Bình Thạnh',
      'deposit': 1500000.0,
      'status': 'disburse',
      'statusLabel': 'Xác nhận tiền cọc',
      'note': 'Tiền cọc: Đặt cọc giữ chỗ',
      'hostName': 'Chủ trọ A (Khu Bình Thạnh)',
    },
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _navigateToSettlementInvoice(double totalAmount) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettlementInvoiceScreen(
          hostName: _selectedHostArea,
          hostAccountNumber: '0388529900',
          hostBankName: 'MB Bank',
          netSettlement: totalAmount > 0 ? (totalAmount * 0.9) : 3750000.0,
          totalDeposit: totalAmount > 0 ? totalAmount : 4100000.0,
          platformFee: totalAmount > 0 ? (totalAmount * 0.1) : 350000.0,
        ),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
      ),
    );
  }

<<<<<<< HEAD
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
=======
  @override
  Widget build(BuildContext context) {
    // Calculate total selected amount
    double totalSelectedAmount = 0.0;
    for (var item in _mockOrderList) {
      if (_selectedOrderIds.contains(item['id'])) {
        totalSelectedAmount += (item['deposit'] as num).toDouble();
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
<<<<<<< HEAD
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
                        value: _selectedHostArea,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF667085),
                          size: 22,
                        ),
                        items: _hostDropdownItems.map((hName) {
                          return DropdownMenuItem<String>(
                            value: hName,
                            child: Text(
                              hName,
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
            color: Colors.white,
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF101828),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Tìm theo Mã HĐ, tên khách, chủ trọ...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF98A2B3),
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 20,
                          color: Color(0xFF667085),
                        ),
                        suffixIcon: ValueListenableBuilder<String>(
                          valueListenable: _searchQuery,
                          builder: (context, query, _) {
                            if (query.trim().isEmpty)
                              return const SizedBox.shrink();
                            return IconButton(
                              icon: const Icon(
                                Icons.cancel,
                                size: 18,
                                color: Color(0xFF98A2B3),
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                _searchQuery.value = '';
                              },
                            );
                          },
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFD0D5DD),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFD0D5DD),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF398FC0),
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
                          title: const Text('Ngày đối soát'),
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
                              child: const Text('Bỏ lọc'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Hủy'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Xong'),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD0D5DD)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_month_outlined,
                          size: 19,
                          color: Color(0xFF475467),
                        ),
                        const SizedBox(width: 6),
                        Text.rich(
                          TextSpan(
                            text: 'Đối soát: ',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF475467),
                            ),
                            children: [
                              TextSpan(
                                text: _selectedDate == null
                                    ? 'Tất cả ngày'
                                    : DateFormat(
                                        'dd/MM/yyyy',
                                      ).format(effectiveSelectedDate),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF101828),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
=======
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF101828)),
          onPressed: () {},
        ),
        title: const Text(
          'QUẢN LÝ ĐƠN',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF101828),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. Host Area Dropdown Selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEAECF0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedHostArea,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF155EEF)),
                  items: [
                    '1-Chủ trọ A (Khu Bình Thạnh)',
                    '2-Chủ trọ B (Khu Quận 10)',
                    '3-Chủ trọ C (Khu Cầu Giấy)',
                  ].map((value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Row(
                        children: [
                          const Icon(Icons.home_work_outlined, size: 18, color: Color(0xFF155EEF)),
                          const SizedBox(width: 8),
                          Text(
                            value,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF101828),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedHostArea = val);
                    }
                  },
                ),
              ),
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
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF98A2B3)),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF667085)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF667085)),
                      SizedBox(width: 4),
                      Text('16/09/2026', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475467))),
                    ],
                  ),
                ),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
              ],
            ),
          ),

<<<<<<< HEAD
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
=======
          // 3. Tab Filter Chips (Đang xử lý, Đã cọc, Đã trả hết)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
            child: Row(
              children: [
                _buildStatusPill('Đang xử lý (3)', 'disburse', const Color(0xFFF79009)),
                const SizedBox(width: 8),
                _buildStatusPill('Đã cọc (2)', 'deposit_paid', const Color(0xFF155EEF)),
                const SizedBox(width: 8),
                _buildStatusPill('Đã trả hết', 'completed', const Color(0xFF027A48)),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
              ],
            ),
          ),

<<<<<<< HEAD
          // ── Khối 4: Header Phụ Của Danh Sách ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: const BoxDecoration(
              color: Color(0xFFF4F9FF),
              border: Border(
                top: BorderSide(color: Color(0xFFDCEAF5)),
                bottom: BorderSide(color: Color(0xFFDCEAF5)),
=======
          // 4. Header Bar (MÃ CỌC / TÊN KHÁCH THUÊ | TRẠNG THÁI)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF2F4F7),
              border: Border(
                top: BorderSide(color: Color(0xFFEAECF0)),
                bottom: BorderSide(color: Color(0xFFEAECF0)),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
<<<<<<< HEAD
              children: [
                Text(
                  _filter == 'cancelled'
                      ? 'MÃ GD / NGÀY HỦY'
                      : (_filter == 'pending'
                            ? 'MÃ GD / HẠN KHÁCH THUÊ CHUYỂN'
                            : 'MÃ GD / PHÂN LOẠI CỌC'),
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
=======
              children: const [
                Text(
                  'MÃ CỌC / KHÁCH CHUYỂN',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF667085), letterSpacing: 0.3),
                ),
                Text(
                  'TRẠNG THÁI',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF667085), letterSpacing: 0.3),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                ),
              ],
            ),
          ),

<<<<<<< HEAD
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
=======
          // 5. Orders Stream & List View
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('bookings').snapshots(),
              builder: (context, snapshot) {
                // Show loading indicator while Firestore initializes (prevents white screen)
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF155EEF),
                      strokeWidth: 2.5,
                    ),
                  );
                }

                // Show error state if Firestore fails
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_outlined,
                              size: 40, color: Color(0xFF98A2B3)),
                          const SizedBox(height: 8),
                          const Text(
                            'Không thể tải dữ liệu từ máy chủ',
                            style: TextStyle(
                                color: Color(0xFF667085), fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                        ],
                      ),
                    ),
                  );
                }

<<<<<<< HEAD
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
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFD92D20),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Đã tự lọc: ${filteredList.length} đơn hủy',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFB42318),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Hoàn khách 85%: ${currencyFormatter.format(totalRefund)}đ • Bồi thường chủ: ${currencyFormatter.format(totalHostComp)}đ',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF475467),
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
                                  'HÓA ĐƠN HỦY (${filteredList.length})',
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
                                        Text(
                                          'Đã tự lọc: ${checkInOrders.length} đơn đã check-in',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: checkInOrders.isNotEmpty
                                                ? const Color(0xFF027A48)
                                                : const Color(0xFFB54708),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        const Text(
                                          'Tổng giải ngân: ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF475467),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            '${currencyFormatter.format(autoCheckInAmount)} đ',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF398FC0),
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
                                  backgroundColor: const Color(0xFF398FC0),
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
                                  style: const TextStyle(
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
=======
                final firestoreDocs = snapshot.data?.docs ?? [];
                final query = _searchCtrl.text.trim().toUpperCase();

                // Merge with Mock Data for full interactive showcase
                final items = _mockOrderList.where((item) {
                  final code = (item['orderCode'] as String).toUpperCase();
                  final name = (item['renterName'] as String).toUpperCase();
                  final title = (item['roomTitle'] as String).toUpperCase();
                  final matchesQuery = query.isEmpty || code.contains(query) || name.contains(query) || title.contains(query);
                  if (!matchesQuery) return false;

                  final status = _localStatusOverrides[item['id']] ?? item['status'];
                  if (_filter == 'all') return true;
                  return status == _filter;
                }).toList();

                if (items.isEmpty && firestoreDocs.isEmpty) {
                  return const Center(
                    child: Text('Không có đơn nào phù hợp với bộ lọc', style: TextStyle(color: Color(0xFF667085))),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final id = item['id'] as String;
                    final isChecked = _selectedOrderIds.contains(id);
                    final effectiveStatus = _localStatusOverrides[id] ?? item['status'];

                    return _buildOrderItemCard(
                      id: id,
                      orderCode: item['orderCode'],
                      subTag: item['subTag'],
                      renterName: item['renterName'],
                      roomTitle: item['roomTitle'],
                      deposit: item['deposit'],
                      status: effectiveStatus,
                      statusLabel: item['statusLabel'],
                      note: item['note'],
                      isChecked: isChecked,
                      onToggleCheck: () {
                        setState(() {
                          if (isChecked) {
                            _selectedOrderIds.remove(id);
                          } else {
                            _selectedOrderIds.add(id);
                          }
                        });
                      },
                      onActionPressed: () {
                        setState(() {
                          _localStatusOverrides[id] = 'completed';
                        });
                        ref.read(adminServiceProvider).approveBookingDisbursement(
                              bookingId: id,
                              orderCode: item['orderCode'],
                              hostName: item['renterName'],
                              amount: item['deposit'],
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF12B76A),
                            content: Text('Đã xác nhận thanh toán đơn ${item['orderCode']}!'),
                          ),
                        );
                      },
                    );
                  },
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                );
              },
            ),
          ),
<<<<<<< HEAD
=======

          // 6. Bottom Sticky Invoice Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: Color(0xFFEAECF0))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Đã chọn: ${_selectedOrderIds.length} đơn',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF667085)),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Text('Tổng thanh toán: ', style: TextStyle(fontSize: 11, color: Color(0xFF475467))),
                          Text(
                            '${currencyFormatter.format(totalSelectedAmount > 0 ? totalSelectedAmount : 2000000)} đ',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF155EEF),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () => _navigateToSettlementInvoice(totalSelectedAmount),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF155EEF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'TẠO HÓA ĐƠN ➔',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
        ],
      ),
    );
  }

<<<<<<< HEAD
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
=======
  Widget _buildStatusPill(String label, String value, Color activeColor) {
    final isSelected = _filter == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filter = isSelected ? 'all' : value),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : const Color(0xFFEAECF0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? activeColor : const Color(0xFF475467),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderItemCard({
    required String id,
    required String orderCode,
    required String subTag,
    required String renterName,
    required String roomTitle,
    required double deposit,
    required String status,
    required String statusLabel,
    required String note,
    required bool isChecked,
    required VoidCallback onToggleCheck,
    required VoidCallback onActionPressed,
  }) {
    final isDone = status == 'completed';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isChecked ? const Color(0xFF155EEF) : const Color(0xFFEAECF0),
          width: isChecked ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: onToggleCheck,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isChecked ? const Color(0xFF155EEF) : Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isChecked ? const Color(0xFF155EEF) : const Color(0xFFD0D5DD),
                    ),
                  ),
                  child: isChecked
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF8FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  orderCode,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF155EEF)),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  subTag,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF027A48)),
                ),
              ),
              const Spacer(),
              Text(
                '${currencyFormatter.format(deposit)} đ',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF101828),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                ),
              ),
            ],
          ),
<<<<<<< HEAD
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECDCA)),
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
                        color: const Color(0xFFFEF3F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECDCA)),
                      ),
                      child: Text(
                        orderCode,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFD92D20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cancel_outlined,
                          size: 13,
                          color: Color(0xFFD92D20),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          deadline,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD92D20),
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
                            'Đã hủy',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB42318),
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

          // Footer Card: Tỷ lệ phân bổ & Nút Hóa Đơn Hủy
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFFFFBFB),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
              border: Border(top: BorderSide(color: Color(0xFFFECDCA))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3F2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Đơn hủy',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD92D20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hoàn khách 85% (${currencyFormatter.format(renterRefund)}đ) • Bồi thường chủ 10% (${currencyFormatter.format(hostCompensation)}đ)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB42318),
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
                        color: const Color(0xFFE9F5FC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFB2DDFF)),
                      ),
                      child: Text(
                        orderCode,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF398FC0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: Color(0xFFF79009),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          deadline,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB54708),
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
=======
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 28.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      renterName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF101828)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      roomTitle,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF667085)),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: onActionPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDone ? const Color(0xFFF2F4F7) : const Color(0xFF155EEF),
                    foregroundColor: isDone ? const Color(0xFF475467) : Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: Text(
                    isDone ? 'Đã thanh toán' : statusLabel,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
                  ),
                ),
              ],
            ),
          ),
<<<<<<< HEAD
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
                            ? const Color(0xFFECFDF3)
                            : const Color(0xFFE9F5FC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isFullPayment
                              ? const Color(0xFFA6F4C5)
                              : const Color(0xFFB2DDFF),
                        ),
                      ),
                      child: Text(
                        orderCode,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isFullPayment
                              ? const Color(0xFF027A48)
                              : const Color(0xFF398FC0),
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
                              ? const Color(0xFF12B76A)
                              : const Color(0xFF667085),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          deadline,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isCheckIn
                                ? const Color(0xFF027A48)
                                : const Color(0xFF475467),
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
                          color: const Color(0xFFF9F5FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFD6BBFB)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 7,
                              color: Color(0xFF6941C6),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Đã giải ngân',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF6941C6),
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
                          color: const Color(0xFFFEF0C7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFEDF89)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 6,
                              color: Color(0xFFF79009),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Chờ nhận phòng',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB54708),
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
              color: isCheckIn
                  ? const Color(0xFFF4F9FF)
                  : const Color(0xFFFEFBF0),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(13),
              ),
              border: Border(
                top: BorderSide(
                  color: isCheckIn
                      ? const Color(0xFFDCEAF5)
                      : const Color(0xFFFEF0C7),
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
                        ? const Color(0xFFECFDF3)
                        : const Color(0xFFE9F5FC),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isFullPayment ? 'Cọc hết (100%)' : 'Cọc 1 phần',
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
                          ? const Color(0xFF6941C6)
                          : (isCheckIn
                                ? const Color(0xFF027A48)
                                : const Color(0xFFB54708)),
                    ),
                  ),
                ),
              ],
=======
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 28.0),
            child: Text(
              note,
              style: const TextStyle(fontSize: 11, color: Color(0xFF98A2B3)),
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
            ),
          ),
        ],
      ),
    );
  }
<<<<<<< HEAD

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
=======
}
>>>>>>> abc92fb4245a835e7551085a84e6ad76a154ce62
