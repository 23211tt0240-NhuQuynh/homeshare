import '../theme/admin_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminNotificationsBottomSheet extends StatelessWidget {
  final Function(String type, String? targetId)? onNavigateTarget;

  const AdminNotificationsBottomSheet({super.key, this.onNavigateTarget});

  // Chuyển đổi mốc thời gian hiển thị thân thiện
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Vừa xong';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays == 1) return 'Hôm qua';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Đánh dấu tất cả là đã đọc
  Future<void> _markAllAsRead(List<QueryDocumentSnapshot> docs) async {
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['isRead'] != true) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }

  // Đánh dấu 1 thông báo là đã đọc
  Future<void> _markAsRead(String docId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(docId)
        .update({'isRead': true});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Thanh gạch ngang nhỏ kéo mành
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('recipientRole', isEqualTo: 'admin')
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final unreadDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['isRead'] != true;
              }).toList();

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Thông Báo Hệ Thống',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AdminColors.ink,
                          ),
                        ),
                        if (unreadDocs.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AdminColors.dangerContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${unreadDocs.length} mới',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AdminColors.danger,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (unreadDocs.isNotEmpty)
                      TextButton(
                        onPressed: () => _markAllAsRead(unreadDocs),
                        child: Text(
                          'Đọc tất cả',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: AdminColors.accent,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1),

          // Danh sách thông báo Realtime
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('recipientRole', isEqualTo: 'admin')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 56,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Chưa có thông báo nào',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AdminColors.muted,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Sắp xếp thông báo mới nhất lên đầu
                final sortedDocs = docs.toList()
                  ..sort((a, b) {
                    final aTime =
                        (a.data() as Map<String, dynamic>)['createdAt']
                            as Timestamp?;
                    final bTime =
                        (b.data() as Map<String, dynamic>)['createdAt']
                            as Timestamp?;
                    // createdAt null = vừa ghi, serverTimestamp chưa về -> coi là mới nhất
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return -1;
                    if (bTime == null) return 1;
                    return bTime.compareTo(aTime);
                  });

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: sortedDocs.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 68),
                  itemBuilder: (context, index) {
                    final doc = sortedDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isRead = data['isRead'] == true;
                    final title = data['title'] ?? 'Thông báo';
                    final body = data['body'] ?? data['message'] ?? '';
                    final type =
                        (data['notificationType'] ?? data['type'] ?? 'general')
                            .toString();
                    final targetId = (data['targetId'] ?? data['bookingId'])
                        ?.toString();
                    final timestamp = data['createdAt'] as Timestamp?;

                    return InkWell(
                      onTap: () async {
                        if (!isRead) {
                          await _markAsRead(doc.id);
                        }
                        if (context.mounted) {
                          Navigator.pop(context);
                          if (onNavigateTarget != null) {
                            onNavigateTarget!(type, targetId);
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        color: isRead
                            ? Colors.transparent
                            : AdminColors.paper,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildNotificationIcon(type),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: isRead
                                                ? FontWeight.w600
                                                : FontWeight.bold,
                                            color: AdminColors.ink,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _formatTimestamp(timestamp),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: AdminColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    body,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isRead
                                          ? AdminColors.muted
                                          : AdminColors.mutedStrong,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (!isRead) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 6),
                                decoration: BoxDecoration(
                                  color: AdminColors.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Biểu tượng phân loại từng dạng thông báo
  Widget _buildNotificationIcon(String type) {
    IconData iconData;
    Color iconColor;
    Color bgColor;

    switch (type) {
      case 'booking':
      case 'disbursement':
        iconData = Icons.account_balance_wallet_rounded;
        iconColor = AdminColors.success;
        bgColor = AdminColors.successContainer;
        break;
      case 'post_approval':
        iconData = Icons.apartment_rounded;
        iconColor = AdminColors.accent;
        bgColor = AdminColors.paper;
        break;
      case 'report':
        iconData = Icons.report_problem_rounded;
        iconColor = AdminColors.danger;
        bgColor = AdminColors.dangerContainer;
        break;
      default:
        iconData = Icons.notifications_rounded;
        iconColor = AdminColors.warningInk;
        bgColor = AdminColors.warningContainer;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }
}
