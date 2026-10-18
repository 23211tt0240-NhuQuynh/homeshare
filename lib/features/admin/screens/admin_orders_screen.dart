import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/admin_service.dart';
import 'settlement_invoice_screen.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filter = 'all'; // 'all', 'disburse', 'deposit_paid', 'completed'
  String _selectedHostArea = '1-Chủ trọ A (Khu Bình Thạnh)';
  final Set<String> _selectedOrderIds = {'1-X92F'}; // Selected for batch invoice
  final currencyFormatter = NumberFormat('#,###', 'vi_VN');

  Stream<QuerySnapshot>? get _bookingsStream {
    try {
      return FirebaseFirestore.instance.collection('bookings').snapshots();
    } catch (_) {
      return null;
    }
  }

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
      ),
    );
  }

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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
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
              ],
            ),
          ),

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
              ],
            ),
          ),

          // 4. Header Bar (MÃ CỌC / TÊN KHÁCH THUÊ | TRẠNG THÁI)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF2F4F7),
              border: Border(
                top: BorderSide(color: Color(0xFFEAECF0)),
                bottom: BorderSide(color: Color(0xFFEAECF0)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'MÃ CỌC / KHÁCH CHUYỂN',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF667085), letterSpacing: 0.3),
                ),
                Text(
                  'TRẠNG THÁI',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF667085), letterSpacing: 0.3),
                ),
              ],
            ),
          ),

          // 5. Orders Stream & List View
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _bookingsStream,
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
                        ],
                      ),
                    ),
                  );
                }

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
                );
              },
            ),
          ),

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
        ],
      ),
    );
  }

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
                ),
              ),
            ],
          ),
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
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 28.0),
            child: Text(
              note,
              style: const TextStyle(fontSize: 11, color: Color(0xFF98A2B3)),
            ),
          ),
        ],
      ),
    );
  }
}