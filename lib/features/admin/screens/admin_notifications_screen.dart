import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminNotificationsBottomSheet extends StatelessWidget {
  final Function(String type, String? targetId)? onNavigateTarget;

  const AdminNotificationsBottomSheet({
    super.key,
    this.onNavigateTarget,
  });

  @override
  Widget build(BuildContext context) {
    return _AdminNotificationsContent(onNavigateTarget: onNavigateTarget);
  }
}

class _AdminNotificationsContent extends StatefulWidget {
  final Function(String type, String? targetId)? onNavigateTarget;

  const _AdminNotificationsContent({this.onNavigateTarget});

  @override
  State<_AdminNotificationsContent> createState() =>
      _AdminNotificationsContentState();
}

class _AdminNotificationsContentState
    extends State<_AdminNotificationsContent>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF398FC0);
  late final TabController _tabController =
      TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Vừa xong';
    final date = timestamp.toDate();
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays == 1) return 'Hôm qua';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _markAllAsRead(List<QueryDocumentSnapshot> docs) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['isRead'] != true) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }

  Future<void> _markAsRead(String docId) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(docId)
        .update({'isRead': true});
  }

  String _category(Map<String, dynamic> data) {
    final type = (data['notificationType'] ?? data['type'] ?? '')
        .toString()
        .toLowerCase();
    final content = '${data['title'] ?? ''} ${data['body'] ?? data['message'] ?? ''}'
        .toLowerCase();
    final value = '$type $content';

    if (value.contains('booking') ||
        value.contains('disbursement') ||
        value.contains('cancellation') ||
        value.contains('đơn') ||
        value.contains('cọc') ||
        value.contains('thanh toán') ||
        value.contains('giải ngân')) {
      return 'orders';
    }
    if (value.contains('post') ||
        value.contains('report') ||
        value.contains('bài đăng') ||
        value.contains('tin đăng') ||
        value.contains('phòng')) {
      return 'posts';
    }
    // Các cảnh báo tài khoản và thông báo quản trị chung được xếp vào Người dùng.
    return 'users';
  }

  List<QueryDocumentSnapshot> _sortDocs(List<QueryDocumentSnapshot> docs) {
    return docs.toList()..sort((a, b) {
      final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return -1;
      if (bTime == null) return 1;
      return bTime.compareTo(aTime);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFFF7FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('recipientRole', isEqualTo: 'admin')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _primary),
                  );
                }

                final allDocs = _sortDocs(snapshot.data?.docs ?? []);
                final unreadDocs = allDocs.where((doc) {
                  return (doc.data() as Map<String, dynamic>)['isRead'] != true;
                }).toList();
                const categories = ['orders', 'posts', 'users'];
                final labels = <String, String>{
                  'orders': 'Đơn',
                  'posts': 'Bài đăng',
                  'users': 'Người dùng',
                };
                final icons = <String, IconData>{
                  'orders': Icons.receipt_long_rounded,
                  'posts': Icons.apartment_rounded,
                  'users': Icons.people_alt_rounded,
                };

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 12, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF4FA),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(
                              Icons.home_work_rounded,
                              color: _primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'HomeShare',
                                  style: TextStyle(
                                    color: _primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Flexible(
                                      child: Text(
                                        'Thông báo hệ thống',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF101828),
                                        ),
                                      ),
                                    ),
                                    if (unreadDocs.isNotEmpty) ...[
                                      const SizedBox(width: 7),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEAF4FA),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${unreadDocs.length} mới',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: _primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (unreadDocs.isNotEmpty)
                            TextButton(
                              onPressed: () => _markAllAsRead(allDocs),
                              style: TextButton.styleFrom(
                                foregroundColor: _primary,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              child: const Text(
                                'Đọc tất cả',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE4EAF0)),
                    Material(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        labelColor: _primary,
                        unselectedLabelColor: const Color(0xFF667085),
                        indicatorColor: _primary,
                        indicatorWeight: 3,
                        tabs: categories.map((category) {
                          final count = allDocs.where((doc) {
                            return _category(doc.data() as Map<String, dynamic>) ==
                                category;
                          }).length;
                          return Tab(
                            height: 48,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(icons[category], size: 16),
                                const SizedBox(width: 5),
                                Text(labels[category]!),
                                if (count > 0) ...[
                                  const SizedBox(width: 5),
                                  Text(
                                    '$count',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: categories.map((category) {
                          final docs = allDocs.where((doc) {
                            return _category(doc.data() as Map<String, dynamic>) ==
                                category;
                          }).toList();
                          if (docs.isEmpty) {
                            return _emptyState(labels[category]!);
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: docs.length,
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              indent: 68,
                              color: Color(0xFFE4EAF0),
                            ),
                            itemBuilder: (context, index) =>
                                _notificationTile(context, docs[index]),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String category) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            size: 52,
            color: Color(0xFFB8C7D3),
          ),
          const SizedBox(height: 10),
          Text(
            'Chưa có thông báo $category',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notificationTile(
    BuildContext context,
    QueryDocumentSnapshot doc,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final isRead = data['isRead'] == true;
    final title = (data['title'] ?? 'Thông báo').toString();
    final body = (data['body'] ?? data['message'] ?? '').toString();
    final type = (data['notificationType'] ?? data['type'] ?? 'general').toString();
    final targetId = (data['targetId'] ?? data['bookingId'])?.toString();
    final timestamp = data['createdAt'] as Timestamp?;

    return InkWell(
      onTap: () async {
        if (!isRead) await _markAsRead(doc.id);
        if (!context.mounted) return;
        Navigator.pop(context);
        widget.onNavigateTarget?.call(type, targetId);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isRead ? Colors.transparent : const Color(0xFFEAF4FA),
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
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                            color: const Color(0xFF101828),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimestamp(timestamp),
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF98A2B3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isRead
                          ? const Color(0xFF667085)
                          : const Color(0xFF344054),
                    ),
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
                decoration: const BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(String type) {
    final normalized = type.toLowerCase();
    final isOrder = normalized.contains('booking') ||
        normalized.contains('disbursement') ||
        normalized.contains('cancellation');
    final isPost = normalized.contains('post') || normalized.contains('report');
    final iconData = isOrder
        ? Icons.account_balance_wallet_rounded
        : isPost
            ? Icons.apartment_rounded
            : normalized == 'warning'
                ? Icons.person_off_rounded
                : Icons.notifications_rounded;
    final iconColor = isOrder
        ? const Color(0xFF12B76A)
        : isPost
            ? _primary
            : normalized == 'warning'
                ? const Color(0xFFD92D20)
                : const Color(0xFFD97706);
    final bgColor = isOrder
        ? const Color(0xFFECFDF3)
        : isPost
            ? const Color(0xFFEAF4FA)
            : normalized == 'warning'
                ? const Color(0xFFFEF3F2)
                : const Color(0xFFFFFBEB);

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
