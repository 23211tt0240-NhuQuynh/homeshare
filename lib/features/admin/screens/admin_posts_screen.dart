import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:home_share/features/admin/services/post_review_service.dart';
import 'package:home_share/features/admin/services/post_content_screening_service.dart';
import '../../../data/models/room_model.dart';
import 'admin_post_review_detail_screen.dart';
import '../widgets/admin_branded_title.dart';

class AdminPostsScreen extends ConsumerStatefulWidget {
  const AdminPostsScreen({super.key});

  @override
  ConsumerState<AdminPostsScreen> createState() => _AdminPostsScreenState();
}

class _AdminPostsScreenState extends ConsumerState<AdminPostsScreen> {
  String _filter = 'all'; // all, pending, active, rejected, attention
  DateTimeRange? _dateRange;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, Future<Map<String, dynamic>?>> _hostProfiles = {};
  final Map<String, Future<List<String>>> _roomImageLoads = {};
  final Map<String, Future<String?>> _imageScans = {};
  final Map<String, String?> _imageScanResults = {};
  bool _hasAttentionPosts = false;

  // Danh sách bài đăng bị báo cáo (roomId có report pending)
  Set<String> _reportedPostIds = {};
  Map<String, List<Map<String, dynamic>>> _reportsByRoomId = {};
  StreamSubscription<QuerySnapshot>? _reportsSubscription;

  @override
  void initState() {
    super.initState();
    try {
      _reportsSubscription = FirebaseFirestore.instance
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen((snapshot) {
          final reportsByRoomId = <String, List<Map<String, dynamic>>>{};
          for (final reportDoc in snapshot.docs) {
            final report = reportDoc.data();
            final roomId = (report['roomId'] ?? '').toString().trim();
            if (roomId.isEmpty) continue;
            reportsByRoomId.putIfAbsent(roomId, () => []).add({
              ...report,
              'reportId': reportDoc.id,
            });
          }
          if (mounted) {
            setState(() {
              _reportsByRoomId = reportsByRoomId;
              _reportedPostIds = reportsByRoomId.keys.toSet();
            });
          }
        });
    } catch (_) {}
  }

