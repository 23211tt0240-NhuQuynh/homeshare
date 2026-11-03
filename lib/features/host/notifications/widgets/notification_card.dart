import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
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

  Color _getBadgeBg(String roomCode) {
    if (roomCode.startsWith('3')) {
      return const Color(0xFFECFDF3); // Xanh lá dịu
    } else if (roomCode.startsWith('2')) {
      return const Color(0xFFF4EBFF); // Tím nhạt dịu
    }
    return const Color(0xFFEFF8FF); // Xanh dương
  }

  Color _getBadgeTextColor(String roomCode) {
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
    if (name.startsWith('N')) return (AppColors.isDark ? AppColors.textDark : const Color(0xFF175CD3));
    if (name.startsWith('L')) return const Color(0xFFC11574);
    return const Color(0xFF344054);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notif = notification;
    final dateFmt = DateFormat('dd/MM/yyyy');
    final checkInStr = dateFmt.format(notif.checkInDate ?? notif.createdAt);
    final relativeTimeStr = _formatRelativeTime(notif.createdAt);

    return Container(
      margin: EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
            padding: EdgeInsets.all(16),
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
                        color: _getBadgeBg(notif.displayRoomCode),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            notif.displayRoomCode,
                            style: TextStyle(
                              fontSize: notif.displayRoomCode.length > 3
                                  ? 12
                                  : 15,
                              fontWeight: FontWeight.bold,
                              color: _getBadgeTextColor(notif.displayRoomCode),
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
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
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF101828),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 2),
                          Text(
                            notif.roomFloorInfo.isNotEmpty &&
                                    notif.roomTitle.isNotEmpty
                                ? notif.roomFloorInfo
                                : (notif.roomFloorInfo.isNotEmpty
                                      ? 'Phòng trọ'
                                      : 'Phòng trọ tiện nghi'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF667085),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    // Tag mã booking #BK12345
                    Container(
                      constraints: const BoxConstraints(maxWidth: 110),
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF8FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        notif.displayBookingCode,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // 2. Khối thông tin khách thuê & tiền cọc
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
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
                      SizedBox(width: 10),
                      // Tên khách thuê
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Khách thuê',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF667085),
                              ),
                            ),
                            Text(
                              notif.renterName.isNotEmpty
                                  ? notif.renterName
                                  : 'Khách thuê HomeShare',
                              style: TextStyle(
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
                      // Số tiền cọc
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currentTabType ==
                                    HostNotificationType.paymentCompleted
                                ? 'Đã thanh toán'
                                : (currentTabType ==
                                          HostNotificationType.staying
                                      ? 'Tiền cọc / phí phòng'
                                      : 'Tiền cọc giữ phòng'),
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF667085),
                            ),
                          ),
                          Text(
                            _formatCurrency(notif.amount),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 10),

                // 3. Ngày nhận phòng & thời gian gửi
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: Color(0xFF667085),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Dự kiến nhận phòng: $checkInStr  •  $relativeTimeStr',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667085),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12),

                // 4. Khối trạng thái hoặc Nút hành động tương ứng với từng Tab
                _buildBottomAction(context, ref, notif),
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
    if (notif.isRoommateApproval) {
      if (notif.statusId == 'approved' || notif.statusId == 'accepted') {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFA6F4C5)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: Color(0xFF12B76A),
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  currentTabType == HostNotificationType.staying
                      ? 'Đang ở • Đã xác nhận duyệt cho vào ở ghép'
                      : 'Đã xác nhận duyệt cho vào ở ghép',
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
      } else if (notif.statusId == 'rejected') {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3F2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFECDCA)),
          ),
          child: Row(
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
                      title: Text('Từ chối ở ghép'),
                      content: Text(
                        'Từ chối cho ${notif.newRoommateName.isNotEmpty ? notif.newRoommateName : "người này"} vào ở ghép phòng ${notif.displayRoomCode}?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text('Đóng'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD92D20),
                          ),
                          child: Text('Xác nhận từ chối'),
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
                  side: BorderSide(color: Color(0xFFFDA29B)),
                  padding: EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Từ chối',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(width: 8),
            // Nút Xác nhận duyệt vào phòng
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Xác nhận cho vào ở ghép'),
                      content: Text(
                        'Xác nhận duyệt cho ${notif.newRoommateName.isNotEmpty ? notif.newRoommateName : "khách"} vào ở ghép cùng ${notif.primaryTenantName.isNotEmpty ? notif.primaryTenantName : "người thuê chính"} tại phòng ${notif.displayRoomCode}?\n\nSau khi xác nhận, người này sẽ chính thức được thêm vào danh sách người ở của phòng.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text('Hủy'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF12B76A),
                          ),
                          child: Text('Xác nhận duyệt'),
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
                icon: Icon(Icons.check_rounded, size: 16),
                label: Text(
                  'Duyệt vào phòng',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF12B76A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 9),
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
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFA6F4C5)),
        ),
        child: Row(
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
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0x99FEF0C7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFEDF89)),
        ),
        child: Row(
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
                backgroundColor: AppColors.surface,
                side: BorderSide(color: Color(0xFFD0D5DD)),
                padding: EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(Icons.edit_calendar_outlined, size: 15),
              label: Text(
                'Sửa ngày đến',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(width: 10),
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
                padding: EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(Icons.login_rounded, size: 16),
              label: Text(
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
}
