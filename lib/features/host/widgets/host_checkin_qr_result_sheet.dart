import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/booking_service.dart';
import '../screens/host_checkin_handover_screen.dart';
import '../../../core/constants/app_colors.dart';

/// BottomSheet hiển thị thông tin phòng và người dùng sau khi Chủ trọ quét mã QR nhận phòng
class HostCheckinQrResultSheet extends StatefulWidget {
  final Map<String, dynamic> qrData;
  final String hostId;
  final VoidCallback? onStatusChanged;

  const HostCheckinQrResultSheet({
    super.key,
    required this.qrData,
    required this.hostId,
    this.onStatusChanged,
  });

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> qrData,
    required String hostId,
    VoidCallback? onStatusChanged,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HostCheckinQrResultSheet(
        qrData: qrData,
        hostId: hostId,
        onStatusChanged: onStatusChanged,
      ),
    );
  }

  @override
  State<HostCheckinQrResultSheet> createState() => _HostCheckinQrResultSheetState();
}

class _HostCheckinQrResultSheetState extends State<HostCheckinQrResultSheet> {
  bool _isLoading = false;

  double? _liveRoomPrice;
  double? _liveDeposit;
  double? _liveTotalAmount;
  String? _livePaymentOption;
  String? _liveRoomTitle;
  String? _liveRoomAddress;

  @override
  void initState() {
    super.initState();
    _liveRoomPrice = _rawRoomPrice;
    _liveDeposit = _rawDeposit;
    _liveTotalAmount = _rawTotalAmount;
    _livePaymentOption = _rawPaymentOption;
    _fetchMissingDataIfNeeded();
  }

  Future<void> _fetchMissingDataIfNeeded() async {
    final bId = _bookingId;
    final rId = _roomId;

    if (bId.isNotEmpty) {
      try {
        final bDoc = await FirebaseFirestore.instance.collection(FirestoreCollections.bookings).doc(bId).get();
        if (bDoc.exists && bDoc.data() != null) {
          final data = bDoc.data()!;
          final price = (data['roomPrice'] ?? data['giaThue'] ?? data['giaPhong'] ?? data['price']) as num?;
          final dep = (data['deposit'] ?? data['tienCoc']) as num?;
          final tot = (data['totalAmount'] ?? data['tongPhaiTra'] ?? data['paymentAmount']) as num?;
          final opt = (data['paymentOption'] ?? data['hinhThucThanhToan'])?.toString();
          final title = (data['roomTitle'] ?? data['tieuDePhong'])?.toString();
          final addr = (data['roomAddress'] ?? data['diaChiPhong'])?.toString();

          if (mounted) {
            setState(() {
              if (price != null && price > 0) _liveRoomPrice = price.toDouble();
              if (dep != null && dep > 0) _liveDeposit = dep.toDouble();
              if (tot != null && tot > 0) _liveTotalAmount = tot.toDouble();
              if (opt != null && opt.isNotEmpty) _livePaymentOption = opt;
              if (title != null && title.isNotEmpty) _liveRoomTitle = title;
              if (addr != null && addr.isNotEmpty) _liveRoomAddress = addr;
            });
          }
        }
      } catch (e) {
        debugPrint('Error fetching booking data in sheet: $e');
      }
    }

    if ((_liveRoomPrice == null || _liveRoomPrice == 0) && rId.isNotEmpty) {
      try {
        final rDoc = await FirebaseFirestore.instance.collection('host_rooms').doc(rId).get();
        if (rDoc.exists && rDoc.data() != null) {
          final data = rDoc.data()!;
          final price = (data['price'] ?? data['giaPhong'] ?? data['giaThue']) as num?;
          final dep = (data['deposit'] ?? data['tienCoc']) as num?;
          final title = (data['title'] ?? data['tieuDe'])?.toString();
          final addr = (data['address'] ?? data['diaChi'])?.toString();

          if (mounted) {
            setState(() {
              if (price != null && price > 0) _liveRoomPrice = price.toDouble();
              if (dep != null && dep > 0 && (_liveDeposit == null || _liveDeposit == 0)) {
                _liveDeposit = dep.toDouble();
              }
              if (title != null && title.isNotEmpty && (_liveRoomTitle == null || _liveRoomTitle!.isEmpty)) {
                _liveRoomTitle = title;
              }
              if (addr != null && addr.isNotEmpty && (_liveRoomAddress == null || _liveRoomAddress!.isEmpty)) {
                _liveRoomAddress = addr;
              }
            });
          }
        }
      } catch (e) {
        debugPrint('Error fetching room data in sheet: $e');
      }
    }
  }

