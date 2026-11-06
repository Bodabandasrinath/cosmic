import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic/core/utils/validators.dart';
import 'package:cosmic/core/utils/date_formatter.dart';
import 'package:cosmic/models/user_model.dart';
import 'package:cosmic/models/message_model.dart';
import 'package:cosmic/models/call_model.dart';
import 'package:cosmic/models/chat_model.dart';
import 'package:cosmic/models/follow_request_model.dart';

void main() {
  group('Authentication & User Validation Tests', () {
    test('Username validator checks length and illegal characters', () {
      expect(Validators.validateUsername(''), 'Username is required');
      expect(Validators.validateUsername('ab'), 'Username must be at least 3 characters');
      expect(Validators.validateUsername('valid_user.123'), null);
      expect(Validators.validateUsername('invalid user!'), 'Only letters, numbers, underscores, and dots are allowed');
    });

    test('Email validator validates correct email format', () {
      expect(Validators.validateEmail(''), 'Email is required');
      expect(Validators.validateEmail('invalid-email'), 'Please enter a valid email address');
      expect(Validators.validateEmail('user@cosmic.chat'), null);
    });

    test('Password validator requires minimum 6 characters', () {
      expect(Validators.validatePassword(''), 'Password is required');
      expect(Validators.validatePassword('12345'), 'Password must be at least 6 characters');
      expect(Validators.validatePassword('secret123'), null);
    });

    test('UserModel serializes and deserializes properly', () {
      final now = DateTime.now();
      final user = UserModel(
        uid: 'user_123',
        username: 'stargazer',
        displayName: 'Star Gazer',
        email: 'star@cosmic.chat',
        phone: '+1234567890',
        bio: 'Exploring the cosmos',
        createdAt: now,
        isOnline: true,
      );

      final map = user.toMap();
      expect(map['uid'], 'user_123');
      expect(map['username'], 'stargazer');
      expect(map['displayName'], 'Star Gazer');
      expect(map['isOnline'], true);

      final reconstructed = UserModel.fromMap(map);
      expect(reconstructed.uid, user.uid);
      expect(reconstructed.username, user.username);
      expect(reconstructed.displayName, user.displayName);
      expect(reconstructed.isOnline, user.isOnline);
    });
  });

  group('Chat & Messaging Model Tests', () {
    test('MessageModel supports text, image, video, audio, call types', () {
      final now = DateTime.now();

      final textMsg = MessageModel(
        id: 'msg_1',
        senderId: 'user_a',
        receiverId: 'user_b',
        chatId: 'chat_ab',
        text: 'Hello from Cosmic!',
        type: MessageType.text,
        timestamp: now,
        isDelivered: true,
        isSeen: false,
      );

      expect(textMsg.type, MessageType.text);
      expect(textMsg.toMap()['type'], 'text');

      final callMsg = MessageModel(
        id: 'call_internal_123',
        senderId: 'user_a',
        receiverId: 'user_b',
        chatId: 'chat_ab',
        text: 'Outgoing video call (1m 15s)',
        type: MessageType.call,
        callType: 'video',
        callStatus: 'completed',
        startedAt: now,
        endedAt: now.add(const Duration(seconds: 75)),
        durationSeconds: 75,
        timestamp: now,
      );

      expect(callMsg.type, MessageType.call);
      expect(callMsg.callType, 'video');
      expect(callMsg.callStatus, 'completed');
      expect(callMsg.durationSeconds, 75);

      final callMap = callMsg.toMap();
      expect(callMap['type'], 'call');
      expect(callMap['callType'], 'video');
      expect(callMap['callStatus'], 'completed');
      expect(callMap['durationSeconds'], 75);

      final reconstructedCall = MessageModel.fromMap(callMap, documentId: 'call_internal_123');
      expect(reconstructedCall.type, MessageType.call);
      expect(reconstructedCall.callType, 'video');
      expect(reconstructedCall.callStatus, 'completed');
      expect(reconstructedCall.durationSeconds, 75);

      final imageMsg = MessageModel(
        id: 'msg_2',
        senderId: 'user_a',
        receiverId: 'user_b',
        chatId: 'chat_ab',
        text: '📷 Photo',
        type: MessageType.image,
        mediaUrl: 'https://storage.cosmic.chat/photo.jpg',
        timestamp: now,
      );

      expect(imageMsg.type, MessageType.image);
      expect(imageMsg.mediaUrl, 'https://storage.cosmic.chat/photo.jpg');

      final audioMsg = MessageModel(
        id: 'msg_3',
        senderId: 'user_a',
        receiverId: 'user_b',
        chatId: 'chat_ab',
        text: '🎤 Voice message',
        type: MessageType.audio,
        mediaUrl: 'https://storage.cosmic.chat/voice.m4a',
        durationSeconds: 15,
        timestamp: now,
      );

      expect(audioMsg.type, MessageType.audio);
      expect(audioMsg.durationSeconds, 15);
    });

    test('MessageModel accurately handles reactions and soft-delete states', () {
      final now = DateTime.now();
      final msg = MessageModel(
        id: 'msg_react',
        senderId: 'user_a',
        receiverId: 'user_b',
        chatId: 'chat_ab',
        text: 'Look at the moon tonight!',
        type: MessageType.text,
        timestamp: now,
        reactions: {'user_b': '❤️', 'user_c': '🔥'},
        isDeleted: false,
      );

      final map = msg.toMap();
      expect(map['reactions'], {'user_b': '❤️', 'user_c': '🔥'});
      expect(map['isDeleted'], false);

      final reconstructed = MessageModel.fromMap(map, documentId: 'msg_react');
      expect(reconstructed.reactions['user_b'], '❤️');
      expect(reconstructed.reactions['user_c'], '🔥');
      expect(reconstructed.isDeleted, false);

      final deletedMsg = reconstructed.copyWith(
        isDeleted: true,
        text: 'This message was deleted',
      );
      expect(deletedMsg.isDeleted, true);
      expect(deletedMsg.text, 'This message was deleted');
    });

    test('ChatModel accurately tracks unread counts and participants', () {
      final now = DateTime.now();
      final chat = ChatModel(
        id: 'chat_1_2',
        participants: ['user_1', 'user_2'],
        lastMessage: 'Hey there!',
        lastMessageTime: now,
        lastSenderId: 'user_1',
        unreadCounts: {'user_1': 0, 'user_2': 3},
      );

      expect(chat.participants.contains('user_1'), true);
      expect(chat.participants.contains('user_2'), true);
      expect(chat.unreadCounts['user_2'], 3);
      expect(chat.unreadCounts['user_1'], 0);
    });
  });

  group('Calling & WebRTC Signaling Model Tests', () {
    test('CallModel correctly handles states without any user-facing room IDs', () {
      final now = DateTime.now();
      final call = CallModel(
        callId: 'internal_session_98765', // Internal session identifier only
        callerId: 'user_a',
        receiverId: 'user_b',
        callerName: 'Alice',
        receiverName: 'Bob',
        type: CallType.voice,
        status: CallStatus.calling,
        createdAt: now,
      );

      // Verify call ID is purely internal
      expect(call.callId, 'internal_session_98765');
      expect(call.status, CallStatus.calling);

      // Verify Firebase signaling map serialization
      final callMap = call.toMap();
      expect(callMap['callId'], 'internal_session_98765');
      expect(callMap['chatId'], 'user_a_user_b');
      expect(callMap['callerId'], 'user_a');
      expect(callMap['receiverId'], 'user_b');
      expect(callMap['callType'], 'voice');
      expect(callMap['startedAt'], isNotNull);

      final reconstructedCall = CallModel.fromMap(callMap, documentId: 'internal_session_98765');
      expect(reconstructedCall.callId, 'internal_session_98765');
      expect(reconstructedCall.chatId, 'user_a_user_b');
      expect(reconstructedCall.type, CallType.voice);

      // State transition to accepted
      final acceptedCall = call.copyWith(
        status: CallStatus.accepted,
        acceptedAt: now.add(const Duration(seconds: 4)),
      );
      expect(acceptedCall.status, CallStatus.accepted);
      expect(acceptedCall.acceptedAt, isNotNull);

      // State transition to ended
      final endedCall = acceptedCall.copyWith(
        status: CallStatus.ended,
        endedAt: now.add(const Duration(seconds: 120)),
        durationSeconds: 116,
      );
      expect(endedCall.status, CallStatus.ended);
      expect(endedCall.durationSeconds, 116);
    });

    test('DateFormatter calculates duration strings accurately', () {
      expect(DateFormatter.formatCallDuration(0), '00:00');
      expect(DateFormatter.formatCallDuration(65), '01:05');
      expect(DateFormatter.formatCallDuration(360), '06:00');
      expect(DateFormatter.formatCallDuration(3665), '61:05');
    });
  });

  group('Follow & Mutual Friendship Model Tests', () {
    test('FollowRequestModel serializes, deserializes and supports transitions', () {
      final now = DateTime.now();
      final request = FollowRequestModel(
        id: 'userA_userB',
        senderId: 'userA',
        receiverId: 'userB',
        status: FollowRequestStatus.pending,
        senderUsername: 'alice',
        senderDisplayName: 'Alice Star',
        receiverUsername: 'bob',
        receiverDisplayName: 'Bob Cosmos',
        createdAt: now,
      );

      expect(request.status, FollowRequestStatus.pending);
      expect(request.id, 'userA_userB');

      final map = request.toMap();
      expect(map['status'], 'pending');
      expect(map['senderId'], 'userA');
      expect(map['receiverId'], 'userB');

      final reconstructed = FollowRequestModel.fromMap(map, documentId: 'userA_userB');
      expect(reconstructed.status, FollowRequestStatus.pending);
      expect(reconstructed.senderUsername, 'alice');

      // Transition to accepted
      final accepted = reconstructed.copyWith(
        status: FollowRequestStatus.accepted,
        updatedAt: now.add(const Duration(minutes: 5)),
      );
      expect(accepted.status, FollowRequestStatus.accepted);
      expect(accepted.updatedAt, isNotNull);

      // Transition to rejected
      final rejected = reconstructed.copyWith(
        status: FollowRequestStatus.rejected,
      );
      expect(rejected.status, FollowRequestStatus.rejected);
    });
  });
}
