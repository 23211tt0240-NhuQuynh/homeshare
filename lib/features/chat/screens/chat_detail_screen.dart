import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/room_model.dart';
import '../../../data/models/roommate_post_model.dart';
import '../../../core/services/call_service.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/roommate_service.dart';
import '../../renter/screens/room_detail_screen.dart';
import '../../renter/screens/roommate_room_detail_screen.dart';
import '../services/roommate_invitation_eligibility_service.dart';
import '../services/roommate_invitation_policy.dart';
import 'call_screen.dart';

/// Màn hình Chi tiết Tin nhắn & Trao đổi (Feature #10 theo chuẩn SRS CDLTDD & Tc_CHAT_01 -> 50)
class ChatDetailScreen extends ConsumerStatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverAvatar;
  final String receiverPhone;
  final bool isLandlord;
  final String currentUserId;
  final String currentUserName;
  final RoomModel? pinnedRoom;
  final RoommatePostModel? pinnedPost;
  final String? roommatePostId;

  const ChatDetailScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatar = '',
    this.receiverPhone = '0903888999',
    this.isLandlord = true,
    required this.currentUserId,
    required this.currentUserName,
    this.pinnedRoom,
    this.pinnedPost,
    this.roommatePostId,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  static final _phoneRegex = RegExp(r'\b(0\d{9,10})\b');

  bool _isBlocked = false;
  bool _showPinnedRoom = true;
  bool _showPinnedPost = true;
  RoommatePostModel? _linkedPost;
  bool _showScrollToBottom = false;
  bool _isRecordingAudio = false;
  String? _senderRole;
  String? _receiverRole;
  RoomModel? _activeRentedRoom;
  late final RoommateInvitationEligibilityService _invitationEligibilityService;
  final Set<String> _deletedForMeIds = {};
  final Set<String> _revokedIds = {};
  ChatMessageModel? _replyingToMessage;
  final FocusNode _focusNode = FocusNode();

  bool get _isUserToUser {
    return RoommateInvitationPolicy.canInvite(
      senderRole: _senderRole,
      receiverRole: _receiverRole,
      hasActiveRoom: true,
    );
  }

  bool get _canSendRoommateInvitation => _isUserToUser && _activeRentedRoom != null;

  bool get _receiverIsHost => _receiverRole == 'host';

  @override
  void initState() {
    super.initState();
    _invitationEligibilityService = RoommateInvitationEligibilityService();
    _scrollController.addListener(_onScroll);
    // Tự động đánh dấu đã đọc khi mở chi tiết cuộc trò chuyện và kiểm tra vai trò đối phương
    _linkedPost = widget.pinnedPost;
    Future.microtask(() {
      if (mounted) {
        ref.read(chatServiceProvider).markAsRead(widget.currentUserId, widget.receiverId);
        _refreshRoommateInvitationEligibility();
        _attachRoommatePost();
      }
    });
  }

  Future<RoommateInvitationEligibility> _refreshRoommateInvitationEligibility() async {
    final eligibility = await _invitationEligibilityService.resolve(
      senderId: widget.currentUserId,
      receiverId: widget.receiverId,
    );
    if (mounted) {
      setState(() {
        _senderRole = eligibility.senderRole;
        _receiverRole = eligibility.receiverRole;
        _activeRentedRoom = eligibility.activeRoom;
      });
    }
    return eligibility;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final show = _scrollController.offset > 150;
    if (show != _showScrollToBottom) {
      setState(() => _showScrollToBottom = show);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setReplyMessage(ChatMessageModel msg) {
    setState(() {
      _replyingToMessage = msg;
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToMessage = null;
    });
  }

  Map<String, dynamic> _replyPayload() {
    final replying = _replyingToMessage;
    if (replying == null) return {};
    return {
      'messageId': replying.id,
      'senderId': replying.senderId,
      'senderName': replying.senderId == widget.currentUserId ? widget.currentUserName : widget.receiverName,
      'text': replying.messageType == 'image' ? '📷 [Hình ảnh]' : replying.text,
      'messageType': replying.messageType,
    };
  }

  void _clearReply() {
    if (_replyingToMessage == null) return;
    setState(() => _replyingToMessage = null);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Gửi tin nhắn văn bản (Tc_CHAT_21 -> 25)
  Future<void> _sendMessage([String? overrideText]) async {
    final text = (overrideText ?? _messageController.text).trim();
    if (text.isEmpty) {
      // Chặn gửi tin nhắn rỗng hoặc chỉ có khoảng trắng (Tc_CHAT_24)
      return;
    }

    if (_isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể gửi tin nhắn do đối phương đã bị chặn.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    // Kiểm tra bộ lọc từ ngữ vi phạm tiêu chuẩn cộng đồng (Tc_CHAT_49)
    if (ChatService.checkProfanity(text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tin nhắn vi phạm tiêu chuẩn cộng đồng về an toàn thông tin.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (overrideText == null) {
      _messageController.clear();
    }

    final message = ChatMessageModel(
      id: '',
      senderId: widget.currentUserId,
      senderName: widget.currentUserName,
      receiverId: widget.receiverId,
      text: text,
      timestamp: DateTime.now(),
      status: 'sent',
      extraData: _replyingToMessage == null ? const {} : {'replyTo': _replyPayload()},
    );

    try {
      final roomMeta = <String, dynamic>{};
      if (widget.pinnedRoom != null) {
        roomMeta.addAll({
          'roomCode': '#LT-${widget.pinnedRoom!.id.hashCode.abs() % 1000}',
          'roomTitle': widget.pinnedRoom!.title,
          'roomPrice': widget.pinnedRoom!.price,
          'roomImage': widget.pinnedRoom!.images.isNotEmpty ? widget.pinnedRoom!.images.first : '',
        });
      }
      final linkedPostId = (_linkedPost?.id ?? widget.pinnedPost?.id ?? '').trim();
      if (linkedPostId.isNotEmpty) {
        roomMeta['roommatePostId'] = linkedPostId;
        roomMeta['tinOGhepId'] = linkedPostId;
      }

      await ref.read(chatServiceProvider).sendMessage(
        message,
        receiverName: widget.receiverName,
        receiverAvatar: widget.receiverAvatar,
        receiverPhone: widget.receiverPhone,
        roomMetadata: roomMeta,
      );
      _clearReply();
      _scrollToBottom();
    } catch (e) {
      if (overrideText == null) {
        _messageController.text = text;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi gửi tin: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  // Gửi thẻ đa phương tiện (Lịch hẹn, Lời mời ở ghép, Vị trí, Ảnh)
  Future<bool> _sendRichMessage({
    required String text,
    required String messageType,
    String attachmentUrl = '',
    Map<String, dynamic> extraData = const {},
  }) async {
    final combinedExtraData = Map<String, dynamic>.from(extraData);
    if (_replyingToMessage != null) {
      combinedExtraData['replyTo'] = _replyPayload();
    }

    final message = ChatMessageModel(
      id: '',
      senderId: widget.currentUserId,
      senderName: widget.currentUserName,
      receiverId: widget.receiverId,
      text: text,
      messageType: messageType,
      attachmentUrl: attachmentUrl,
      extraData: combinedExtraData,
      timestamp: DateTime.now(),
      status: 'sent',
    );

    try {
      await ref.read(chatServiceProvider).sendMessage(
        message,
        receiverName: widget.receiverName,
        receiverAvatar: widget.receiverAvatar,
        receiverPhone: widget.receiverPhone,
      );
      _clearReply();
      _scrollToBottom();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
        );
      }
      return false;
    }
  }

  Future<void> _startOnlineCall({required bool video}) async {
    final granted = await CallPermissions.ensure(video: video);
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(video ? 'Cần quyền micro và camera để gọi video.' : 'Cần quyền micro để gọi thoại.')),
      );
      return;
    }

    try {
      final session = await ref.read(callServiceProvider).startCall(
        callerId: widget.currentUserId,
        callerName: widget.currentUserName,
        calleeId: widget.receiverId,
        calleeName: widget.receiverName,
        video: video,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CallScreen(call: session, isCaller: true)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không bắt đầu được cuộc gọi: $e')),
      );
    }
  }

  void _makeAudioCall() => _startOnlineCall(video: false);

  void _makeVideoCall() => _startOnlineCall(video: true);

  // Hiện số điện thoại khi bấm vào số trong nội dung tin nhắn
  void _showPhoneContactDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.primaryContainer,
              child: Icon(Icons.phone, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Gọi cho ${widget.receiverName}', style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Số điện thoại liên hệ trực tiếp:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.receiverPhone,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20, color: AppColors.textMuted),
                    tooltip: 'Sao chép số',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.receiverPhone));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã sao chép số điện thoại')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Hệ thống hỗ trợ gọi trực tiếp qua mạng di động của thiết bị.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.call, size: 18),
            label: const Text('Bắt Đầu Gọi'),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đang kết nối cuộc gọi tới ${widget.receiverPhone}...'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Menu tùy chọn ba chấm (Tc_CHAT_06 -> 08)
  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline, color: AppColors.primary),
              title: const Text('Xem hồ sơ đối tác'),
              onTap: () {
                Navigator.pop(ctx);
                _showPartnerProfileDialog();
              },
            ),
            ListTile(
              leading: Icon(_isBlocked ? Icons.lock_open : Icons.block, color: AppColors.danger),
              title: Text(_isBlocked ? 'Bỏ chặn người dùng này' : 'Chặn người dùng này (Block)'),
              subtitle: Text(
                _isBlocked ? 'Cho phép nhận và gửi tin nhắn trở lại' : 'Người này sẽ không thể gửi tin nhắn cho bạn',
                style: const TextStyle(fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _isBlocked = !_isBlocked);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isBlocked ? 'Đã chặn người dùng' : 'Đã bỏ chặn người dùng'),
                    backgroundColor: _isBlocked ? AppColors.danger : AppColors.primary,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_problem_outlined, color: Colors.orange),
              title: const Text('Báo cáo vi phạm (Report)'),
              subtitle: const Text('Báo cáo hành vi lừa đảo, quấy rối hoặc thông tin giả', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _showReportDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.textMuted),
              title: const Text('Xóa lịch sử cuộc trò chuyện'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã làm trống lịch sử trò chuyện cục bộ')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPartnerProfileDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryContainer,
              child: Text(
                widget.receiverName.isNotEmpty ? widget.receiverName[0] : 'U',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(widget.receiverName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (widget.isLandlord) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: AppColors.primary, size: 16),
                      ],
                    ],
                  ),
                  Text(
                    widget.isLandlord ? 'Chủ nhà trọ đã xác thực' : 'Người thuê / Tìm ở ghép',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone_outlined, size: 20),
              title: Text(widget.receiverPhone, style: const TextStyle(fontSize: 14)),
              subtitle: const Text('Số điện thoại liên hệ', style: TextStyle(fontSize: 11)),
            ),
            const ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.shield_outlined, size: 20, color: AppColors.primary),
              title: Text('Điểm uy tín: 100/100', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              subtitle: Text('Đã xác thực CCCD & Căn cước công dân', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
        ],
      ),
    );
  }

  void _showReportDialog() {
    final reasons = ['Lừa đảo tiền đặt cọc', 'Thông tin phòng không đúng sự thật', 'Quấy rối / Từ ngữ thô tục', 'Lý do khác'];
    String selected = reasons[0];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: const Text('Báo cáo vi phạm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons
                .map(
                  (r) => ListTile(
                    dense: true,
                    leading: Icon(
                      selected == r ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: selected == r ? AppColors.primary : AppColors.textMuted,
                      size: 20,
                    ),
                    title: Text(r, style: const TextStyle(fontSize: 13)),
                    onTap: () => setDState(() => selected = r),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã gửi báo cáo vi phạm tới Ban Quản Trị HomeShare')),
                );
              },
              child: const Text('Gửi Báo Cáo'),
            ),
          ],
        ),
      ),
    );
  }

  // Menu đính kèm phương tiện (+) (Tc_CHAT_29)
  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const Text('Đính kèm phương tiện & hành động', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildAttachOption(
                      icon: Icons.photo_library_outlined,
                      label: 'Gửi ảnh Album',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndSendImage(ImageSource.gallery);
                      },
                    ),
                  ),
                  Expanded(
                    child: _buildAttachOption(
                      icon: Icons.camera_alt_outlined,
                      label: 'Chụp ảnh',
                      color: Colors.purple,
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndSendImage(ImageSource.camera);
                      },
                    ),
                  ),
                  Expanded(
                    child: _buildAttachOption(
                      icon: Icons.location_on_outlined,
                      label: 'Vị trí hiện tại',
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(ctx);
                        _sendLocationMessage();
                      },
                    ),
                  ),
                  Expanded(
                    child: _buildAttachOption(
                      icon: Icons.group_add_outlined,
                      label: 'Mời ở ghép',
                      color: Colors.orange,
                      onTap: () {
                        Navigator.pop(ctx);
                        _showRoommateInviteDialog();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Chọn và gửi ảnh thật (Album hoặc Camera), đồng bộ lên Firebase để cả 2 bên đều xem được
  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedImage = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedImage == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 1),
            content: Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 12),
                Text('Đang tải và đồng bộ ảnh lên Firebase...'),
              ],
            ),
          ),
        );
      }

      final file = File(pickedImage.path);
      final bytes = await file.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      String attachmentUrl = '';
      try {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedImage.name}';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('chat_media')
            .child(widget.currentUserId)
            .child(fileName);

        final uploadTask = storageRef.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        final snapshot = await uploadTask.timeout(const Duration(seconds: 5));
        attachmentUrl = await snapshot.ref.getDownloadURL();
      } catch (storageError) {
        debugPrint('[Chat] Firebase Storage chưa kích hoạt hoặc lỗi ($storageError). Lưu ảnh trực tiếp vào Firebase Cloud Firestore.');
        // Lưu ảnh Base64 vào Firebase Firestore để 100% cả 2 bên thiết bị đều tải và hiển thị được
        attachmentUrl = base64Image;
      }

      await _sendRichMessage(
        text: source == ImageSource.camera ? '[Hình ảnh chụp]' : '[Hình ảnh từ album]',
        messageType: 'image',
        attachmentUrl: attachmentUrl,
        extraData: {
          'fileName': pickedImage.name,
          'fileSize': bytes.length,
          'source': source.name,
        },
      );
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể chọn ảnh: $e')),
        );
      }
    }
  }

  Future<void> _pickAndSendImageFromAlbum() => _pickAndSendImage(ImageSource.gallery);

  void _sendLocationMessage() {
    _sendRichMessage(
      text: 'Vị trí phòng: Số 8, Đường Linh Trung, Phường Linh Trung, TP. Thủ Đức',
      messageType: 'location',
      extraData: {
        'address': 'Số 8, Đường Linh Trung, TP. Thủ Đức',
        'latitude': 10.8654,
        'longitude': 106.7725,
      },
    );
  }


  Future<void> _showRoommateInviteDialog() async {
    final eligibility = await _refreshRoommateInvitationEligibility();
    if (!mounted) return;

    final isUserToUser = RoommateInvitationPolicy.canInvite(
      senderRole: eligibility.senderRole,
      receiverRole: eligibility.receiverRole,
      hasActiveRoom: true,
    );

    if (!isUserToUser ||
        eligibility.blockReason == RoommateInvitationBlockReason.roleNotAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tính năng mời ở ghép chỉ áp dụng giữa người dùng với nhau (người thuê gửi cho người thuê).'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final targetRoom = eligibility.activeRoom;
    if (targetRoom == null) {
      final lookupFailed = eligibility.blockReason == RoommateInvitationBlockReason.lookupFailed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lookupFailed
                ? 'Không thể xác minh phòng của bạn lúc này. Vui lòng kiểm tra kết nối và thử lại.'
                : 'Bạn phải đang ở trong trọ mới có thể gửi lời mời ở ghép.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final roomTitle = targetRoom.title.trim().isNotEmpty
        ? targetRoom.title.trim()
        : (targetRoom.roomCode.trim().isNotEmpty ? targetRoom.roomCode.trim() : targetRoom.id);
    final sharePrice = targetRoom.price > 0 ? (targetRoom.price / 2).round() : 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.handshake_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Mời vào ở ghép', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gửi lời mời ghép phòng tới: ${widget.receiverName}'),
            const SizedBox(height: 8),
            Text(
              'Phòng: $roomTitle',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              sharePrice > 0
                  ? 'Chi phí dự kiến: ${NumberFormat("#,###", "vi_VN").format(sharePrice)} đ/tháng/người'
                  : 'Chi phí dự kiến: Chưa cập nhật',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sau khi đối phương chấp nhận, thông báo sẽ tự động được gửi tới Chủ trọ.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _sendVerifiedRoommateInvitation();
            },
            child: const Text('Gửi Lời Mời'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendVerifiedRoommateInvitation() async {
    // Kiểm tra lại ngay trước lúc ghi tin nhắn để không dùng quyền/phòng đã cũ.
    final eligibility = await _refreshRoommateInvitationEligibility();
    if (!mounted) return;

    final room = eligibility.activeRoom;
    if (!eligibility.canInvite || room == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            eligibility.blockReason == RoommateInvitationBlockReason.roleNotAllowed
                ? 'Lời mời ở ghép chỉ được gửi giữa hai người dùng (người thuê).'
                : 'Không tìm thấy phòng đang thuê hợp lệ. Lời mời chưa được gửi.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final roomTitle = room.title.trim().isNotEmpty
        ? room.title.trim()
        : (room.roomCode.trim().isNotEmpty ? room.roomCode.trim() : room.id);
    final sharePrice = room.price > 0 ? (room.price / 2).round() : 0;
    final sent = await _sendRichMessage(
      text: 'Lời mời cùng ở ghép phòng tại HomeShare',
      messageType: 'roommate_invitation',
      extraData: {
        'status': 'pending',
        'roomId': room.id,
        'roomCode': room.roomCode,
        'roomTitle': roomTitle,
        'hostId': room.hostId,
        'pricePerPerson': sharePrice,
        'senderName': widget.currentUserName,
        'senderId': widget.currentUserId,
        'receiverName': widget.receiverName,
        'receiverId': widget.receiverId,
      },
    );

    if (!sent) return;
    try {
      await ref.read(chatServiceProvider).notifyUserRoommateInvitation(
            receiverId: widget.receiverId,
            senderId: widget.currentUserId,
            senderName: widget.currentUserName,
            roomId: room.id,
            roomCode: room.roomCode.trim().isNotEmpty ? room.roomCode.trim() : room.id,
            roomTitle: roomTitle,
            pricePerPerson: sharePrice.toDouble(),
            hostId: room.hostId,
          );
    } catch (error) {
      debugPrint('[Chat] Đã gửi lời mời nhưng chưa tạo được thông báo: $error');
    }
  }

  Future<void> _acceptRoommateInvite(ChatMessageModel msg) async {
    try {
      final roomId = msg.extraData['roomId']?.toString().trim() ?? '';
      if (roomId.isEmpty) {
        throw StateError('Lời mời không liên kết với phòng hợp lệ.');
      }

      RoomModel? verifiedRoom;
      for (final collection in const ['rooms', 'host_rooms']) {
        final roomDoc = await FirebaseFirestore.instance.collection(collection).doc(roomId).get();
        if (roomDoc.exists && roomDoc.data() != null) {
          final candidate = RoomModel.fromMap(roomDoc.data()!, roomDoc.id);
          if (candidate.hostId.trim().isNotEmpty) {
            verifiedRoom = candidate;
            break;
          }
        }
      }
      if (verifiedRoom == null || verifiedRoom.hostId.trim().isEmpty) {
        throw StateError('Không xác minh được phòng hoặc chủ trọ của lời mời.');
      }

      final hostId = verifiedRoom.hostId.trim();
      final roomTitle = verifiedRoom.title.trim().isNotEmpty
          ? verifiedRoom.title.trim()
          : (verifiedRoom.roomCode.trim().isNotEmpty ? verifiedRoom.roomCode.trim() : verifiedRoom.id);

      final updatedExtraData = Map<String, dynamic>.from(msg.extraData);
      updatedExtraData['status'] = 'accepted';
      updatedExtraData['acceptedBy'] = widget.currentUserId;
      updatedExtraData['acceptedByName'] = widget.currentUserName;
      updatedExtraData['acceptedAt'] = DateTime.now().toIso8601String();

      await ref.read(chatServiceProvider).updateMessageExtraData(
        senderId: msg.senderId,
        receiverId: msg.receiverId,
        messageId: msg.id,
        extraData: updatedExtraData,
      );

      // Chỉ thông báo đúng chủ trọ lấy từ document phòng đã xác minh.
      await ref.read(chatServiceProvider).notifyHostRoommateAccepted(
        hostId: hostId,
        roomId: roomId,
        roomTitle: roomTitle,
        primaryTenantName: msg.senderName,
        primaryTenantId: msg.senderId,
        newRoommateName: widget.currentUserName,
        newRoommateId: widget.currentUserId,
      );

      // Gửi tin nhắn xác nhận realtime vào đoạn chat
      await _sendMessage('✅ Tôi đã chấp nhận lời mời ở ghép cùng bạn tại phòng $roomTitle. Hệ thống đã gửi thông báo đến chủ nhà!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã chấp nhận lời mời ở ghép và gửi thông báo đến chủ nhà thành công!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi chấp nhận lời mời: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _rejectRoommateInvite(ChatMessageModel msg) async {
    try {
      final updatedExtraData = Map<String, dynamic>.from(msg.extraData);
      updatedExtraData['status'] = 'rejected';
      updatedExtraData['rejectedBy'] = widget.currentUserId;
      updatedExtraData['rejectedAt'] = DateTime.now().toIso8601String();

      await ref.read(chatServiceProvider).updateMessageExtraData(
        senderId: msg.senderId,
        receiverId: msg.receiverId,
        messageId: msg.id,
        extraData: updatedExtraData,
      );

      await _sendMessage('Tôi xin phép từ chối lời mời ở ghép này nhé. Cảm ơn bạn!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã từ chối lời mời ở ghép.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _revokeRoommateInvite(ChatMessageModel msg) async {
    try {
      final updatedExtraData = Map<String, dynamic>.from(msg.extraData);
      updatedExtraData['status'] = 'revoked';
      updatedExtraData['revokedAt'] = DateTime.now().toIso8601String();

      await ref.read(chatServiceProvider).updateMessageExtraData(
        senderId: msg.senderId,
        receiverId: msg.receiverId,
        messageId: msg.id,
        extraData: updatedExtraData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thu hồi lời mời ở ghép.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  // Ghi âm tin nhắn thoại (Tc_CHAT_34 -> 37)
  void _toggleAudioRecording() {
    setState(() => _isRecordingAudio = !_isRecordingAudio);
    if (!_isRecordingAudio) {
      _sendRichMessage(
        text: 'Tin nhắn thoại (0:05)',
        messageType: 'audio',
        extraData: {
          'duration': '0:05',
          'isPlaying': false,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi tin nhắn âm thanh thoại')),
      );
    }
  }

  // Sao chép tin nhắn (Tc_CHAT_40)
  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép vào bộ nhớ tạm')),
    );
  }

  // Xóa tin nhắn phía tôi (Tc_CHAT_41)
  void _deleteForMe(String messageId) {
    setState(() {
      _deletedForMeIds.add(messageId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã xóa tin nhắn ở phía bạn')),
    );
  }

  // Menu thao tác khi nhấn giữ tin nhắn (Long Press Context Menu - TC 40, 41)
  void _showMessageContextMenu(ChatMessageModel msg, bool isMe) {
    final isRevoked = msg.messageType == 'revoked' || msg.status == 'revoked' || _revokedIds.contains(msg.id);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isRevoked)
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: AppColors.primary),
                title: const Text('Trả lời tin nhắn', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  msg.messageType == 'image' ? '📷 [Hình ảnh]' : (msg.text.isNotEmpty ? msg.text : 'Tin nhắn'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _setReplyMessage(msg);
                },
              ),
            if (!isRevoked)
              ListTile(
                leading: const Icon(Icons.copy_outlined, color: AppColors.primary),
                title: const Text('Sao chép nội dung tin nhắn'),
                onTap: () {
                  Navigator.pop(ctx);
                  _copyMessage(msg.text);
                },
              ),
            // Thu hồi tin nhắn ở cả 2 phía (chỉ người gửi tin nhắn mới được thu hồi)
            if (isMe && !isRevoked)
              ListTile(
                leading: const Icon(Icons.undo_rounded, color: Colors.orange),
                title: const Text(
                  'Thu hồi tin nhắn (Cả 2 bên)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                ),
                subtitle: const Text('Hiển thị "Tin nhắn đã được thu hồi" cho cả hai người', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmRevokeMessage(msg);
                },
              ),
            // Xóa tin nhắn ở cả 2 phía (Xóa vĩnh viễn khỏi cuộc trò chuyện của cả 2)
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined, color: AppColors.danger),
                title: const Text(
                  'Xóa tin nhắn ở cả 2 bên',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger),
                ),
                subtitle: const Text('Xóa hoàn toàn tin nhắn này khỏi cuộc trò chuyện của cả hai người', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteForEveryone(msg);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFF64748B)),
              title: const Text('Xóa ở phía tôi (Chỉ mình tôi)'),
              subtitle: const Text('Chỉ ẩn tin nhắn này trên thiết bị của bạn', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteForMe(msg.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Xác nhận thu hồi tin nhắn ở cả 2 bên
  void _confirmRevokeMessage(ChatMessageModel msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.undo_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Thu hồi tin nhắn?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Tin nhắn này sẽ bị thu hồi và hiển thị "Tin nhắn đã được thu hồi" ở cả phía bạn và đối phương.',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _revokeMessage(msg.id);
            },
            child: const Text('Thu hồi'),
          ),
        ],
      ),
    );
  }

  // Xác nhận xóa tin nhắn ở cả 2 bên (xóa vĩnh viễn)
  void _confirmDeleteForEveryone(ChatMessageModel msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_outlined, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Xóa tin nhắn ở cả 2 bên?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Tin nhắn này sẽ bị xóa hoàn toàn khỏi cuộc trò chuyện của cả phía bạn và phía đối phương.',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteForEveryone(msg.id);
            },
            child: const Text('Xóa cả 2 bên'),
          ),
        ],
      ),
    );
  }

  Future<void> _revokeMessage(String messageId) async {
    setState(() {
      _revokedIds.add(messageId);
    });

    try {
      await ref.read(chatServiceProvider).revokeMessageForEveryone(
        senderId: widget.currentUserId,
        receiverId: widget.receiverId,
        messageId: messageId,
      );
    } catch (e) {
      debugPrint('Error revoking message: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thu hồi tin nhắn ở cả 2 bên')),
      );
    }
  }

  Future<void> _deleteForEveryone(String messageId) async {
    setState(() {
      _deletedForMeIds.add(messageId);
    });

    try {
      await ref.read(chatServiceProvider).deleteMessagePermanently(
        senderId: widget.currentUserId,
        receiverId: widget.receiverId,
        messageId: messageId,
      );
    } catch (e) {
      debugPrint('Error deleting message for everyone: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa vĩnh viễn tin nhắn ở cả 2 bên')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.78;
    final messagesAsync = ref.watch(messagesStreamProvider(ChatParams(
      userA: widget.currentUserId,
      userB: widget.receiverId,
    )));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        leading: Semantics(
          label: 'Quay lại danh sách tin nhắn',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Quay lại',
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: InkWell(
          onTap: _showPartnerProfileDialog,
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryContainer,
                    child: Text(
                      widget.receiverName.isNotEmpty ? widget.receiverName[0] : 'U',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.receiverName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.isLandlord) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: AppColors.primary, size: 15),
                        ],
                      ],
                    ),
                    const Row(
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: Colors.green),
                        SizedBox(width: 4),
                        Text('Đang trực tuyến', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Nút Gọi thoại (Tc_CHAT_04)
          Semantics(
            label: 'Gọi điện thoại cho ${widget.receiverName}',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.phone_outlined, color: AppColors.primary),
              tooltip: 'Gọi thoại',
              onPressed: _makeAudioCall,
            ),
          ),
          // Nút Gọi video (Tc_CHAT_05)
          Semantics(
            label: 'Gọi video với ${widget.receiverName}',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.videocam_outlined, color: AppColors.primary),
              tooltip: 'Gọi video',
              onPressed: _makeVideoCall,
            ),
          ),
          // Nút tùy chọn ba chấm (Tc_CHAT_06)
          Semantics(
            label: 'Tùy chọn cuộc trò chuyện',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Tùy chọn',
              onPressed: _showOptionsMenu,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 1. Thẻ bảo vệ giao dịch an toàn (SRS 2.10)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: const Color(0xFFFEF3C7),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: Color(0xFFB45309)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Bảo vệ an toàn: Tuyệt đối không cọc tiền trước khi đến xem phòng trực tiếp.',
                        style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Thẻ phòng trọ ghim trên đầu khung chat (Tc_CHAT_09 -> 11 & SRS 2.10)
              if (_showPinnedRoom && widget.pinnedRoom != null)
                _buildPinnedRoomCard(widget.pinnedRoom!),

              if (_showPinnedPost && widget.pinnedRoom == null && _linkedPost != null)
                _buildPinnedPostCard(_linkedPost!),

              // 3. Danh sách tin nhắn Realtime
              Expanded(
                child: messagesAsync.when(
                  data: (rawMessages) {
                    final messages = rawMessages.where((m) => !_deletedForMeIds.contains(m.id)).toList();

                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'Bắt đầu cuộc trò chuyện với ${widget.receiverName}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Nhấn vào các câu hỏi nhanh bên dưới để gửi ngay',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      );
                    }

                    return RepaintBoundary(
                      child: ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        addAutomaticKeepAlives: true,
                        addRepaintBoundaries: true,
                        physics: const ClampingScrollPhysics(),
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isMe = msg.senderId == widget.currentUserId;
                          return RepaintBoundary(
                            key: ValueKey(msg.id),
                            child: _buildMessageItem(msg, isMe, maxBubbleWidth),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Lỗi tải tin nhắn: $err')),
                ),
              ),

              // 4. Thanh câu hỏi gợi ý nhanh (Quick Action Chips - Tc_CHAT_12 -> 14 & SRS 2.10)
              RepaintBoundary(
                child: _buildQuickChipsBar(),
              ),

              // 5. Thanh nhập tin nhắn và đính kèm
              RepaintBoundary(
                child: _buildInputArea(),
              ),
            ],
          ),

          // Nút nổi cuộn xuống đáy khi cuộn ngược lên (Tc_CHAT_43)
          if (_showScrollToBottom)
            Positioned(
              right: 16,
              bottom: 120,
              child: FloatingActionButton.small(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                tooltip: 'Cuộn xuống tin mới nhất',
                onPressed: _scrollToBottom,
                child: const Icon(Icons.arrow_downward, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  // Widget Thẻ phòng trọ ghim trên đầu khung chat (Tc_CHAT_09 -> 11)
  /// Ghi tinOGhepId lên cuộc trò chuyện đã có, hoặc đọc lại id đó khi mở từ danh sách tin nhắn.
  Future<void> _attachRoommatePost() async {
    final chatId = ChatService.getChatId(widget.currentUserId, widget.receiverId);
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
    final current = _linkedPost;
    if (current != null && current.id.isNotEmpty) {
      final snap = await chatRef.get();
      if (snap.exists) {
        await chatRef.set({
          'roommatePostId': current.id,
          'tinOGhepId': current.id,
        }, SetOptions(merge: true));
      }
      return;
    }

    var postId = (widget.roommatePostId ?? '').trim();
    if (postId.isEmpty) {
      final snap = await chatRef.get();
      postId = '${snap.data()?['roommatePostId'] ?? snap.data()?['tinOGhepId'] ?? ''}'.trim();
    }
    if (postId.isEmpty || !mounted) return;
    final post = await ref.read(roommateServiceProvider).loadPost(postId);
    if (!mounted || post == null) return;
    setState(() => _linkedPost = post);
  }

  void _openRoommatePost(RoommatePostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RoommateRoomDetailScreen(post: post)),
    );
  }

  Widget _buildPinnedPostCard(RoommatePostModel post) {
    final price = post.pricePerPerson > 0 ? post.pricePerPerson : 0.0;
    final image = post.images.isNotEmpty ? post.images.first.trim() : '';
    final address = post.address.trim();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 58,
              height: 58,
              child: _pinnedPostImage(image),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => _openRoommatePost(post),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title.trim().isEmpty ? 'Bài tìm ở ghép' : post.title.trim(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (price > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(price)}/người',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                  if (address.isNotEmpty)
                    Text(
                      address,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Column(
            children: [
              InkWell(
                onTap: () => setState(() => _showPinnedPost = false),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 4),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(72, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _openRoommatePost(post),
                child: const Text('Xem bài', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pinnedPostImage(String image) {
    if (image.startsWith('http://') || image.startsWith('https://')) {
      return Image.network(
        image,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const ColoredBox(
          color: AppColors.primaryContainer,
          child: Icon(Icons.article_outlined, color: AppColors.primary),
        ),
      );
    }
    if (image.startsWith('data:image')) {
      try {
        final comma = image.indexOf(',');
        final bytes = base64Decode(comma == -1 ? image : image.substring(comma + 1));
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }
    return const ColoredBox(
      color: AppColors.primaryContainer,
      child: Icon(Icons.article_outlined, color: AppColors.primary),
    );
  }

  Widget _buildPinnedRoomCard(RoomModel room) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ảnh thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 58,
              height: 58,
              color: AppColors.primaryContainer,
              child: room.images.isNotEmpty
                  ? Image.network(
                      room.images.first,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.home, color: AppColors.primary),
                    )
                  : const Icon(Icons.home, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 10),
          // Thông tin phòng
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room)),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#LT-${room.id.hashCode.abs() % 1000} • ${room.title}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(room.price)}/tháng',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    room.address,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Nút Xem phòng & Đóng
          Column(
            children: [
              InkWell(
                onTap: () => setState(() => _showPinnedRoom = false),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.close, size: 16, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 4),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RoomDetailScreen(room: room)),
                  );
                },
                child: const Text('Xem phòng', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Widget Thanh câu hỏi gợi ý nhanh (Tc_CHAT_12 -> 14)
  Widget _buildQuickChipsBar() {
    final chips = _isUserToUser
        ? <String>[
            'Chào bạn, bạn đã tìm được phòng chưa?',
            'Ngân sách phòng trọ bạn dự kiến bao nhiêu?',
            'Thói quen sinh hoạt của bạn như thế nào?',
            if (_canSendRoommateInvitation) '+ Mời vào ở ghép',
          ]
        : (widget.isLandlord || _receiverIsHost)
            ? [
                'Phòng này còn trống không?',
                'Có chỗ để xe không?',
                'Giờ giấc như thế nào?',
              ]
            : [
                'Chào bạn, bạn cần hỗ trợ thông tin gì?',
                'Phòng còn trống không?',
              ];

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          final isInviteChip = chip == '+ Mời vào ở ghép';

          return ActionChip(
            backgroundColor: isInviteChip ? AppColors.primaryContainer : Colors.white,
            side: BorderSide(color: isInviteChip ? AppColors.primary : AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            label: Text(
              chip,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isInviteChip ? FontWeight.bold : FontWeight.w500,
                color: isInviteChip ? AppColors.primary : AppColors.textDark,
              ),
            ),
            onPressed: () {
              if (isInviteChip) {
                _showRoommateInviteDialog();
              } else {
                _sendMessage(chip);
              }
            },
          );
        },
      ),
    );
  }

  // Widget Thanh nhập tin nhắn và đính kèm
  Widget _buildInputArea() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingToMessage != null) _buildReplyBanner(),
            Row(
          children: [
            // Nút Thêm đính kèm (+) (Tc_CHAT_29)
            IconButton(
              tooltip: 'Đính kèm',
              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 26),
              onPressed: _showAttachmentMenu,
            ),

            // Nút Chọn ảnh từ Album nhanh (Tc_CHAT_30)
            IconButton(
              tooltip: 'Chọn ảnh từ Album',
              icon: const Icon(Icons.photo_library_outlined, color: AppColors.primary, size: 24),
              onPressed: _pickAndSendImageFromAlbum,
            ),

            // Ô nhập liệu văn bản (Tc_CHAT_21, 22)
            Expanded(
              child: Semantics(
                label: 'Nội dung tin nhắn',
                textField: true,
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: _isRecordingAudio ? 'Đang ghi âm (0:05)...' : 'Nhập tin nhắn...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: _isRecordingAudio ? AppColors.danger : AppColors.textMuted,
                      fontWeight: _isRecordingAudio ? FontWeight.bold : FontWeight.normal,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Nút Micro ghi âm (Tc_CHAT_34 -> 36)
            IconButton(
              tooltip: 'Ghi âm tin nhắn',
              icon: Icon(
                _isRecordingAudio ? Icons.stop_circle : Icons.mic_none,
                color: _isRecordingAudio ? AppColors.danger : AppColors.textMuted,
                size: 24,
              ),
              onPressed: _toggleAudioRecording,
            ),

            // Nút Gửi (Tc_CHAT_23 -> 25)
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                tooltip: 'Gửi tin nhắn',
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: () => _sendMessage(),
              ),
            ),
          ],
        ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyBanner() {
    final replying = _replyingToMessage;
    if (replying == null) return const SizedBox.shrink();

    final isMe = replying.senderId == widget.currentUserId;
    final senderName = isMe ? 'chính bạn' : widget.receiverName;
    final previewText = replying.messageType == 'image' ? '📷 [Hình ảnh]' : replying.text;

    return Container(
      margin: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 3.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Đang trả lời $senderName',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  previewText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Color(0xFF94A3B8)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Hủy trả lời',
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }

  Widget _buildReplyQuote(Map<String, dynamic> reply, bool isMe) {
    final senderName = reply['senderName']?.toString() ?? 'Tin nhắn';
    final text = reply['text']?.toString() ?? '';
    final isImage = reply['messageType'] == 'image';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withValues(alpha: 0.18) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white : AppColors.primary,
            width: 3.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.reply_rounded,
                size: 13,
                color: isMe ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white : AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            isImage ? '📷 [Hình ảnh]' : text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: isMe ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  // Builder cho từng loại bong bóng tin nhắn (Văn bản, Lịch hẹn, Lời mời ở ghép, Vị trí, Ảnh, Audio)
  Widget _buildMessageItem(ChatMessageModel msg, bool isMe, [double? maxBubbleWidth]) {
    final isRevoked = msg.messageType == 'revoked' || msg.status == 'revoked' || _revokedIds.contains(msg.id);
    return Dismissible(
      key: ValueKey('msg_swipe_${msg.id.isNotEmpty ? msg.id : msg.timestamp.millisecondsSinceEpoch}'),
      direction: isRevoked ? DismissDirection.none : DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        _setReplyMessage(msg);
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: const Icon(Icons.reply_rounded, color: AppColors.primary, size: 24),
      ),
      child: GestureDetector(
      onLongPress: () => _showMessageContextMenu(msg, isMe),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(
            maxWidth: maxBubbleWidth ?? (MediaQuery.of(context).size.width * 0.78),
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              _buildMessageBubbleBody(msg, isMe),
              const SizedBox(height: 2),
              // Nhãn thời gian và trạng thái (Tc_CHAT_26)
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('HH:mm').format(msg.timestamp),
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg.isRead ? Icons.done_all : Icons.check,
                      size: 13,
                      color: msg.isRead ? Colors.blue : AppColors.textMuted,
                    ),
                  ] else if (!msg.isRead && msg.status != 'read') ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Chưa đọc',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildMessageBubbleBody(ChatMessageModel msg, bool isMe) {
    final isRevoked = msg.messageType == 'revoked' || msg.status == 'revoked' || _revokedIds.contains(msg.id);

    // 0. Tin nhắn đã được thu hồi (Xóa ở cả 2 phía)
    if (isRevoked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block_outlined, size: 14, color: Color(0xFF94A3B8)),
            SizedBox(width: 6),
            Text(
              'Tin nhắn đã được thu hồi',
              style: TextStyle(
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }

    // 1. Thẻ Lịch hẹn xem phòng (Appointment Card - SRS 2.10 line 1090)
    if (msg.messageType == 'appointment') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.event_available, color: AppColors.primary, size: 20),
                SizedBox(width: 6),
                Text('LỊCH HẸN XEM PHÒNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
              ],
            ),
            const Divider(height: 16),
            Text(msg.text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    msg.extraData['address'] ?? 'Số 8, Linh Trung, TP. Thủ Đức',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lịch hẹn xem phòng đã được lưu vào hệ thống')),
                );
              },
              child: const Text('Xem Chi Tiết Lịch Hẹn', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    // 2. Thẻ Lời mời vào ở ghép (Tc_CHAT_14 -> 20 & Figma Node: 3346:3226)
    if (msg.messageType == 'roommate_invitation') {
      final inviteStatus = msg.extraData['status']?.toString() ?? 'pending';
      final roomTitle = msg.extraData['roomTitle']?.toString() ?? 'Căn hộ mini / Phòng trọ';
      final priceVal = msg.extraData['pricePerPerson'];
      final priceStr = priceVal != null
          ? '${NumberFormat('#,###', 'vi_VN').format(priceVal)} đ/tháng/người'
          : '1.800.000 đ/tháng/người';

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: inviteStatus == 'accepted'
                ? AppColors.primary
                : inviteStatus == 'rejected'
                    ? Colors.grey.shade400
                    : Colors.orange.shade300,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.handshake,
                  color: inviteStatus == 'accepted'
                      ? AppColors.primary
                      : inviteStatus == 'rejected'
                          ? Colors.grey
                          : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  inviteStatus == 'accepted'
                      ? 'ĐÃ ĐỒNG Ý Ở GHÉP'
                      : inviteStatus == 'rejected'
                          ? 'ĐÃ TỪ CHỐI Ở GHÉP'
                          : 'LỜI MỜI VÀO Ở GHÉP',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: inviteStatus == 'accepted'
                        ? AppColors.primary
                        : inviteStatus == 'rejected'
                            ? Colors.grey
                            : Colors.orange,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Text(
              roomTitle,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Chi phí: $priceStr', style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            if (inviteStatus == 'accepted')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 16),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Đã chấp nhận • Đã gửi thông báo đến chủ nhà',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            else if (inviteStatus == 'rejected')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cancel_rounded, color: Colors.grey.shade600, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Lời mời đã bị từ chối',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )
            else if (inviteStatus == 'revoked')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.remove_circle_outline, color: Colors.grey.shade600, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Lời mời đã được thu hồi',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )
            else if (!isMe)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        minimumSize: const Size.fromHeight(32),
                      ),
                      onPressed: () => _rejectRoommateInvite(msg),
                      child: const Text('Từ chối', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(32),
                      ),
                      onPressed: () => _acceptRoommateInvite(msg),
                      child: const Text('Chấp nhận', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              )
            else
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  minimumSize: const Size.fromHeight(32),
                ),
                onPressed: () => _revokeRoommateInvite(msg),
                child: const Text('Thu hồi lời mời', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
      );
    }

    // 3. Thẻ Vị trí bản đồ thu nhỏ (Tc_CHAT_38, 39)
    if (msg.messageType == 'location') {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_pin, color: Colors.red, size: 36),
                    Text('Bản đồ Google Maps', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(msg.text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.directions, size: 16),
              label: const Text('Mở Chỉ Đường', style: TextStyle(fontSize: 12)),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đang mở ứng dụng Bản đồ dẫn đường...')),
                );
              },
            ),
          ],
        ),
      );
    }

    // 4. Thẻ Tin nhắn Âm thanh Thoại (Tc_CHAT_36, 37)
    if (msg.messageType == 'audio') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: isMe ? Colors.white24 : AppColors.primaryContainer,
              child: Icon(
                Icons.play_arrow,
                color: isMe ? Colors.white : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '||| | |||| | |||',
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              msg.extraData['duration'] ?? '0:05',
              style: TextStyle(
                color: isMe ? Colors.white70 : AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    // 5. Thẻ Hình ảnh đính kèm (Tc_CHAT_30 -> 33)
    if (msg.messageType == 'image') {
      Widget buildImageWidget({BoxFit fit = BoxFit.cover}) {
        final url = msg.attachmentUrl.trim();

        // A. Ảnh dạng Base64 Data URI lưu trữ trực tiếp trên Firebase Firestore (cả 2 bên đều xem được)
        if (url.startsWith('data:image')) {
          try {
            final commaIdx = url.indexOf(',');
            final base64Data = commaIdx != -1 ? url.substring(commaIdx + 1) : url;
            final bytes = base64Decode(base64Data);
            return Image.memory(
              bytes,
              fit: fit,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40),
              ),
            );
          } catch (e) {
            debugPrint('[Chat] Lỗi giải mã Base64: $e');
          }
        }

        // B. Ảnh từ URL Online (Firebase Storage hoặc HTTP/HTTPS)
        if (url.startsWith('http://') || url.startsWith('https://')) {
          return Image.network(
            url,
            fit: fit,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40),
            ),
          );
        }

        // C. Fallback file cục bộ nếu có trên cùng thiết bị
        if (url.isNotEmpty && File(url).existsSync()) {
          return Image.file(
            File(url),
            fit: fit,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40),
            ),
          );
        }

        final localFallback = msg.extraData['localPath']?.toString() ?? '';
        if (localFallback.isNotEmpty && File(localFallback).existsSync()) {
          return Image.file(
            File(localFallback),
            fit: fit,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40),
            ),
          );
        }

        return const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 40),
        );
      }

      final imageBox = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            // Xem ảnh phóng to toàn màn hình (Tc_CHAT_33)
            showDialog(
              context: context,
              builder: (ctx) => Dialog(
                backgroundColor: Colors.black87,
                insetPadding: const EdgeInsets.all(12),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    InteractiveViewer(
                      clipBehavior: Clip.none,
                      maxScale: 4.0,
                      child: Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: buildImageWidget(fit: BoxFit.contain),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        radius: 18,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          child: Container(
            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 240),
            color: Colors.grey.shade100,
            child: buildImageWidget(fit: BoxFit.cover),
          ),
        ),
      );

      if (msg.isReply) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isMe ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildReplyQuote(msg.replyTo!, isMe),
              const SizedBox(height: 6),
              imageBox,
            ],
          ),
        );
      }

      return imageBox;
    }

    // 6. Bong bóng tin nhắn văn bản thông thường (Tc_CHAT_25 & SRS 2.10 link detect)
    final containsPhone = _phoneRegex.hasMatch(msg.text);
    final isUnread = !isMe && (!msg.isRead || msg.status != 'read');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMe ? 16 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 16),
        ),
        border: isUnread
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (msg.isReply) ...[
            _buildReplyQuote(msg.replyTo!, isMe),
            const SizedBox(height: 6),
          ],
          if (isUnread) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'TIN NHẮN CHƯA ĐỌC',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
          Text(
            msg.text,
            style: TextStyle(
              color: isMe ? Colors.white : AppColors.textDark,
              fontSize: 14,
              fontWeight: isUnread ? FontWeight.w800 : FontWeight.w400,
              height: 1.35,
            ),
          ),
          if (containsPhone) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: _showPhoneContactDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isMe ? Colors.white24 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone, size: 13, color: isMe ? Colors.white : Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      'Bấm để gọi nhanh',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white : Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
