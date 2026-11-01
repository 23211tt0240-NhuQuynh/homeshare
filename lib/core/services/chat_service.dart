import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/firestore_collections.dart';
import '../../data/models/chat_model.dart';
import '../../features/chat/services/roommate_invitation_eligibility_service.dart';

class ChatParams {
  final String userA;
  final String userB;

  const ChatParams({required this.userA, required this.userB});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatParams && userA == other.userA && userB == other.userB;

  @override
  int get hashCode => Object.hash(userA, userB);
}

/// Helper chuyển đổi đệ quy `Map<Object?, Object?>` từ Realtime Database sang `Map<String, dynamic>`
Map<String, dynamic> _deepCastMap(dynamic map) {
  if (map is! Map) return {};
  final result = <String, dynamic>{};
  map.forEach((key, value) {
    if (value is Map) {
      result[key.toString()] = _deepCastMap(value);
    } else if (value is List) {
      result[key.toString()] = value
          .map((e) => e is Map ? _deepCastMap(e) : e)
          .toList();
    } else {
      result[key.toString()] = value;
    }
  });
  return result;
}

class ChatService {
  static const String rtdbUrl =
      'https://homeshare-fe18e-default-rtdb.firebaseio.com';

  final FirebaseDatabase _rtdb;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ChatService({FirebaseDatabase? rtdb})
    : _rtdb =
          rtdb ??
          FirebaseDatabase.instanceFor(
            app: Firebase.app(),
            databaseURL: rtdbUrl,
          );

  // Danh sách từ khóa bị cấm lọc tự động theo Tc_CHAT_49
  static const List<String> _prohibitedKeywords = [
    'lừa đảo',
    'lua dao',
    'cờ bạc',
    'co bac',
    'đánh bạc',
    'danh bac',
    'nạp tiền ảo',
    'nap tien ao',
    'hack tiền',
    'hack tien',
    'chuyển tiền trước không xem phòng',
  ];

  /// Kiểm tra tin nhắn vi phạm tiêu chuẩn cộng đồng (Tc_CHAT_49)
  static bool checkProfanity(String text) {
    final lower = text.toLowerCase();
    for (final word in _prohibitedKeywords) {
      if (lower.contains(word)) {
        return true;
      }
    }
    return false;
  }

  // Tính chatId / cuocTroChuyenId duy nhất giữa 2 người dùng
  static String getChatId(String a, String b) {
    final cleanA = a.trim();
    final cleanB = b.trim();
    return cleanA.compareTo(cleanB) < 0
        ? '${cleanA}_$cleanB'
        : '${cleanB}_$cleanA';
  }

  /// Thiết lập hiện diện (Presence: Online / Offline / LastSeen) qua Realtime Database
  void setupPresence(String userId) {
    final cleanId = userId.trim();
    if (cleanId.isEmpty) return;

    try {
      final connectedRef = _rtdb.ref('.info/connected');
      final userPresenceRef = _rtdb.ref('presence/$cleanId');

      connectedRef.onValue.listen((event) {
        final connected = event.snapshot.value as bool? ?? false;
        if (connected) {
          userPresenceRef.onDisconnect().update({
            'isOnline': false,
            'lastSeen': ServerValue.timestamp,
          });
          userPresenceRef.update({
            'isOnline': true,
            'lastSeen': ServerValue.timestamp,
          });
        }
      });
    } catch (e) {
      debugPrint('Error setting up presence: $e');
    }
  }

  /// Stream trạng thái Online của đối phương trong Realtime Database
  Stream<bool> getPartnerPresenceStream(String partnerId) {
    final cleanId = partnerId.trim();
    if (cleanId.isEmpty) return Stream.value(false);

    return _rtdb.ref('presence/$cleanId/isOnline').onValue.map((event) {
      return event.snapshot.value as bool? ?? false;
    });
  }

  /// Cập nhật trạng thái đang soạn tin (Typing indicator)
  Future<void> setTypingStatus({
    required String senderId,
    required String receiverId,
    required bool isTyping,
  }) async {
    final chatId = getChatId(senderId, receiverId);
    final typingRef = _rtdb.ref('typing/$chatId/$senderId');

    try {
      if (isTyping) {
        typingRef.onDisconnect().set(false);
        await typingRef.set(true);
      } else {
        await typingRef.set(false);
      }
    } catch (e) {
      debugPrint('Error setting typing status: $e');
    }
  }

