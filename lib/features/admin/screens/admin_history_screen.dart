import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/role_resolver.dart';
import '../widgets/admin_branded_title.dart';
import '../services/admin_audit_identity.dart';
import '../services/admin_audit_excel_exporter.dart';
import '../services/admin_access_service.dart';

class AdminHistoryScreen extends ConsumerStatefulWidget {
  const AdminHistoryScreen({super.key});

  @override
  ConsumerState<AdminHistoryScreen> createState() => _AdminHistoryScreenState();
}

class _AdminHistoryScreenState extends ConsumerState<AdminHistoryScreen>
    with TickerProviderStateMixin {
  static const _legacySeedLogIds = {
    'log_1',
    'log_2',
    'log_3',
    'log_4',
    'ulog_1',
    'ulog_2',
    'ulog_3',
  };

  final TextEditingController _searchCtrl = TextEditingController();
  final Map<String, Future<bool>> _auditAdminRoleFutures = {};
  DateTime? _selectedDate;
  DateTime get effectiveSelectedDate => _selectedDate ?? DateTime.now();

  final currencyFormatter = NumberFormat('#,###', 'vi_VN');
  bool _filterByDate = false;
  bool _isExportingAuditLogs = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.dispose();
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

  int _historyGroupFor(String category, String targetType) {
    final normalized = category.toLowerCase().replaceAll('_', '').trim();
    final target = targetType.toLowerCase().trim();
    if (target == 'post' ||
        target == 'posts' ||
        normalized.contains('post') ||
        normalized.contains('baitdang')) {
      return 1;
    }
    if (target == 'user' ||
        target == 'users' ||
        normalized.contains('user') ||
        normalized.contains('nguoidung') ||
        normalized.contains('account') ||
        normalized.contains('vipham') ||
        normalized.contains('violation')) {
      return 2;
    }
    if (normalized == 'system' || normalized == 'hethong') return 3;
    return 0;
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

  String _auditValue(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
    Set<String> ignoredValues = const {},
  }) {
    for (final key in keys) {
      final value = (data[key] ?? '').toString().trim();
      if (value.isNotEmpty && !ignoredValues.contains(value.toLowerCase())) {
        return value;
      }
    }
    return fallback;
  }

  Future<List<Map<String, dynamic>>> _filterAuditLogsByActor(
    List<Map<String, dynamic>> logs,
    String query,
  ) async {
    final adminLogs = <Map<String, dynamic>>[];
    for (final log in logs) {
      if (await _isAdminAuditLog(log)) adminLogs.add(log);
    }
    if (query.isEmpty) return adminLogs;

    final normalizedQuery = query.toLowerCase();
    return adminLogs.where((log) {
      final title = (log['title'] ?? '').toString().toLowerCase();
      final subtitle = (log['subtitle'] ?? '').toString().toLowerCase();
      final cat = (log['category'] ?? '').toString().toLowerCase();
      return title.contains(normalizedQuery) ||
          subtitle.contains(normalizedQuery) ||
          cat.contains(normalizedQuery);
    }).toList();
  }

  Future<bool> _isAdminAuditLog(Map<String, dynamic> data) async {
    final role = (data['actorRole'] ?? '').toString().trim().toLowerCase();
    if (role == 'host' ||
        role == 'landlord' ||
        role == 'chutro' ||
        role == 'renter' ||
        role == 'tenant' ||
        role == 'nguoidung' ||
        role == 'user') {
      return false;
    }

    final title = (data['title'] ?? data['action'] ?? '').toString().toLowerCase();
    final subtitle = (data['subtitle'] ?? data['details'] ?? '').toString().toLowerCase();
    if (title.startsWith('khách ') ||
        title.startsWith('người thuê ') ||
        title.startsWith('người dùng ') ||
        title == 'xác nhận nhận phòng' ||
        subtitle.contains('báo đã chuyển khoản ngoài app') ||
        subtitle.contains('thành công qua mã qr')) {
      return false;
    }

    if (AdminAuditIdentity.hasExplicitAdminRole(data)) return true;
    if (AdminAuditIdentity.isKnownAdminAction(data)) return true;

    final actorUid = AdminAuditIdentity.legacyActorUid(data);
    if (actorUid == null) {
      return true;
    }

    return _auditAdminRoleFutures.putIfAbsent(actorUid, () async {
      try {
        final user = await FirebaseFirestore.instance
            .collection('users')
            .doc(actorUid)
            .get();
        if (RoleResolver.extractRoleFromMap(user.data()) ==
            RoleResolver.admin) {
          return true;
        }

        final access = await AdminAccessService.accessStream(actorUid).first;
        return access.data()?['enabled'] == true;
      } catch (error) {
        return false;
      }
    });
  }

  Future<void> _exportMonthlyAuditLogs() async {
    final selectedMonth = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        var selectedYear = effectiveSelectedDate.year.clamp(2020, 2100);
        final monthGridHeight = (MediaQuery.sizeOf(dialogContext).height * 0.4)
            .clamp(160.0, 320.0)
            .toDouble();
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Chọn tháng xuất Excel'),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Năm',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      DropdownButton<int>(
                        value: selectedYear,
                        items: [
                          for (var year = 2020; year <= 2100; year++)
                            DropdownMenuItem(
                              value: year,
                              child: Text(year.toString()),
                            ),
                        ],
                        onChanged: (year) {
                          if (year != null) {
                            setDialogState(() => selectedYear = year);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: monthGridHeight,
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var month = 1; month <= 12; month++)
                            SizedBox(
                              width: 88,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(
                                  dialogContext,
                                  DateTime(selectedYear, month),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                ),
                                child: Text('Tháng $month'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Hủy'),
              ),
            ],
          ),
        );
      },
    );
    if (selectedMonth == null || !mounted) return;

    setState(() => _isExportingAuditLogs = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('audit_logs')
          .get();
      final monthLogs = <({DateTime date, List<Object?> row})>[];

      for (final doc in snapshot.docs) {
        if (_legacySeedLogIds.contains(doc.id)) continue;
        final data = doc.data();
        if (!await _isAdminAuditLog(data)) continue;
        final date = _parseDateTimeSafe(
          data['timestamp'] ??
              data['createdAt'] ??
              data['updatedAt'] ??
              data['effectiveAt'],
        );
        if (date == null ||
            date.year != selectedMonth.year ||
            date.month != selectedMonth.month) {
          continue;
        }

        final title = (data['title'] ?? data['action'] ?? 'Tác vụ Admin').toString();
        final subtitle = (data['subtitle'] ??
                data['details'] ??
                data['description'] ??
                data['target'] ??
                '')
            .toString();
        final catRaw = (data['category'] ?? '').toString().toLowerCase();
        final combined = '$catRaw ${title.toLowerCase()} ${subtitle.toLowerCase()}';
        
        String categoryLabel;
        if (catRaw.contains('post') || catRaw.contains('baidang') || combined.contains('tin đăng') || combined.contains('bài đăng')) {
          categoryLabel = 'Bài đăng';
        } else if (catRaw.contains('user') || catRaw.contains('nguoidung') || catRaw.contains('vipham') || catRaw.contains('violation') || combined.contains('tài khoản')) {
          categoryLabel = 'Người dùng';
        } else if (catRaw.contains('finance') ||
            catRaw.contains('taichinh') ||
            catRaw.contains('quanlydon') ||
            catRaw.contains('order') ||
            catRaw.contains('booking') ||
            catRaw.contains('deposit') ||
            catRaw.contains('refund') ||
            combined.contains('quản lý đơn') ||
            combined.contains('tiền cọc') ||
            combined.contains('đơn thuê') ||
            combined.contains('thanh toán') ||
            combined.contains('quyết toán') ||
            combined.contains('hoàn cọc') ||
            combined.contains('hoa hồng')) {
          categoryLabel = 'Tài chính';
        } else {
          categoryLabel = 'Hệ thống';
        }

        final rawAmount = data['amount'] ?? data['totalAmount'];
        monthLogs.add((
          date: date,
          row: [
            doc.id,
            DateFormat('dd/MM/yyyy HH:mm:ss').format(date),
            title,
            subtitle,
            categoryLabel,
            rawAmount is num ? rawAmount : '',
          ],
        ));
      }

      if (monthLogs.isEmpty) {
        _showAuditExportMessage(
          'Không có thao tác nào trong tháng ${DateFormat('MM/yyyy').format(selectedMonth)}.',
        );
        return;
      }

      monthLogs.sort((a, b) => b.date.compareTo(a.date));
      final rows = <List<Object?>>[
        const [
          'Mã nhật ký',
          'Thời gian',
          'Thao tác',
          'Chi tiết',
          'Danh mục',
          'Số tiền (đ)',
        ],
        ...monthLogs.map((entry) => entry.row),
      ];
      final bytes = AdminAuditExcelExporter.create(rows);
      final fileName =
          'lich_su_admin_${DateFormat('yyyy_MM').format(selectedMonth)}.xlsx';
      final tempFile = File('${Directory.systemTemp.path}/$fileName');
      await tempFile.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [
          XFile(
            tempFile.path,
            name: fileName,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject:
            'Lịch sử hoạt động admin tháng ${DateFormat('MM/yyyy').format(selectedMonth)}',
      );
      _showAuditExportMessage(
        'Đã tạo file $fileName. Chọn nơi lưu trong bảng chia sẻ.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Không thể xuất lịch sử admin theo tháng: $error\n$stackTrace',
      );
      _showAuditExportMessage('Không thể xuất Excel: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isExportingAuditLogs = false);
    }
  }

  void _showAuditExportMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFFD92D20)
            : const Color(0xFF12B76A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _authenticateAndShowAdminAccessManager() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !AdminAccessService.isManager(user)) return;

    final authenticated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ManagerAuthenticationDialog(user: user),
    );
    if (authenticated == true && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) _showAdminAccessManager();
    }
  }

  void _showAdminAccessManager() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final screen = MediaQuery.sizeOf(dialogContext);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: SizedBox(
            width: screen.width * 0.9,
            height: screen.height * 0.72,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Quản lý quyền Admin',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: 'admin')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'Không tải được danh sách admin. Kiểm tra mạng hoặc quyền Firestore.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final admins = snapshot.data!.docs;
                      if (admins.isEmpty) {
                        return const Center(
                          child: Text('Chưa có tài khoản admin.'),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: admins.length,
                        itemBuilder: (context, index) {
                          final doc = admins[index];
                          final data = doc.data();
                          final email = (data['email'] ?? '').toString();
                          final name =
                              (data['displayName'] ?? data['hoTen'] ?? email)
                                  .toString();
                          final isManagerAccount =
                              email.trim().toLowerCase() ==
                              AdminAccessService.managerEmail;

                          return StreamBuilder<
                            DocumentSnapshot<Map<String, dynamic>>
                          >(
                            stream: AdminAccessService.accessStream(doc.id),
                            builder: (context, accessSnapshot) {
                              final enabled =
                                  isManagerAccount ||
                                  accessSnapshot.data?.data()?['enabled'] ==
                                      true;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '$email\nUID: ${doc.id}${isManagerAccount ? ' • Manager' : ''}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                isThreeLine: true,
                                trailing:
                                    accessSnapshot.connectionState ==
                                            ConnectionState.waiting &&
                                        !isManagerAccount
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Switch.adaptive(
                                        value: enabled,
                                        onChanged:
                                            isManagerAccount ||
                                                accessSnapshot.hasError
                                            ? null
                                            : (value) async {
                                                try {
                                                  await AdminAccessService.setAdminAccess(
                                                    uid: doc.id,
                                                    adminName: name,
                                                    enabled: value,
                                                  );
                                                } catch (e) {
                                                  if (!mounted || !context.mounted) return;
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Không thể cập nhật quyền admin: $e',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                      ),
                              );
                            },
                          );
                        },
                        separatorBuilder: (_, _) => const Divider(height: 1),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Đóng'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Cập nhật Tỷ lệ Hoa hồng Sàn lên Firestore
  Future<void> _updateCommissionRate(double currentRate, double newRate) async {
    try {
      final actorFields = await AdminAuditIdentity.currentActorFields();
      final now = DateTime.now();
      final timeStr = DateFormat('HH:mm:ss').format(now);
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.set(db.collection('system_configs').doc('platform_settings'), {
        'commission_rate': newRate,
        'previous_rate': currentRate,
        'performer': actorFields['performer'],
        'performerId': actorFields['performerId'],
        'timeStr': timeStr,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(db.collection('commission_rate_history').doc(), {
        'previousRate': currentRate,
        'rate': newRate,
        'effectiveAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        ...actorFields,
      });

      // Ghi nhật ký kiểm toán và cấu hình theo cùng một batch.
      batch.set(db.collection('audit_logs').doc(), {
        ...actorFields,
        'title': 'Cập Nhật Phí Hoa Hồng Sàn',
        'subtitle':
            'Thay đổi mức phí từ ${currentRate.toStringAsFixed(1)}% ➔ ${newRate.toStringAsFixed(1)}%',
        'timeStr': timeStr,
        'amount': null,
        'category': 'system',
        'dateGroup': 'HÔM NAY - ${DateFormat('dd/MM/yyyy').format(now)}',
        'timestamp': FieldValue.serverTimestamp(),
      });
      await batch.commit();

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

  // Cập nhật trạng thái bảo trì lên Firestore
  Future<void> _updateMaintenanceMode(
    bool isMaintenance,
    Map<String, dynamic> currentData,
  ) async {
    try {
      final actorFields = await AdminAuditIdentity.currentActorFields();
      final now = DateTime.now();
      final timeStr = DateFormat('HH:mm:ss').format(now);
      final performer = actorFields['performer'].toString();

      await FirebaseFirestore.instance
          .collection('system_configs')
          .doc('maintenance_config')
          .set({
            'is_maintenance': isMaintenance,
            'message':
                currentData['message'] ??
                'HomeShare đang bảo trì nâng cấp hệ thống. Vui lòng quay lại sau!',
            'expected_completion':
                currentData['expected_completion'] ?? '2026-10-27T02:00:00Z',
            'allowed_roles': currentData['allowed_roles'] ?? ['QUAN_TRI_VIEN'],
            'updated_at': FieldValue.serverTimestamp(),
            'updated_by': performer,
            'updated_by_id': actorFields['actorUid'],
          }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('audit_logs').add({
        ...actorFields,
        'title': 'Cập Nhật Chế Độ Bảo Trì',
        'subtitle': '${isMaintenance ? 'Bật' : 'Tắt'} chế độ bảo trì hệ thống',
        'performer': performer,
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
              'Đã ${isMaintenance ? 'bật' : 'tắt'} chế độ bảo trì hệ thống!',
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
              'Không thể cập nhật bảo trì: $e',
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

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String? validationMessage;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: StatefulBuilder(
                builder: (context, setSheetState) => Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
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
                        'Mức phí mới áp dụng cho đơn tạo sau thời điểm cập nhật. Đơn cũ giữ tỷ lệ hoa hồng tại thời điểm đơn được tạo.',
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
                          errorText: validationMessage,
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
                        onChanged: (_) {
                          if (validationMessage != null) {
                            setSheetState(() => validationMessage = null);
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            final parsed = double.tryParse(
                              rateCtrl.text.trim().replaceAll(',', '.'),
                            );
                            if (parsed == null || parsed < 0 || parsed > 50) {
                              setSheetState(
                                () => validationMessage =
                                    'Vui lòng nhập tỷ lệ từ 0 đến 50%.',
                              );
                              return;
                            }
                            FocusScope.of(ctx).unfocus();
                            Navigator.pop(ctx);
                            _updateCommissionRate(currentRate, parsed);
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
            ),
          ),
        );
      },
    ).whenComplete(rateCtrl.dispose);
  }

  // Bottom sheet chỉnh sửa cấu hình bảo trì
  void _showMaintenanceConfigBottomSheet(Map<String, dynamic> currentData) {
    final messageCtrl = TextEditingController(
      text: (currentData['message'] ?? '').toString(),
    );
    final rolesCtrl = TextEditingController(
      text:
          (currentData['allowed_roles'] as List?)?.join(', ') ??
          'QUAN_TRI_VIEN',
    );

    DateTime? expectedCompletion = _parseDateTimeSafe(
      currentData['expected_completion'],
    );
    expectedCompletion ??= DateTime.now().add(const Duration(days: 1));

    // Use StatefulBuilder to update date inside the bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx2).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
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
                          color: const Color(0xFFFEF0C7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.build_circle_rounded,
                          color: Color(0xFFF79009),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Chỉnh sửa Chế Độ Bảo Trì',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF101828),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Message
                  const Text(
                    'Thông báo bảo trì',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF344054),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: messageCtrl,
                    maxLines: 3,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF101828),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Nhập thông báo hiển thị khi bảo trì...',
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF98A2B3),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF4F9FF),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
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
                          color: Color(0xFFF79009),
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Expected completion date/time
                  const Text(
                    'Thời gian hoàn thành dự kiến',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF344054),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: ctx2,
                        initialDate: expectedCompletion ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (pickedDate != null) {
                        if (!ctx2.mounted) return;
                        final pickedTime = await showTimePicker(
                          context: ctx2,
                          initialTime: TimeOfDay.fromDateTime(
                            expectedCompletion ?? DateTime.now(),
                          ),
                        );
                        if (pickedTime != null) {
                          setSheetState(() {
                            expectedCompletion = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F9FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFDCEAF5),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 20,
                            color: Color(0xFFF79009),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              expectedCompletion != null
                                  ? DateFormat(
                                      'dd/MM/yyyy HH:mm',
                                    ).format(expectedCompletion!)
                                  : 'Chọn ngày giờ...',
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF101828),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF667085),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Allowed roles
                  const Text(
                    'Vai trò được phép truy cập (cách nhau bởi dấu phẩy)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF344054),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: rolesCtrl,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF101828),
                    ),
                    decoration: InputDecoration(
                      hintText: 'VD: QUAN_TRI_VIEN, MOD',
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF98A2B3),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF4F9FF),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
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
                          color: Color(0xFFF79009),
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () async {
                        final roles = rolesCtrl.text
                            .split(',')
                            .map((r) => r.trim())
                            .where((r) => r.isNotEmpty)
                            .toList();
                        Navigator.pop(ctx2);

                        final now = DateTime.now();
                        final timeStr = DateFormat('HH:mm:ss').format(now);
                        final actorFields =
                            await AdminAuditIdentity.currentActorFields();
                        final performer = actorFields['performer'].toString();

                        try {
                          await FirebaseFirestore.instance
                              .collection('system_configs')
                              .doc('maintenance_config')
                              .set({
                                'message': messageCtrl.text.trim(),
                                'expected_completion':
                                    expectedCompletion?.toIso8601String() ?? '',
                                'allowed_roles': roles,
                                'updated_at': FieldValue.serverTimestamp(),
                                'updated_by': performer,
                                'updated_by_id': actorFields['actorUid'],
                              }, SetOptions(merge: true));

                          await FirebaseFirestore.instance
                              .collection('audit_logs')
                              .add({
                                ...actorFields,
                                'title': 'Cập Nhật Chế Độ Bảo Trì',
                                'subtitle':
                                    'Chỉnh sửa cấu hình bảo trì hệ thống',
                                'performer': performer,
                                'timeStr': timeStr,
                                'amount': null,
                                'category': 'system',
                                'dateGroup':
                                    'HÔM NAY - ${DateFormat('dd/MM/yyyy').format(now)}',
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
                                content: const Text(
                                  'Đã lưu cấu hình bảo trì!',
                                  style: TextStyle(
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
                                  'Lỗi lưu cấu hình: $e',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF79009),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'LƯU CẤU HÌNH',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Modal Chi tiết Nhật ký
  void _showLogDetail(Map<String, dynamic> log) {
    final title = (log['title'] ?? '').toString();
    final subtitle = (log['subtitle'] ?? '').toString();
    final timeStr = (log['timeStr'] ?? '').toString();
    final category = (log['category'] ?? '').toString();
    final amount = log['amount'] is num
        ? (log['amount'] as num).toDouble()
        : null;
    final dateGroup = (log['dateGroup'] ?? '').toString();
    final dt = log['dateTime'] as DateTime?;
    final fullDateTime = dt != null
        ? DateFormat('dd/MM/yyyy HH:mm:ss').format(dt)
        : timeStr;

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
                _buildCategoryBadge(category, title: title, subtitle: subtitle),
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
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF12B76A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Thời gian thao tác: chỉ hiển thị giờ/ngày
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 18,
                  color: Color(0xFF398FC0),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Thời gian: $fullDateTime',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF475467),
                      fontWeight: FontWeight.w500,
                    ),
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

  // Badge theo category - Quản lý đơn luôn hiển thị (TÀI CHÍNH), không hiển thị (HỆ THỐNG)
  Widget _buildCategoryBadge(
    String category, {
    String title = '',
    String subtitle = '',
  }) {
    Color bgColor;
    Color textColor;
    String label;
    final normalized = category.toLowerCase().replaceAll('_', '').trim();
    final combined = '$normalized ${title.toLowerCase()} ${subtitle.toLowerCase()}';

    final isFinanceOrOrder = normalized.contains('finance') ||
        normalized.contains('taichinh') ||
        normalized.contains('quanlydon') ||
        normalized.contains('order') ||
        normalized.contains('booking') ||
        normalized.contains('deposit') ||
        normalized.contains('refund') ||
        normalized.contains('hoancoc') ||
        normalized.contains('nhanphong') ||
        normalized.contains('thanhtoan') ||
        normalized.contains('quyettoan') ||
        normalized.contains('tiencoc') ||
        combined.contains('quản lý đơn') ||
        combined.contains('tiền cọc') ||
        combined.contains('hoàn cọc') ||
        combined.contains('nhận phòng') ||
        combined.contains('thanh toán') ||
        combined.contains('quyết toán') ||
        combined.contains('hoa hồng');

    if (isFinanceOrOrder) {
      bgColor = const Color(0xFFECFDF3);
      textColor = const Color(0xFF12B76A);
      label = 'TÀI CHÍNH';
    } else {
      switch (normalized) {
        case 'violation':
        case 'vipham':
          bgColor = const Color(0xFFFEF3F2);
          textColor = const Color(0xFFD92D20);
          label = 'VI PHẠM';
          break;
        case 'user':
        case 'users':
        case 'nguoidung':
        case 'account':
          bgColor = const Color(0xFFE9F5FC);
          textColor = const Color(0xFF398FC0);
          label = 'TÀI KHOẢN';
          break;
        case 'post':
        case 'posts':
        case 'baidang':
          bgColor = const Color(0xFFE9F5FC);
          textColor = const Color(0xFF398FC0);
          label = 'BÀI ĐĂNG';
          break;
        default:
          bgColor = const Color(0xFFF2F4F7);
          textColor = const Color(0xFF344054);
          label = 'HỆ THỐNG';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
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
                  hintText: 'Tìm kiếm theo tác vụ, nội dung...',
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
                    final performer = (data['performer'] ?? 'Chưa có cập nhật')
                        .toString();
                    final performerId =
                        (data['performerId'] ?? data['updated_by_id'] ?? '')
                            .toString();
                    final updatedAt = _parseDateTimeSafe(data['updatedAt']);
                    final timeStr =
                        data['timeStr']?.toString() ??
                        (updatedAt == null
                            ? 'Chưa có thời gian'
                            : DateFormat(
                                'dd/MM/yyyy HH:mm:ss',
                              ).format(updatedAt));

                    final icon = Container(
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
                    );
                    final details = Column(
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
                              const TextSpan(text: 'Thay đổi mức phí từ '),
                              TextSpan(
                                text: '${previousRate.toStringAsFixed(1)}% ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF344054),
                                ),
                              ),
                              const TextSpan(text: '➔ '),
                              TextSpan(
                                text: '${currentRate.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF398FC0),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            const Text(
                              'Thực hiện bởi:',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF667085),
                              ),
                            ),
                            Text(
                              performer,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF398FC0),
                              ),
                            ),
                            Text(
                              '• $timeStr',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF667085),
                              ),
                            ),
                          ],
                        ),
                        if (performerId.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            'UID: $performerId',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF667085),
                            ),
                          ),
                        ],
                      ],
                    );
                    final changeButton = ElevatedButton(
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
                    );

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
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 520) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    icon,
                                    const SizedBox(width: 12),
                                    Expanded(child: details),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                changeButton,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              icon,
                              const SizedBox(width: 14),
                              Expanded(child: details),
                              const SizedBox(width: 12),
                              changeButton,
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),

                // ====================================================
                // THẺ CHẾ ĐỘ BẢO TRÌ HỆ THỐNG
                // ====================================================
                StreamBuilder<DocumentSnapshot>(
                  stream: () {
                    try {
                      return FirebaseFirestore.instance
                          .collection('system_configs')
                          .doc('maintenance_config')
                          .snapshots();
                    } catch (_) {
                      return const Stream<DocumentSnapshot>.empty();
                    }
                  }(),
                  builder: (context, snapshot) {
                    Map<String, dynamic> mData = {};
                    if (snapshot.hasData &&
                        snapshot.data != null &&
                        snapshot.data!.exists) {
                      try {
                        mData =
                            snapshot.data!.data() as Map<String, dynamic>? ??
                            {};
                      } catch (_) {}
                    }

                    final isMaintenance =
                        (mData['is_maintenance'] as bool?) ?? false;
                    final maintenanceMsg =
                        (mData['message'] ??
                                'HomeShare đang bảo trì nâng cấp hệ thống.')
                            .toString();
                    final updatedBy =
                        (mData['updated_by'] ?? 'Chưa có cập nhật').toString();
                    final allowedRoles =
                        (mData['allowed_roles'] as List?)
                            ?.map((e) => e.toString())
                            .toList() ??
                        ['QUAN_TRI_VIEN'];

                    final updatedAtDt = _parseDateTimeSafe(mData['updated_at']);
                    final updatedAtStr = updatedAtDt != null
                        ? DateFormat('dd/MM/yyyy HH:mm:ss').format(updatedAtDt)
                        : 'Chưa có thời gian';

                    final expectedDt = _parseDateTimeSafe(
                      mData['expected_completion'],
                    );
                    final expectedStr = expectedDt != null
                        ? DateFormat('dd/MM/yyyy HH:mm').format(expectedDt)
                        : 'Chưa xác định';

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isMaintenance
                              ? const Color(0xFFFEC84B)
                              : const Color(0xFFDCEAF5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF0C7),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.build_circle_rounded,
                                  size: 26,
                                  color: Color(0xFFF79009),
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Chế Độ Bảo Trì Hệ Thống',
                                      style: TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF101828),
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Bật/Tắt chế độ bảo trì toàn hệ thống',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF667085),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Toggle Switch
                              Switch(
                                value: isMaintenance,
                                activeThumbColor: const Color(0xFFF79009),
                                activeTrackColor: const Color(0xFFFEC84B),
                                onChanged: (val) {
                                  _updateMaintenanceMode(val, mData);
                                },
                              ),
                            ],
                          ),

                          // Expanded info khi đang BẬT
                          if (isMaintenance) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFEC84B),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        size: 16,
                                        color: Color(0xFFB45309),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          maintenanceMsg,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            color: Color(0xFF92400E),
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.schedule_rounded,
                                        size: 14,
                                        color: Color(0xFF667085),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Hoàn thành dự kiến: $expectedStr',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF475467),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.shield_outlined,
                                        size: 14,
                                        color: Color(0xFF667085),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Cho phép: ${allowedRoles.join(', ')}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF475467),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 10),
                          // Footer: người cập nhật + thời gian
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 14,
                                color: Color(0xFF667085),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Bởi: $updatedBy • $updatedAtStr',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF667085),
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    _showMaintenanceConfigBottomSheet(mData),
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 15,
                                  color: Color(0xFFF79009),
                                ),
                                label: const Text(
                                  'Chỉnh sửa cấu hình',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFF79009),
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Nút Lọc Theo Ngày
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
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
                    OutlinedButton.icon(
                      onPressed: _isExportingAuditLogs
                          ? null
                          : _exportMonthlyAuditLogs,
                      icon: _isExportingAuditLogs
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('Xuất Excel theo tháng'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF398FC0),
                        side: const BorderSide(color: Color(0xFFDCEAF5)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ====================================================
                // LỊCH SỬ HOẠT ĐỘNG
                // ====================================================
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    const Text(
                      'LỊCH SỬ HOẠT ĐỘNG',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF398FC0),
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (AdminAccessService.isManager(
                      AdminAccessService.safeCurrentUser,
                    ))
                      OutlinedButton.icon(
                        onPressed: _authenticateAndShowAdminAccessManager,
                        icon: const Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 17,
                        ),
                        label: const Text('Quản lý admin'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF398FC0),
                          side: const BorderSide(color: Color(0xFFDCEAF5)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // TabBar
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F9FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDCEAF5)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: const Color(0xFF101828),
                    unselectedLabelColor: const Color(0xFF667085),
                    labelStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                    isScrollable: true,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.receipt_long_rounded, size: 18),
                        text: 'Quản lý đơn',
                        iconMargin: EdgeInsets.only(bottom: 4),
                      ),
                      Tab(
                        icon: Icon(Icons.article_rounded, size: 18),
                        text: 'Bài đăng',
                        iconMargin: EdgeInsets.only(bottom: 4),
                      ),
                      Tab(
                        icon: Icon(Icons.people_rounded, size: 18),
                        text: 'Quản lý Users',
                        iconMargin: EdgeInsets.only(bottom: 4),
                      ),
                      Tab(
                        icon: Icon(Icons.settings_rounded, size: 18),
                        text: 'Hệ thống',
                        iconMargin: EdgeInsets.only(bottom: 4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Tab content via StreamBuilder (single stream, split by category)
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
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(
                            color: Color(0xFF398FC0),
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.cloud_off_rounded,
                                size: 42,
                                color: Color(0xFFD92D20),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Không thể tải lịch sử từ Firebase.',
                                style: TextStyle(color: Color(0xFF475467)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                snapshot.error.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF667085),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final List<QueryDocumentSnapshot> docs =
                        snapshot.data?.docs ?? [];
                    final List<Map<String, dynamic>> allLogs = [];

                    for (var doc in docs) {
                      // These seven IDs were written by the old mock seeder.
                      if (_legacySeedLogIds.contains(doc.id)) continue;
                      try {
                        final data = doc.data() as Map<String, dynamic>? ?? {};
                        final title =
                            (data['title'] ??
                                    data['action'] ??
                                    'Tác vụ hệ thống')
                                .toString();
                        final performer = _auditValue(
                          data,
                          const [
                            'actor',
                            'adminName',
                            'performer',
                            'performedBy',
                            'reviewedBy',
                            'updated_by',
                            'updatedBy',
                            'createdByName',
                            'adminEmail',
                            'actorEmail',
                            'updatedByEmail',
                            'actorName',
                            'updatedByName',
                            'performedByName',
                          ],
                          fallback: '',
                          ignoredValues: const {
                            'admin',
                            'không rõ',
                            'không xác định',
                            'n/a',
                            'system',
                            'hệ thống',
                            'hệ thống / admin',
                            'homeshare system',
                          },
                        );
                        final performerId =
                            AdminAuditIdentity.legacyActorUid(data) ?? 'N/A';
                        final subtitle =
                            (data['subtitle'] ??
                                    data['details'] ??
                                    data['description'] ??
                                    data['target'] ??
                                    '')
                                .toString();
                        final category = (data['category'] ?? 'system')
                            .toString();
                        final targetType =
                            (data['target_type'] ?? data['targetType'] ?? '')
                                .toString();
                        final rawAmount = data['amount'] ?? data['totalAmount'];
                        final amount = rawAmount is num
                            ? rawAmount.toDouble()
                            : null;
                        final dt = _parseDateTimeSafe(
                          data['timestamp'] ??
                              data['createdAt'] ??
                              data['updatedAt'] ??
                              data['effectiveAt'],
                        );
                        final timeStr =
                            data['timeStr']?.toString() ??
                            (dt == null
                                ? 'Chưa có thời gian'
                                : DateFormat('HH:mm:ss').format(dt));
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
                              dateGroup = DateFormat('dd/MM/yyyy').format(dt);
                            }
                          } else {
                            dateGroup = 'LỊCH SỬ CHUNG';
                          }
                        }

                        final fullDateTime = dt != null
                            ? DateFormat('dd/MM/yyyy HH:mm:ss').format(dt)
                            : 'Chưa có thời gian';

                        allLogs.add({
                          'id': doc.id,
                          'title': title,
                          'subtitle': subtitle,
                          'amount': amount,
                          'performer': performer,
                          'performerId': performerId,
                          'actorRole': data['actorRole'],
                          'actorUid': AdminAuditIdentity.legacyActorUid(data),
                          'adminEmail':
                              data['adminEmail'] ??
                              data['actorEmail'] ??
                              data['updatedByEmail'],
                          'timeStr': timeStr,
                          'fullDateTime': fullDateTime,
                          'category': category,
                          'target_type': targetType,
                          'dateGroup': dateGroup,
                          'dateTime': dt,
                        });
                      } catch (_) {}
                    }

                    // Sort newest first
                    allLogs.sort((a, b) {
                      final dtA = a['dateTime'] as DateTime?;
                      final dtB = b['dateTime'] as DateTime?;
                      if (dtA == null && dtB == null) return 0;
                      if (dtA == null) return 1;
                      if (dtB == null) return -1;
                      return dtB.compareTo(dtA);
                    });

                    final dateFilteredLogs = allLogs.where((log) {
                      if (!_filterByDate || _selectedDate == null) return true;
                      final dt = log['dateTime'] as DateTime?;
                      return dt != null &&
                          dt.year == _selectedDate!.year &&
                          dt.month == _selectedDate!.month &&
                          dt.day == _selectedDate!.day;
                    }).toList();
                    final query = _searchCtrl.text.trim();

                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: _filterAuditLogsByActor(dateFilteredLogs, query),
                      builder: (context, filterSnapshot) {
                        if (filterSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 28),
                              child: CircularProgressIndicator(
                                color: Color(0xFF398FC0),
                              ),
                            ),
                          );
                        }
                        final filtered = filterSnapshot.data ?? const [];
                        final groupedLogs = List.generate(
                          4,
                          (_) => <Map<String, dynamic>>[],
                        );
                        for (final log in filtered) {
                          final group = _historyGroupFor(
                            (log['category'] ?? '').toString(),
                            (log['target_type'] ?? '').toString(),
                          );
                          groupedLogs[group].add(log);
                        }

                        return AnimatedBuilder(
                          animation: _tabController,
                          builder: (context, _) {
                            final currentTab = _tabController.index;
                            final logsToShow = groupedLogs[currentTab];

                            // Group by dateGroup
                            final Map<String, List<Map<String, dynamic>>>
                            grouped = {};
                            for (var log in logsToShow) {
                              final group = (log['dateGroup'] ?? 'LỊCH SỬ')
                                  .toString();
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
                                      Text(
                                        query.isNotEmpty
                                            ? 'Không tìm thấy nhật ký phù hợp'
                                            : const [
                                                'Chưa có lịch sử quản lý đơn',
                                                'Chưa có lịch sử bài đăng',
                                                'Chưa có lịch sử người dùng',
                                                'Chưa có lịch sử hệ thống',
                                              ][currentTab],
                                        style: const TextStyle(
                                          color: Color(0xFF667085),
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (_filterByDate ||
                                          query.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        TextButton(
                                          onPressed: () => setState(() {
                                            _filterByDate = false;
                                            _searchCtrl.clear();
                                          }),
                                          child: const Text(
                                            'Xóa bộ lọc',
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
                                        padding: const EdgeInsets.only(
                                          bottom: 14,
                                        ),
                                        child: InkWell(
                                          onTap: () => _showLogDetail(log),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          child: _buildHistoryCard(log),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            );
                          },
                        );
                      },
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
    return _buildHistoryCardContent(log);
  }

  Widget _buildHistoryCardContent(Map<String, dynamic> log) {
    final title = (log['title'] ?? '').toString();
    final subtitle = (log['subtitle'] ?? '').toString();
    final fullDateTime = (log['fullDateTime'] ?? log['timeStr'] ?? '').toString();
    final category = (log['category'] ?? '').toString();
    final amount = log['amount'] is num
        ? (log['amount'] as num).toDouble()
        : null;

    final normalized = category.toLowerCase().replaceAll('_', '').trim();
    final combined = '$normalized ${title.toLowerCase()} ${subtitle.toLowerCase()}';
    final isFinanceOrOrder = normalized.contains('finance') ||
        normalized.contains('taichinh') ||
        normalized.contains('quanlydon') ||
        normalized.contains('order') ||
        normalized.contains('booking') ||
        normalized.contains('deposit') ||
        normalized.contains('refund') ||
        normalized.contains('hoancoc') ||
        normalized.contains('nhanphong') ||
        normalized.contains('thanhtoan') ||
        normalized.contains('quyettoan') ||
        normalized.contains('tiencoc') ||
        combined.contains('quản lý đơn') ||
        combined.contains('tiền cọc') ||
        combined.contains('hoàn cọc') ||
        combined.contains('nhận phòng') ||
        combined.contains('thanh toán') ||
        combined.contains('quyết toán') ||
        combined.contains('hoa hồng');

    Widget iconWidget;

    if (isFinanceOrOrder) {
      iconWidget = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.monetization_on_rounded,
          color: Color(0xFF12B76A),
          size: 24,
        ),
      );
    } else {
      switch (normalized) {
        case 'violation':
        case 'vipham':
          iconWidget = Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3F2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.gavel_rounded,
              color: Color(0xFFD92D20),
              size: 24,
            ),
          );
          break;
        case 'user':
        case 'users':
        case 'account':
        case 'nguoidung':
          iconWidget = Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE9F5FC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.manage_accounts_rounded,
              color: Color(0xFF398FC0),
              size: 24,
            ),
          );
          break;
        case 'post':
        case 'posts':
        case 'baidang':
          iconWidget = Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE9F5FC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.article_rounded,
              color: Color(0xFF398FC0),
              size: 24,
            ),
          );
          break;
        default:
          iconWidget = Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFEF0C7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.settings_suggest_rounded,
              color: Color(0xFFB54708),
              size: 24,
            ),
          );
      }
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
                    _buildCategoryBadge(
                      category,
                      title: title,
                      subtitle: subtitle,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildSubtitleWithHighlightedAmount(subtitle, amount, category),
                const SizedBox(height: 7),
                // Chỉ hiển thị giờ/ngày thao tác, không hiển thị tên hay UID admin
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: Color(0xFF667085),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      fullDateTime,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF667085),
                        fontWeight: FontWeight.w500,
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

