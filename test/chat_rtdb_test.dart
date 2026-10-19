import 'package:flutter_test/flutter_test.dart';
import 'package:home_share/core/services/chat_service.dart';
import 'package:home_share/data/models/chat_model.dart';

void main() {
  group('ChatService RTDB & Model Tests', () {
    test('getChatId generates consistent canonical ID regardless of user order', () {
      final id1 = ChatService.getChatId('user_alpha', 'user_beta');
      final id2 = ChatService.getChatId('user_beta', 'user_alpha');
      expect(id1, equals('user_alpha_user_beta'));
      expect(id2, equals(id1));

      final id3 = ChatService.getChatId('  user_xyz  ', 'user_abc');
      expect(id3, equals('user_abc_user_xyz'));
    });

    test('checkProfanity detects sensitive scam and prohibited keywords', () {
      expect(ChatService.checkProfanity('Xin chào bạn'), isFalse);
      expect(ChatService.checkProfanity('Cảnh báo đây là vụ lừa đảo đặt cọc'), isTrue);
      expect(ChatService.checkProfanity('Trang web danh bac trực tuyến'), isTrue);
      expect(ChatService.checkProfanity('chuyển tiền trước không xem phòng nhé'), isTrue);
    });

    test('ChatMessageModel serialization and deserialization with Realtime Database integer timestamp', () {
      final now = DateTime(2026, 10, 19, 10, 30);
      final model = ChatMessageModel(
        id: 'msg_001',
        conversationId: 'user_a_user_b',
        senderId: 'user_a',
        senderName: 'Nguyen Van A',
        receiverId: 'user_b',
        text: 'Phòng trọ này còn trống không bạn?',
        messageType: 'text',
        timestamp: now,
        status: 'sent',
        isRead: false,
        extraData: {
          'replyTo': {
            'messageId': 'msg_000',
            'text': 'Chào bạn',
          }
        },
      );

      final rtdbMap = model.toRealtimeMap();
      expect(rtdbMap['id'], equals('msg_001'));
      expect(rtdbMap['conversationId'], equals('user_a_user_b'));
      expect(rtdbMap['timestamp'], equals(now.millisecondsSinceEpoch));
      expect(rtdbMap['text'], equals('Phòng trọ này còn trống không bạn?'));

      // Deserialize lại từ map của RTDB
      final parsed = ChatMessageModel.fromMap(rtdbMap, 'msg_001');
      expect(parsed.id, equals('msg_001'));
      expect(parsed.senderId, equals('user_a'));
      expect(parsed.receiverId, equals('user_b'));
      expect(parsed.text, equals('Phòng trọ này còn trống không bạn?'));
      expect(parsed.timestamp.millisecondsSinceEpoch, equals(now.millisecondsSinceEpoch));
      expect(parsed.isReply, isTrue);
      expect(parsed.replyTo?['messageId'], equals('msg_000'));
    });

    test('ConversationModel parsing from Realtime Database map format', () {
      final nowMillis = DateTime.now().millisecondsSinceEpoch;
      final rawConvMap = <String, dynamic>{
        'chatId': 'user_a_user_b',
        'users': ['user_a', 'user_b'],
        'lastMessage': 'Dạ phòng còn trống nhé',
        'lastSenderId': 'user_b',
        'lastSenderName': 'Cô Lan Nhà Trọ',
        'lastTimestamp': nowMillis,
        'unreadFor_user_a': 2,
        'unreadFor_user_b': 0,
        'readBy': {
          'user_a': false,
          'user_b': true,
        },
        'userNames': {
          'user_a': 'Nguyen Van A',
          'user_b': 'Cô Lan Nhà Trọ',
        },
        'partnerNames': {
          'user_a': 'Cô Lan Nhà Trọ',
          'user_b': 'Nguyen Van A',
        },
        'roomCode': '#LT-104',
        'roomTitle': 'Phòng ban công thoáng mát ĐH Nông Lâm',
        'roomPrice': 2800000,
      };

      final convForA = ConversationModel.fromMap(rawConvMap, 'user_a_user_b', 'user_a');
      expect(convForA.id, equals('user_a_user_b'));
      expect(convForA.partnerId, equals('user_b'));
      expect(convForA.partnerName, equals('Cô Lan Nhà Trọ'));
      expect(convForA.lastMessage, equals('Dạ phòng còn trống nhé'));
      expect(convForA.unreadCount, equals(2));
      expect(convForA.isRead, isFalse);
      expect(convForA.roomCode, equals('#LT-104'));
      expect(convForA.roomPrice, equals(2800000.0));

      final convForB = ConversationModel.fromMap(rawConvMap, 'user_a_user_b', 'user_b');
      expect(convForB.partnerId, equals('user_a'));
      expect(convForB.partnerName, equals('Nguyen Van A'));
      expect(convForB.unreadCount, equals(0));
      expect(convForB.isRead, isTrue);
    });
  });
}
