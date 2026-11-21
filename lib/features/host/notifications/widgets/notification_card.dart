import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/room_issue_service.dart';
import '../../../../data/models/room_issue_model.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/providers/user_provider.dart';
import '../../../profile/screens/cccd_verification_screen.dart';
import '../../screens/host_checkin_checkout_screen.dart';
import '../models/host_notification_model.dart';
import '../notification_types.dart';
import '../providers/host_notification_provider.dart';
import 'host_update_deposit_bottom_sheet.dart';

/// Card thông báo role Chủ Trọ (Figma Image 2 & Image 4)
class NotificationCard extends ConsumerWidget {
  final HostNotificationModel notification;
  final HostNotificationType currentTabType;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.currentTabType,
  });

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return '${formatter.format(amount)} đ';
  }

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes.clamp(1, 59);
      return 'Gửi $m phút trước';
    } else if (diff.inHours < 24) {
      return 'Gửi ${diff.inHours} giờ trước';
    } else {
      return 'Gửi ${diff.inDays} ngày trước';
    }
  }

  Color _getBadgeBg(String roomCode, {bool isRoomIssue = false}) {
    if (isRoomIssue) {
      return const Color(0xFFFFF7ED); // Cam nhạt dịu cho sự cố
    }
    if (roomCode.startsWith('3')) {
      return const Color(0xFFECFDF3); // Xanh lá dịu
    } else if (roomCode.startsWith('2')) {
      return const Color(0xFFF4EBFF); // Tím nhạt dịu
    }
    return const Color(0xFFEFF8FF); // Xanh dương
  }

  Color _getBadgeTextColor(String roomCode, {bool isRoomIssue = false}) {
    if (isRoomIssue) {
      return const Color(0xFFEA580C); // Cam đậm
    }
    if (roomCode.startsWith('3')) {
      return const Color(0xFF027A48);
    } else if (roomCode.startsWith('2')) {
      return const Color(0xFF6941C6);
    }
    return AppColors.primary;
  }

  Color _getAvatarBg(String name) {
    if (name.startsWith('N')) return const Color(0xFFD1E9FF);
    if (name.startsWith('L')) return const Color(0xFFFCE7F6);
    return const Color(0xFFF2F4F7);
  }

  Color _getAvatarTextColor(String name) {
    if (name.startsWith('N')) return const Color(0xFF175CD3);
    if (name.startsWith('L')) return const Color(0xFFC11574);
    return const Color(0xFF344054);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notif = notification;
    if (notif.isDisbursementNotification) {
      return _buildDisbursementCard(context, ref, notif);
    }
    if (notif.isCccdNotification) {
      return _buildCccdNotificationCard(context, ref, notif);
    }
    if (notif.isGeneralSystemNotification) {
      return _buildGeneralSystemCard(context, ref, notif);
    }
    final dateFmt = DateFormat('dd/MM/yyyy');
    final checkInStr = dateFmt.format(notif.checkInDate ?? notif.createdAt);
    final relativeTimeStr = _formatRelativeTime(notif.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: notif.isRead
              ? const Color(0xFFEAECF0)
              : const Color(0x4D155EEF),
          width: notif.isRead ? 1 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Đánh dấu đã đọc trên Firestore khi chạm vào thẻ
            ref.read(hostNotificationRepositoryProvider).markAsRead(notif.id);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Hàng trên: Huy hiệu số phòng, tiêu đề & mã booking
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Huy hiệu số phòng (101, 203, 302...)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getBadgeBg(notif.displayRoomCode, isRoomIssue: notif.isRoomIssue),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: notif.isRoomIssue && notif.displayRoomCode.isEmpty
                              ? const Icon(Icons.build_rounded, size: 20, color: Color(0xFFEA580C))
                              : Text(
                                  notif.displayRoomCode.isNotEmpty ? notif.displayRoomCode : 'SC',
                                  style: TextStyle(
                                    fontSize: notif.displayRoomCode.length > 3
                                        ? 12
                                        : 15,
                                    fontWeight: FontWeight.bold,
                                    color: _getBadgeTextColor(notif.displayRoomCode, isRoomIssue: notif.isRoomIssue),
                                  ),
                                  maxLines: 1,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Tiêu đề phòng & tầng
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notif.roomTitle.isNotEmpty
                                ? notif.roomTitle
                                : (notif.roomFloorInfo.isNotEmpty
                                      ? notif.roomFloorInfo
                                      : 'Phòng ${notif.displayRoomCode}'),
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF101828),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            notif.roomFloorInfo.isNotEmpty &&
                                    notif.roomTitle.isNotEmpty
                                ? notif.roomFloorInfo
                                : (notif.roomFloorInfo.isNotEmpty
                                      ? 'Phòng trọ'
                                      : 'Phòng trọ tiện nghi'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF667085),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Tag mã booking #BK12345
                    Container(
                      constraints: const BoxConstraints(maxWidth: 110),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: notif.isRoomIssue ? const Color(0xFFFFF7ED) : const Color(0xFFEFF8FF),
                        borderRadius: BorderRadius.circular(8),
                        border: notif.isRoomIssue ? Border.all(color: const Color(0xFFFED7AA)) : null,
                      ),
                      child: Text(
                        notif.isRoomIssue
                            ? (notif.issueId.isNotEmpty
                                ? '#SC_${notif.issueId.length > 5 ? notif.issueId.substring(notif.issueId.length - 5) : notif.issueId}'
                                : notif.displayBookingCode)
                            : notif.displayBookingCode,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: notif.isRoomIssue ? const Color(0xFFC2410C) : AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 2. Khối thông tin khách thuê & tiền cọc
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      // Avatar chữ cái của khách thuê
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _getAvatarBg(notif.renterName),
                        child: Text(
                          notif.renterName.isNotEmpty
                              ? notif.renterName[0].toUpperCase()
                              : 'K',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _getAvatarTextColor(notif.renterName),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Tên khách thuê
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notif.isRoomIssue ? 'Người báo sự cố' : 'Khách thuê',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF667085),
                              ),
                            ),
                            Text(
                              notif.renterName.isNotEmpty
                                  ? notif.renterName
                                  : 'Khách thuê HomeShare',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF101828),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Loại sự cố hoặc Số tiền cọc
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            notif.isRoomIssue
                                ? 'Loại sự cố'
                                : currentTabType ==
                                        HostNotificationType.paymentCompleted
                                    ? 'Đã thanh toán'
                                    : (currentTabType ==
                                              HostNotificationType.staying
                                          ? 'Tiền cọc / phí phòng'
                                          : 'Tiền cọc giữ phòng'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF667085),
                            ),
                          ),
                          Text(
                            notif.isRoomIssue
                                ? (notif.category.isNotEmpty ? notif.category : 'Sự cố phòng')
                                : _formatCurrency(notif.amount),
                            style: TextStyle(
                              fontSize: notif.isRoomIssue ? 12 : 14,
                              fontWeight: FontWeight.bold,
                              color: notif.isRoomIssue ? const Color(0xFFD97706) : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 3. Chi tiết sự cố (nếu là Room Issue) hoặc Ngày nhận phòng
                if (notif.isRoomIssue) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFD97706)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                notif.category.isNotEmpty ? notif.category : 'Chi tiết sự cố',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: notif.severity == 'high' ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                RoomIssueSeverities.toDisplayVi(notif.severity),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: notif.severity == 'high' ? const Color(0xFFDC2626) : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (notif.message.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            notif.message,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF451A03),
                              height: 1.35,
                            ),
                          ),
                        ],
                        if (notif.imageUrls.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 60,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: notif.imageUrls.length,
                              separatorBuilder: (_, index) => const SizedBox(width: 8),
                              itemBuilder: (ctx, idx) {
                                final imgPath = notif.imageUrls[idx];
                                final isLocal = File(imgPath).existsSync();
                                return InkWell(
                                  onTap: () => _showImageDialog(context, imgPath),
                                  borderRadius: BorderRadius.circular(8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: isLocal
                                        ? Image.file(File(imgPath), width: 60, height: 60, fit: BoxFit.cover)
                                        : Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.image, size: 24, color: Colors.grey),
                                          ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 13, color: Color(0xFF667085)),
                      const SizedBox(width: 6),
                      Text(
                        'Thời gian gửi: $relativeTimeStr',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: Color(0xFF667085),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Dự kiến nhận phòng: $checkInStr  •  $relativeTimeStr',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF667085),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // 4. Khối trạng thái hoặc Nút hành động tương ứng với từng Tab
                _buildBottomAction(context, ref, notif),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCccdNotificationCard(
    BuildContext context,
    WidgetRef ref,
    HostNotificationModel notif,
  ) {
    final profile = ref.watch(userProfileProvider).asData?.value;
    final relativeTime = _formatRelativeTime(notif.createdAt);
    final isRejected = notif.isCccdRejectedNotification;
    final isApproved = notif.isCccdApprovedNotification;
    final liveVerified = profile?.isCccdVerified == true;
    final livePending = profile?.isCccdPending == true;
    final liveRejected = profile?.isCccdRejected == true;

    final Color accentColor;
    final Color softBg;
    final Color borderColor;
    final IconData iconData;
    final String badgeText;

    if (isRejected) {
      accentColor = const Color(0xFFD92D20);
      softBg = const Color(0xFFFEF3F2);
      borderColor = notif.isRead
          ? const Color(0xFFEAECF0)
          : const Color(0xFFFDA29B);
      iconData = Icons.gpp_bad_rounded;
      badgeText = 'Bị từ chối';
    } else if (isApproved) {
      accentColor = const Color(0xFF039855);
      softBg = const Color(0xFFECFDF3);
      borderColor = notif.isRead
          ? const Color(0xFFEAECF0)
          : const Color(0xFF86EFAC);
      iconData = Icons.verified_user_rounded;
      badgeText = 'Đã phê duyệt ✓';
    } else {
      accentColor = const Color(0xFFD97706);
      softBg = const Color(0xFFFFFBEB);
      borderColor = notif.isRead
          ? const Color(0xFFEAECF0)
          : const Color(0xFFFDE68A);
      iconData = Icons.hourglass_top_rounded;
      badgeText = liveVerified
          ? 'Đã phê duyệt ✓'
          : (liveRejected ? 'Cần gửi lại' : 'Đang chờ Admin duyệt');
    }

    final showResubmitButton =
        (isRejected || (liveRejected && !isApproved)) &&
        !liveVerified &&
        !livePending;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: notif.isRead ? 1 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (!notif.id.startsWith('live_')) {
              ref
                  .read(hostNotificationRepositoryProvider)
                  .markAsRead(notif.id);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: softBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(iconData, color: accentColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: softBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Xác thực CCCD • $badgeText',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            notif.title,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF101828),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (notif.message.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    notif.message,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF475467),
                    ),
                  ),
                ],
                if (isRejected &&
                    notif.rejectReason.isNotEmpty &&
                    !notif.message.contains(notif.rejectReason)) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECDCA)),
                    ),
                    child: Text(
                      'Lý do từ chối: ${notif.rejectReason}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB42318),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 13,
                      color: Color(0xFF667085),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      relativeTime,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
                if (showResubmitButton) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (!notif.id.startsWith('live_')) {
                          ref
                              .read(hostNotificationRepositoryProvider)
                              .markAsRead(notif.id);
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CccdVerificationScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.camera_alt_outlined, size: 17),
                      label: const Text(
                        'Chụp & gửi lại CCCD',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD92D20),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ] else if (isRejected && livePending) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.hourglass_top_rounded,
                          size: 15,
                          color: Color(0xFFD97706),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Bạn đã gửi lại hồ sơ • Đang chờ Admin duyệt',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (isRejected && liveVerified) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA6F4C5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 15,
                          color: Color(0xFF12B76A),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Tài khoản đã được xác thực CCCD thành công ✓',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF027A48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralSystemCard(
    BuildContext context,
    WidgetRef ref,
    HostNotificationModel notif,
  ) {
    final relativeTime = _formatRelativeTime(notif.createdAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: notif.isRead
              ? const Color(0xFFEAECF0)
              : const Color(0x4D155EEF),
          width: notif.isRead ? 1 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (!notif.id.startsWith('live_')) {
              ref
                  .read(hostNotificationRepositoryProvider)
                  .markAsRead(notif.id);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Thông báo hệ thống',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            notif.title,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF101828),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (notif.message.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    notif.message,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF475467),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 13,
                      color: Color(0xFF667085),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      relativeTime,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Chủ trọ - Xem thông báo giải ngân - Chạm thẻ để đánh dấu đã đọc, không yêu cầu xác nhận nhận tiền.
  Widget _buildDisbursementCard(
    BuildContext context,
    WidgetRef ref,
    HostNotificationModel notif,
  ) {
    final relativeTime = _formatRelativeTime(notif.createdAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: notif.isRead
              ? const Color(0xFFEAECF0)
              : const Color(0xFF86EFAC),
          width: notif.isRead ? 1 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () =>
              ref.read(hostNotificationRepositoryProvider).markAsRead(notif.id),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFECFDF3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        color: Color(0xFF039855),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notif.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF101828),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            relativeTime,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF667085),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 22,
                      color: Color(0xFF12B76A),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  notif.message,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF475467),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Thực nhận sau phí hoa hồng',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF027A48),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatCurrency(notif.amount),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF027A48),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction(
    BuildContext context,
    WidgetRef ref,
    HostNotificationModel notif,
  ) {
    if (notif.isRoomIssue) {
      return _buildRoomIssueAction(context, ref, notif);
    }
    if (notif.isRoommateApproval) {
      if (notif.statusId == 'approved' || notif.statusId == 'accepted') {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFA6F4C5)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: Color(0xFF12B76A),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  currentTabType == HostNotificationType.staying
                      ? 'Đang ở • Đã xác nhận duyệt cho vào ở ghép'
                      : 'Đã xác nhận duyệt cho vào ở ghép',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF027A48),
                  ),
                ),
              ),
            ],
          ),
        );
      } else if (notif.statusId == 'rejected') {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFECDCA)),
          ),
          child: const Row(
            children: [
              Icon(Icons.cancel_rounded, size: 16, color: Color(0xFFD92D20)),
              SizedBox(width: 6),
              Text(
                'Đã từ chối cho vào ở ghép',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB42318),
                ),
              ),
            ],
          ),
        );
      } else {
        // Pending: Host confirms or rejects roommate entry
        return Row(
          children: [
            // Nút Từ chối
            Expanded(
              flex: 2,
              child: OutlinedButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Từ chối ở ghép'),
                      content: Text(
                        'Từ chối cho ${notif.newRoommateName.isNotEmpty ? notif.newRoommateName : "người này"} vào ở ghép phòng ${notif.displayRoomCode}?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Đóng'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD92D20),
                          ),
                          child: const Text('Xác nhận từ chối'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await ref
                        .read(hostNotificationRepositoryProvider)
                        .rejectRoommateRequest(
                          notificationId: notif.id,
                          primaryTenantId: notif.primaryTenantId,
                          primaryTenantName: notif.primaryTenantName,
                          newRoommateId: notif.newRoommateId,
                          newRoommateName: notif.newRoommateName,
                          roomTitle: notif.roomTitle,
                          roomCode: notif.displayRoomCode,
                          userNotificationId: notif.userNotificationId,
                        );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã từ chối yêu cầu vào ở ghép.'),
                          backgroundColor: Color(0xFFD92D20),
                        ),
                      );
                    }
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD92D20),
                  side: const BorderSide(color: Color(0xFFFDA29B)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Từ chối',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Nút Xác nhận duyệt vào phòng
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Xác nhận cho vào ở ghép'),
                      content: Text(
                        'Xác nhận duyệt cho ${notif.newRoommateName.isNotEmpty ? notif.newRoommateName : "khách"} vào ở ghép cùng ${notif.primaryTenantName.isNotEmpty ? notif.primaryTenantName : "người thuê chính"} tại phòng ${notif.displayRoomCode}?\n\nSau khi xác nhận, người này sẽ chính thức được thêm vào danh sách người ở của phòng.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Hủy'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF12B76A),
                          ),
                          child: const Text('Xác nhận duyệt'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    try {
                      await ref
                          .read(hostNotificationRepositoryProvider)
                          .approveRoommateRequest(
                            notificationId: notif.id,
                            roomId: notif.roomId,
                            primaryTenantId: notif.primaryTenantId,
                            primaryTenantName: notif.primaryTenantName,
                            newRoommateId: notif.newRoommateId,
                            newRoommateName: notif.newRoommateName,
                            roomTitle: notif.roomTitle,
                            roomCode: notif.displayRoomCode,
                            userNotificationId: notif.userNotificationId,
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF12B76A),
                            content: Text(
                              'Đã duyệt cho ${notif.newRoommateName} vào ở ghép phòng ${notif.displayRoomCode} thành công! Đã lưu vào tab Đang ở.',
                            ),
                          ),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Chưa duyệt được người ở ghép: $error',
                            ),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text(
                  'Duyệt vào phòng',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF12B76A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        );
      }
    }

    if (currentTabType == HostNotificationType.staying) {
      // Tab "Đang ở": Hiển thị trạng thái khách đang sinh sống tại phòng
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFA6F4C5)),
        ),
        child: const Row(
          children: [
            Icon(Icons.home_rounded, size: 16, color: Color(0xFF12B76A)),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Khách đang sinh sống tại phòng',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF027A48),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (currentTabType == HostNotificationType.pendingAction) {
      // Tab "Đang xử lý": Thanh hiển thị trạng thái Chờ xác nhận cọc màu vàng (Figma Ảnh 2)
      // Quyền xác nhận thuộc role Admin, chủ nhà chỉ xem trạng thái
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0x99FEF0C7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFEDF89)),
        ),
        child: const Row(
          children: [
            Text('⏳', style: TextStyle(fontSize: 13)),
            SizedBox(width: 6),
            Text(
              'Chờ xác nhận cọc',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB54708),
              ),
            ),
          ],
        ),
      );
    } else if (currentTabType == HostNotificationType.deposit ||
        currentTabType == HostNotificationType.paymentCompleted) {
      // Tab "Đã cọc" & "Đã thanh toán hết" có chức năng như nhau:
      // + Chỉnh sửa ngày đến check in (mở bottom sheet)
      // + Nút Check-in chỉ điều hướng tới màn quản lý; không xử lý booking tại Thông báo.
      return Row(
        children: [
          // Nút Chỉnh sửa ngày đến check in
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                ref
                    .read(hostNotificationRepositoryProvider)
                    .markAsRead(notif.id);
                HostUpdateDepositBottomSheet.show(context, notification: notif);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF344054),
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFD0D5DD)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.edit_calendar_outlined, size: 15),
              label: const Text(
                'Sửa ngày đến',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Nút Checkin chuyển sang trang checkin
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                ref
                    .read(hostNotificationRepositoryProvider)
                    .markAsRead(notif.id);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const HostCheckinCheckoutScreen(initialTab: 0),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.login_rounded, size: 16),
              label: const Text(
                'Check-in',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildRoomIssueAction(
    BuildContext context,
    WidgetRef ref,
    HostNotificationModel notif,
  ) {
    final isResolved = notif.statusId == 'resolved' || notif.statusId == 'completed';

    if (isResolved) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFA6F4C5)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF12B76A)),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Đã khắc phục & hoàn tất xử lý sự cố ✓',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF027A48),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        if (notif.reporterPhone.isNotEmpty) ...[
          Expanded(
            flex: 2,
            child: OutlinedButton.icon(
              onPressed: () async {
                final phoneUri = Uri(scheme: 'tel', path: notif.reporterPhone);
                if (await canLaunchUrl(phoneUri)) {
                  await launchUrl(phoneUri);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Số điện thoại liên hệ: ${notif.reporterPhone}')),
                  );
                }
              },
              icon: const Icon(Icons.phone_in_talk_rounded, size: 14),
              label: Text(
                'Gọi: ${notif.reporterPhone}',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFF93C5FD)),
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            onPressed: () => _showResolveIssueDialog(context, ref, notif),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 15),
            label: const Text(
              'Đã khắc phục xong',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showResolveIssueDialog(
    BuildContext context,
    WidgetRef ref,
    HostNotificationModel notif,
  ) async {
    final notesController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.task_alt_rounded, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Xác nhận đã khắc phục',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn xác nhận đã xử lý xong sự cố "${notif.category}" tại phòng ${notif.roomTitle}?',
              style: const TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: InputDecoration(
                labelText: 'Ghi chú xử lý (Tùy chọn)',
                hintText: 'Ví dụ: Đã thay bóng đèn, sửa vòi sen...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xác nhận hoàn tất'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(roomIssueServiceProvider).resolveRoomIssue(
              issueId: notif.issueId,
              hostNotes: notesController.text.trim(),
              hostNotificationId: notif.id,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã cập nhật trạng thái sự cố: Đã khắc phục xong ✓'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi cập nhật sự cố: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showImageDialog(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 18),
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}
