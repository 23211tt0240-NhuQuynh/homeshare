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
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Hồ sơ đã thay đổi. Vui lòng mở lại từ danh sách.'),
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
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    tenant.displayName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(tenant.statusLabel),
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
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Đã nhận phòng theo đơn/phòng. Chưa có hồ sơ kỳ ở và bàn giao chi tiết.',
                      ),
                    ),
                  if (!tenant.isActive)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Đơn đã duyệt, chờ chủ trọ thực hiện nhận phòng tại mục Check-in / Check-out.',
                      ),
                    ),
                  const Divider(),
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
                    child: const Text('Đóng'),
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
          const SizedBox(width: 8),
          _buildStatPill(
            icon: Icons.people_outline,
            text: '${stats.activeTenantCount} người đang thuê',
          ),
          const SizedBox(width: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF475569)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
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
    final rooms = <String, TenantItem>{
      for (final tenant in tenantsAsync.value ?? <TenantItem>[])
        if (_propertyId == null || tenant.propertyId == _propertyId)
          tenant.roomId: tenant,
    };
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: IconButton(
          onPressed: _openSwitcherMenu,
          icon: const Icon(Icons.menu),
        ),
        title: const Text('Quản lý người thuê'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: () => ref.invalidate(hostTenantsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                statsAsync.when(
                  data: _buildStatsRow,
                  loading: () => const LinearProgressIndicator(),
                  error: (error, stack) => const Text('Chưa tải được thống kê'),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Tên, SĐT, phòng, cơ sở, mã đơn',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: 'all',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Cơ sở'),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('Tất cả cơ sở'),
                    ),
                    ...properties.map(
                      (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _propertyId = value == 'all' ? null : value;
                    _roomId = null;
                  }),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey(
                    'tenant-room-${_propertyId ?? 'all'}-${rooms.keys.join(',')}',
                  ),
                  initialValue: rooms.containsKey(_roomId) ? _roomId : 'all',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Phòng'),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('Tất cả phòng'),
                    ),
                    ...rooms.values.map(
                      (tenant) => DropdownMenuItem(
                        value: tenant.roomId,
                        child: Text(tenant.roomName),
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          tenants.isEmpty
                              ? 'Chưa có người thuê. Khách sẽ xuất hiện sau khi quét QR và xác nhận check-in.'
                              : 'Không có người thuê phù hợp bộ lọc.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ...list.map(
                      (tenant) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              tenant.statusLabel,
                              style: TextStyle(
                                color: tenant.isActive
                                    ? Colors.green.shade800
                                    : Colors.orange.shade900,
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Không tải được danh sách người thuê. Kiểm tra kết nối và quyền truy cập dữ liệu.',
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(hostTenantsProvider),
                        child: const Text('Thử lại'),
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
