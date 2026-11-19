import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../data/models/resident_model.dart';
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
import 'host_checkin_checkout_screen.dart';
import 'host_main_screen.dart';
import 'host_management_menu.dart';

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
      builder: (context) {
        final hiddenCccdIds = <String>{};
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Consumer(
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
                final members = _resolveTenantMembers(tenant);
                final allHidden = members.isNotEmpty &&
                    members.every((m) => hiddenCccdIds.contains(m.id));
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
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.group_outlined,
                                    size: 20,
                                    color: Color(0xFF0F766E),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Thành viên đang ở (${tenant.memberCount})',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF0F172A),
                                        ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: const Color(0xFF0F766E),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                                onPressed: () {
                                  setSheetState(() {
                                    if (allHidden) {
                                      hiddenCccdIds.clear();
                                    } else {
                                      hiddenCccdIds.addAll(members.map((m) => m.id));
                                    }
                                  });
                                },
                                icon: Icon(
                                  allHidden
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  allHidden ? 'Hiện tất cả CCCD' : 'Ẩn tất cả CCCD',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...members.map(
                          (resident) => _buildResidentCard(
                            context,
                            resident,
                            isPrimary: resident.formId == 'chinh' ||
                                (resident.userId.isNotEmpty &&
                                    resident.userId == tenant.renterId),
                            isCccdHidden: hiddenCccdIds.contains(resident.id),
                            onToggleCccd: () {
                              setSheetState(() {
                                if (hiddenCccdIds.contains(resident.id)) {
                                  hiddenCccdIds.remove(resident.id);
                                } else {
                                  hiddenCccdIds.add(resident.id);
                                }
                              });
                            },
                          ),
                        ),
                        if (tenant.isActive) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                if (widget.onSectionChanged != null) {
                                  widget.onSectionChanged!(
                                    HostManagementSection.checkinCheckout,
                                  );
                                } else {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const HostCheckinCheckoutScreen(),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.exit_to_app,
                                color: Colors.white,
                                size: 20,
                              ),
                              label: const Text(
                                'Thực hiện Check-out trả phòng',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Đóng'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  List<ResidentModel> _resolveTenantMembers(TenantItem tenant) {
    if (tenant.roommates.isNotEmpty) {
      return tenant.roommates;
    }
    return [
      ResidentModel(
        id: tenant.id,
        periodId: tenant.periodId,
        roomId: tenant.roomId,
        userId: tenant.renterId,
        fullName: tenant.primaryName,
        phone: tenant.phone,
        avatar: tenant.avatar,
        formId: 'chinh',
        statusId: 'dangO',
        moveInDate: tenant.moveInDate,
        cccdNumber: tenant.cccdNumber,
        cccdFrontImageUrl: tenant.cccdFrontImageUrl,
        cccdBackImageUrl: tenant.cccdBackImageUrl,
        isCccdVerified: tenant.isCccdVerified,
      ),
    ];
  }

  void _showCccdPreviewDialog({
    required BuildContext context,
    required String title,
    required String imagePath,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.badge_outlined, color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.8,
                maxScale: 4.0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildCccdImage(imagePath, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCccdImage(
    String path, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
  }) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return _buildImagePlaceholder(hasError: false);
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: trimmed,
        fit: fit,
        width: width,
        height: height,
        placeholder: (_, _) => const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, _, _) => _buildImagePlaceholder(hasError: true),
      );
    }
    if (trimmed.startsWith('assets/')) {
      return Image.asset(
        trimmed,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, _, _) => _buildImagePlaceholder(hasError: true),
      );
    }
    try {
      final file = File(trimmed);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, _, _) => _buildImagePlaceholder(hasError: true),
        );
      }
    } catch (_) {}
    return _buildImagePlaceholder(hasError: true);
  }

  Widget _buildImagePlaceholder({bool hasError = false}) {
    return Container(
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasError ? Icons.broken_image_outlined : Icons.badge_outlined,
            size: 28,
            color: const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 4),
          Text(
            hasError ? 'Không tải được ảnh' : 'Chưa cập nhật ảnh',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCccdThumb({
    required BuildContext context,
    required String label,
    required String imagePath,
    required String residentName,
  }) {
    final hasImage = imagePath.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              hasImage ? Icons.image_outlined : Icons.hide_image_outlined,
              size: 14,
              color: hasImage ? const Color(0xFF0F766E) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: hasImage ? const Color(0xFF0F766E) : const Color(0xFF475569),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: hasImage
              ? () => _showCccdPreviewDialog(
                    context: context,
                    title: 'CCCD $label - $residentName',
                    imagePath: imagePath,
                  )
              : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 95,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasImage ? const Color(0xFF0D9488) : const Color(0xFFCBD5E1),
                width: hasImage ? 1.2 : 1.0,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCccdImage(imagePath, fit: BoxFit.cover),
                  if (hasImage)
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in, color: Colors.white, size: 12),
                            SizedBox(width: 3),
                            Text(
                              'Phóng to',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _maskCccdNumber(String number) {
    final clean = number.trim();
    if (clean.length <= 4) return '••••';
    if (clean.length <= 8) {
      return '${clean.substring(0, 2)}••••${clean.substring(clean.length - 2)}';
    }
    return '${clean.substring(0, 3)}••••••${clean.substring(clean.length - 3)}';
  }

  Widget _buildResidentCard(
    BuildContext context,
    ResidentModel resident, {
    required bool isPrimary,
    bool isCccdHidden = false,
    VoidCallback? onToggleCccd,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isPrimary ? const Color(0xFFDBEAFE) : const Color(0xFFF3E8FF),
                backgroundImage: (resident.avatar.isNotEmpty &&
                        (resident.avatar.startsWith('http://') ||
                            resident.avatar.startsWith('https://')))
                    ? CachedNetworkImageProvider(resident.avatar)
                    : null,
                child: resident.avatar.isEmpty
                    ? Icon(
                        isPrimary ? Icons.person : Icons.people_outline,
                        color: isPrimary ? const Color(0xFF1D4ED8) : const Color(0xFF7E22CE),
                        size: 20,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resident.fullName.isNotEmpty ? resident.fullName : 'Chưa có tên',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPrimary ? const Color(0xFFEFF6FF) : const Color(0xFFFAF5FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isPrimary ? const Color(0xFFBFDBFE) : const Color(0xFFE9D5FF),
                            ),
                          ),
                          child: Text(
                            isPrimary ? 'Thuê chính' : 'Ở ghép',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isPrimary ? const Color(0xFF1D4ED8) : const Color(0xFF7E22CE),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: resident.isCccdVerified
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: resident.isCccdVerified
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFFFDE68A),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                resident.isCccdVerified ? Icons.verified : Icons.info_outline,
                                size: 12,
                                color: resident.isCccdVerified
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFB45309),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                resident.isCccdVerified
                                    ? 'Đã xác thực CCCD (eKYC)'
                                    : 'Chưa xác thực CCCD',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: resident.isCccdVerified
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  SelectableText(
                    resident.phone.isNotEmpty ? resident.phone : 'Chưa có SĐT',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    'Ngày vào: ${DateFormat('dd/MM/yyyy').format(resident.moveInDate)}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                  ),
                ],
              ),
              if (resident.cccdNumber.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    SelectableText(
                      isCccdHidden
                          ? 'Số CCCD: ${_maskCccdNumber(resident.cccdNumber)}'
                          : 'Số CCCD: ${resident.cccdNumber}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ảnh Căn cước công dân:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              if (onToggleCccd != null)
                InkWell(
                  onTap: onToggleCccd,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCccdHidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 14,
                          color: const Color(0xFF0F766E),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCccdHidden ? 'Hiện CCCD' : 'Ẩn CCCD',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (isCccdHidden)
            InkWell(
              onTap: onToggleCccd,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Ảnh CCCD đang được ẩn để bảo mật thông tin.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_outlined, size: 13, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'Xem ảnh',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildCccdThumb(
                    context: context,
                    label: 'Mặt trước',
                    imagePath: resident.cccdFrontImageUrl,
                    residentName: resident.fullName,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildCccdThumb(
                    context: context,
                    label: 'Mặt sau',
                    imagePath: resident.cccdBackImageUrl,
                    residentName: resident.fullName,
                  ),
                ),
              ],
            ),
        ],
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
        } else if (section != HostManagementSection.tenants) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => HostMainScreen(initialSection: section),
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
    final hostRooms = ref.watch(hostRoomsProvider).value ?? <RoomModel>[];
    final rooms = <String, RoomModel>{
      for (final room in hostRooms)
        if (room.status != 'deleted' &&
            (_propertyId == null || room.propertyId == _propertyId))
          room.id: room,
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
            onPressed: () {
              ref.invalidate(hostTenantsProvider);
              ref.invalidate(hostRoomsProvider);
            },
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _syncingResidents ? null : _syncResidents,
                    icon: _syncingResidents
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync, size: 18),
                    label: Text(
                      _syncingResidents
                          ? 'Đang đồng bộ...'
                          : 'Đồng bộ hồ sơ nhận phòng',
                    ),
                  ),
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
                      (room) => DropdownMenuItem(
                        value: room.id,
                        child: Text(
                          room.roomCode.isNotEmpty
                              ? 'P.${room.roomCode}'
                              : room.title,
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
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
