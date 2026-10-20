import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/booking_service.dart';
import 'settlement_invoice_screen.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = 'disburse'; // 'disburse', 'deposit_paid', 'completed'
  String _selectedHostArea = 'Tất cả chủ trọ';
  final Set<String> _selectedOrderIds = {};
  DateTime? _selectedDate;
  DateTime get effectiveSelectedDate => _selectedDate ?? DateTime.now();

  final currencyFormatter = NumberFormat('#,###', 'vi_VN');

  bool _isSeeding = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _checkAndSeedInitialOrders();
  }

  Future<void> _checkAndSeedInitialOrders() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('bookings').limit(1).get();
      if (snap.docs.isEmpty && !_isSeeding) {
        _isSeeding = true;
        final now = DateTime.now();
        final seedBookings = [
          // 3 đơn Đang xử lý (Chờ xác nhận) như hình thiết kế
          {
            'maDon': '1-8492',
            'maNguoiDung': '8492',
            'tenNguoiO': 'Nguyễn Văn Nam',
            'sdtNguoiO': '0912345678',
            'tieuDePhong': 'Phòng 201 - Bình Thạnh',
            'diaChiPhong': '201 Ung Văn Khiêm, P.25, Q.Bình Thạnh, TP.HCM',
            'giaThue': 3500000.0,
            'tienCoc': 1000000.0,
            'tongPhaiTra': 1000000.0,
            'trangThai': 'choXacNhan',
            'moTa': 'Chờ xác nhận',
            'daThanhToan': false,
            'hinhThucThanhToan': 'deposit',
            'ghiChuChuyenKhoan': '8492',
            'hanChuyen': 'Còn 15p',
            'ghiChu': 'Đặt cọc giữ phòng',
            'tenChuNha': 'Chủ trọ A (Khu Bình Thạnh)',
            'ngayTao': Timestamp.fromDate(now.subtract(const Duration(minutes: 10))),
          },
          {
            'maDon': '1-5821',
            'maNguoiDung': '5821',
            'tenNguoiO': 'Trần Thị Mai',
            'sdtNguoiO': '0987654321',
            'tieuDePhong': 'Phòng 104 - Bình Thạnh',
            'diaChiPhong': '104 D2, P.25, Q.Bình Thạnh, TP.HCM',
            'giaThue': 2800000.0,
            'tienCoc': 500000.0,
            'tongPhaiTra': 500000.0,
            'trangThai': 'choXacNhan',
            'moTa': 'Chờ xác nhận',
            'daThanhToan': false,
            'hinhThucThanhToan': 'deposit',
            'ghiChuChuyenKhoan': '5821',
            'hanChuyen': 'Còn 45p',
            'ghiChu': 'Cọc bảo đảm nhận phòng',
            'tenChuNha': 'Chủ trọ A (Khu Bình Thạnh)',
            'ngayTao': Timestamp.fromDate(now.subtract(const Duration(minutes: 25))),
          },
          {
            'maDon': '1-B490',
            'maNguoiDung': 'B490',
            'tenNguoiO': 'Phạm Minh Tuấn',
            'sdtNguoiO': '0901234567',
            'tieuDePhong': 'Phòng 402 - Bình Thạnh',
            'diaChiPhong': '402 Xô Viết Nghệ Tĩnh, Q.Bình Thạnh, TP.HCM',
            'giaThue': 4200000.0,
            'tienCoc': 1500000.0,
            'tongPhaiTra': 1500000.0,
            'trangThai': 'choXacNhan',
            'moTa': 'Chờ xác nhận',
            'daThanhToan': false,
            'hinhThucThanhToan': 'deposit',
            'ghiChuChuyenKhoan': 'B490',
            'hanChuyen': '23:59',
            'ghiChu': 'Đặt cọc giữ chỗ',
            'tenChuNha': 'Chủ trọ A (Khu Bình Thạnh)',
            'ngayTao': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
          },
          // 5 đơn Đã cọc để khớp số lượng "Đã cọc 5" trong hình thiết kế
          for (var i = 1; i <= 5; i++)
            {
              'maDon': '1-DC0$i',
              'maNguoiDung': 'DC0$i',
              'tenNguoiO': 'Khách cọc #$i',
              'sdtNguoiO': '090333444$i',
              'tieuDePhong': 'Phòng 30$i - Bình Thạnh',
              'diaChiPhong': 'Bình Thạnh, TP.HCM',
              'giaThue': 3000000.0,
              'tienCoc': 1000000.0,
              'tongPhaiTra': 1000000.0,
              'trangThai': 'daCoc',
              'moTa': 'Đã cọc',
              'daThanhToan': true,
              'daNhanPhong': i > 2,
              'hinhThucThanhToan': 'deposit',
              'ghiChuChuyenKhoan': 'DC0$i',
              'ghiChu': i > 2 ? 'Đã nhận phòng' : 'Chưa nhận phòng',
              'tenChuNha': 'Chủ trọ A (Khu Bình Thạnh)',
              'ngayTao': Timestamp.fromDate(now.subtract(Duration(days: i))),
            },
        ];

        final batch = FirebaseFirestore.instance.batch();
        for (var item in seedBookings) {
          final maDon = (item['maDon'] as String?)?.isNotEmpty == true
              ? (item['maDon'] as String)
              : 'DP_SEED_${DateTime.now().millisecondsSinceEpoch}';
          final doc = FirebaseFirestore.instance.collection('bookings').doc(maDon);
          batch.set(doc, item);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Firestore seed bookings error: $e');
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _navigateToSettlementInvoice() {
    if (_selectedOrderIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất 1 đơn để tạo hóa đơn!')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettlementInvoiceScreen(
          hostName: _selectedHostArea,
          hostAccountNumber: '0398829999',
          hostBankName: 'MB Bank',
        ),
      ),
    );
  }

  double _parseToDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  // Phân loại trạng thái đơn đặt phòng chuẩn hóa
  String _determineStatus(Map<String, dynamic> data) {
    try {
      final raw = (data['trangThai'] ?? data['status'] ?? '').toString().trim().toLowerCase();

      if (raw == 'cancelled' || raw == 'dahuy' || raw == 'da_huy' || raw == 'tuchoi' || raw == 'rejected') {
        return 'cancelled';
      }
      if (raw == 'active' || raw == 'dango' || raw == 'dang_o' || raw == 'danhanphong' || data['daNhanPhong'] == true) {
        return 'active';
      }
      if (raw == 'completed' || raw == 'dagiaingan' || raw == 'dathanhtoan' || raw == 'full_paid' ||
          data['daHoanTat'] == true || data['isCompleted'] == true || data['disbursedAt'] != null || data['ngayGiaiNgan'] != null) {
        return 'completed';
      }
      if (raw == 'deposit_paid' || raw == 'paid' || raw == 'approved' ||
          raw == 'daduyet' || raw == 'da_duyet' || raw == 'dacoc' || ((data['daThanhToan'] == true || data['isPaid'] == true) && data['isCompleted'] != true && data['daHoanTat'] != true)) {
        return 'deposit_paid';
      }
      if (raw == 'disburse' || raw == 'pending_confirmation' || raw == 'choxacnhan' ||
          raw == 'pending' || raw == 'choduyet' || raw == 'cho_duyet' || raw == 'pending_payment' || raw == 'dangxuly') {
        return 'disburse';
      }
      return 'disburse';
    } catch (_) {}
    return 'disburse';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF101828)),
          onPressed: () => Navigator.maybePop(context),
        ),
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        toolbarHeight: 64,
        title: const Text(
          'QUẢN LÝ ĐƠN',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF101828),
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: false,
      ),
      // Outer: stream users để lấy TOÀN BỘ chủ trọ
      body: StreamBuilder<QuerySnapshot>(
        stream: () {
          try {
            return FirebaseFirestore.instance.collection('users').snapshots();
          } catch (_) {
            return const Stream<QuerySnapshot>.empty();
          }
        }(),
        builder: (context, userSnapshot) {
          // Inner: stream bookings để lấy đơn hàng thực tế
          return StreamBuilder<QuerySnapshot>(
            stream: () {
              try {
                return FirebaseFirestore.instance.collection('bookings').snapshots();
              } catch (_) {
                return const Stream<QuerySnapshot>.empty();
              }
            }(),
            builder: (context, bookingSnapshot) {
              final userDocs = userSnapshot.data?.docs ?? [];
              final bookingDocs = bookingSnapshot.data?.docs ?? [];

              // ── Bước 1: Xây dựng danh sách chủ trọ từ collection 'users' ──
              // Gắn tiết đầu tố bắt buộc (1-, 2-, 3-...) theo thứ tự xuất hiện
              final Map<String, String> hostPrefixMap = {}; // rawName -> "N-rawName"
              final List<String> hostDropdownItems = ['Tất cả chủ trọ'];
              int hostCounter = 1;

              for (final uDoc in userDocs) {
                final uData = uDoc.data() as Map<String, dynamic>? ?? {};
                final role = (uData['vaiTro'] ?? uData['role'] ?? '').toString().toLowerCase();
                if (role == 'host' || role == 'landlord' || role == 'chutro') {
                  final hName = (uData['hoTen'] ?? uData['fullName'] ?? uData['name'] ?? uData['ten'] ?? '').toString().trim();
                  if (hName.isEmpty || hName == 'Tất cả chủ trọ') continue;
                  if (!hostPrefixMap.containsKey(hName)) {
                    if (RegExp(r'^\d+-').hasMatch(hName)) {
                      hostPrefixMap[hName] = hName;
                    } else {
                      hostPrefixMap[hName] = '$hostCounter-$hName';
                      hostCounter++;
                    }
                    hostDropdownItems.add(hostPrefixMap[hName]!);
                  }
                }
              }

              // ── Bước 2: Xây dựng danh sách đơn từ 'bookings' ──
              final List<Map<String, dynamic>> orderList = [];

              for (final doc in bookingDocs) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                final docId = doc.id;
                final status = _determineStatus(data);

                final rawHostName = (data['tenChuNha'] ?? data['hostName'] ?? data['landlordName'] ?? 'Chủ trọ').toString().trim();

                // Nếu chủ trọ này chưa có trong map (VD: mới thêm đơn thủ công trên Firebase)
                // thì vẫn tự sinh tiết đầu tố để không bị mất
                if (rawHostName.isNotEmpty && rawHostName != 'Tất cả chủ trọ') {
                  if (!hostPrefixMap.containsKey(rawHostName)) {
                    if (RegExp(r'^\d+-').hasMatch(rawHostName)) {
                      hostPrefixMap[rawHostName] = rawHostName;
                    } else {
                      hostPrefixMap[rawHostName] = '$hostCounter-$rawHostName';
                      hostCounter++;
                    }
                    if (!hostDropdownItems.contains(hostPrefixMap[rawHostName]!)) {
                      hostDropdownItems.add(hostPrefixMap[rawHostName]!);
                    }
                  }
                }

                final formattedHostName = hostPrefixMap[rawHostName] ?? rawHostName;
                final isCheckIn = data['daNhanPhong'] == true || data['isCheckIn'] == true;
                final isLocked = data['isLocked'] == true ||
                    (status == 'deposit_paid' && !isCheckIn);

                final paymentOption = (data['hinhThucThanhToan'] ?? data['paymentOption'] ?? data['paymentType'] ?? 'deposit').toString().toLowerCase();
                final isFullPayment = paymentOption == 'full' || paymentOption == 'toanbo' || paymentOption == 'trahet';
                final amount = _parseToDouble(isFullPayment
                    ? (data['paymentAmount'] ?? data['totalAmount'] ?? data['roomPrice'] ?? data['giaPhong'] ?? data['rentalPrice'] ?? data['giaThue'] ?? data['price'])
                    : (data['deposit'] ?? data['tienCoc'] ?? data['depositAmount'] ?? data['paymentAmount'] ?? data['soTienThanhToan']));

                // Mã đơn — gắn tiết đầu tố tương ứng (ưu tiên maDon, orderCode, ghiChuChuyenKhoan, maNguoiDung, transferNote, userCode)
                String rawCode = (data['maDon'] ?? data['orderCode'] ?? data['bookingCode'] ?? data['ghiChuChuyenKhoan'] ?? data['maNguoiDung'] ?? data['transferNote'] ?? data['userCode'] ?? data['renterUserCode'] ??
                        (docId.length > 6 ? docId.substring(0, 6) : docId))
                    .toString()
                    .toUpperCase();
                if (!RegExp(r'^\d+-').hasMatch(rawCode)) {
                  final prefix = formattedHostName.contains('-')
                      ? formattedHostName.split('-').first
                      : '1';
                  rawCode = '$prefix-$rawCode';
                }

                orderList.add({
                  'id': docId,
                  'orderCode': rawCode,
                  'userCode': data['maNguoiDung'] ?? data['userCode'] ?? data['renterUserCode'] ?? data['ghiChuChuyenKhoan'] ?? data['transferNote'] ?? '',
                  'renterId': data['nguoiDungId'] ?? data['nguoiDung_Id'] ?? data['renterId'] ?? data['khachXemId'] ?? '',
                  'subTag': data['moTa']?.toString() ?? data['subTag']?.toString() ??
                      (status == 'disburse'
                          ? 'Chờ xác nhận'
                          : (isCheckIn ? 'Đã check-in' : 'Chờ check-in')),
                  'renterName': (data['tenNguoiO'] ?? data['renterName'] ?? data['userName'] ?? 'Khách thuê').toString(),
                  'roomTitle': (data['tieuDePhong'] ?? data['roomTitle'] ?? 'Phòng trọ').toString(),
                  'deposit': amount,
                  'status': status,
                  'isFullPayment': isFullPayment,
                  'paymentOption': paymentOption,
                  'note': data['ghiChu']?.toString() ?? data['note']?.toString() ??
                      (status == 'disburse'
                          ? (isFullPayment ? 'Thanh toán toàn bộ (không tính cọc)' : 'Đặt cọc giữ phòng')
                          : (isLocked ? 'Chưa nhận phòng' : (isFullPayment ? 'Thanh toán đủ (không tính cọc)' : 'Đã đặt cọc'))),
                  'deadline': data['hanChuyen']?.toString() ?? data['deadline']?.toString() ?? 'Còn 15p',
                  'hostName': formattedHostName,
                  'rawHostName': rawHostName,
                  'isLocked': isLocked,
                  'isCheckIn': isCheckIn,
                });
              }

              // Reset về "Tất cả chủ trọ" nếu host đang chọn đã bị xóa khỏi Firebase
              if (!hostDropdownItems.contains(_selectedHostArea)) {
                _selectedHostArea = 'Tất cả chủ trọ';
              }

              // ── Bước 3: Đếm số lượng đơn thực tế theo host đang chọn ──
              final visibleByHost = _selectedHostArea == 'Tất cả chủ trọ'
                  ? orderList
                  : orderList.where((e) => e['hostName'] == _selectedHostArea).toList();

              final cDisburse = visibleByHost.where((e) => e['status'] == 'disburse').length;
              final cDeposit = visibleByHost.where((e) => e['status'] == 'deposit_paid').length;
              final cCompleted = visibleByHost.where((e) => e['status'] == 'completed').length;
              final cActive = visibleByHost.where((e) => e['status'] == 'active').length;
              final cCancelled = visibleByHost.where((e) => e['status'] == 'cancelled').length;

              // ── Bước 4: Lọc danh sách hiển thị theo search + host + tab ──
              final query = _searchCtrl.text.trim().toUpperCase();
              final filteredList = orderList.where((item) {
                final code = (item['orderCode'] as String).toUpperCase();
                final name = (item['renterName'] as String).toUpperCase();
                final host = (item['hostName'] as String).toUpperCase();

                final matchesQuery = query.isEmpty ||
                    code.contains(query) ||
                    name.contains(query) ||
                    host.contains(query);
                if (!matchesQuery) return false;

                final matchesHost = _selectedHostArea == 'Tất cả chủ trọ' ||
                    item['hostName'] == _selectedHostArea;
                if (!matchesHost) return false;

                return item['status'] == _filter;
              }).toList();

              double totalSelectedAmount = 0.0;
              for (final item in orderList) {
                if (_selectedOrderIds.contains(item['id'])) {
                  totalSelectedAmount += _parseToDouble(item['deposit']);
                }
              }

              return Column(
                children: [
                  // 1. Dropdown Chủ trọ
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 2, bottom: 5),
                          child: Text(
                            'Chủ trọ:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF667085),
                            ),
                          ),
                        ),
                        Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFEAECF0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: _selectedHostArea,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF667085), size: 24),
                              items: hostDropdownItems.map((hName) {
                                return DropdownMenuItem<String>(
                                  value: hName,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF155EEF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.home_rounded,
                                            size: 18, color: Colors.white),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          hName,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF101828),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedHostArea = val;
                                    _selectedOrderIds.clear();
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Tìm kiếm & Ngày đối soát
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (val) => setState(() {}),
                              style: const TextStyle(fontSize: 15, color: Color(0xFF101828)),
                              decoration: InputDecoration(
                                hintText: 'Tìm theo Mã HĐ, tên khách, chủ trọ...',
                                hintStyle:
                                    const TextStyle(fontSize: 13.5, color: Color(0xFF98A2B3)),
                                prefixIcon:
                                    const Icon(Icons.search, size: 22, color: Color(0xFF667085)),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFEAECF0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFFEAECF0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      const BorderSide(color: Color(0xFF155EEF), width: 1.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: effectiveSelectedDate,
                              firstDate: DateTime(2025),
                              lastDate: DateTime(2028),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFEAECF0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month_outlined,
                                    size: 18, color: Color(0xFFD92D20)),
                                const SizedBox(width: 6),
                                Text(
                                  'Đối soát: ${DateFormat('dd/MM/yyyy').format(effectiveSelectedDate)}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF344054)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. Tab lọc trạng thái — hiển thị số lượng đơn thực tế (5 trạng thái)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildStatusPill(
                            label: 'Chờ duyệt',
                            count: cDisburse,
                            value: 'disburse',
                            dotColor: const Color(0xFFF79009),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusPill(
                            label: 'Đã cọc',
                            count: cDeposit,
                            value: 'deposit_paid',
                            dotColor: const Color(0xFF155EEF),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusPill(
                            label: 'Đã trả hết',
                            count: cCompleted,
                            value: 'completed',
                            dotColor: const Color(0xFF7F56D9),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusPill(
                            label: 'Đang ở',
                            count: cActive,
                            value: 'active',
                            dotColor: const Color(0xFF12B76A),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusPill(
                            label: 'Đã hủy',
                            count: cCancelled,
                            value: 'cancelled',
                            dotColor: const Color(0xFFD92D20),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 4. SubHeader
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF2F4F7),
                      border: Border(
                        top: BorderSide(color: Color(0xFFEAECF0)),
                        bottom: BorderSide(color: Color(0xFFEAECF0)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _filter == 'disburse'
                              ? 'MÃ GD / HẠN KHÁCH THUÊ CHUYỂN'
                              : 'MÃ GD / TRẠNG THÁI ĐƠN',
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF667085),
                              letterSpacing: 0.3),
                        ),
                        const Text(
                          'TRẠNG THÁI',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF667085),
                              letterSpacing: 0.3),
                        ),
                      ],
                    ),
                  ),

                  // 5. Danh sách đơn hàng
                  Expanded(
                    child: filteredList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox_outlined,
                                    size: 52, color: Colors.grey.shade400),
                                const SizedBox(height: 10),
                                const Text(
                                  'Không có đơn hàng nào trong danh mục này',
                                  style:
                                      TextStyle(fontSize: 14, color: Color(0xFF667085)),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(14),
                            itemCount: filteredList.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = filteredList[index];
                              final id = item['id'] as String;
                              final isChecked = _selectedOrderIds.contains(id);

                              if (_filter == 'disburse') {
                                return _buildPendingOrderCard(
                                  id: id,
                                  orderCode: item['orderCode'],
                                  renterName: item['renterName'],
                                  roomTitle: item['roomTitle'],
                                  deposit: item['deposit'],
                                  subTag: item['subTag'],
                                  deadline: item['deadline'],
                                  note: item['note'],
                                  isFullPayment: item['isFullPayment'] == true,
                                  onActionPressed: () => _confirmOrder(item),
                                  onCancelPressed: () => _cancelOrder(item),
                                  onCardTap: () => _showStatusChangeDialog(item),
                                );
                              } else {
                                return _buildDepositOrCompletedCard(
                                  id: id,
                                  orderCode: item['orderCode'],
                                  subTag: item['subTag'],
                                  renterName: item['renterName'],
                                  roomTitle: item['roomTitle'],
                                  deposit: item['deposit'],
                                  status: item['status'],
                                  note: item['note'],
                                  isLocked: item['isLocked'] == true,
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
                                  onActionPressed: () => _markOrderPaid(item),
                                  onCheckinPressed: () => _markOrderCheckedIn(item),
                                  onCancelPressed: () => _cancelOrder(item),
                                  onCardTap: () => _showStatusChangeDialog(item),
                                );
                              }
                            },
                          ),
                  ),

                  // 6. Bottom Bar tạo hóa đơn
                  if (_filter == 'deposit_paid' || _filter == 'completed') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: const Border(top: BorderSide(color: Color(0xFFEAECF0))),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
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
                                  Text(
                                    'Đã chọn: ${_selectedOrderIds.length} đơn',
                                    style: const TextStyle(
                                        fontSize: 12.5, color: Color(0xFF667085)),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Text('Tổng thanh toán: ',
                                          style: TextStyle(
                                              fontSize: 12, color: Color(0xFF475467))),
                                      Expanded(
                                        child: Text(
                                          '${currencyFormatter.format(totalSelectedAmount)} đ',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF155EEF),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _navigateToSettlementInvoice,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF155EEF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                'TẠO HÓA ĐƠN (${_selectedOrderIds.length})',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 13.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmOrder(Map<String, dynamic> item) async {
    final id = item['id'] as String;
    final isFull = item['isFullPayment'] == true;
    final targetSubTag = isFull ? 'Đã trả hết' : 'Đã cọc';
    final targetTabName = isFull ? 'Đã trả hết' : 'Đã cọc';
    final actionText = isFull ? 'thanh toán đủ' : 'tiền cọc';

    try {
      await FirebaseFirestore.instance.collection('bookings').doc(id).set({
        'status': isFull ? 'completed' : 'deposit_paid',
        'subTag': targetSubTag,
        'description': targetSubTag,
        'isPaid': true,
        if (isFull) 'isCompleted': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Xóa sạch trường tiếng Việt trên Firestore
        'trangThai': FieldValue.delete(),
        'moTa': FieldValue.delete(),
        'daThanhToan': FieldValue.delete(),
        'ngayDuyet': FieldValue.delete(),
        'ngayCapNhat': FieldValue.delete(),
      }, SetOptions(merge: true));

      // Lấy thông tin chi tiết đơn từ Firestore để đảm bảo đủ dữ liệu
      final bookingDoc = await FirebaseFirestore.instance.collection('bookings').doc(id).get();
      final bookingData = bookingDoc.data() ?? {};
      final hostId = (bookingData['hostId'] ?? bookingData['chuNhaId'] ?? item['hostId'] ?? '').toString();
      final roomId = (bookingData['roomId'] ?? bookingData['phongId'] ?? item['roomId'] ?? '').toString();
      final roomCode = (bookingData['roomCode'] ?? bookingData['maPhong'] ?? item['roomCode'] ?? '101').toString();
      final roomTitle = (item['roomTitle'] ?? bookingData['roomTitle'] ?? bookingData['tieuDePhong'] ?? 'Phòng trọ').toString();
      final renterName = (item['renterName'] ?? bookingData['renterName'] ?? bookingData['tenNguoiO'] ?? 'Khách thuê').toString();
      final renterId = (item['renterId'] ?? bookingData['renterId'] ?? bookingData['nguoiDungId'] ?? '').toString();
      final depositAmount = (item['deposit'] as num?)?.toDouble() ?? (bookingData['deposit'] as num?)?.toDouble() ?? 0.0;

      // 1. Gửi thông báo đến người thuê (Role Renter)
      if (renterId.isNotEmpty && renterId != 'guest') {
        await FirebaseFirestore.instance.collection('notifications').add({
          'recipientId': renterId,
          'recipientRole': 'renter',
          'title': isFull ? 'Thanh toán thành công' : 'Duyệt tiền cọc thành công',
          'body': 'Admin đã xác nhận $actionText cho phòng "$roomTitle". Bạn có thể chuẩn bị dọn vào ở!',
          'message': 'Admin đã xác nhận $actionText cho phòng "$roomTitle". Bạn có thể chuẩn bị dọn vào ở!',
          'notificationType': 'booking',
          'bookingId': id,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 2. Cập nhật hoặc tạo thông báo đến Chủ trọ (Role Host: deposit hoặc paymentCompleted)
      if (hostId.isNotEmpty && hostId != 'guest') {
        final targetNotificationType = isFull ? 'paymentCompleted' : 'deposit';
        final hostTitle = isFull
            ? 'Khách đã thanh toán toàn bộ tiền thuê'
            : 'Khách đã đặt cọc giữ phòng';
        final hostMessage = isFull
            ? 'Admin đã xác nhận khách $renterName thanh toán đủ tiền thuê cho phòng "$roomTitle". Chờ khách nhận phòng/check-in.'
            : 'Admin đã xác nhận khách $renterName đặt cọc giữ phòng "$roomTitle". Chờ khách nhận phòng/check-in.';

        final hostNotifQuery = await FirebaseFirestore.instance
            .collection('notifications')
            .where('bookingId', isEqualTo: id)
            .where('receiverId', isEqualTo: hostId)
            .get();

        if (hostNotifQuery.docs.isNotEmpty) {
          // Chuyển trạng thái thông báo đang xử lý sang đã cọc / đã thanh toán hết
          for (final doc in hostNotifQuery.docs) {
            await doc.reference.update({
              'notificationType': targetNotificationType,
              'statusId': 'confirmed',
              'title': hostTitle,
              'message': hostMessage,
              'isRead': false,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        } else {
          // Tạo thông báo mới cho chủ trọ nếu chưa có
          final newHostNotifRef = FirebaseFirestore.instance.collection('notifications').doc();
          await newHostNotifRef.set({
            'id': newHostNotifRef.id,
            'notificationId': newHostNotifRef.id,
            'receiverId': hostId,
            'senderId': renterId,
            'recipientRole': 'host',
            'notificationType': targetNotificationType,
            'title': hostTitle,
            'message': hostMessage,
            'bookingId': id,
            'bookingCode': id,
            'roomId': roomId,
            'roomCode': roomCode,
            'roomTitle': roomTitle,
            'amount': depositAmount,
            'statusId': 'confirmed',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'renterName': renterName,
            'paymentMethod': 'Chuyển khoản QR',
          });
        }
      }

      // Ghi lịch sử kiểm toán audit_logs
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'action': 'Duyệt $actionText',
        'actor': 'Admin',
        'category': 'taiChinh',
        'details': 'Admin đã xác nhận $actionText cho đơn ${item['orderCode']} của khách ${item['renterName']}. Chuyển vào mục "$targetTabName".',
        'target': 'Đơn $id',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF12B76A),
            content: Text('Đã xác nhận $actionText cho đơn ${item['orderCode']}! Đã chuyển vào mục "$targetTabName".'),
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

  Future<void> _markOrderPaid(Map<String, dynamic> item) async {
    final id = item['id'] as String;
    try {
      await FirebaseFirestore.instance.collection('bookings').doc(id).set({
        'status': 'completed',
        'isCompleted': true,
        'disbursedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Xóa sạch trường tiếng Việt trên Firestore
        'trangThai': FieldValue.delete(),
        'daHoanTat': FieldValue.delete(),
        'ngayGiaiNgan': FieldValue.delete(),
        'ngayCapNhat': FieldValue.delete(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF12B76A),
            content: Text('Đã hoàn tất đơn ${item['orderCode']}!'),
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

  Future<void> _markOrderCheckedIn(Map<String, dynamic> item) async {
    final id = item['id'] as String;
    try {
      final service = BookingService();
      await service.checkinBooking(id, note: 'Admin xác nhận chuyển sang Đang ở');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF12B76A),
            content: Text('Đã xác nhận vào ở cho đơn ${item['orderCode']}! Đã chuyển sang "Đang ở".'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: const Color(0xFFD92D20), content: Text('Lỗi cập nhật: $e')),
        );
      }
    }
  }

  Future<void> _cancelOrder(Map<String, dynamic> item) async {
    final id = item['id'] as String;
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận hủy đơn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn có chắc chắn muốn hủy đơn ${item['orderCode']} của khách ${item['renterName']}?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                hintText: 'Lý do hủy (tùy chọn)...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Đóng')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD92D20), foregroundColor: Colors.white),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final service = BookingService();
        await service.cancelBooking(id, reason: reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : 'Admin hủy đơn');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF155EEF),
              content: Text('Đã hủy đơn ${item['orderCode']} thành công.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: const Color(0xFFD92D20), content: Text('Lỗi hủy đơn: $e')),
          );
        }
      }
    }
  }

  Future<void> _showStatusChangeDialog(Map<String, dynamic> item) async {
    final id = item['id'] as String;
    final orderCode = item['orderCode'] as String;
    final renterName = item['renterName'] as String;
    final roomTitle = item['roomTitle'] as String;
    final currentStatus = (item['status'] ?? '').toString();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF8FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.sync_alt_rounded, color: Color(0xFF155EEF), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CHUYỂN TRẠNG THÁI: $orderCode',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF101828)),
                      ),
                      Text(
                        'Khách: $renterName • $roomTitle',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Chọn trạng thái bạn muốn chuyển:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF344054))),
            const SizedBox(height: 10),

            _buildStatusOptionTile(
              title: '1. Chờ duyệt (Pending)',
              subtitle: 'Đơn mới / Khách chưa hoàn tất cọc',
              icon: Icons.hourglass_empty_rounded,
              color: const Color(0xFFF79009),
              isSelected: currentStatus == 'disburse',
              onTap: () async {
                Navigator.pop(ctx);
                await FirebaseFirestore.instance.collection('bookings').doc(id).set({
                  'status': 'pending',
                  'subTag': 'Chờ xác nhận',
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã chuyển đơn về Chờ duyệt')));
                }
              },
            ),
            const SizedBox(height: 8),

            _buildStatusOptionTile(
              title: '2. Đã duyệt (Approved / Đã cọc)',
              subtitle: 'Đã xác nhận cọc, khách có thể mở mã QR nhận phòng',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF155EEF),
              isSelected: currentStatus == 'deposit_paid',
              onTap: () async {
                Navigator.pop(ctx);
                await _confirmOrder(item);
              },
            ),
            const SizedBox(height: 8),

            _buildStatusOptionTile(
              title: '3. Đang ở (Active / Đã nhận phòng)',
              subtitle: 'Khách đã check-in, đang sinh sống tại phòng',
              icon: Icons.home_work_outlined,
              color: const Color(0xFF12B76A),
              isSelected: currentStatus == 'active',
              onTap: () async {
                Navigator.pop(ctx);
                await _markOrderCheckedIn(item);
              },
            ),
            const SizedBox(height: 8),

            _buildStatusOptionTile(
              title: '4. Đã hủy (Cancelled)',
              subtitle: 'Đơn bị hủy, không tiếp tục thuê',
              icon: Icons.cancel_outlined,
              color: const Color(0xFFD92D20),
              isSelected: currentStatus == 'cancelled',
              onTap: () async {
                Navigator.pop(ctx);
                await _cancelOrder(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFEAECF0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : const Color(0xFF101828),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF667085)),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required int count,
    required String value,
    required Color dotColor,
  }) {
    final isSelected = _filter == value;
    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF155EEF) : const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != Colors.transparent) ...[
              Container(
                width: 7.5,
                height: 7.5,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : const Color(0xFF475467),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF79009) : const Color(0xFFEAECF0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF344054),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
    VoidCallback? onCancelPressed,
    VoidCallback? onCardTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCardTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEAECF0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hàng 1: Mã GD / Tên khách / Badge Trạng thái ──
              Row(
                children: [
                  SizedBox(
                    width: 86,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF8FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFB2DDFF)),
                        ),
                        child: Text(
                          orderCode,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF175CD3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      renterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF101828),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF0C7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6.5,
                          height: 6.5,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF79009),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          subTag,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB54708),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Hàng 2: Hạn chuyển / Tên phòng / Số tiền ──
              Row(
                children: [
                  SizedBox(
                    width: 86,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFFF79009)),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            'Hạn: $deadline',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF79009),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.meeting_room_outlined, size: 15, color: Color(0xFF667085)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            roomTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5, color: Color(0xFF475467)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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

              const SizedBox(height: 10),

              // ── Hàng 3: Loại cọc/trả hết / Ghi chú / Nút xác nhận & Nút Hủy ──
              Row(
                children: [
                  const SizedBox(width: 86),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isFullPayment ? const Color(0xFFEEF4FF) : const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isFullPayment ? 'Trả hết' : 'Tiền cọc',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isFullPayment ? const Color(0xFF3538CD) : const Color(0xFF026AA2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            note,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF667085)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (onCancelPressed != null) ...[
                    OutlinedButton(
                      onPressed: onCancelPressed,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD92D20),
                        side: const BorderSide(color: Color(0xFFFDA29B)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Hủy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                  ],
                  ElevatedButton(
                    onPressed: onActionPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF155EEF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      isFullPayment ? 'Xác nhận trả hết' : 'Xác nhận tiền cọc',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepositOrCompletedCard({
    required String id,
    required String orderCode,
    required String subTag,
    required String renterName,
    required String roomTitle,
    required double deposit,
    required String status,
    required String note,
    required bool isLocked,
    required bool isChecked,
    required VoidCallback onToggleCheck,
    required VoidCallback onActionPressed,
    VoidCallback? onCheckinPressed,
    VoidCallback? onCancelPressed,
    VoidCallback? onCardTap,
  }) {
    final isDone = status == 'completed';
    final isActive = status == 'active' || status == 'dangO';
    final isCancelled = status == 'cancelled' || status == 'daHuy';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCardTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isChecked ? const Color(0xFF155EEF) : const Color(0xFFEAECF0),
              width: isChecked ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isActive) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFECFDF3),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.home_outlined, size: 16, color: Color(0xFF027A48)),
                      SizedBox(width: 6),
                      Text(
                        'Khách đang cư trú (Đang ở)',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF027A48)),
                      ),
                    ],
                  ),
                ),
              ] else if (isCancelled) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF3F2),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFD92D20)),
                      SizedBox(width: 6),
                      Text(
                        'Đơn thuê đã bị hủy',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD92D20)),
                      ),
                    ],
                  ),
                ),
              ] else if (isLocked) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEF0C7),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                  ),
                  child: const Text(
                    'Khóa: Chưa check-in nhận phòng.',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB54708)),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!isLocked && !isActive && !isCancelled) ...[
                          InkWell(
                            onTap: onToggleCheck,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isChecked ? const Color(0xFF155EEF) : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isChecked
                                      ? const Color(0xFF155EEF)
                                      : const Color(0xFFD0D5DD),
                                  width: 1.5,
                                ),
                              ),
                              child: isChecked
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ] else if (isLocked && !isActive && !isCancelled) ...[
                          const Icon(Icons.lock_outline_rounded,
                              size: 20, color: Color(0xFF667085)),
                          const SizedBox(width: 10),
                        ] else if (isActive) ...[
                          const Icon(Icons.home_outlined,
                              size: 20, color: Color(0xFF027A48)),
                          const SizedBox(width: 10),
                        ] else if (isCancelled) ...[
                          const Icon(Icons.cancel_outlined,
                              size: 20, color: Color(0xFFD92D20)),
                          const SizedBox(width: 10),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF8FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            orderCode,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF155EEF)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: isActive
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF3),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check,
                                          size: 13, color: Color(0xFF027A48)),
                                      SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          'Đang ở',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF027A48)),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : isCancelled
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3F2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.close,
                                              size: 13, color: Color(0xFFD92D20)),
                                          SizedBox(width: 3),
                                          Flexible(
                                            child: Text(
                                              'Đã hủy',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFFD92D20)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : isLocked
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF0C7),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            subTag,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFB54708)),
                                          ),
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3.5),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF3),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.check,
                                                  size: 13, color: Color(0xFF027A48)),
                                              const SizedBox(width: 3),
                                              Flexible(
                                                child: Text(
                                                  subTag,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF027A48)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${currencyFormatter.format(deposit)}đ',
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF101828),
                              ),
                            ),
                            if (!isLocked && !isActive && !isCancelled) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF8FF),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text('Hệ thống tự chọn',
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF155EEF),
                                        fontWeight: FontWeight.w600)),
                              ),
                            ] else if (isLocked && !isActive && !isCancelled) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F4F7),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text('Không thể giải ngân',
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF667085),
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                renterName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF101828)),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                roomTitle,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 14, color: Color(0xFF667085)),
                              ),
                            ],
                          ),
                        ),
                        // Nút hành động
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (onCardTap != null)
                              IconButton(
                                tooltip: 'Đổi trạng thái đơn',
                                icon: const Icon(Icons.edit_note_rounded,
                                    color: Color(0xFF475467), size: 22),
                                onPressed: onCardTap,
                              ),
                            if (isActive) ...[
                              OutlinedButton(
                                onPressed: onCardTap,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF027A48),
                                  side: const BorderSide(color: Color(0xFF6CE9A6)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Đổi TT',
                                    style: TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ] else if (isCancelled) ...[
                              OutlinedButton(
                                onPressed: onCardTap,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFD92D20),
                                  side: const BorderSide(color: Color(0xFFFDA29B)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Đổi TT',
                                    style: TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ] else ...[
                              if (onCheckinPressed != null) ...[
                                OutlinedButton(
                                  onPressed: onCheckinPressed,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF027A48),
                                    side: const BorderSide(color: Color(0xFF6CE9A6)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Vào ở',
                                      style: TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (onCancelPressed != null) ...[
                                OutlinedButton(
                                  onPressed: onCancelPressed,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFD92D20),
                                    side: const BorderSide(color: Color(0xFFFDA29B)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Hủy',
                                      style: TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (!isLocked) ...[
                                ElevatedButton(
                                  onPressed: isDone ? null : onActionPressed,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF155EEF),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: const Color(0xFFF2F4F7),
                                    disabledForegroundColor: const Color(0xFF667085),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 9),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: Text(
                                    isDone ? 'Đã hoàn tất' : 'Đã thanh toán',
                                    style: const TextStyle(
                                        fontSize: 12.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFFECFDF3)
                                : isCancelled
                                    ? const Color(0xFFFEF3F2)
                                    : const Color(0xFFECFDF3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isActive
                                ? 'Đang ở'
                                : isCancelled
                                    ? 'Đã hủy'
                                    : (isDone ? 'Trả hết' : 'Tiền cọc'),
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isCancelled
                                    ? const Color(0xFFD92D20)
                                    : const Color(0xFF027A48)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            note,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5, color: Color(0xFF667085)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}