class _ManagerAuthenticationDialog extends StatefulWidget {
  const _ManagerAuthenticationDialog({required this.user});

  final User user;

  @override
  State<_ManagerAuthenticationDialog> createState() =>
      _ManagerAuthenticationDialogState();
}

class _ManagerAuthenticationDialogState
    extends State<_ManagerAuthenticationDialog> {
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (_busy) return;
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _message = 'Vui lòng nhập mật khẩu.');
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final credential = EmailAuthProvider.credential(
        email: AdminAccessService.managerEmail,
        password: password,
      );
      await widget.user.reauthenticateWithCredential(credential);
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = _authErrorMessage(error);
      });
    } catch (error, stackTrace) {
      debugPrint('Không xác thực được Manager: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'Không thể xác thực lúc này. Vui lòng thử lại.';
      });
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: AdminAccessService.managerEmail,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'Đã gửi link đặt lại mật khẩu tới email Manager.';
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = _authErrorMessage(error);
      });
    } catch (error, stackTrace) {
      debugPrint(
        'Không gửi được link đặt lại mật khẩu Manager: $error\n$stackTrace',
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = 'Không gửi được email đặt lại mật khẩu. Vui lòng thử lại.';
      });
    }
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Mật khẩu không đúng.';
      case 'too-many-requests':
        return 'Thử quá nhiều lần. Vui lòng chờ rồi thử lại.';
      case 'network-request-failed':
        return 'Không có kết nối mạng. Vui lòng thử lại.';
      case 'user-not-found':
        return 'Không tìm thấy tài khoản Manager.';
      default:
        return error.message ?? 'Xác thực thất bại.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        actionsAlignment: MainAxisAlignment.end,
        actionsOverflowAlignment: OverflowBarAlignment.end,
        actionsOverflowDirection: VerticalDirection.up,
        actionsOverflowButtonSpacing: 4,
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: const Text('Xác thực Manager'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nhập lại mật khẩu Firebase Auth của ${widget.user.email}.'),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordController,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.visiblePassword,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(
                labelText: 'Mật khẩu tài khoản',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _authenticate(),
            ),
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(
                _message!,
                style: TextStyle(
                  color: _message!.startsWith('Đã gửi')
                      ? const Color(0xFF12B76A)
                      : const Color(0xFFD92D20),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : _sendPasswordReset,
            child: const Text('Gửi link đặt lại'),
          ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: _busy ? null : _authenticate,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Xác thực'),
          ),
        ],
      ),
    );
  }
}
