import '../../../data/models/room_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/user_provider.dart';
import '../../chat/screens/chat_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/host_management_provider.dart';
import '../providers/tenant_management_provider.dart';
import '../repositories/tenant_repository.dart';
import '../widgets/tenant_card.dart';
import 'host_management_menu.dart';
import 'host_violation_management_screen.dart';
import '../../../core/constants/app_colors.dart';

class HostTenantManagementScreen extends ConsumerStatefulWidget {
  final ValueChanged<HostManagementSection>? onSectionChanged;

  const HostTenantManagementScreen({super.key, this.onSectionChanged});

  @override
  ConsumerState<HostTenantManagementScreen> createState() =>
      _HostTenantManagementScreenState();
}

class _HostTenantManagementScreenState
    extends ConsumerState<HostTenantManagementScreen> {
  String _search = '';
  String? _propertyId;
  String? _roomId;

  bool _syncingResidents = false;

  Future<void> _syncResidents() async {
    final hostId = ref.read(hostSessionProvider).value;
    if (_syncingResidents || hostId == null) return;
    setState(() => _syncingResidents = true);
    try {
      final result = await ref
          .read(tenantRepositoryProvider)
          .syncCheckedInResidents(hostId);
      ref.invalidate(hostTenantsProvider);
      ref.invalidate(hostRoomsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã bổ sung ${result.created} hồ sơ nhận phòng.'
            '${result.skipped > 0 ? ' Có ${result.skipped} đơn cần kiểm tra lại trạng thái phòng/kỳ ở.' : ''}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không đồng bộ được hồ sơ nhận phòng: $error')),
      );
    } finally {
      if (mounted) setState(() => _syncingResidents = false);
    }
  }

  void _openTenantChat(TenantItem tenant) {
    final user = ref.read(currentUserProvider);
    final receiverId = tenant.renterId.trim();
    if (user == null ||
        receiverId.isEmpty ||
        receiverId == 'guest' ||
        receiverId.startsWith('manual_') ||
        receiverId == user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa thể mở trò chuyện với tài khoản người thuê này.'),
        ),
      );
      return;
    }
    final profile = ref.read(userProfileProvider).value;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatDetailScreen(
          receiverId: receiverId,
          receiverName: tenant.primaryName,
          receiverAvatar: tenant.avatar,
          receiverPhone: tenant.phone,
          isLandlord: false,
          currentUserId: user.uid,
          currentUserName:
              profile?.displayName ?? user.displayName ?? 'Chủ trọ',
        ),
      ),
    );
  }

  void _showTenantDetails(TenantItem selected) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final items = ref.watch(hostTenantsProvider).value ?? [];
          final matches = items.where(
            (item) =>
                item.id == selected.id ||
                (selected.bookingId.isNotEmpty &&
                    item.bookingId == selected.bookingId),
          );
          if (matches.isEmpty) {
            return Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Hồ sơ đã thay đổi. Vui lòng mở lại từ danh sách.',
                style: TextStyle(color: AppColors.textDark),
              ),
            );
          }
          final tenant = matches.first;
          Widget info(String label, String value) => ListTile(
            title: Text(label),
            subtitle: SelectableText(value.isEmpty ? 'Chưa cập nhật' : value),
          );
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .8,
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
                  Text(
                    tenant.displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textDark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    tenant.statusLabel,
                    style: TextStyle(
                      color: tenant.isActive
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                  info('Người thuê chính', tenant.primaryName),
                  info('Số điện thoại', tenant.phone),
                  info(
                    'Phòng / cơ sở',
                    '${tenant.roomName} • ${tenant.propertyName} • Tầng ${tenant.floor}',
                  ),
                  info(
                    tenant.isActive
                        ? 'Ngày nhận phòng'
                        : 'Ngày dự kiến nhận phòng',
                    DateFormat('dd/MM/yyyy').format(tenant.moveInDate),
                  ),
                  info(
                    'Tiền cọc theo hồ sơ đặt phòng',
                    '${NumberFormat.decimalPattern('vi').format(tenant.deposit)} đ',
                  ),
                  info('Mã đặt phòng', tenant.bookingId),
                  info('Mã kỳ ở', tenant.periodId),
                  if (tenant.isActive && tenant.periodId.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Đã nhận phòng theo đơn/phòng. Chưa có hồ sơ kỳ ở và bàn giao chi tiết.',
                      ),
                    ),
                  if (!tenant.isActive)
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Đơn đã duyệt, chờ chủ trọ thực hiện nhận phòng tại mục Check-in / Check-out.',
                      ),
                    ),
                  Divider(),
                  Text(
                    'Thành viên đang ở (${tenant.memberCount})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (tenant.roommates.isEmpty)
                    info(tenant.primaryName, tenant.phone),
                  ...tenant.roommates.map(
                    (resident) => info(
                      '${resident.fullName} • ${resident.formId == 'chinh' ? 'Thuê chính' : 'Ở ghép'}',
                      '${resident.phone} • Ngày vào: ${DateFormat('dd/MM/yyyy').format(resident.moveInDate)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.isDark
                          ? AppColors.textDark
                          : AppColors.primary,
                    ),
                    child: Text('Đóng'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openSwitcherMenu() {
    HostManagementMenu.show(
      context: context,
      currentSection: HostManagementSection.tenants,
      onSelect: (section) {
        if (widget.onSectionChanged != null) {
          widget.onSectionChanged!(section);
        } else if (section == HostManagementSection.checkinCheckout) {
          Navigator.of(context).pushReplacementNamed('/host/checkin-checkout');
        } else if (section == HostManagementSection.violations) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const HostViolationManagementScreen(),
            ),
          );
        }
      },
    );
  }

  Widget _buildStatsRow(TenantStats stats) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildStatPill(
            icon: Icons.apartment_outlined,
            text: '${stats.facilityCount} cơ sở',
          ),
          SizedBox(width: 8),
          _buildStatPill(
            icon: Icons.people_outline,
            text: '${stats.activeTenantCount} người đang thuê',
          ),
          SizedBox(width: 8),
          _buildStatPill(
            icon: Icons.meeting_room_outlined,
            text: '${stats.occupiedRoomCount} phòng đang sử dụng',
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({required IconData icon, required String text}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textDark),
          SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenantsAsync = ref.watch(hostTenantsProvider);
    final statsAsync = ref.watch(hostTenantStatsProvider);
    final properties = ref.watch(hostPropertiesProvider).value ?? [];
    final hostRooms = ref.watch(hostRoomsProvider).value ?? <RoomModel>[];
    final rooms = <String, RoomModel>{
      for (final room in hostRooms)
        if (room.status != 'deleted' &&
            (_propertyId == null || room.propertyId == _propertyId))
          room.id: room,
    };
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: _openSwitcherMenu,
          icon: Icon(Icons.menu),
        ),
        title: Text('Quản lý người thuê'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: () {
              ref.invalidate(hostTenantsProvider);
              ref.invalidate(hostRoomsProvider);
            },
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                statsAsync.when(
                  data: _buildStatsRow,
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stack) => Text(
                    'Chưa tải được thống kê',
                    style: TextStyle(color: AppColors.textDark),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _syncingResidents ? null : _syncResidents,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.isDark
                          ? AppColors.textDark
                          : AppColors.primary,
                    ),
                    icon: _syncingResidents
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.sync, size: 18),
                    label: Text(
                      _syncingResidents
                          ? 'Đang đồng bộ...'
                          : 'Đồng bộ hồ sơ nhận phòng',
                    ),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Tên, SĐT, phòng, cơ sở, mã đơn',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: 'all',
                  isExpanded: true,
                  dropdownColor: AppColors.surface,
                  style: TextStyle(color: AppColors.textDark),
                  decoration: InputDecoration(labelText: 'Cơ sở'),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(
                        'Tất cả cơ sở',
                        style: TextStyle(color: AppColors.textDark),
                      ),
                    ),
                    ...properties.map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          p.name,
                          style: TextStyle(color: AppColors.textDark),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _propertyId = value == 'all' ? null : value;
                    _roomId = null;
                  }),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'tenant-room-${_propertyId ?? 'all'}-${rooms.keys.join(',')}',
                  ),
                  initialValue: rooms.containsKey(_roomId) ? _roomId : 'all',
                  isExpanded: true,
                  dropdownColor: AppColors.surface,
                  style: TextStyle(color: AppColors.textDark),
                  decoration: InputDecoration(labelText: 'Phòng'),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(
                        'Tất cả phòng',
                        style: TextStyle(color: AppColors.textDark),
                      ),
                    ),
                    ...rooms.values.map(
                      (room) => DropdownMenuItem(
                        value: room.id,
                        child: Text(
                          room.roomCode.isNotEmpty
                              ? 'P.${room.roomCode}'
                              : room.title,
                          style: TextStyle(color: AppColors.textDark),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _roomId = value == 'all' ? null : value),
                ),
              ],
            ),
          ),
          Expanded(
            child: tenantsAsync.when(
              data: (tenants) {
                final list = tenants
                    .where(
                      (t) =>
                          t.matches(_search) &&
                          (_propertyId == null ||
                              t.propertyId == _propertyId) &&
                          (_roomId == null ||
                              !rooms.containsKey(_roomId) ||
                              t.roomId == _roomId) &&
                          t.isActive,
                    )
                    .toList();
                return ListView(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    if (list.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          _search.trim().isNotEmpty
                              ? 'Không có người thuê phù hợp bộ lọc.'
                              : _roomId != null && rooms.containsKey(_roomId)
                              ? 'Phòng này chưa có người thuê đang ở.'
                              : _propertyId != null
                              ? 'Cơ sở này chưa có người thuê đang ở.'
                              : tenants.isEmpty
                              ? 'Chưa có người thuê. Khách sẽ xuất hiện sau khi quét QR và xác nhận check-in.'
                              : 'Không có người thuê phù hợp bộ lọc.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                    ...list.map(
                      (tenant) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text(
                              tenant.statusLabel,
                              style: TextStyle(
                                color: tenant.isActive
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ),
                          ),
                          TenantCard(
                            tenant: tenant,
                            onTap: () => _showTenantDetails(tenant),
                            onMessage: () => _openTenantChat(tenant),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Không tải được danh sách người thuê. Kiểm tra kết nối và quyền truy cập dữ liệu.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textDark),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(hostTenantsProvider),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.isDark
                              ? AppColors.textDark
                              : AppColors.primary,
                        ),
                        child: Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
