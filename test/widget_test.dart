import 'dart:typed_data';

import 'package:at_me_chat/core/services/app_preferences_service.dart';
import 'package:at_me_chat/core/services/local_chat_cache_service.dart';
import 'package:at_me_chat/data/models/conversation_model.dart';
import 'package:at_me_chat/data/models/message_model.dart';
import 'package:at_me_chat/data/models/profile_model.dart';
import 'package:at_me_chat/modules/auth/widgets/otp_pin_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.reset();
  });

  group('ProfileModel', () {
    test('parses json and builds handle / initials / discoverability / written status', () {
      final ProfileModel p = ProfileModel.fromJson(<String, dynamic>{
        'id': 'u1',
        'username': 'hadi_99',
        'display_name': 'هادي أحمد',
        'bio': 'مهندس برمجيات',
        'status_text': 'الحمد لله دائماً وأبداً ✨',
        'status_color': '#2563EB',
        'is_online': true,
        'is_profile_discoverable': false,
        'last_seen': '2026-10-25T08:00:00Z',
      });

      expect(p.handle, '@hadi_99');
      expect(p.bio, 'مهندس برمجيات');
      expect(p.hasActiveStatus, isTrue);
      expect(p.statusText, 'الحمد لله دائماً وأبداً ✨');
      expect(p.statusColor, '#2563EB');
      expect(p.isOnline, isTrue);
      expect(p.isProfileDiscoverable, isFalse);
      expect(p.email, isNull);
      expect(p.initials, 'هأ');
    });
  });

  group('AppPreferencesService & LocalChatCacheService', () {
    test('saves/destroys user session, switches ar/en language, and caches chats offline', () async {
      final LocalChatCacheService cache =
          await Get.putAsync<LocalChatCacheService>(
            () => LocalChatCacheService().init(),
          );
      final AppPreferencesService prefs =
          await Get.putAsync<AppPreferencesService>(
            () => AppPreferencesService().init(),
          );

      expect(prefs.isLoggedIn.value, isFalse);
      expect(prefs.isDarkMode.value, isTrue);
      expect(prefs.languageCode.value, 'ar');
      expect(prefs.isArabic, isTrue);

      await prefs.setLanguage('en');
      expect(prefs.languageCode.value, 'en');
      expect(prefs.isArabic, isFalse);

      final ProfileModel user = ProfileModel(
        id: 'u1',
        email: 'hadi@example.com',
        username: 'hadi',
        displayName: 'هادي',
        isOnline: true,
        isProfileDiscoverable: false,
      );

      await prefs.saveUserSession(user);
      expect(prefs.isLoggedIn.value, isTrue);
      expect(prefs.cachedProfile.value?.username, 'hadi');
      expect(prefs.isProfileDiscoverable.value, isFalse);

      // Save conversations & messages to offline cache
      final ConversationModel conv = ConversationModel(
        id: 'c1',
        user1Id: 'u1',
        user2Id: 'u2',
        lastMessage: 'رسالة محفوظة محلياً',
        lastMessageType: 'text',
        lastMessageSenderId: 'u1',
        lastMessageAt: DateTime.utc(2026, 10, 25, 10, 0),
        otherUser: const ProfileModel(
          id: 'u2',
          username: 'friend_user',
          displayName: 'صديق',
          isOnline: false,
        ),
      );

      await cache.saveConversations(<ConversationModel>[conv]);
      final List<ConversationModel> loadedConvs =
          await cache.getCachedConversations();
      expect(loadedConvs.length, 1);
      expect(loadedConvs.first.id, 'c1');
      expect(loadedConvs.first.otherUser?.username, 'friend_user');

      final MessageModel msg = MessageModel(
        id: 'm100',
        conversationId: 'c1',
        senderId: 'u2',
        messageType: MessageType.text,
        content: 'هذه الرسالة تعمل بدون إنترنت',
        audioDuration: 0,
        isRead: true,
        createdAt: DateTime.utc(2026, 10, 25, 10, 5),
      );
      await cache.saveMessages('c1', <MessageModel>[msg]);
      final List<MessageModel> loadedMsgs = await cache.getCachedMessages('c1');
      expect(loadedMsgs.length, 1);
      expect(loadedMsgs.first.bodyText, 'هذه الرسالة تعمل بدون إنترنت');

      await prefs.setDarkMode(false);
      expect(prefs.isDarkMode.value, isFalse);
      await prefs.setDarkMode(true);
      expect(prefs.isDarkMode.value, isTrue);

      // Custom background wallpaper persistence & reset
      expect(prefs.hasCustomBackground, isFalse);
      final Uint8List fakeImageBytes = Uint8List.fromList(<int>[137, 80, 78, 71]);
      await prefs.setCustomBackgroundImage(fakeImageBytes);
      expect(prefs.hasCustomBackground, isTrue);
      expect(prefs.customBackgroundBytes.value, fakeImageBytes);
      await prefs.setBackgroundDim(0.60);
      expect(prefs.backgroundDim.value, 0.60);
      await prefs.clearCustomBackgroundImage();
      expect(prefs.hasCustomBackground, isFalse);

      await prefs.destroyUserSession();
      expect(prefs.isLoggedIn.value, isFalse);
      expect(prefs.cachedProfile.value, isNull);
      // Offline cache is wiped on sign out
      expect(await cache.getCachedConversations(), isEmpty);
      // Dark mode & language remain preserved
      expect(prefs.isDarkMode.value, isTrue);
      expect(prefs.languageCode.value, 'en');
    });
  });

  group('MessageModel', () {
    test('parses audio message', () {
      final MessageModel m = MessageModel.fromJson(<String, dynamic>{
        'id': 'm1',
        'conversation_id': 'c1',
        'sender_id': 'u1',
        'message_type': 'audio',
        'media_url': 'https://x/voice.m4a',
        'audio_duration': 12,
        'is_read': false,
        'created_at': '2026-10-25T08:00:00Z',
      });

      expect(m.isAudio, isTrue);
      expect(m.duration, const Duration(seconds: 12));
      expect(m.preview, '🎵 رسالة صوتية');
      expect(m.isMine('u1'), isTrue);
    });

    test('encodes and parses quoted reply messages', () {
      final String encoded = MessageModel.encodeWithReply(
        text: 'وعليكم السلام ورحمة الله',
        replySender: 'أحمد',
        replyText: 'السلام عليكم',
      );

      final MessageModel m = MessageModel.fromJson(<String, dynamic>{
        'id': 'm2',
        'conversation_id': 'c1',
        'sender_id': 'u1',
        'message_type': 'text',
        'content': encoded,
        'is_read': true,
        'created_at': '2026-10-25T08:01:00Z',
      });

      expect(m.hasReply, isTrue);
      expect(m.replySenderName, 'أحمد');
      expect(m.replySnippet, 'السلام عليكم');
      expect(m.bodyText, 'وعليكم السلام ورحمة الله');
    });
  });

  group('ConversationModel', () {
    test('resolves the other participant from embedded profiles', () {
      final ConversationModel c = ConversationModel.fromJson(
        <String, dynamic>{
          'id': 'c1',
          'user1_id': 'me',
          'user2_id': 'other',
          'last_message': 'مرحبا',
          'last_message_type': 'text',
          'last_message_sender_id': 'me',
          'last_message_at': '2026-10-25T08:00:00Z',
          'user1': <String, dynamic>{
            'id': 'me',
            'username': 'me',
            'display_name': 'Me',
          },
          'user2': <String, dynamic>{
            'id': 'other',
            'username': 'friend',
            'display_name': 'Friend',
          },
        },
        currentUserId: 'me',
      );

      expect(c.otherUserId('me'), 'other');
      expect(c.otherUser?.username, 'friend');
      expect(c.isLastMessageMine('me'), isTrue);
    });
  });

  group('OtpPinField & OtpView', () {
    testWidgets('renders 6 OTP cells inside Scaffold without Material error', (
      WidgetTester tester,
    ) async {
      final TextEditingController otpCtrl = TextEditingController();
      final FocusNode focusNode = FocusNode();
      String? completedCode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: OtpPinField(
                key: const Key('otp_pinput'),
                length: 6,
                controller: otpCtrl,
                focusNode: focusNode,
                onCompleted: (String code) => completedCode = code,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('otp_pinput')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(EditableText), '123456');
      await tester.pump();

      expect(completedCode, '123456');
      expect(find.text('1'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);

      otpCtrl.dispose();
      focusNode.dispose();
    });
  });

  group('Group Conversation & Payload', () {
    test('serializes groupInsertPayload correctly with members and avatar', () {
      final GroupChatMeta meta = GroupChatMeta(
        name: 'مجموعة المطورين',
        description: 'نقاشات تقنية',
        avatarUrl: 'https://example.com/avatar.jpg',
        ownerId: 'u1',
        adminIds: <String>['u1'],
        memberIds: <String>['u1', 'u2', 'u3'],
        onlyAdminsCanSend: true,
        onlyAdminsCanEditInfo: true,
        inviteCode: 'GRP-123456',
      );

      final Map<String, dynamic> payload = ConversationModel.groupInsertPayload(
        creatorId: 'u1',
        secondUserId: 'u2',
        meta: meta,
        visibleLastMessage: 'تم إنشاء المجموعة',
      );

      expect(payload['is_group'], isTrue);
      expect(payload['group_name'], 'مجموعة المطورين');
      expect(payload['group_description'], 'نقاشات تقنية');
      expect(payload['group_avatar_url'], 'https://example.com/avatar.jpg');
      expect(payload['group_owner_id'], 'u1');
      expect(payload['group_admins'], <String>['u1']);
      expect(payload['group_members'], <String>['u1', 'u2', 'u3']);
      expect(payload['only_admins_can_send'], isTrue);
      expect(payload['only_admins_can_edit'], isTrue);
      expect(payload['group_invite_code'], 'GRP-123456');
    });
  });

  group('StatusSegmentItem & Color/Image', () {
    test('parses multi-segment json status story', () {
      final String json = '''
      [
        {"id":"s1","text":"أهلاً بكم في حالتي الأولى","color":"#10B981","created_at":"${DateTime.now().toIso8601String()}"},
        {"id":"s2","text":"صورة جديدة","color":"#3B82F6","img":"https://example.com/status.jpg","created_at":"${DateTime.now().toIso8601String()}"}
      ]
      ''';

      final ProfileModel user = ProfileModel(
        id: 'u1',
        username: 'ali',
        displayName: 'علي',
        statusText: json,
      );

      expect(user.hasActiveStatus, isTrue);
      expect(user.statusSegments.length, 2);
      expect(user.statusSegments.first.text, 'أهلاً بكم في حالتي الأولى');
      expect(user.statusSegments.first.colorHex, '#10B981');
      expect(user.statusSegments.last.hasImage, isTrue);
      expect(user.statusSegments.last.imageBase64, 'https://example.com/status.jpg');
    });
  });

  group('Mentions Detection', () {
    test('matches mention regex for user tags in chat', () {
      final RegExp mentionRegex = RegExp(r'(@[a-zA-Z0-9_]{3,20})');
      const String text = 'مرحباً @hadi_99 و @ali_developer كيف حالكم اليوم؟';
      final List<String> matches = mentionRegex
          .allMatches(text)
          .map((Match m) => m.group(0)!)
          .toList();

      expect(matches, <String>['@hadi_99', '@ali_developer']);
    });
  });
}
