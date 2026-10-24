import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';
import '../widgets/admin_branded_title.dart';

class AdminHistoryScreen extends ConsumerStatefulWidget {
  const AdminHistoryScreen({super.key});

  @override
  ConsumerState<AdminHistoryScreen> createState() => _AdminHistoryScreenState();
}

class _AdminHistoryScreenState extends ConsumerState<AdminHistoryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  DateTime? _selectedDate;
  DateTime get effectiveSelectedDate => _selectedDate ?? DateTime.now();

  final currencyFormatter = NumberFormat('#,###', 'vi_VN');
  bool _filterByDate = false;
  bool _isSeeding = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _checkAndSeedInitialLogs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFD92D20),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Đăng xuất',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF101828),
              ),
            ),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản Quản trị viên không?',
          style: TextStyle(
            fontSize: 14.5,
            color: Color(0xFF475467),
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: const BorderSide(color: Color(0xFFD0D5DD)),
            ),
            child: const Text(
              'Hủy',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF344054),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD92D20),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Đăng xuất',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      try {
        final authService = ref.read(authServiceProvider);
        await authService.signOut();
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFD92D20),
              content: Text('Lỗi khi đăng xuất: $e'),
            ),
          );
        }
      }
    }
  }

  // Tự động khởi tạo dữ liệu kiểm toán mẫu lên Firebase nếu Firestore 'audit_logs' đang rỗng
  Future<void> _checkAndSeedInitialLogs() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('audit_logs')
          .limit(1)
          .get();
      if (snap.docs.isEmpty && !_isSeeding) {
        _isSeeding = true;
        final batch = FirebaseFirestore.instance.batch();

        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));

        final seedLogs = [
          {
            'id': 'log_1',
            'title': 'Duyệt Giải Ngân Cọc #DHBB21',
            'subtitle': 'Chuyển 4.250.000 đ ➔ Chủ trọ Đặng Thu Hà',
            'amount': 4250000.0,
            'performer': 'Admin A',
            'timeStr': '14:10:25',
            'category': 'finance',
            'dateGroup': 'HÔM NAY - ${DateFormat('dd/MM/yyyy').format(now)}',
            'timestamp': Timestamp.fromDate(now),
          },
          {
            'id': 'log_2',
            'title': 'Duyệt Hoàn Cọc #DHBB19 (Hủy phòng...)',
            'subtitle': 'Hoàn trả 3.000.000 đ ➔ KH Nguyễn Văn C',
            'amount': 3000000.0,
            'performer': 'Admin A',
            'timeStr': '16:45:00',
            'category': 'refund',
            'dateGroup':
                'HÔM QUA - ${DateFormat('dd/MM/yyyy').format(yesterday)}',
            'timestamp': Timestamp.fromDate(yesterday),
          },
          {
            'id': 'log_3',
            'title': 'Cập Nhật STK VietQR Hệ Thống',
            'subtitle': 'Đổi STK MBBank: ...889999 (Xác thực PayOS)',
            'amount': null,
            'performer': 'Super Admin B',
            'timeStr': '10:15:30',
            'category': 'system',
            'dateGroup':
                'HÔM QUA - ${DateFormat('dd/MM/yyyy').format(yesterday)}',
            'timestamp': Timestamp.fromDate(yesterday),
          },
        ];

        for (var item in seedLogs) {
          final docRef = FirebaseFirestore.instance
              .collection('audit_logs')
              .doc(item['id'] as String);
          batch.set(docRef, item);
        }

        // Tạo cấu hình hoa hồng mặc định nếu chưa có
        final configRef = FirebaseFirestore.instance
            .collection('system_configs')
            .doc('platform_settings');
        batch.set(configRef, {
          'commission_rate': 10.0,
          'previous_rate': 10.0,
          'performer': 'Super Admin B',
          'timeStr': '09:30:12',
          'updatedAt': Timestamp.fromDate(now),
        }, SetOptions(merge: true));

        await batch.commit();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Firestore seed audit_logs error: $e');
    }
  }

  // Parse thời gian an toàn tuyệt đối
  DateTime? _parseDateTimeSafe(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) {
      try {
        return val.toDate();
      } catch (_) {
        return null;
      }
    }
    if (val is DateTime) return val;
    if (val is String) {
      try {
        return DateTime.tryParse(val);
      } catch (_) {
        return null;
      }
    }
    if (val is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(val);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // Cập nhật Tỷ lệ Hoa hồng Sàn lên Firestore
  Future<void> _updateCommissionRate(double currentRate, double newRate) async {
    try {
      final now = DateTime.now();
      final timeStr = DateFormat('HH:mm:ss').format(now);

      await FirebaseFirestore.instance
          .collection('system_configs')
          .doc('platform_settings')
          .set({
            'commission_rate': newRate,
            'previous_rate': currentRate,
            'performer': 'Super Admin B',
            'timeStr': timeStr,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Ghi nhật ký kiểm toán vào Firestore
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'title': 'Cập Nhật Phí Hoa Hồng Sàn',
        'subtitle':
            'Thay đổi mức phí từ ${currentRate.toStringAsFixed(1)}% ➔ ${newRate.toStringAsFixed(1)}%',
        'performer': 'Super Admin B',
        'timeStr': timeStr,
        'amount': null,
        'category': 'system',
        'dateGroup': 'HÔM NAY - ${DateFormat('dd/MM/yyyy').format(now)}',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF12B76A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Text(
              'Đã cập nhật hoa hồng sàn thành ${newRate.toStringAsFixed(1)}% lên Firebase!',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD92D20),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Text(
              'Không thể cập nhật: $e',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        );
      }
    }
  }

  // Modal cấu hình tỷ lệ hoa hồng
  void _showCommissionConfigBottomSheet(double currentRate) {
    final rateCtrl = TextEditingController(text: currentRate.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 22),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9F5FC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.settings_suggest_rounded,
                      color: Color(0xFF398FC0),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Cấu hình Tỷ lệ Hoa Hồng Sàn',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF101828),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Mức phí áp dụng tự động khi quyết toán các đơn cọc phòng trên toàn hệ thống HomeShare.',
                style: TextStyle(
                  fontSize: 14.5,
                  color: Color(0xFF667085),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: rateCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF101828),
                ),
                decoration: InputDecoration(
                  labelText: 'Tỷ lệ hoa hồng sàn (%)',
                  labelStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF344054),
                  ),
                  hintText: 'Nhập %, ví dụ: 5.0',
                  hintStyle: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF98A2B3),
                  ),
                  suffixText: '%',
                  suffixStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF398FC0),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF4F9FF),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFFDCEAF5),
                      width: 1.2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFFDCEAF5),
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF398FC0),
                      width: 1.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    final parsed = double.tryParse(rateCtrl.text);
                    if (parsed != null && parsed >= 0 && parsed <= 50) {
                      Navigator.pop(ctx);
                      _updateCommissionRate(currentRate, parsed);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF398FC0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'LƯU CẤU HÌNH MỚI',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
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

  // Modal Chi tiết Nhật ký
  void _showLogDetail(Map<String, dynamic> log) {
    final title = (log['title'] ?? '').toString();
    final subtitle = (log['subtitle'] ?? '').toString();
    final performer = (log['performer'] ?? '').toString();
    final timeStr = (log['timeStr'] ?? '').toString();
    final category = (log['category'] ?? '').toString();
    final amount = log['amount'] is num
        ? (log['amount'] as num).toDouble()
        : null;
    final dateGroup = (log['dateGroup'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: category == 'finance'
                        ? const Color(0xFFECFDF3)
                        : (category == 'refund'
                              ? const Color(0xFFFEF3F2)
                              : const Color(0xFF0C111D)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    category == 'finance'
                        ? 'TÀI CHÍNH'
                        : (category == 'refund' ? 'HOÀN CỌC' : 'HỆ THỐNG'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: category == 'finance'
                          ? const Color(0xFF12B76A)
                          : (category == 'refund'
                                ? const Color(0xFFD92D20)
                                : Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  dateGroup,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101828),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF475467),
                height: 1.4,
              ),
            ),
            if (amount != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDCEAF5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Số tiền giao dịch:',
                      style: TextStyle(fontSize: 14, color: Color(0xFF667085)),
                    ),
                    Text(
                      '${currencyFormatter.format(amount)} đ',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: category == 'finance'
                            ? const Color(0xFF12B76A)
                            : const Color(0xFFD92D20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 20,
                  color: Color(0xFF398FC0),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Người thực hiện: ',
                  style: TextStyle(fontSize: 14, color: Color(0xFF667085)),
                ),
                Text(
                  performer,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF398FC0),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.access_time_rounded,
                  size: 18,
                  color: Color(0xFF667085),
                ),
                const SizedBox(width: 4),
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Color(0xFFD0D5DD)),
                ),
                child: const Text(
                  'ĐÓNG',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF344054),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: const AdminBrandedTitle(title: 'Lịch sử'),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: InkWell(
              onTap: () => _confirmLogout(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECDCA)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.logout_rounded,
                      size: 17,
                      color: Color(0xFFD92D20),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Đăng xuất',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD92D20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Ô Tìm kiếm
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: SizedBox(
              height: 48,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() {}),
                style: const TextStyle(
                  fontSize: 14.5,
                  color: Color(0xFF101828),
                ),
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên Admin, Mã HĐ, Loại tác vụ...',
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF98A2B3),
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 22,
                    color: Color(0xFF667085),
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            size: 18,
                            color: Color(0xFF98A2B3),
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF4F9FF),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFFDCEAF5),
                      width: 1.2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFFDCEAF5),
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF398FC0),
                      width: 1.6,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Nội dung cuộn chính
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Mục CẤU HÌNH
                const Text(
                  'CẤU HÌNH',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF398FC0),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),

                // Thẻ Cấu hình hoa hồng sàn
                StreamBuilder<DocumentSnapshot>(
                  stream: () {
                    try {
                      return FirebaseFirestore.instance
                          .collection('system_configs')
                          .doc('platform_settings')
                          .snapshots();
                    } catch (_) {
                      return const Stream<DocumentSnapshot>.empty();
                    }
                  }(),
                  builder: (context, snapshot) {
                    Map<String, dynamic> data = {};
                    if (snapshot.hasData &&
                        snapshot.data != null &&
                        snapshot.data!.exists) {
                      try {
                        data =
                            snapshot.data!.data() as Map<String, dynamic>? ??
                            {};
                      } catch (_) {}
                    }

                    final currentRate =
                        (data['commission_rate'] as num?)?.toDouble() ?? 10.0;
                    final previousRate =
                        (data['previous_rate'] as num?)?.toDouble() ?? 10.0;
                    final performer = (data['performer'] ?? 'Super Admin B')
                        .toString();
                    final timeStr = (data['timeStr'] ?? '09:30:12').toString();

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFDCEAF5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9F5FC),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.local_offer_rounded,
                              size: 26,
                              color: Color(0xFFF79009),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cập Nhật Phí Hoa Hồng Sàn',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF101828),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      color: Color(0xFF475467),
                                    ),
                                    children: [
                                      const TextSpan(
                                        text: 'Thay đổi mức phí từ ',
                                      ),
                                      TextSpan(
                                        text:
                                            '${previousRate.toStringAsFixed(1)}% ',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF344054),
                                        ),
                                      ),
                                      const TextSpan(text: '➔ '),
                                      TextSpan(
                                        text:
                                            '${currentRate.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF398FC0),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Text(
                                      'Thực hiện bởi: ',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF667085),
                                      ),
                                    ),
                                    Text(
                                      performer,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF398FC0),
                                      ),
                                    ),
                                    Text(
                                      ' • $timeStr',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF667085),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () =>
                                _showCommissionConfigBottomSheet(currentRate),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE9F5FC),
                              foregroundColor: const Color(0xFF398FC0),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'THAY ĐỔI',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Nút Lọc Theo Ngày
                Row(
                  children: [
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: effectiveSelectedDate,
                          firstDate: DateTime(2025),
                          lastDate: DateTime(2028),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                            _filterByDate = true;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF4FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDCEAF5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_month_outlined,
                              size: 20,
                              color: Color(0xFF344054),
                            ),
                            const SizedBox(width: 8),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  color: Color(0xFF344054),
                                ),
                                children: [
                                  const TextSpan(text: 'Đối soát: '),
                                  TextSpan(
                                    text: DateFormat(
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
                    if (_filterByDate) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => setState(() => _filterByDate = false),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Color(0xFF667085),
                        ),
                        label: const Text(
                          'Hiện tất cả',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF667085),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                // Lấy Nhật ký kiểm toán 100% Động từ Firebase 'audit_logs'
                StreamBuilder<QuerySnapshot>(
                  stream: () {
                    try {
                      return FirebaseFirestore.instance
                          .collection('audit_logs')
                          .snapshots();
                    } catch (_) {
                      return const Stream<QuerySnapshot>.empty();
                    }
                  }(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF398FC0),
                        ),
                      );
                    }

                    List<QueryDocumentSnapshot> docs =
                        snapshot.data?.docs ?? [];
                    final List<Map<String, dynamic>> logsList = [];

                    for (var doc in docs) {
                      try {
                        final data = doc.data() as Map<String, dynamic>? ?? {};
                        final title = (data['title'] ?? 'Tác vụ hệ thống')
                            .toString();
                        final performer = (data['performer'] ?? 'Admin')
                            .toString();
                        final subtitle = (data['subtitle'] ?? '').toString();
                        final category = (data['category'] ?? 'system')
                            .toString();
                        final amount = data['amount'] is num
                            ? (data['amount'] as num).toDouble()
                            : null;
                        final timeStr = (data['timeStr'] ?? '12:00:00')
                            .toString();

                        final dt = _parseDateTimeSafe(data['timestamp']);
                        String dateGroup = (data['dateGroup'] ?? '').toString();

                        if (dateGroup.isEmpty) {
                          if (dt != null) {
                            final now = DateTime.now();
                            if (dt.year == now.year &&
                                dt.month == now.month &&
                                dt.day == now.day) {
                              dateGroup =
                                  'HÔM NAY - ${DateFormat('dd/MM/yyyy').format(dt)}';
                            } else {
                              dateGroup =
                                  'HÔM QUA - ${DateFormat('dd/MM/yyyy').format(dt)}';
                            }
                          } else {
                            dateGroup = 'LỊCH SỬ CHUNG';
                          }
                        }

                        logsList.add({
                          'id': doc.id,
                          'title': title,
                          'subtitle': subtitle,
                          'amount': amount,
                          'performer': performer,
                          'timeStr': timeStr,
                          'category': category,
                          'dateGroup': dateGroup,
                          'dateTime': dt ?? DateTime.now(),
                        });
                      } catch (_) {}
                    }

                    // Sắp xếp theo thời gian mới nhất
                    logsList.sort((a, b) {
                      final dtA = a['dateTime'] as DateTime?;
                      final dtB = b['dateTime'] as DateTime?;
                      if (dtA == null && dtB == null) return 0;
                      if (dtA == null) return 1;
                      if (dtB == null) return -1;
                      return dtB.compareTo(dtA);
                    });

                    final query = _searchCtrl.text.trim().toUpperCase();
                    final filtered = logsList.where((log) {
                      if (_filterByDate && _selectedDate != null) {
                        final dt = log['dateTime'] as DateTime?;
                        if (dt != null) {
                          if (dt.year != _selectedDate!.year ||
                              dt.month != _selectedDate!.month ||
                              dt.day != _selectedDate!.day) {
                            return false;
                          }
                        }
                      }
                      if (query.isEmpty) return true;
                      final t = (log['title'] ?? '').toString().toUpperCase();
                      final p = (log['performer'] ?? '')
                          .toString()
                          .toUpperCase();
                      final s = (log['subtitle'] ?? '')
                          .toString()
                          .toUpperCase();
                      return t.contains(query) ||
                          p.contains(query) ||
                          s.contains(query);
                    }).toList();

                    // Nhóm danh sách theo ngày
                    final Map<String, List<Map<String, dynamic>>> grouped = {};
                    for (var log in filtered) {
                      final group = (log['dateGroup'] ?? 'LỊCH SỬ').toString();
                      grouped.putIfAbsent(group, () => []).add(log);
                    }

                    if (grouped.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.history_toggle_off_rounded,
                                size: 56,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Chưa có lịch sử hoạt động nào trên Firestore',
                                style: TextStyle(
                                  color: Color(0xFF667085),
                                  fontSize: 15,
                                ),
                              ),
                              if (_filterByDate) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _filterByDate = false),
                                  child: const Text(
                                    'Xem tất cả các ngày',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF398FC0),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: grouped.entries.map((entry) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 4,
                                bottom: 12,
                              ),
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF344054),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            ...entry.value.map(
                              (log) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: InkWell(
                                  onTap: () => _showLogDetail(log),
                                  borderRadius: BorderRadius.circular(18),
                                  child: _buildHistoryCard(log),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Thẻ Lịch sử
  Widget _buildHistoryCard(Map<String, dynamic> log) {
    final title = (log['title'] ?? '').toString();
    final subtitle = (log['subtitle'] ?? '').toString();
    final performer = (log['performer'] ?? '').toString();
    final timeStr = (log['timeStr'] ?? '').toString();
    final category = (log['category'] ?? '').toString();
    final amount = log['amount'] is num
        ? (log['amount'] as num).toDouble()
        : null;

    Widget iconWidget;
    Widget badgeWidget;

    if (category == 'finance') {
      iconWidget = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.check_box_rounded,
          color: Color(0xFF12B76A),
          size: 26,
        ),
      );
      badgeWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'TÀI CHÍNH',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF12B76A),
          ),
        ),
      );
    } else if (category == 'refund') {
      iconWidget = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3F2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.sync_alt_rounded,
          color: Color(0xFFD92D20),
          size: 24,
        ),
      );
      badgeWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3F2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'HOÀN CỌC',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFFD92D20),
          ),
        ),
      );
    } else {
      iconWidget = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFFEF0C7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.account_balance_rounded,
          color: Color(0xFFB54708),
          size: 24,
        ),
      );
      badgeWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: const Color(0xFF0C111D),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'HỆ THỐNG',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCEAF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconWidget,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF101828),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    badgeWidget,
                  ],
                ),
                const SizedBox(height: 6),
                _buildSubtitleWithHighlightedAmount(subtitle, amount, category),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Text(
                      'Thực hiện bởi: ',
                      style: TextStyle(fontSize: 13, color: Color(0xFF667085)),
                    ),
                    Text(
                      performer,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF398FC0),
                      ),
                    ),
                    Text(
                      ' • $timeStr',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitleWithHighlightedAmount(
    String subtitle,
    double? amount,
    String category,
  ) {
    if (amount != null) {
      final formatted = currencyFormatter.format(amount);
      if (subtitle.contains(formatted)) {
        final parts = subtitle.split(formatted);
        final color = category == 'finance'
            ? const Color(0xFF12B76A)
            : const Color(0xFFD92D20);

        return RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 14.5, color: Color(0xFF475467)),
            children: [
              TextSpan(text: parts[0]),
              TextSpan(
                text: '$formatted đ',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (parts.length > 1)
                TextSpan(text: parts[1].replaceAll('đ', '').trimLeft()),
            ],
          ),
        );
      }
    }

    return Text(
      subtitle,
      style: const TextStyle(fontSize: 14.5, color: Color(0xFF475467)),
    );
  }
}