  @override
  void dispose() {
    _reportsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  bool _isHostResubmitted(Map<String, dynamic> data) {
    if (data['hostResubmittedAt'] != null || data['resubmittedAt'] != null) {
      return true;
    }
    DateTime? parseTime(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.tryParse(value?.toString() ?? '');
    }

    final reviewedAt = parseTime(data['reviewedAt']);
    final updatedAt = parseTime(data['updatedAt']);
    if (reviewedAt != null && updatedAt != null) {
      return updatedAt.difference(reviewedAt).inSeconds > 2;
    }
    return false;
  }

  String _normalizedPostStatus(Map<String, dynamic> data) {
    final status =
        (data['status'] ?? data['statusId'] ?? data['status_id'] ?? 'pending')
            .toString()
            .trim()
            .toLowerCase();
    if (const {
      'active',
      'approved',
      'danghien',
      'đang hiển thị',
      'đã duyệt',
      'da duyet',
      'published',
      'live',
    }.contains(status)) {
      return 'active';
    }
    if (data['deletedAt'] != null ||
        const {
          'deleted',
          'da xoa',
          'đã xóa',
          'da_xoa',
          'removed',
        }.contains(status)) {
      return 'rejected';
    }
    if (_isHostResubmitted(data)) {
      return 'pending';
    }
    if (const {
      'rejected',
      'reject',
      'denied',
      'tuchoi',
      'tu choi',
      'từ chối',
      'da tu choi',
      'đã từ chối',
      'da_tu_choi',
      'hidden',
      'đã ẩn',
      'da an',
    }.contains(status)) {
      return 'rejected';
    }
    return 'pending';
  }

  bool _containsReviewFlag(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    if (_normalizedPostStatus(data) != 'pending') return false;

    final imageText = _imageScanResults[doc.id];
    final hasImageFlag =
        _postImages(data).isNotEmpty &&
        _imageScanResults.containsKey(doc.id) &&
        imageText != null &&
        PostContentScreeningService.reviewReasons(
          data,
          extraText: imageText,
        ).isNotEmpty;
    return PostContentScreeningService.reviewReasons(data).isNotEmpty ||
        hasImageFlag ||
        _reportedPostIds.contains(doc.id);
  }

  Future<String?> _scanPostImages(DocumentSnapshot doc, List<String> images) {
    return _imageScans.putIfAbsent(doc.id, () async {
      try {
        final result = await PostContentScreeningService.scanImages(images);
        if (mounted) setState(() => _imageScanResults[doc.id] = result);
        return result;
      } catch (error) {
        debugPrint('OCR bài đăng ${doc.id} thất bại: $error');
        if (mounted) setState(() => _imageScanResults[doc.id] = null);
        return null;
      }
    });
  }

  Future<Map<String, dynamic>?> _hostProfile(String hostId) {
    return _hostProfiles.putIfAbsent(hostId, () async {
      if (hostId.isEmpty) return null;
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(hostId)
          .get();
      return snapshot.data();
    });
  }

  Future<List<Map<String, dynamic>>> _loadReportDetails(String postId) async {
    final cachedReports = _reportsByRoomId[postId];
    if (cachedReports != null && cachedReports.isNotEmpty) return cachedReports;

    final reports = FirebaseFirestore.instance.collection('reports');
    final snapshots = await Future.wait([
      reports.where('roomId', isEqualTo: postId).get(),
      reports.where('postId', isEqualTo: postId).get(),
      reports.where('post_id', isEqualTo: postId).get(),
    ]);
    final uniqueReports = <String, Map<String, dynamic>>{};
    for (final snapshot in snapshots) {
      for (final reportDoc in snapshot.docs) {
        uniqueReports[reportDoc.id] = {
          ...reportDoc.data(),
          'reportId': reportDoc.id,
        };
      }
    }
    return uniqueReports.values.toList();
  }

  String _reportField(
    Map<String, dynamic> report,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = report[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  DateTime? _reportDate(Map<String, dynamic> report) {
    final value = report['createdAt'] ?? report['created_at'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  Future<void> _showReportDetails(String postId, String postTitle) async {
    final reportsFuture = _loadReportDetails(postId);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFFF4FAFE),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFD6EAF7)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: reportsFuture,
              builder: (context, snapshot) {
                final reports = snapshot.data ?? const [];
                final Widget reportContent;
                if (snapshot.connectionState == ConnectionState.waiting) {
                  reportContent = const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF398FC0),
                      ),
                    ),
                  );
                } else if (snapshot.hasError) {
                  reportContent = Text(
                    'Không tải được báo cáo: ${snapshot.error}',
                    style: const TextStyle(
                      color: Color(0xFFB42318),
                      fontSize: 13,
                    ),
                  );
                } else if (reports.isEmpty) {
                  reportContent = const Text(
                    'Không tìm thấy thông tin báo cáo cho bài đăng này.',
                    style: TextStyle(color: Color(0xFF667085), fontSize: 13),
                  );
                } else {
                  reportContent = Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (
                            var index = 0;
                            index < reports.length;
                            index++
                          ) ...[
                            if (index > 0) const SizedBox(height: 10),
                            _buildReportReasonCard(reports[index]),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDDF1FC),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.home_work_rounded,
                            color: Color(0xFF398FC0),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'HomeShare',
                          style: TextStyle(
                            color: Color(0xFF398FC0),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Lý do báo cáo',
                      style: TextStyle(
                        color: Color(0xFF17324D),
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      postTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    reportContent,
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF287AA8),
                        ),
                        child: const Text('Đóng'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportReasonCard(Map<String, dynamic> report) {
    final reason = _reportField(report, const ['reason', 'type']);
    final detail = _reportField(report, const [
      'description',
      'detail',
      'note',
    ]);
    final reporter = _reportField(report, const [
      'reporterName',
      'reporter_name',
    ], fallback: 'Người báo cáo');
    final reporterId = _reportField(report, const [
      'reporter_id',
      'reporterId',
    ]);
    final reportedName = _reportField(report, const [
      'reportedUserName',
      'reported_name',
      'targetUserName',
      'hostName',
      'landlordName',
    ], fallback: 'Người bị báo cáo');
    final reportedUserId = _reportField(report, const [
      'reported_user_id',
      'reportedUserId',
      'author_id',
      'authorId',
      'targetUserId',
      'hostId',
      'landlordId',
    ]);
    final postId = _reportField(report, const [
      'post_id',
      'postId',
      'roomId',
      'room_id',
    ]);
    final createdAt = _reportDate(report);
    final status = _reportField(report, const ['status'], fallback: 'pending');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6EAF7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _reportIdentityRow(
            Icons.person_outline_rounded,
            'Người báo cáo',
            reporter,
            reporterId,
          ),
          const SizedBox(height: 8),
          _reportIdentityRow(
            Icons.person_pin_circle_outlined,
            'Người bị báo cáo',
            reportedName,
            reportedUserId,
          ),
          const SizedBox(height: 8),
          _reportIdentityRow(Icons.article_outlined, 'ID bài đăng', '', postId),
          if (createdAt != null) ...[
            const SizedBox(height: 8),
            _reportIdentityRow(
              Icons.schedule_rounded,
              'Thời gian',
              DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
              '',
            ),
          ],
          const SizedBox(height: 8),
          _reportIdentityRow(
            Icons.flag_outlined,
            'Trạng thái',
            _reportStatusLabel(status),
            '',
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFD6EAF7)),
          const SizedBox(height: 12),
          const Text(
            'Lý do',
            style: TextStyle(
              color: Color(0xFF287AA8),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            reason.isEmpty ? 'Không có lý do cụ thể' : reason,
            style: const TextStyle(
              color: Color(0xFF344054),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              detail,
              style: const TextStyle(
                color: Color(0xFF667085),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reportIdentityRow(
    IconData icon,
    String label,
    String value,
    String id,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF398FC0)),
        const SizedBox(width: 7),
        Expanded(
          child: Wrap(
            spacing: 5,
            runSpacing: 2,
            children: [
              Text(
                '$label:',
                style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
              ),
              if (value.isNotEmpty)
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF287AA8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (id.isNotEmpty)
                SelectableText(
                  '($id)',
                  style: const TextStyle(
                    color: Color(0xFF667085),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _reportStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Chờ xử lý';
      case 'approved':
      case 'resolved':
      case 'reviewed':
        return 'Đã xử lý';
      case 'rejected':
      case 'dismissed':
        return 'Đã bỏ qua';
      default:
        return status;
    }
  }

  // Định dạng tiền tệ an toàn trên Flutter Web
  String _formatMoney(num amount) {
    return "${amount.toStringAsFixed(0).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.')} đ";
  }

  double _num(dynamic v) => v is num ? v.toDouble() : 0.0;

  int? _optionalCount(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toInt();
      if (value != null) {
        final parsed = int.tryParse(value.toString());
        if (parsed != null) return parsed;
      }
    }
    final stats = data['stats'];
    if (stats is Map) {
      for (final key in keys) {
        final value = stats[key];
        if (value is num) return value.toInt();
        if (value != null) {
          final parsed = int.tryParse(value.toString());
          if (parsed != null) return parsed;
        }
      }
    }
    return null;
  }

  List<String> _postAmenities(Map<String, dynamic> data) {
    final raw =
        data['amenities'] ??
        data['tienIch'] ??
        data['roomAmenities'] ??
        data['features'];
    final values = raw is List ? raw : (raw == null ? const [] : [raw]);
    return values
        .map((value) {
          if (value is Map) {
            return (value['name'] ?? value['title'] ?? value['label'] ?? '')
                .toString()
                .trim();
          }
          return value?.toString().trim() ?? '';
        })
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  String _postText(
    Map<String, dynamic> data,
    List<String> keys,
    String fallback,
  ) {
    for (final key in keys) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  List<String> _postImages(Map<String, dynamic> data) {
    final raw =
        data['images'] ??
        data['roomImages'] ??
        data['anhPhong'] ??
        data['imageUrls'] ??
        data['photos'] ??
        data['photoUrls'] ??
        data['danhSachAnh'] ??
        data['hinhAnh'] ??
        data['hinh_anh'] ??
        data['anhList'] ??
        data['imageUrl'] ??
        data['photoUrl'] ??
        data['thumbnailUrl'] ??
        data['coverImage'] ??
        data['anh_bia'] ??
        data['anhBia'] ??
        data['image'];

    String? imageUrl(dynamic item) {
      if (item is String) {
        var value = item.trim().replaceAll('"', '').replaceAll("'", "");
        if (value.startsWith('{') && value.endsWith('}')) {
          final match = RegExp(
            r'''(?:duongDan|url|image|imageUrl|downloadURL|link):\s*["']?([^,"'}]+)''',
          ).firstMatch(value);
          if (match != null) {
            value = match
                .group(1)!
                .trim()
                .replaceAll('"', '')
                .replaceAll("'", "");
          }
        }
        return value.isEmpty ? null : value;
      }
      if (item is Map) {
        final value =
            item['url'] ??
            item['duongDan'] ??
            item['image'] ??
            item['imageUrl'] ??
            item['downloadURL'] ??
            item['downloadUrl'] ??
            item['storageUrl'] ??
            item['duong_dan'] ??
            item['link'];
        return value is String && value.trim().isNotEmpty
            ? value.trim().replaceAll('"', '').replaceAll("'", "")
            : null;
      }
      return null;
    }

    final items = raw is List ? raw : [raw];
    return items.map(imageUrl).whereType<String>().toSet().toList();
  }

  Future<List<String>> _loadImagesFromRoom(
    String roomId, {
    String? postId,
    String? propertyId,
  }) async {
    final normalizedId = roomId.trim();
    final normalizedPostId = (postId ?? '').trim();
    final normalizedPropId = (propertyId ?? '').trim();
    if (normalizedId.isEmpty &&
        normalizedPostId.isEmpty &&
        normalizedPropId.isEmpty) {
      return const [];
    }

    final results = <String>[];
    void addAllUnique(Iterable<String> urls) {
      for (final u in urls) {
        final clean = u.trim();
        if (clean.isNotEmpty && !results.contains(clean)) {
          results.add(clean);
        }
      }
    }

    String? extractImageDocUrl(Map<String, dynamic> data) {
      final raw =
          data['url'] ??
          data['url_anh'] ??
          data['duongDan'] ??
          data['imageUrl'] ??
          data['image'] ??
          data['downloadURL'] ??
          data['downloadUrl'] ??
          data['storageUrl'] ??
          data['duong_dan'] ??
          data['link'];
      if (raw is String && raw.trim().isNotEmpty) {
        return raw.trim().replaceAll('"', '').replaceAll("'", "");
      }
      final listImgs = _postImages(data);
      return listImgs.isNotEmpty ? listImgs.first : null;
    }

    final db = FirebaseFirestore.instance;

    try {
      if (normalizedId.isNotEmpty) {
        final roomDoc = await db.collection('rooms').doc(normalizedId).get();
        if (roomDoc.exists) {
          addAllUnique(
            _postImages(roomDoc.data() ?? const <String, dynamic>{}),
          );
          if (results.isNotEmpty) return results;
        }

        final snapshots = await Future.wait([
          db
              .collection('rooms')
              .where('roomId', isEqualTo: normalizedId)
              .limit(1)
              .get(),
          db
              .collection('posts')
              .where('roomId', isEqualTo: normalizedId)
              .limit(1)
              .get(),
          db
              .collection('room_images')
              .where('roomId', isEqualTo: normalizedId)
              .get(),
        ]);

        for (final d in snapshots[0].docs) {
          addAllUnique(_postImages(d.data()));
        }
        for (final d in snapshots[1].docs) {
          addAllUnique(_postImages(d.data()));
        }
        for (final d in snapshots[2].docs) {
          final u = extractImageDocUrl(d.data());
          if (u != null) addAllUnique([u]);
        }
        if (results.isNotEmpty) return results;
      }

      if (normalizedPostId.isNotEmpty) {
        final snap = await db
            .collection('room_images')
            .where('postId', isEqualTo: normalizedPostId)
            .get();
        for (final d in snap.docs) {
          final u = extractImageDocUrl(d.data());
          if (u != null) addAllUnique([u]);
        }
      }
    } catch (_) {
      // Ignore room image fetch errors and keep the post card usable.
    }

    return results;
  }

  Widget _buildPostThumbWidget(
    List<String> postImages,
    String roomId, {
    String? postId,
    String? propertyId,
    int index = 0,
  }) {
    final normalizedRoomId = roomId.trim();
    if (index < postImages.length) {
      final url = postImages[index].trim();
      if (url.isNotEmpty) {
        return _networkPostThumbnail(
          url,
          onError: () => _buildPostThumbWidget(
            postImages,
            normalizedRoomId,
            postId: postId,
            propertyId: propertyId,
            index: index + 1,
          ),
        );
      }
    }
    return _buildRoomImageFallback(
      normalizedRoomId,
      postId: postId,
      propertyId: propertyId,
      failedUrls: postImages.toSet(),
    );
  }

  Widget _networkPostThumbnail(String url, {Widget Function()? onError}) {
    if (url.startsWith('data:image/') && url.contains('base64,')) {
      try {
        final bytes = base64Decode(url.substring(url.indexOf('base64,') + 7));
        return Image.memory(
          bytes,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              onError?.call() ?? _postThumbnailPlaceholder(),
        );
      } catch (_) {
        return onError?.call() ?? _postThumbnailPlaceholder();
      }
    }

    final isFirebaseStorageUrl =
        url.contains('firebasestorage.googleapis.com') ||
        url.contains('storage.googleapis.com');
    return Image.network(
      url,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      webHtmlElementStrategy: isFirebaseStorageUrl
          ? WebHtmlElementStrategy.prefer
          : WebHtmlElementStrategy.fallback,
      errorBuilder: (context, error, stackTrace) =>
          onError?.call() ?? _postThumbnailPlaceholder(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF398FC0),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoomImageFallback(
    String roomId, {
    String? postId,
    String? propertyId,
    Set<String> failedUrls = const {},
  }) {
    final cacheKey =
        '${roomId.trim()}|${(postId ?? '').trim()}|${(propertyId ?? '').trim()}';
    if (cacheKey == '||') return _postThumbnailPlaceholder();

    final imagesFuture = _roomImageLoads.putIfAbsent(
      cacheKey,
      () => _loadImagesFromRoom(
        roomId,
        postId: postId,
        propertyId: propertyId,
      ),
    );
    return FutureBuilder<List<String>>(
      future: imagesFuture,
      builder: (context, snapshot) {
        final candidates = (snapshot.data ?? const <String>[])
            .where((image) => !failedUrls.contains(image))
            .toList();
        if (candidates.isEmpty) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF398FC0),
                ),
              ),
            );
          }
          return _postThumbnailPlaceholder();
        }
        return _networkPostThumbnail(candidates.first);
      },
    );
  }

  Widget _postThumbnailPlaceholder() {
    return const Center(
      child: Icon(
        Icons.broken_image_outlined,
        size: 28,
        color: Color(0xFF7AA6C2),
      ),
    );
  }

  // Chuyển DocumentSnapshot (collection posts) thành RoomModel
  // Schema posts: rentalPrice, depositAmount, roomId, hostId, images, amenities...
  RoomModel _docToRoomModel(
    DocumentSnapshot doc, {
    Map<String, dynamic>? hostProfile,
  }) {
    {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final images = _postImages(data);

      final rentalPrice = _num(
        data['rentalPrice'] ?? data['price'] ?? data['giaThue'] ?? data['gia'],
      );
      final deposit = _num(
        data['depositAmount'] ??
            data['deposit'] ??
            data['tienCoc'] ??
            data['tienDatCoc'],
      );

      return RoomModel(
        id: doc.id,
        roomCode: (data['roomCode'] ?? data['maPhong'] ?? data['roomId'] ?? '')
            .toString(),
        title: _postText(data, const ['title', 'tieuDe'], 'Bài đăng phòng trọ'),
        description: _postText(data, const [
          'description',
          'moTa',
          'noiDung',
          'content',
          'roomDescription',
        ], ''),
        price: rentalPrice,
        deposit: deposit > 0 ? deposit : rentalPrice,
        address: _postText(data, const [
          'address',
          'diaChi',
          'diaChiChiTiet',
        ], 'Đang cập nhật địa chỉ'),
        district: _postText(data, const ['district', 'quanHuyen'], ''),
        city: _postText(data, const ['city', 'thanhPho', 'province'], ''),
        area: _num(data['area'] ?? data['areaM2'] ?? data['dienTich']),
        roomType: _postText(data, const [
          'roomType',
          'loaiPhong',
          'propertyType',
        ], 'Phòng trọ'),
        amenities: _postAmenities(data),
        images: images,
        hostId:
            (data['hostId'] ??
                    data['landlordId'] ??
                    data['userId'] ??
                    data['ownerId'] ??
                    '')
                .toString(),
        hostName:
            (data['hostName'] ??
                    data['landlordName'] ??
                    hostProfile?['displayName'] ??
                    hostProfile?['hoTen'] ??
                    hostProfile?['fullName'] ??
                    'Chủ trọ')
                .toString(),
        hostPhone:
            (data['hostPhone'] ??
                    data['phone'] ??
                    hostProfile?['phoneNumber'] ??
                    hostProfile?['soDienThoai'] ??
                    'Đang cập nhật')
                .toString(),
        hostAvatar:
            (data['hostAvatar'] ??
                    data['avatarUrl'] ??
                    data['anhDaiDien'] ??
                    hostProfile?['avatarUrl'] ??
                    hostProfile?['anhDaiDien'] ??
                    '')
                .toString(),
        createdAt: data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.tryParse((data['createdAt'] ?? '').toString()) ??
                  DateTime.now(),
      );
    }
  }

  void _openDetailPreview(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final posts = _docToRoomModel(doc);
    final status = _normalizedPostStatus(data);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPostReviewDetailScreen(
          room: posts,
          docId: doc.id,
          postPurpose: _postText(data, const [
            'postPurpose',
            'purpose',
            'rentalPurpose',
            'category',
          ], ''),
          viewCount: _optionalCount(data, const ['viewCount', 'views', 'view']),
          favoriteCount: _optionalCount(data, const [
            'favoriteCount',
            'favorites',
            'likes',
            'likeCount',
          ]),
          postStatus: status,
          canApprove: status != 'rejected' || _isHostResubmitted(data),
          onApproved: () async {
            try {
              await PostReviewService.approve(doc.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF12B76A),
                    content: Text('Đã phê duyệt bài đăng thành công!'),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Lỗi duyệt bài: $e')));
              }
            }
          },
          onRejected: () async {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFFD92D20),
                  content: Text('Đã từ chối bài đăng thành công!'),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  // Duyệt bài đăng trực tiếp (cập nhật posts + thông báo chủ trọ + audit log)
  Future<void> _approvePost(String docId) async {
    try {
      await PostReviewService.approve(docId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF12B76A),
            content: Text('Đã duyệt bài đăng!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi duyệt bài: $e')));
      }
    }
  }

  // Hạ bài / Gỡ bài (cập nhật posts + thông báo chủ trọ + audit log)
  Future<void> _rejectPost(String docId) async {
    try {
      await PostReviewService.reject(
        docId,
        reason: 'Admin đã gỡ bài đăng khỏi hệ thống',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFD92D20),
            content: Text('Đã hạ bài đăng khỏi hệ thống!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi gỡ bài: $e')));
      }
    }
  }

  Future<void> _chooseDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _dateRange,
      helpText: 'Chọn khoảng ngày báo cáo / bài đăng',
      saveText: 'ÁP DỤNG',
    );
    if (picked != null && mounted) setState(() => _dateRange = picked);
  }

  bool _isWithinSelectedDateRange(DateTime? date) {
    if (_dateRange == null) return true;
    if (date == null) return false;
    final start = DateTime(
      _dateRange!.start.year,
      _dateRange!.start.month,
      _dateRange!.start.day,
    );
    final end = DateTime(
      _dateRange!.end.year,
      _dateRange!.end.month,
      _dateRange!.end.day,
      23,
      59,
      59,
      999,
    );
    return !date.isBefore(start) && !date.isAfter(end);
  }

  String _postSearchText(Map<String, dynamic> data, String id) {
    return [
      id,
      data['roomCode'],
      data['roomId'],
      data['title'],
      data['tieuDe'],
      data['hostId'],
      data['landlordId'],
      data['userId'],
      data['hostName'],
      data['landlordName'],
      data['hostPhone'],
      data['phone'],
      data['address'],
      data['description'],
    ].whereType<Object>().join(' ').toLowerCase();
  }

  DateTime? _postCreatedAt(Map<String, dynamic> data) {
    final value = data['createdAt'] ?? data['created_at'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  DateTime? _attentionCreatedAt(String postId, Map<String, dynamic> data) {
    final reports = _reportsByRoomId[postId];
    if (reports != null && reports.isNotEmpty) {
      final reportDates = reports
          .map(_reportDate)
          .whereType<DateTime>()
          .toList();
      if (reportDates.isNotEmpty) {
        return reportDates.reduce(
          (latest, date) => date.isAfter(latest) ? date : latest,
        );
      }
    }
    return _postCreatedAt(data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleSpacing: 16,
        toolbarHeight: 72,
        title: const AdminBrandedTitle(
          title: 'Quản lý bài đăng',
          subtitle: 'Duyệt & kiểm duyệt tin phòng trọ',
        ),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Thanh Lọc Trạng Thái (Tất cả, Chờ duyệt, Đã duyệt, Từ chối)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterPill(
                        'Tất cả',
                        'all',
                        const Color(0xFF398FC0),
                      ),
                      _buildFilterPill(
                        'Chờ duyệt',
                        'pending',
                        const Color(0xFF398FC0),
                      ),
                      _buildFilterPill(
                        'Đã duyệt',
                        'active',
                        const Color(0xFF398FC0),
                      ),
                      _buildFilterPill(
                        'Từ chối',
                        'rejected',
                        const Color(0xFF398FC0),
                      ),
                      _buildFilterPill(
                        'Cần lưu ý',
                        'attention',
                        const Color(0xFF398FC0),
                        showDot: _hasAttentionPosts,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final searchWidth = constraints.maxWidth > 700
                        ? 360.0
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: searchWidth,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Tìm theo tên hoặc ID bài đăng...',
                              hintStyle: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF98A2B3),
                              ),
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 19,
                                color: Color(0xFF667085),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _chooseDateRange,
                          icon: const Icon(
                            Icons.calendar_month_outlined,
                            size: 17,
                          ),
                          label: Text(
                            _dateRange == null
                                ? 'Tất cả ngày'
                                : '${DateFormat('dd/MM/yyyy').format(_dateRange!.start)} – ${DateFormat('dd/MM/yyyy').format(_dateRange!.end)}',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475467),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: const BorderSide(color: Color(0xFFD0D5DD)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // 2. Danh Sách Bài Đăng Realtime từ Firebase
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: () {
                try {
                  return FirebaseFirestore.instance
                      .collection('posts')
                      .snapshots();
                } catch (_) {
                  return const Stream<QuerySnapshot>.empty();
                }
              }(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint('Lỗi tải posts trong Admin: ${snapshot.error}');
                  if (_hasAttentionPosts) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _hasAttentionPosts) {
                        setState(() => _hasAttentionPosts = false);
                      }
                    });
                  }
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Không tải được bài đăng. Kiểm tra mạng hoặc quyền đọc collection posts.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                final searchText = _searchController.text
                    .trim()
                    .toLowerCase();

                bool isAttentionDoc(DocumentSnapshot doc) {
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final relevantDate = _attentionCreatedAt(doc.id, data);
                  if (!_isWithinSelectedDateRange(relevantDate)) {
                    return false;
                  }
                  if (searchText.isNotEmpty &&
                      !_postSearchText(data, doc.id).contains(searchText)) {
                    return false;
                  }
                  return _containsReviewFlag(doc);
                }

                final hasAttentionPosts = docs.any(isAttentionDoc);
                if (hasAttentionPosts != _hasAttentionPosts) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _hasAttentionPosts != hasAttentionPosts) {
                      setState(() => _hasAttentionPosts = hasAttentionPosts);
                    }
                  });
                }

                // Lọc danh sách theo Tab đang chọn (Đã chuẩn hóa status)
                final filteredDocs = docs.where((doc) {
                  if (_filter == 'attention') return isAttentionDoc(doc);

                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final relevantDate = _postCreatedAt(data);
                  if (!_isWithinSelectedDateRange(relevantDate)) {
                    return false;
                  }

                  if (searchText.isNotEmpty &&
                      !_postSearchText(data, doc.id).contains(searchText)) {
                    return false;
                  }

                  final status = _normalizedPostStatus(data);
                  if (_filter == 'all') return true;
                  if (_filter == 'pending') return status == 'pending';
                  if (_filter == 'active') return status == 'active';
                  if (_filter == 'rejected') return status == 'rejected';
                  return true;
                }).toList();

                DateTime postDate(DocumentSnapshot doc) {
                  final value =
                      (doc.data() as Map<String, dynamic>?)?['createdAt'];
                  return value is Timestamp
                      ? value.toDate()
                      : DateTime.fromMillisecondsSinceEpoch(0);
                }

                filteredDocs.sort((a, b) {
                  final da = a.data() as Map<String, dynamic>? ?? {};
                  final db = b.data() as Map<String, dynamic>? ?? {};
                  final handledA = _normalizedPostStatus(da) != 'pending';
                  final handledB = _normalizedPostStatus(db) != 'pending';
                  if (_filter == 'all' && handledA != handledB) {
                    return handledA ? 1 : -1;
                  }
                  return postDate(b).compareTo(postDate(a));
                });

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Thanh đếm số lượng kết quả
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                      child: Text(
                        _filter == 'attention'
                            ? '${filteredDocs.length} bài cần admin đọc kỹ'
                            : 'Tìm thấy ${filteredDocs.length} kết quả',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ),

                    // Danh sách card
                    Expanded(
                      child: filteredDocs.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.apartment_rounded,
                                    size: 48,
                                    color: Color(0xFFD0D5DD),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Không có bài đăng nào trong danh mục này',
                                    style: TextStyle(color: Color(0xFF667085)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                              itemCount: filteredDocs.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final doc = filteredDocs[index];
                                return _buildPostCard(doc);
                              },
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

  Widget _buildFilterPill(
    String label,
    String value,
    Color color, {
    bool showDot = false,
  }) {
    final isSelected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: value == 'attention' ? 112 : 96,
        child: InkWell(
          onTap: () => setState(() => _filter = value),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: isSelected ? color : const Color(0xFFEAF4FA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? color : const Color(0xFFD8EAF5),
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : const Color(0xFF536B82),
                  ),
                ),
                if (value == 'attention' && showDot) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD92D20),
                      shape: BoxShape.circle,
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

  Widget _buildPostCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final id = doc.id;
    final title = (data['title'] ?? data['tieuDe'] ?? 'Bài đăng chưa có tên')
        .toString();
    final price = _num(data['rentalPrice'] ?? data['price']);
    final hostId =
        (data['hostId'] ?? data['landlordId'] ?? data['userId'] ?? '')
            .toString();
    final rawHostName = data['hostName'] ?? data['landlordName'];
    final hostName = rawHostName?.toString();
    final phone = (data['hostPhone'] ?? data['phone'] ?? '').toString();
    final rawRejectReason = data['rejectReason'];
    final rejectReason = rawRejectReason?.toString();
    final isReported = _reportedPostIds.contains(id);

    // Lấy danh sách ảnh hiển thị
    final images = _postImages(data);

    final status = _normalizedPostStatus(data);
    final isPending = status == 'pending';
    final isActive = status == 'active';
    final isRejected = status == 'rejected';
    final canReviewAgain = isRejected && _isHostResubmitted(data);
    final reviewReasons = isPending
        ? PostContentScreeningService.reviewReasons(data)
        : const <String>[];
    final imageUrls = _postImages(data);
    if (isPending &&
        imageUrls.isNotEmpty &&
        PostContentScreeningService.supportsImageScanning) {
      _scanPostImages(doc, imageUrls);
    }
    final imageText = _imageScanResults[id];
    final imageReasons = !isPending || imageText == null
        ? const <String>[]
        : PostContentScreeningService.reviewReasons(data, extraText: imageText);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _openDetailPreview(doc),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPending
                  ? const Color(0xFFB9DDF1)
                  : const Color(0xFFDCEAF3),
              width: isPending ? 1.4 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Badge báo cáo (hiển thị nếu bài bị report pending)
            if (isReported) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: const Color(0xFFEAF6FC),
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    onTap: () => _showReportDetails(id, title),
                    borderRadius: BorderRadius.circular(9),
                    child: SizedBox(
                      width: double.infinity,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: const Color(0xFFB9DDF1)),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.flag_rounded,
                              size: 15,
                              color: Color(0xFF287AA8),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'BÁO CÁO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF287AA8),
                                letterSpacing: 0.3,
                              ),
                            ),
                            SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                '· Có người dùng báo cáo bài đăng này',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF287AA8),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 84,
                    height: 84,
                    color: const Color(0xFFE6F1F8),
                    child: _buildPostThumbWidget(
                      images,
                      (data['roomId'] ??
                              data['phongId'] ??
                              data['roomCode'] ??
                              '')
                          .toString(),
                      postId: id,
                      propertyId:
                          (data['propertyId'] ?? data['batDongSanId'] ?? '')
                              .toString(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isPending)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF0C7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '• Chờ duyệt',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB54708),
                                ),
                              ),
                            )
                          else if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Đã duyệt',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF027A48),
                                ),
                              ),
                            )
                          else if (isRejected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE4E2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '• Từ chối',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD92D20),
                                ),
                              ),
                            ),
                          const Spacer(),
                          InkWell(
                            onTap: () => _openDetailPreview(doc),
                            borderRadius: BorderRadius.circular(16),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: Color(0xFF98A2B3),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF101828),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 13,
                            color: Color(0xFF667085),
                          ),
                          const SizedBox(width: 4),
                          FutureBuilder<Map<String, dynamic>?>(
                            future: _hostProfile(hostId),
                            builder: (context, snapshot) {
                              final profile = snapshot.data;
                              final name =
                                  (hostName ??
                                          profile?['displayName'] ??
                                          profile?['hoTen'] ??
                                          profile?['fullName'] ??
                                          'Chủ trọ')
                                      .toString();
                              return Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF667085),
                                ),
                              );
                            },
                          ),
                          if (phone.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '• $phone',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF98A2B3),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatMoney(price),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF155EEF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (reviewReasons.isNotEmpty || imageReasons.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE4E7EC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.fact_check_outlined,
                          size: 16,
                          color: Color(0xFF398FC0),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Bài đăng cần lưu ý',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF344054),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ...reviewReasons.map(
                      (reason) => Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          '• $reason',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF667085),
                          ),
                        ),
                      ),
                    ),
                    ...imageReasons
                        .where((reason) => !reviewReasons.contains(reason))
                        .map(
                          (reason) => Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              '• Chữ trong ảnh: $reason',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF667085),
                              ),
                            ),
                          ),
                        ),
                    const SizedBox(height: 4),
                    const Text(
                      'Gợi ý tự động để tham khảo; admin cần kiểm tra nội dung đầy đủ.',
                      style: TextStyle(fontSize: 10, color: Color(0xFF98A2B3)),
                    ),
                  ],
                ),
              ),
            ],

            if (isPending) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approvePost(id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF398FC0),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '✓ Duyệt bài đăng',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _openDetailPreview(doc),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFDA29B)),
                        foregroundColor: const Color(0xFFD92D20),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '✕ Từ chối',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (isActive) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openDetailPreview(doc),
                      icon: const Icon(Icons.visibility_outlined, size: 14),
                      label: const Text(
                        'Xem Trực Tiếp',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectPost(id),
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        size: 14,
                        color: Color(0xFFD92D20),
                      ),
                      label: const Text(
                        'Hạ Tin / Gỡ Bài',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD92D20),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFDA29B)),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (isRejected) ...[
              if (rejectReason != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: Color(0xFFD92D20),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          rejectReason,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFD92D20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canReviewAgain ? () => _approvePost(id) : null,
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: Text(
                    canReviewAgain
                        ? 'Duyệt lại / Hiện bài'
                        : 'Chờ chủ trọ chỉnh sửa bài',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canReviewAgain
                        ? const Color(0xFF398FC0)
                        : const Color(0xFFE4E7EC),
                    foregroundColor: canReviewAgain
                        ? Colors.white
                        : const Color(0xFF667085),
                    disabledBackgroundColor: const Color(0xFFE4E7EC),
                    disabledForegroundColor: const Color(0xFF667085),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