  /// Stream kiểm tra xem đối phương có đang soạn tin hay không
  Stream<bool> isPartnerTypingStream({
    required String currentUserId,
    required String partnerId,
  }) {
    final chatId = getChatId(currentUserId, partnerId);
    return _rtdb.ref('typing/$chatId/$partnerId').onValue.map((event) {
      return event.snapshot.value as bool? ?? false;
    });
  }

  /// Gửi tin nhắn mới lưu vào Realtime Database `messages/{chatId}/{messageId}`
  /// Tốc độ mili-giây, không bị giới hạn 1 write/s của Firestore Document
  Future<void> sendMessage(
    ChatMessageModel message, {
    String? receiverName,
    String? receiverAvatar,
    String? receiverPhone,
    Map<String, dynamic>? roomMetadata,
  }) async {
    // 1. Kiểm tra không gửi rỗng / toàn khoảng trắng (Tc_CHAT_24)
    if (message.text.trim().isEmpty && message.messageType == 'text') {
      throw ArgumentError('Nội dung tin nhắn không được để trống.');
    }

    // 2. Kiểm tra bộ lọc từ khóa cấm / lừa đảo (Tc_CHAT_49)
    if (checkProfanity(message.text)) {
      throw Exception(
        'Tin nhắn vi phạm tiêu chuẩn cộng đồng về an toàn thông tin.',
      );
    }

    // Không lưu lời mời nếu thiếu liên kết phòng hoặc định danh hai bên.
    if (message.messageType == 'roommate_invitation') {
      final roomId = '${message.extraData['roomId'] ?? ''}'.trim();
      final senderId = '${message.extraData['senderId'] ?? ''}'.trim();
      final receiverId = '${message.extraData['receiverId'] ?? ''}'.trim();
      if (roomId.isEmpty ||
          senderId != message.senderId ||
          receiverId != message.receiverId ||
          senderId == receiverId) {
        throw StateError(
          'Lời mời ở ghép không có dữ liệu phòng/người dùng hợp lệ.',
        );
      }
    }

    final chatId = getChatId(message.senderId, message.receiverId);
    final messagesRef = _rtdb.ref('messages/$chatId');
    final newMsgRef = message.id.isNotEmpty
        ? messagesRef.child(message.id)
        : messagesRef.push();
    final msgId =
        newMsgRef.key ?? DateTime.now().millisecondsSinceEpoch.toString();

    // 3. Chuẩn bị payload tin nhắn Realtime Database
    final msgData = message
        .copyWith(id: msgId, conversationId: chatId)
        .toRealtimeMap();
    msgData['timestamp'] = ServerValue.timestamp;

    // 4. Atomic multi-path updates cập nhật đồng thời message + conversation + reset typing
    final Map<String, dynamic> updates = {};
    updates['messages/$chatId/$msgId'] = msgData;

    updates['conversations/$chatId/chatId'] = chatId;
    updates['conversations/$chatId/cuocTroChuyenId'] = chatId;
    updates['conversations/$chatId/users'] = [
      message.senderId,
      message.receiverId,
    ];
    updates['conversations/$chatId/lastMessage'] = message.text;
    updates['conversations/$chatId/lastSenderName'] = message.senderName;
    updates['conversations/$chatId/lastSenderId'] = message.senderId;
    updates['conversations/$chatId/lastTimestamp'] = ServerValue.timestamp;
    updates['conversations/$chatId/isRead'] = false;
    updates['conversations/$chatId/unreadCount'] = ServerValue.increment(1);
    updates['conversations/$chatId/unreadFor_${message.receiverId}'] =
        ServerValue.increment(1);
    updates['conversations/$chatId/unreadFor_${message.senderId}'] = 0;
    updates['conversations/$chatId/readBy/${message.senderId}'] = true;
    updates['conversations/$chatId/readBy/${message.receiverId}'] = false;
    updates['conversations/$chatId/userNames/${message.senderId}'] =
        message.senderName;
    updates['conversations/$chatId/partnerNames/${message.receiverId}'] =
        message.senderName;

    if (receiverName != null && receiverName.trim().isNotEmpty) {
      updates['conversations/$chatId/userNames/${message.receiverId}'] =
          receiverName.trim();
      updates['conversations/$chatId/partnerNames/${message.senderId}'] =
          receiverName.trim();
    }
    if (receiverAvatar != null && receiverAvatar.isNotEmpty) {
      updates['conversations/$chatId/userAvatars/${message.receiverId}'] =
          receiverAvatar;
    }
    if (receiverPhone != null && receiverPhone.isNotEmpty) {
      updates['conversations/$chatId/userPhones/${message.receiverId}'] =
          receiverPhone;
    }

    if (roomMetadata != null) {
      roomMetadata.forEach((k, v) {
        updates['conversations/$chatId/$k'] = v;
      });
    }

    // Tắt trạng thái đang gõ phím của người gửi ngay sau khi tin nhắn được bắn đi
    updates['typing/$chatId/${message.senderId}'] = false;

    await _rtdb.ref().update(updates);

    // Ghi nhận thông báo vào Firestore để Cloud Function tự động gửi FCM đến người nhận
    try {
      final notifId = _firestore.collection('notifications').doc().id;
      await _firestore.collection('notifications').doc(notifId).set({
        'id': notifId,
        'notificationId': notifId,
        'recipientId': message.receiverId,
        'receiverId': message.receiverId,
        'senderId': message.senderId,
        'type': 'chat_message',
        'notificationType': 'chat_message',
        'targetId': chatId,
        'title': message.senderName.isNotEmpty
            ? message.senderName
            : 'Tin nhắn mới',
        'message': message.text.isNotEmpty
            ? message.text
            : '[Hình ảnh/Tệp tin]',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[ChatService] Lỗi tạo thông báo Firestore cho tin nhắn: $e');
    }
  }

  /// Đánh dấu đã đọc toàn bộ tin nhắn trong hội thoại
  Future<void> markAsRead(String currentUserId, String partnerId) async {
    final cleanA = currentUserId.trim();
    final cleanB = partnerId.trim();
    if (cleanA.isEmpty || cleanB.isEmpty) return;

    final chatId = getChatId(cleanA, cleanB);

    final Map<String, dynamic> updates = {};
    updates['conversations/$chatId/isRead'] = true;
    updates['conversations/$chatId/unreadCount'] = 0;
    updates['conversations/$chatId/unreadFor_$cleanA'] = 0;
    updates['conversations/$chatId/readBy/$cleanA'] = true;

    try {
      await _rtdb.ref().update(updates);
    } catch (e) {
      debugPrint('Error marking conversation as read in RTDB: $e');
    }

    // Cập nhật các tin nhắn nhận được gần đây thành 'read'
    try {
      final snapshot = await _rtdb
          .ref('messages/$chatId')
          .orderByChild('receiverId')
          .equalTo(cleanA)
          .limitToLast(30)
          .get();

      if (snapshot.exists && snapshot.value is Map) {
        final Map<String, dynamic> msgUpdates = {};
        final data = snapshot.value as Map;
        data.forEach((key, val) {
          if (val is Map &&
              (val['isRead'] == false || val['status'] != 'read')) {
            msgUpdates['messages/$chatId/$key/isRead'] = true;
            msgUpdates['messages/$chatId/$key/status'] = 'read';
          }
        });
        if (msgUpdates.isNotEmpty) {
          await _rtdb.ref().update(msgUpdates);
        }
      }
    } catch (e) {
      debugPrint('Error marking messages as read in RTDB: $e');
    }
  }

  /// Cập nhật dữ liệu phụ trợ của tin nhắn (lịch hẹn, phản hồi lời mời...)
  Future<void> updateMessageExtraData({
    required String senderId,
    required String receiverId,
    required String messageId,
    required Map<String, dynamic> extraData,
  }) async {
    final chatId = getChatId(senderId, receiverId);
    await _rtdb.ref('messages/$chatId/$messageId/extraData').update(extraData);
  }

  /// Thu hồi tin nhắn ở cả 2 phía (Xóa nội dung tin nhắn và chuyển sang trạng thái đã thu hồi)
  Future<void> revokeMessageForEveryone({
    required String senderId,
    required String receiverId,
    required String messageId,
  }) async {
    final chatId = getChatId(senderId, receiverId);
    final Map<String, dynamic> updates = {};

    updates['messages/$chatId/$messageId/text'] = 'Tin nhắn đã được thu hồi';
    updates['messages/$chatId/$messageId/attachmentUrl'] = '';
    updates['messages/$chatId/$messageId/messageType'] = 'revoked';
    updates['messages/$chatId/$messageId/status'] = 'revoked';
    updates['messages/$chatId/$messageId/isRevoked'] = true;
    updates['messages/$chatId/$messageId/revokedAt'] = ServerValue.timestamp;

    // Cập nhật tóm tắt cuộc trò chuyện nếu đây là tin nhắn cuối
    try {
      final convSnap = await _rtdb.ref('conversations/$chatId').get();
      if (convSnap.exists && convSnap.value is Map) {
        final convData = convSnap.value as Map;
        if (convData['lastSenderId'] == senderId) {
          updates['conversations/$chatId/lastMessage'] =
              'Tin nhắn đã được thu hồi';
        }
      }
    } catch (e) {
      debugPrint('Error checking lastSenderId on revoke: $e');
    }

    await _rtdb.ref().update(updates);
  }

  /// Xóa tin nhắn hoàn toàn khỏi Realtime Database ở cả 2 phía
  Future<void> deleteMessagePermanently({
    required String senderId,
    required String receiverId,
    required String messageId,
  }) async {
    final chatId = getChatId(senderId, receiverId);

    // 1. Xóa vĩnh viễn tin nhắn khỏi node messages
    await _rtdb.ref('messages/$chatId/$messageId').remove();

    // 2. Cập nhật lại thông tin lastMessage cho cuộc hội thoại
    try {
      final lastSnap = await _rtdb
          .ref('messages/$chatId')
          .orderByChild('timestamp')
          .limitToLast(1)
          .get();

      final Map<String, dynamic> updates = {};
      if (lastSnap.exists && lastSnap.value is Map) {
        final map = lastSnap.value as Map;
        final lastMsgKey = map.keys.first;
        final lastData = map[lastMsgKey] as Map;
        updates['conversations/$chatId/lastMessage'] = lastData['text'] ?? '';
        updates['conversations/$chatId/lastSenderId'] =
            lastData['senderId'] ?? '';
        updates['conversations/$chatId/lastTimestamp'] =
            lastData['timestamp'] ?? ServerValue.timestamp;
      } else {
        updates['conversations/$chatId/lastMessage'] = '';
        updates['conversations/$chatId/lastSenderId'] = '';
      }
      await _rtdb.ref().update(updates);
    } catch (e) {
      debugPrint('Error updating conversation on permanent delete in RTDB: $e');
    }
  }

  /// Stream tin nhắn Realtime tức thì qua Realtime Database WebSocket (không trễ)
  Stream<List<ChatMessageModel>> getMessagesStream(String userA, String userB) {
    final cleanA = userA.trim();
    final cleanB = userB.trim();
    if (cleanA.isEmpty || cleanB.isEmpty) {
      return Stream.value([]);
    }

    final chatId = getChatId(cleanA, cleanB);
    return _rtdb.ref('messages/$chatId').onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) {
        return <ChatMessageModel>[];
      }

      final List<ChatMessageModel> list = [];
      if (snapshot.value is Map) {
        final dataMap = snapshot.value as Map;
        dataMap.forEach((key, value) {
          if (value is Map) {
            try {
              final rawMap = _deepCastMap(value);
              list.add(ChatMessageModel.fromMap(rawMap, key.toString()));
            } catch (e) {
              debugPrint('Error parsing RTDB message $key: $e');
            }
          }
        });
      }

      // Sắp xếp tin nhắn giảm dần theo thời gian (tin nhắn mới nhất ở index 0 cho reverse ListView)
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }

  /// Gửi thông báo đến chủ nhà khi người được mời chấp nhận lời mời ở ghép (Firestore Notifications)
  Future<void> notifyHostRoommateAccepted({
    required String hostId,
    required String roomId,
    String roomCode = '',
    required String roomTitle,
    required String primaryTenantName,
    required String primaryTenantId,
    required String newRoommateName,
    required String newRoommateId,
    String userNotificationId = '',
  }) async {
    if (hostId.isEmpty) return;

    String resolvedCode = roomCode.trim();
    if (resolvedCode.isEmpty && roomId.isNotEmpty) {
      try {
        final roomSnap = await _firestore.collection('host_rooms').doc(roomId).get();
        if (roomSnap.exists) {
          resolvedCode = (roomSnap.data()?['roomCode'] ?? roomSnap.data()?['maPhong'] ?? '').toString().trim();
        }
      } catch (_) {}
    }
    if (resolvedCode.isEmpty) {
      resolvedCode = 'P001';
    }
    final notifRef = _firestore.collection('notifications').doc();
    await notifRef.set({
      'notificationId': notifRef.id,
      'id': notifRef.id,
      'receiverId': hostId,
      'nguoiNhanId': hostId,
      'recipientRole': 'host',
      'senderId': newRoommateId,
      'nguoiGuiId': newRoommateId,
      'notificationType': 'pendingAction',
      'legacyNotificationType': 'pendingAction',
      'type': 'pendingAction',
      'actionType': 'roommate_approval',
      'title': 'Yêu cầu duyệt người ở ghép mới',
      'tieuDe': 'Yêu cầu duyệt người ở ghép mới',
      'message':
          '$newRoommateName đã đồng ý ở ghép cùng $primaryTenantName tại phòng $roomTitle ($resolvedCode). Vui lòng xác nhận duyệt để khách chính thức vào phòng.',
      'noiDung':
          '$newRoommateName đã đồng ý ở ghép cùng $primaryTenantName tại phòng $roomTitle ($resolvedCode). Vui lòng xác nhận duyệt để khách chính thức vào phòng.',
      'roomId': roomId,
      'phongId': roomId,
      'roomTitle': roomTitle,
      'renterName': '$primaryTenantName & $newRoommateName',
      'primaryTenantName': primaryTenantName,
      'primaryTenantId': primaryTenantId,
      'newRoommateName': newRoommateName,
      'newRoommateId': newRoommateId,
      'userNotificationId': userNotificationId,
      'statusId': 'pending',
      'status': 'pending',
      'isRead': false,
      'daDoc': false,
      'createdAt': FieldValue.serverTimestamp(),
      'ngayTao': FieldValue.serverTimestamp(),
      'bookingCode': resolvedCode,
      'roomCode': resolvedCode,
    });
  }

  /// Gửi thông báo đến người được mời ở ghép (chuông thông báo của User)
  Future<String> notifyUserRoommateInvitation({
    required String receiverId,
    required String senderId,
    required String senderName,
    required String roomId,
    String roomCode = '',
    required String roomTitle,
    required double pricePerPerson,
    String hostId = '',
    String note = '',
    String messageId = '',
  }) async {
    final cleanReceiverId = receiverId.trim();
    final cleanSenderId = senderId.trim();
    final cleanRoomId = roomId.trim();
    final cleanRoomTitle = roomTitle.trim();
    if (cleanReceiverId.isEmpty ||
        cleanSenderId.isEmpty ||
        cleanRoomId.isEmpty ||
        cleanRoomTitle.isEmpty ||
        cleanReceiverId == cleanSenderId) {
      throw ArgumentError('Thông báo lời mời ở ghép thiếu dữ liệu bắt buộc.');
    }

    final resolvedCode = roomCode.trim().isNotEmpty
        ? roomCode.trim()
        : cleanRoomId;

    // Kiểm tra sức chứa phòng: Nếu phòng đã đủ người thì không ghi vào chuông thông báo (notifications)
    try {
      final eligibilityService =
          RoommateInvitationEligibilityService(firestore: _firestore);
      final capResult = await eligibilityService.checkRoomCapacity(
        cleanRoomId,
        senderId: cleanSenderId,
      );
      if (capResult.isFull) {
        debugPrint(
          '[ChatService] Phòng $cleanRoomId đã đạt sức chứa tối đa '
          '(${capResult.currentOccupants}/${capResult.capacity} người). '
          'Bỏ qua ghi nhận vào chuông thông báo theo quy định.',
        );
        return '';
      }
    } catch (e) {
      debugPrint(
        '[ChatService] Lỗi kiểm tra sức chứa phòng trước khi tạo thông báo: $e',
      );
    }

    final notifRef = _firestore.collection(FirestoreCollections.notificationUser).doc();
    final notifId = notifRef.id;
    final customMessage = note.trim().isNotEmpty
        ? note.trim()
        : '$senderName đã gửi lời mời bạn cùng ở ghép tại phòng $roomTitle.';

    final payload = {
      'notificationId': notifId,
      'id': notifId,
      'receiverId': cleanReceiverId,
      'recipientId': cleanReceiverId,
      'userId': cleanReceiverId,
      'nguoiNhanId': cleanReceiverId,
      'recipientRole': 'renter',
      'senderId': cleanSenderId,
      'senderName': senderName,
      'hostId': hostId,
      'notificationType': 'roommate_invitation',
      'type': 'roommate_invitation',
      'title': 'Lời mời ở ghép mới',
      'tieuDe': 'Lời mời ở ghép mới',
      'message': customMessage,
      'noiDung': customMessage,
      'note': note.trim(),
      'roomId': cleanRoomId,
      'roomCode': resolvedCode,
      'roomTitle': cleanRoomTitle,
      'pricePerPerson': pricePerPerson,
      'status': 'pending',
      'isRead': false,
      'daDoc': false,
      if (messageId.isNotEmpty) 'messageId': messageId,
      'createdAt': FieldValue.serverTimestamp(),
      'ngayTao': FieldValue.serverTimestamp(),
    };

    // Chỉ ghi vào duy nhất collection notification_user cho người dùng/người thuê
    await notifRef.set(payload);
    return notifId;
  }

  /// Đồng bộ trạng thái lời mời ở ghép từ Tin nhắn Chat sang Thông báo (Notifications)
  Future<String?> syncRoommateInviteFromChatToNotification({
    required String senderId,
    required String receiverId,
    required String roomId,
    required String newStatus,
    String messageId = '',
    String notificationId = '',
  }) async {
    try {
      final cleanSenderId = senderId.trim();
      final cleanReceiverId = receiverId.trim();
      final cleanRoomId = roomId.trim();
      String? matchedNotificationId;

      // Chỉ tìm và đồng bộ trong duy nhất collection notification_user
      final col = _firestore.collection(FirestoreCollections.notificationUser);

      // 1. Nếu có notificationId cụ thể, cập nhật trực tiếp
      if (notificationId.isNotEmpty) {
        try {
          final docSnap = await col.doc(notificationId).get();
          if (docSnap.exists) {
            await col.doc(notificationId).update({
              'status': newStatus,
              'isRead': true,
              'daDoc': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            return notificationId;
          }
        } catch (_) {}
      }

      // 2. Nếu có messageId, tìm theo messageId
      if (messageId.isNotEmpty) {
        try {
          final qMsg = await col
              .where('messageId', isEqualTo: messageId)
              .limit(5)
              .get();
          for (final doc in qMsg.docs) {
            await doc.reference.update({
              'status': newStatus,
              'isRead': true,
              'daDoc': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            matchedNotificationId ??= doc.id;
          }
        } catch (_) {}
      }

      if (matchedNotificationId != null) {
        return matchedNotificationId;
      }

      // 3. Quét các thông báo roommate_invitation giữa hai người dùng
      try {
        final q = await col
            .where('notificationType', isEqualTo: 'roommate_invitation')
            .where('senderId', isEqualTo: cleanSenderId)
            .get();

        for (final doc in q.docs) {
          final data = doc.data();
          final dReceiver =
              '${data['receiverId'] ?? data['recipientId'] ?? data['userId'] ?? ''}'
                  .trim();
          final dRoom = '${data['roomId'] ?? data['phongId'] ?? ''}'.trim();
          if (dReceiver == cleanReceiverId &&
              (cleanRoomId.isEmpty || dRoom == cleanRoomId)) {
            await doc.reference.update({
              'status': newStatus,
              'isRead': true,
              'daDoc': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            matchedNotificationId ??= doc.id;
          }
        }
      } catch (_) {}

      return matchedNotificationId;
    } catch (e) {
      debugPrint('[ChatService] Lỗi đồng bộ lời mời sang thông báo: $e');
      return null;
    }
  }

  /// Đồng bộ trạng thái lời mời ở ghép từ Thông báo sang Tin nhắn Chat (Realtime Database)
  Future<void> syncRoommateInviteFromNotificationToChat({
    required String senderId,
    required String receiverId,
    required String roomId,
    required String newStatus,
    String acceptedBy = '',
    String acceptedByName = '',
    String messageId = '',
  }) async {
    try {
      final cleanSenderId = senderId.trim();
      final cleanReceiverId = receiverId.trim();
      final cleanRoomId = roomId.trim();
      if (cleanSenderId.isEmpty || cleanReceiverId.isEmpty) return;

      final chatId = getChatId(cleanSenderId, cleanReceiverId);
      final messagesRef = _rtdb.ref('messages/$chatId');

      final updates = <String, dynamic>{
        'status': newStatus,
      };
      if (newStatus == 'accepted' || newStatus == 'waiting_host_approval') {
        updates['acceptedBy'] =
            acceptedBy.isNotEmpty ? acceptedBy : cleanReceiverId;
        if (acceptedByName.isNotEmpty) updates['acceptedByName'] = acceptedByName;
        updates['acceptedAt'] = DateTime.now().toIso8601String();
      } else if (newStatus == 'rejected') {
        updates['rejectedBy'] = cleanReceiverId;
        updates['rejectedAt'] = DateTime.now().toIso8601String();
      } else if (newStatus == 'revoked') {
        updates['revokedAt'] = DateTime.now().toIso8601String();
      }

      // 1. Cập nhật trực tiếp nếu có messageId
      if (messageId.isNotEmpty) {
        final msgSnap = await messagesRef.child(messageId).get();
        if (msgSnap.exists) {
          await messagesRef.child('$messageId/extraData').update(updates);
          return;
        }
      }

      // 2. Quét các tin nhắn roommate_invitation trong cuộc hội thoại
      final snap = await messagesRef
          .orderByChild('messageType')
          .equalTo('roommate_invitation')
          .get();

      if (snap.exists && snap.value is Map) {
        final map = snap.value as Map;
        for (final entry in map.entries) {
          final msgKey = entry.key.toString();
          final val = entry.value;
          if (val is Map) {
            final extra = val['extraData'];
            if (extra is Map) {
              final dRoom = '${extra['roomId'] ?? ''}'.trim();
              final currentStatus = '${extra['status'] ?? 'pending'}';
              if ((cleanRoomId.isEmpty || dRoom == cleanRoomId) &&
                  currentStatus != newStatus) {
                await messagesRef.child('$msgKey/extraData').update(updates);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ChatService] Lỗi đồng bộ lời mời sang tin nhắn chat: $e');
    }
  }

  /// Stream danh sách cuộc trò chuyện gần đây của người dùng từ Realtime Database
  Stream<List<ConversationModel>> getConversationsStream(String currentUserId) {
    final cleanUid = currentUserId.trim();
    if (cleanUid.isEmpty) {
      return Stream.value([]);
    }

    return _rtdb.ref('conversations').onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) {
        return <ConversationModel>[];
      }

      final List<ConversationModel> list = [];
      if (snapshot.value is Map) {
        final dataMap = snapshot.value as Map;
        dataMap.forEach((chatId, value) {
          if (value is Map) {
            final convMap = _deepCastMap(value);
            final users = List<String>.from(convMap['users'] ?? []);
            if (users.contains(cleanUid)) {
              try {
                list.add(
                  ConversationModel.fromMap(
                    convMap,
                    chatId.toString(),
                    cleanUid,
                  ),
                );
              } catch (e) {
                debugPrint('Error parsing RTDB conversation $chatId: $e');
              }
            }
          }
        });
      }

      list.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return list;
    });
  }
}

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

final messagesStreamProvider = StreamProvider.autoDispose
    .family<List<ChatMessageModel>, ChatParams>((ref, params) {
      final service = ref.watch(chatServiceProvider);
      return service.getMessagesStream(params.userA, params.userB);
    });

final userConversationsStreamProvider = StreamProvider.autoDispose
    .family<List<ConversationModel>, String>((ref, userId) {
      final service = ref.watch(chatServiceProvider);
      return service.getConversationsStream(userId);
    });

/// Stream trạng thái Online của đối tác chat
final partnerPresenceStreamProvider = StreamProvider.autoDispose
    .family<bool, String>((ref, partnerId) {
      final service = ref.watch(chatServiceProvider);
      return service.getPartnerPresenceStream(partnerId);
    });

/// Stream kiểm tra đối tác có đang gõ phím hay không
final partnerTypingStreamProvider = StreamProvider.autoDispose
    .family<bool, ChatParams>((ref, params) {
      final service = ref.watch(chatServiceProvider);
      return service.isPartnerTypingStream(
        currentUserId: params.userA,
        partnerId: params.userB,
      );
    });