  String get _bookingId => (widget.qrData['bookingId'] ?? widget.qrData['id'] ?? '').toString();
  String get _roomId => (widget.qrData['roomId'] ?? widget.qrData['phongId'] ?? '').toString();
  String get _roomCode => (widget.qrData['roomCode'] ?? widget.qrData['maPhong'] ?? '204').toString();
  String get _roomTitle => _liveRoomTitle ?? (widget.qrData['roomTitle'] ?? widget.qrData['tieuDePhong'] ?? 'Phòng trọ').toString();
  String get _roomAddress => _liveRoomAddress ?? (widget.qrData['roomAddress'] ?? widget.qrData['diaChiPhong'] ?? 'Địa chỉ phòng').toString();

  double get _rawRoomPrice {
    final val = widget.qrData['roomPrice'] ?? widget.qrData['giaThue'] ?? widget.qrData['price'] ?? widget.qrData['giaPhong'];
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  double get _rawDeposit {
    final val = widget.qrData['deposit'] ?? widget.qrData['tienCoc'] ?? widget.qrData['depositAmount'];
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  double get _rawTotalAmount {
    final val = widget.qrData['totalAmount'] ?? widget.qrData['tongPhaiTra'] ?? widget.qrData['paymentAmount'] ?? widget.qrData['amount'] ?? widget.qrData['paidAmount'];
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  String get _rawPaymentOption => (widget.qrData['paymentOption'] ?? widget.qrData['hinhThucThanhToan'] ?? widget.qrData['paymentType'] ?? 'deposit').toString();

  double get effectivePrice => (_liveRoomPrice != null && _liveRoomPrice! > 0) ? _liveRoomPrice! : _rawRoomPrice;
  double get effectiveDeposit => (_liveDeposit != null && _liveDeposit! > 0) ? _liveDeposit! : _rawDeposit;
  double get effectiveTotal => (_liveTotalAmount != null && _liveTotalAmount! > 0) ? _liveTotalAmount! : _rawTotalAmount;
  String get effectivePaymentOption => _livePaymentOption ?? _rawPaymentOption;
  bool get isFullPayment => effectivePaymentOption == 'full' || effectivePaymentOption == 'toanbo' || effectivePaymentOption == 'trahet';

  double get effectivePaidAmount {
    if (isFullPayment) {
      return effectivePrice > 0 ? effectivePrice : (effectiveTotal > 0 ? effectiveTotal : effectiveDeposit);
    }
    return effectiveDeposit > 0 ? effectiveDeposit : (effectiveTotal > 0 ? effectiveTotal : effectivePrice);
  }

  int get _rentalMonths {
    final val = widget.qrData['rentalMonths'] ?? widget.qrData['soThangThue'];
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 1;
    return 1;
  }

  String get _renterName => (widget.qrData['renterName'] ?? widget.qrData['tenNguoiO'] ?? 'Khách thuê').toString();
  String get _renterPhone => (widget.qrData['renterPhone'] ?? widget.qrData['sdtNguoiO'] ?? '').toString();
  String get _renterUserCode => (widget.qrData['renterUserCode'] ?? widget.qrData['renterCode'] ?? widget.qrData['maNguoiDung'] ?? '').toString();

  String get _moveInDateStr {
    final val = widget.qrData['moveInDate'] ?? widget.qrData['ngayVao'];
    if (val != null) {
      if (val is String) {
        try {
          final dt = DateTime.parse(val);
          return DateFormat('dd/MM/yyyy').format(dt);
        } catch (_) {}
      }
    }
    return DateFormat('dd/MM/yyyy').format(DateTime.now());
  }

  // 1. Chuyển sang màn hình Bàn giao thiết bị & Chốt điện nước
  void _openHandoverScreen() {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HostCheckinHandoverScreen(
          bookingId: _bookingId,
          roomId: _roomId,
          roomCode: _roomCode,
        ),
      ),
    ).then((_) {
      if (widget.onStatusChanged != null) widget.onStatusChanged!();
    });
  }

  // 2. Xác nhận nhận phòng nhanh (Chuyển đơn sang Đang ở ngay)
  Future<void> _quickConfirmCheckin() async {
    setState(() => _isLoading = true);
    try {
      final service = BookingService();
      await service.checkinBooking(
        _bookingId,
        roomId: _roomId,
        hostId: widget.hostId,
        note: 'Xác nhận nhận phòng trực tiếp từ mã QR',
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xác nhận nhận phòng thành công cho khách $_renterName! Trạng thái đơn đã chuyển sang "Đang ở".'),
          backgroundColor: const Color(0xFF12B76A),
          duration: const Duration(seconds: 3),
        ),
      );

      if (widget.onStatusChanged != null) widget.onStatusChanged!();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi cập nhật nhận phòng: $e'),
          backgroundColor: const Color(0xFFD92D20),
        ),
      );
    }
  }

  // 3. Từ chối / Hủy đơn
  Future<void> _cancelBooking() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Xác nhận từ chối / Hủy đơn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn có chắc chắn muốn từ chối nhận phòng và hủy đơn thuê này không?',
              style: TextStyle(fontSize: 13.5, height: 1.4, color: Color(0xFF475467)),
            ),
            SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Nhập lý do hủy...',
                hintStyle: TextStyle(fontSize: 13, color: Color(0xFF98A2B3)),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Đóng'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD92D20),
              foregroundColor: Colors.white,
            ),
            child: Text('Xác nhận hủy'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final service = BookingService();
        await service.cancelBooking(
          _bookingId,
          reason: reasonController.text.trim().isNotEmpty
              ? reasonController.text.trim()
              : 'Chủ trọ từ chối khi quét QR',
        );

        if (!mounted) return;
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã hủy đơn thuê thành công.'),
            backgroundColor: Color(0xFF155EEF),
          ),
        );

        if (widget.onStatusChanged != null) widget.onStatusChanged!();
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi hủy đơn: $e'),
            backgroundColor: const Color(0xFFD92D20),
          ),
        );
      }
    }
  }

  void _callPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Clipboard.setData(ClipboardData(text: cleanPhone));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã sao chép SĐT: $cleanPhone')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat('#,###', 'vi_VN');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            margin: EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFA6F4C5)),
                  ),
                  child: Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF12B76A),
                    size: 26,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QUÉT QR THÀNH CÔNG',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF101828),
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Thông tin phòng & khách thuê nhận phòng',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667085),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: Color(0xFF667085)),
                ),
              ],
            ),
          ),

          Divider(height: 1),

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge Mã đơn & Trạng thái
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEAECF0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 18, color: Color(0xFF155EEF)),
                            SizedBox(width: 6),
                            Text(
                              'Mã đơn: $_bookingId',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF101828),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isFullPayment ? const Color(0xFFF9F5FF) : const Color(0xFFECFDF3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isFullPayment ? const Color(0xFFE9D7FE) : const Color(0xFFA6F4C5)),
                          ),
                          child: Text(
                            isFullPayment ? 'Đã trả hết toàn bộ' : 'Đã duyệt tiền cọc',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isFullPayment ? const Color(0xFF6941C6) : const Color(0xFF027A48),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 14),

                  // ── THẺ 1: THÔNG TIN TIỀN & THANH TOÁN (QUÉT TỪ QR) ──
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6FEF9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFA6F4C5), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF12B76A).withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1FADF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.payments_rounded, size: 20, color: Color(0xFF027A48)),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'THÔNG TIN TIỀN & THANH TOÁN',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF027A48),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        // Khung hiển thị số tiền thanh toán to rõ
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFD1FADF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isFullPayment ? 'SỐ TIỀN ĐÃ THANH TOÁN:' : 'TIỀN CỌC ĐÃ THANH TOÁN:',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF475467),
                                  letterSpacing: 0.2,
                                ),
                              ),
                              SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    currencyFormatter.format(effectivePaidAmount),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF027A48),
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'đ',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF027A48),
                                    ),
                                  ),
                                  Spacer(),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF3),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF12B76A)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Hợp lệ',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF027A48)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Text(
                                isFullPayment
                                    ? '✓ Đã thanh toán 100% tiền phòng tháng đầu (không tính cọc)'
                                    : '✓ Đã duyệt cọc giữ phòng hợp lệ qua MBBank',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF027A48),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        _buildRow(
                          'Giá thuê phòng:',
                          '${currencyFormatter.format(effectivePrice)} đ/tháng',
                          highlightColor: const Color(0xFF155EEF),
                          isBold: true,
                        ),
                        if (!isFullPayment)
                          _buildRow(
                            'Tiền cọc giữ phòng:',
                            '${currencyFormatter.format(effectiveDeposit)} đ',
                            highlightColor: const Color(0xFF027A48),
                            isBold: true,
                          )
                        else
                          _buildRow(
                            'Tiền đặt cọc:',
                            '0 đ (Không tính cọc)',
                          ),
                        _buildRow(
                          'Hình thức trả:',
                          isFullPayment ? 'Trả hết (Toàn bộ tiền phòng)' : 'Đặt cọc giữ phòng',
                          highlightColor: isFullPayment ? const Color(0xFF7F56D9) : const Color(0xFF155EEF),
                        ),
                        _buildRow('Phương thức:', 'Chuyển khoản QR MBBank'),
                      ],
                    ),
                  ),

                  SizedBox(height: 14),

                  // ── THẺ 2: THÔNG TIN PHÒNG TRỌ ──
                  _buildSection(
                    title: 'THÔNG TIN PHÒNG TRỌ',
                    icon: Icons.meeting_room_outlined,
                    iconColor: const Color(0xFF155EEF),
                    children: [
                      _buildRow('Tên phòng:', _roomTitle, isBold: true),
                      if (_roomCode.isNotEmpty)
                        _buildRow('Mã phòng:', _roomCode),
                      _buildRow('Địa chỉ:', _roomAddress),
                    ],
                  ),

                  SizedBox(height: 14),

                  // ── THẺ 2: THÔNG TIN NGƯỜI THUÊ ──
                  _buildSection(
                    title: 'THÔNG TIN KHÁCH THUÊ',
                    icon: Icons.person_outline_rounded,
                    iconColor: const Color(0xFF7F56D9),
                    children: [
                      _buildRow('Họ và tên:', _renterName, isBold: true),
                      Padding(
                        padding: EdgeInsets.only(bottom: 7),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Số điện thoại:',
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF667085), fontWeight: FontWeight.w500),
                            ),
                            Row(
                              children: [
                                Text(
                                  _renterPhone,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF101828),
                                  ),
                                ),
                                if (_renterPhone.isNotEmpty) ...[
                                  SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => _callPhone(_renterPhone),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF8FF),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.phone_in_talk, size: 13, color: AppColors.textDark),
                                          SizedBox(width: 4),
                                          Text('Gọi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_renterUserCode.isNotEmpty)
                        _buildRow('Mã người dùng:', _renterUserCode),
                      _buildRow('Ngày vào ở:', _moveInDateStr),
                      _buildRow('Thời hạn thuê:', '$_rentalMonths tháng'),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Hướng dẫn hành động
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEAECF0)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 18, color: AppColors.textMuted),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bạn có thể tiến hành bàn giao thiết bị & chốt chỉ số điện nước, hoặc xác nhận vào ở ngay để chuyển đơn sang "Đang ở".',
                            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),

                  // ── CÁC NÚT BẤM HÀNH ĐỘNG ──
                  if (_isLoading)
                    Center(child: CircularProgressIndicator())
                  else ...[
                    // Nút 1: Bàn giao & Chốt điện nước
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _openHandoverScreen,
                        icon: Icon(Icons.handyman_outlined, size: 18),
                        label: Text(
                          'BÀN GIAO & CHỐT ĐIỆN NƯỚC',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF155EEF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                    SizedBox(height: 10),

                    // Nút 2: Xác nhận nhận phòng nhanh (Chuyển sang Đang ở)
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: _quickConfirmCheckin,
                        icon: Icon(Icons.check_circle_outline, size: 18),
                        label: Text(
                          'XÁC NHẬN VÀO Ở NGAY (CHUYỂN SANG ĐANG Ở)',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF12B76A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                    SizedBox(height: 10),

                    // Nút 3: Từ chối / Hủy đơn
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: _cancelBooking,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD92D20),
                          side: BorderSide(color: Color(0xFFFDA29B)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Từ chối nhận phòng / Hủy đơn',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAECF0)),
      ),
      padding: EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: iconColor,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Divider(height: 1, color: Color(0xFFEAECF0)),
          SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    Color? highlightColor,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF667085),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                color: highlightColor ?? (isBold ? const Color(0xFF101828) : const Color(0xFF344054)),
                fontWeight: (isBold || highlightColor != null)
                    ? FontWeight.bold
                    : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
