import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_constants.dart';
import '../../core/services/app_preferences_service.dart';
import '../../core/services/local_chat_cache_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../data/models/conversation_model.dart';
import '../../data/models/message_model.dart';
import '../../data/models/profile_model.dart';
import '../home/home_controller.dart';

/// Controller for `/chat` — handles 1-on-1 & Group realtime messaging,
/// offline message queuing & auto-sync on reconnect, group admin permissions,
/// read receipts, live typing indicators, reply-to-message, in-chat message
/// search, starred messages, emoji picker, `.m4a` AAC voice recording,
/// uploading to Supabase Storage, and audio playback with speed control.
class ChatController extends GetxController {
  // ---------------------------------------------------------------------------
  // Arguments & Conversation Context
  // ---------------------------------------------------------------------------
  late final String conversationId;
  final Rxn<ConversationModel> conversation = Rxn<ConversationModel>();
  final Rxn<ProfileModel> otherUser = Rxn<ProfileModel>();

  // Group Chat Members & Admin Management State
  final RxList<ProfileModel> groupMembersList = <ProfileModel>[].obs;
  final RxList<ProfileModel> addableFriendsList = <ProfileModel>[].obs;
  final RxBool isLoadingGroupMembers = false.obs;

  // ---------------------------------------------------------------------------
  // Text, Reply, Emoji & Scroll Controllers
  // ---------------------------------------------------------------------------
  final TextEditingController messageInputController = TextEditingController();
  final TextEditingController chatSearchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final RxString typedText = ''.obs;
  final RxBool isSendingText = false.obs;
  final RxBool showEmojiBar = false.obs;
  final RxBool showAttachmentBar = false.obs;
  final RxBool showScrollToBottomBtn = false.obs;

  // Reply-to-message state
  final Rxn<MessageModel> replyingToMessage = Rxn<MessageModel>();

  // In-chat search & filter state
  final RxBool isSearchMode = false.obs;
  final RxString searchQuery = ''.obs;
  final RxBool showStarredOnly = false.obs;

  // Mention (@) suggestions state
  final RxBool showMentionOverlay = false.obs;
  final RxList<ProfileModel> mentionCandidates = <ProfileModel>[].obs;
  int _mentionStartIndex = -1;

  // ---------------------------------------------------------------------------
  // Realtime Messages Stream, Offline Outbox & Typing Broadcast
  // ---------------------------------------------------------------------------
  final RxList<MessageModel> messages = <MessageModel>[].obs;
  final RxBool isLoadingMessages = true.obs;
  final RxBool isOtherUserTyping = false.obs;

  StreamSubscription<List<Map<String, dynamic>>>? _messagesSubscription;
  RealtimeChannel? _otherUserProfileChannel;
  RealtimeChannel? _typingChannel;
  Timer? _otherTypingClearTimer;
  Timer? _offlineRetryTimer;
  DateTime? _lastTypingBroadcastAt;

  final Set<String> _markingAsReadIds = <String>{};

  // ---------------------------------------------------------------------------
  // Voice Note Recording (.m4a / AAC)
  // ---------------------------------------------------------------------------
  final AudioRecorder _audioRecorder = AudioRecorder();
  final RxBool isRecording = false.obs;
  final RxBool isUploadingAudio = false.obs;
  final RxBool isUpdatingGroupAvatar = false.obs;
  final RxInt recordingSeconds = 0.obs;
  Timer? _recordingTimer;
  String? _currentRecordingPath;

  // ---------------------------------------------------------------------------
  // Voice Note Playback (Single active AudioPlayer across all bubbles)
  // ---------------------------------------------------------------------------
  final AudioPlayer _audioPlayer = AudioPlayer();
  final RxString activeAudioMessageId = ''.obs;
  final RxBool isAudioPlaying = false.obs;
  final RxBool isAudioBuffering = false.obs;
  final Rx<Duration> audioPosition = Duration.zero.obs;
  final Rx<Duration> audioTotalDuration = Duration.zero.obs;
  final RxDouble playbackSpeed = 1.0.obs;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  String? get currentUserId => supabase.auth.currentUser?.id;

  bool get hasTypedText => typedText.value.trim().isNotEmpty;

  /// Group Chat Helpers
  bool get isGroupChat => conversation.value?.isGroup ?? false;

  GroupChatMeta? get groupMeta => conversation.value?.groupMeta;

  bool get isCurrentUserGroupAdmin =>
      isGroupChat && (groupMeta?.isAdmin(currentUserId ?? '') ?? false);

  bool get isCurrentUserGroupOwner =>
      isGroupChat && (groupMeta?.isOwner(currentUserId ?? '') ?? false);

  bool get canCurrentUserSendMessages =>
      !isGroupChat || (groupMeta?.canUserSend(currentUserId ?? '') ?? true);

  bool get canCurrentUserEditGroupInfo =>
      isGroupChat && (groupMeta?.canUserEditInfo(currentUserId ?? '') ?? false);

  /// `mm:ss` label for the active recording counter (`00:12`).
  String get recordingTimerLabel => formatSeconds(recordingSeconds.value);

  /// Common Arabic & global quick emojis for the composer bar.
  static const List<String> quickEmojis = <String>[
    '❤️',
    '😂',
    '👍',
    '🔥',
    '😍',
    '🙏',
    '👏',
    '🎉',
    '😊',
    '😎',
    '🤔',
    '😢',
    '💯',
    '🌹',
    '✨',
    '👋',
  ];

  /// Filtered messages based on in-chat search query or starred filter.
  List<MessageModel> get visibleMessages {
    final String q = searchQuery.value.trim().toLowerCase();
    final bool starredFilter = showStarredOnly.value;
    final Set<String> starredIds = Get.isRegistered<AppPreferencesService>()
        ? AppPreferencesService.to.starredMessageIds
        : const <String>{};

    if (q.isEmpty && !starredFilter) {
      return messages;
    }

    return messages.where((MessageModel m) {
      if (starredFilter && !starredIds.contains(m.id)) {
        return false;
      }
      if (q.isNotEmpty) {
        final String text = m.bodyText.toLowerCase();
        final String reply = (m.replySnippet ?? '').toLowerCase();
        if (!text.contains(q) && !reply.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void onInit() {
    super.onInit();
    _parseArguments();
    _restoreDraftIfAvailable();
    _initScrollListener();
    _initAudioPlayerListeners();
    _subscribeToMessages();
    _subscribeToOtherUserProfile();
    _subscribeToTypingChannel();
    if (isGroupChat) {
      loadGroupMembers();
    }
    _offlineRetryTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) {
        if (Get.isRegistered<LocalChatCacheService>() &&
            LocalChatCacheService.to
                .getPendingMessagesForConversation(conversationId)
                .isNotEmpty) {
          flushPendingMessagesForThisChat();
        }
      },
    );
  }

  @override
  void onClose() {
    _saveCurrentDraft();
    _messagesSubscription?.cancel();
    _otherTypingClearTimer?.cancel();
    _offlineRetryTimer?.cancel();

    if (_otherUserProfileChannel != null) {
      supabase.removeChannel(_otherUserProfileChannel!);
      _otherUserProfileChannel = null;
    }
    if (_typingChannel != null) {
      supabase.removeChannel(_typingChannel!);
      _typingChannel = null;
    }

    _recordingTimer?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playerStateSub?.cancel();

    _cleanupRecordingAndPlayers();

    messageInputController.dispose();
    chatSearchController.dispose();
    scrollController.dispose();
    super.onClose();
  }

  void _initScrollListener() {
    scrollController.addListener(() {
      if (!scrollController.hasClients) return;
      final bool shouldShow = scrollController.offset > 280;
      if (showScrollToBottomBtn.value != shouldShow) {
        showScrollToBottomBtn.value = shouldShow;
      }
    });
  }

  void _restoreDraftIfAvailable() {
    if (conversationId.isEmpty ||
        !Get.isRegistered<AppPreferencesService>()) {
      return;
    }
    final String draft = AppPreferencesService.to.getDraft(conversationId);
    if (draft.isNotEmpty) {
      messageInputController.text = draft;
      typedText.value = draft;
    }
  }

  void _saveCurrentDraft() {
    if (conversationId.isEmpty ||
        !Get.isRegistered<AppPreferencesService>()) {
      return;
    }
    AppPreferencesService.to.saveDraft(
      conversationId,
      messageInputController.text,
    );
  }

  Future<void> _cleanupRecordingAndPlayers() async {
    try {
      if (isRecording.value) {
        await _audioRecorder.stop();
      }
    } catch (_) {}
    try {
      await _audioRecorder.dispose();
    } catch (_) {}
    try {
      await _audioPlayer.stop();
      await _audioPlayer.dispose();
    } catch (_) {}
  }

  void _parseArguments() {
    final dynamic args = Get.arguments;
    if (args is Map<String, dynamic>) {
      conversationId = (args['conversationId'] as String?) ??
          (args['conversation'] as ConversationModel?)?.id ??
          '';
      if (args['conversation'] is ConversationModel) {
        conversation.value = args['conversation'] as ConversationModel;
      }
      if (args['otherUser'] is ProfileModel) {
        otherUser.value = args['otherUser'] as ProfileModel;
      }
      if (args['initialMessage'] is String) {
        final String initMsg = (args['initialMessage'] as String).trim();
        if (initMsg.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            messageInputController.text = initMsg;
            typedText.value = initMsg;
            sendTextMessage();
          });
        }
      }
    } else if (args is ConversationModel) {
      conversationId = args.id;
      conversation.value = args;
      otherUser.value = args.otherUser;
    } else {
      conversationId = '';
    }

    if (otherUser.value == null &&
        conversationId.isNotEmpty &&
        !isGroupChat) {
      _fetchConversationAndOtherUser();
    }
  }

  Future<void> _fetchConversationAndOtherUser() async {
    final String? uid = currentUserId;
    if (uid == null || conversationId.isEmpty) return;

    try {
      final Map<String, dynamic>? convRow = await supabase
          .from(SupabaseConstants.conversationsTable)
          .select()
          .eq('id', conversationId)
          .maybeSingle();

      if (convRow == null) return;

      final ConversationModel parsedConv =
          ConversationModel.fromJson(convRow, currentUserId: uid);
      conversation.value = parsedConv;

      if (parsedConv.isGroup) {
        await loadGroupMembers();
        return;
      }

      final String otherId = parsedConv.otherUserId(uid);
      Map<String, dynamic>? profRow;
      try {
        profRow = await supabase
            .from(SupabaseConstants.profilesTable)
            .select(SupabaseConstants.publicProfileColumns)
            .eq('id', otherId)
            .maybeSingle();
      } on PostgrestException {
        profRow = await supabase
            .from(SupabaseConstants.profilesTable)
            .select(SupabaseConstants.fallbackPublicProfileColumns)
            .eq('id', otherId)
            .maybeSingle();
      }

      if (profRow != null) {
        otherUser.value = ProfileModel.fromJson(profRow);
        _subscribeToOtherUserProfile();
      }
    } catch (_) {}
  }

  // ===========================================================================
  // 1) REALTIME MESSAGES STREAM, OFFLINE CACHE, TYPING BROADCAST & READ RECEIPTS
  // ===========================================================================
  void _mergeServerAndPendingMessages(List<MessageModel> serverOrCachedList) {
    final List<MessageModel> pendingForThisChat =
        Get.isRegistered<LocalChatCacheService>()
            ? LocalChatCacheService.to.getPendingMessagesForConversation(
                conversationId,
              )
            : <MessageModel>[];

    final Set<String> existingIds =
        serverOrCachedList.map((MessageModel m) => m.id).toSet();

    final List<MessageModel> merged = <MessageModel>[
      ...pendingForThisChat.where((MessageModel p) => !existingIds.contains(p.id)),
      ...serverOrCachedList,
    ]..sort(
        (MessageModel a, MessageModel b) => b.createdAt.compareTo(a.createdAt),
      );

    messages.assignAll(merged);
  }

  Future<void> _subscribeToMessages() async {
    if (conversationId.isEmpty) {
      isLoadingMessages.value = false;
      return;
    }

    isLoadingMessages.value = true;

    // 1) Immediately load locally cached messages + pending outbox messages
    if (Get.isRegistered<LocalChatCacheService>()) {
      final List<MessageModel> cached =
          await LocalChatCacheService.to.getCachedMessages(conversationId);
      _mergeServerAndPendingMessages(cached);
      if (messages.isNotEmpty) {
        isLoadingMessages.value = false;
      }
    }

    // 2) Subscribe to live Supabase Realtime stream and keep local cache synced
    _messagesSubscription = supabase
        .from(SupabaseConstants.messagesTable)
        .stream(primaryKey: <String>['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .listen(
          (List<Map<String, dynamic>> rows) {
            final List<MessageModel> serverList =
                rows.map(MessageModel.fromJson).toList()
                  ..sort(
                    // Newest first because ListView uses reverse: true
                    (MessageModel a, MessageModel b) =>
                        b.createdAt.compareTo(a.createdAt),
                  );

            _mergeServerAndPendingMessages(serverList);
            isLoadingMessages.value = false;

            if (Get.isRegistered<LocalChatCacheService>()) {
              LocalChatCacheService.to.saveMessages(conversationId, messages);
            }

            _markIncomingUnreadMessagesAsRead(serverList);
            flushPendingMessagesForThisChat();
          },
          onError: (_) {
            // Keep showing offline cached + pending messages on network error
            isLoadingMessages.value = false;
          },
        );
  }

  void _subscribeToTypingChannel() {
    if (conversationId.isEmpty) return;

    _typingChannel = supabase
        .channel('typing_conv_$conversationId')
        .onBroadcast(
          event: 'typing',
          callback: (Map<String, dynamic> payload) {
            final String? senderId = payload['user_id'] as String?;
            if (senderId == null || senderId == currentUserId) return;

            final bool typing = (payload['is_typing'] as bool?) ?? true;
            isOtherUserTyping.value = typing;
            _otherTypingClearTimer?.cancel();
            if (typing) {
              _otherTypingClearTimer = Timer(
                const Duration(seconds: 3),
                () => isOtherUserTyping.value = false,
              );
            }
          },
        )
        .subscribe();
  }

  void _broadcastTyping(bool typing) {
    final String? myId = currentUserId;
    if (myId == null || _typingChannel == null) return;

    final DateTime now = DateTime.now();
    if (typing &&
        _lastTypingBroadcastAt != null &&
        now.difference(_lastTypingBroadcastAt!).inMilliseconds < 1200) {
      return;
    }
    _lastTypingBroadcastAt = now;

    try {
      _typingChannel!.sendBroadcastMessage(
        event: 'typing',
        payload: <String, dynamic>{
          'user_id': myId,
          'is_typing': typing,
        },
      );
    } catch (_) {}
  }

  Future<void> _markIncomingUnreadMessagesAsRead(
    List<MessageModel> currentMessages,
  ) async {
    final String? myId = currentUserId;
    if (myId == null) return;

    final List<String> unreadIncomingIds = currentMessages
        .where(
          (MessageModel m) =>
              m.senderId != myId &&
              !m.isRead &&
              !m.isPending &&
              !_markingAsReadIds.contains(m.id),
        )
        .map((MessageModel m) => m.id)
        .toList();

    if (unreadIncomingIds.isEmpty) return;

    _markingAsReadIds.addAll(unreadIncomingIds);
    try {
      await supabase
          .from(SupabaseConstants.messagesTable)
          .update(<String, dynamic>{'is_read': true})
          .inFilter('id', unreadIncomingIds);
    } catch (_) {
      _markingAsReadIds.removeAll(unreadIncomingIds);
    }
  }

  void _subscribeToOtherUserProfile() {
    final String? otherId = otherUser.value?.id;
    if (otherId == null || otherId.isEmpty || isGroupChat) return;
    if (_otherUserProfileChannel != null) return;

    _otherUserProfileChannel = supabase
        .channel('chat_other_user_$otherId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConstants.profilesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: otherId,
          ),
          callback: (PostgresChangePayload payload) {
            final Map<String, dynamic> row = payload.newRecord;
            if (row.isNotEmpty && otherUser.value != null) {
              otherUser.value = otherUser.value!.copyWith(
                displayName: (row['display_name'] as String?) ??
                    otherUser.value!.displayName,
                username:
                    (row['username'] as String?) ?? otherUser.value!.username,
                avatarUrl: (row['avatar_url'] as String?) ??
                    otherUser.value!.avatarUrl,
                bio: (row['bio'] as String?) ?? otherUser.value!.bio,
                isOnline:
                    (row['is_online'] as bool?) ?? otherUser.value!.isOnline,
                isProfileDiscoverable:
                    (row['is_profile_discoverable'] as bool?) ??
                        otherUser.value!.isProfileDiscoverable,
                lastSeen: row['last_seen'] != null
                    ? DateTime.tryParse(row['last_seen'].toString())?.toLocal()
                    : otherUser.value!.lastSeen,
              );
            }
          },
        )
        .subscribe();
  }

  // ===========================================================================
  // 2) SEND TEXT MESSAGE, OFFLINE QUEUING & AUTO-RESEND
  // ===========================================================================
  void onTextChanged(String value) {
    typedText.value = value;
    _broadcastTyping(value.trim().isNotEmpty);
    _checkForMention(value);
  }

  void _checkForMention(String text) {
    final TextSelection selection = messageInputController.selection;
    final int cursorPos =
        selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    if (cursorPos == 0) {
      showMentionOverlay.value = false;
      _mentionStartIndex = -1;
      return;
    }

    final String textBeforeCursor = text.substring(0, cursorPos);
    final int lastAt = textBeforeCursor.lastIndexOf('@');
    if (lastAt == -1) {
      showMentionOverlay.value = false;
      _mentionStartIndex = -1;
      return;
    }

    // Ensure '@' is at start or preceded by whitespace
    if (lastAt > 0 &&
        !RegExp(r'\s').hasMatch(textBeforeCursor[lastAt - 1])) {
      showMentionOverlay.value = false;
      _mentionStartIndex = -1;
      return;
    }

    final String query = textBeforeCursor.substring(lastAt + 1).toLowerCase();
    if (query.contains(' ')) {
      showMentionOverlay.value = false;
      _mentionStartIndex = -1;
      return;
    }

    _mentionStartIndex = lastAt;
    _filterMentionCandidates(query);
  }

  void _filterMentionCandidates(String query) {
    final List<ProfileModel> sourceList = <ProfileModel>[];

    if (isGroupChat) {
      sourceList.addAll(groupMembersList);
    } else if (otherUser.value != null) {
      sourceList.add(otherUser.value!);
    }

    if (Get.isRegistered<HomeController>()) {
      final HomeController home = Get.find<HomeController>();
      for (final conv in home.conversations) {
        if (!conv.isGroup && conv.otherUser != null) {
          if (!sourceList.any((p) => p.id == conv.otherUser!.id)) {
            sourceList.add(conv.otherUser!);
          }
        }
      }
      for (final u in home.statusUsers) {
        if (!sourceList.any((p) => p.id == u.id)) {
          sourceList.add(u);
        }
      }
    }

    final String? myId = currentUserId;
    final List<ProfileModel> filtered = sourceList.where((ProfileModel p) {
      if (p.id == myId) return false;
      if (query.isEmpty) return true;
      return p.displayName.toLowerCase().contains(query) ||
          p.username.toLowerCase().contains(query);
    }).toList();

    mentionCandidates.assignAll(filtered);
    showMentionOverlay.value = filtered.isNotEmpty;
  }

  void insertMention(ProfileModel user) {
    final String text = messageInputController.text;
    final TextSelection selection = messageInputController.selection;
    final int cursorPos =
        selection.baseOffset >= 0 ? selection.baseOffset : text.length;

    int atIndex = _mentionStartIndex;
    if (atIndex == -1 || atIndex >= text.length) {
      atIndex = text.lastIndexOf('@', cursorPos > 0 ? cursorPos - 1 : 0);
    }
    if (atIndex == -1) atIndex = cursorPos;

    final String mentionText = '@${user.username} ';
    final String newText = text.replaceRange(atIndex, cursorPos, mentionText);

    messageInputController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: atIndex + mentionText.length),
    );
    typedText.value = newText;
    showMentionOverlay.value = false;
    _mentionStartIndex = -1;
  }

  void toggleEmojiBar() {
    if (!showEmojiBar.value) {
      showAttachmentBar.value = false;
    }
    showEmojiBar.value = !showEmojiBar.value;
  }

  void toggleAttachmentBar() {
    if (!showAttachmentBar.value) {
      showEmojiBar.value = false;
    }
    showAttachmentBar.value = !showAttachmentBar.value;
  }

  void insertEmoji(String emoji) {
    final String text = messageInputController.text;
    final TextSelection sel = messageInputController.selection;
    final int start = sel.start >= 0 ? sel.start : text.length;
    final int end = sel.end >= 0 ? sel.end : text.length;
    final String updated = text.replaceRange(start, end, emoji);
    messageInputController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    typedText.value = updated;
    _broadcastTyping(true);
  }

  void setReplyMessage(MessageModel message) {
    replyingToMessage.value = message;
  }

  void cancelReply() {
    replyingToMessage.value = null;
  }

  String _buildConversationLastMessageValue(String plainPreview) {
    if (isGroupChat && groupMeta != null) {
      return ConversationModel.encodeGroupLastMessage(
        meta: groupMeta!,
        visibleLastMessage: plainPreview,
      );
    }
    return plainPreview;
  }

  Future<void> sendTextMessage() async {
    final String rawContent = messageInputController.text.trim();
    final String? myId = currentUserId;
    if (rawContent.isEmpty ||
        myId == null ||
        conversationId.isEmpty ||
        !canCurrentUserSendMessages) {
      return;
    }

    final MessageModel? replyTarget = replyingToMessage.value;
    String finalContent = rawContent;

    if (replyTarget != null) {
      final bool replyIsMine = replyTarget.isMine(myId);
      final String senderLabel = replyIsMine
          ? 'أنت'
          : (otherUser.value?.displayName.trim().isNotEmpty == true
              ? otherUser.value!.displayName
              : 'مستخدم');
      finalContent = MessageModel.encodeWithReply(
        text: rawContent,
        replySender: senderLabel,
        replyText: replyTarget.preview,
      );
    }

    messageInputController.clear();
    typedText.value = '';
    replyingToMessage.value = null;
    showEmojiBar.value = false;
    showAttachmentBar.value = false;
    showMentionOverlay.value = false;
    _broadcastTyping(false);

    if (Get.isRegistered<AppPreferencesService>()) {
      AppPreferencesService.to.saveDraft(conversationId, '');
    }

    // Create optimistic message immediately with `isPending: true`
    final String tempId = 'pending_${DateTime.now().microsecondsSinceEpoch}';
    final MessageModel optimisticMsg = MessageModel(
      id: tempId,
      conversationId: conversationId,
      senderId: myId,
      messageType: MessageType.text,
      content: finalContent,
      mediaUrl: null,
      audioDuration: 0,
      isRead: false,
      createdAt: DateTime.now(),
      isPending: true,
    );

    messages.insert(0, optimisticMsg);
    if (Get.isRegistered<LocalChatCacheService>()) {
      await LocalChatCacheService.to.saveMessages(conversationId, messages);
    }
    scrollToBottom();

    try {
      // 1) Try inserting into Supabase `messages`
      final Map<String, dynamic> insertedRow = await supabase
          .from(SupabaseConstants.messagesTable)
          .insert(
            MessageModel.textPayload(
              conversationId: conversationId,
              senderId: myId,
              content: finalContent,
            ),
          )
          .select()
          .single();

      // Replace optimistic pending message with confirmed server message
      final MessageModel sentMessage = MessageModel.fromJson(insertedRow);
      final int idx = messages.indexWhere((MessageModel m) => m.id == tempId);
      if (idx >= 0) {
        if (messages.any((MessageModel m) => m.id == sentMessage.id)) {
          messages.removeAt(idx);
        } else {
          messages[idx] = sentMessage;
        }
      }

      if (Get.isRegistered<LocalChatCacheService>()) {
        await LocalChatCacheService.to.saveMessages(conversationId, messages);
      }

      // 2) Update `last_message` in `conversations` safely in separate block
      try {
        await supabase
            .from(SupabaseConstants.conversationsTable)
            .update(
              ConversationModel.lastMessagePayload(
                lastMessage: _buildConversationLastMessageValue(rawContent),
                lastMessageType: SupabaseConstants.messageTypeText,
                senderId: myId,
                groupMeta: groupMeta,
              ),
            )
            .eq('id', conversationId);
      } catch (_) {}
    } catch (e) {
      if (e is PostgrestException && e.code == '23503') {
        final bool isAr = Get.isRegistered<AppPreferencesService>()
            ? AppPreferencesService.to.isArabic
            : true;
        _showError(
          isAr
              ? 'المحادثة غير موجودة على الخادم'
              : 'Conversation does not exist on server',
        );
      } else {
        // Offline: Keep message in chat with pending clock icon
        // and enqueue in LocalChatCacheService so it sends automatically when online!
        if (Get.isRegistered<LocalChatCacheService>()) {
          await LocalChatCacheService.to.enqueueOfflineMessage(optimisticMsg);
          await LocalChatCacheService.to.saveMessages(conversationId, messages);
        }
      }
    }
  }

  /// Automatically sends any pending messages for this conversation when
  /// internet connectivity becomes available.
  Future<void> flushPendingMessagesForThisChat() async {
    if (!Get.isRegistered<LocalChatCacheService>()) return;
    final String? myId = currentUserId;
    if (myId == null || conversationId.isEmpty) return;

    final List<MessageModel> pendingList = LocalChatCacheService.to
        .getPendingMessagesForConversation(conversationId);
    if (pendingList.isEmpty) return;

    // Sort oldest first so they arrive in chronological order
    pendingList.sort(
      (MessageModel a, MessageModel b) => a.createdAt.compareTo(b.createdAt),
    );

    for (final MessageModel pending in pendingList) {
      try {
        if (pending.isText) {
          final Map<String, dynamic> inserted = await supabase
              .from(SupabaseConstants.messagesTable)
              .insert(
                MessageModel.textPayload(
                  conversationId: conversationId,
                  senderId: myId,
                  content: pending.content ?? '',
                ),
              )
              .select()
              .single();

          try {
            await supabase
                .from(SupabaseConstants.conversationsTable)
                .update(
                  ConversationModel.lastMessagePayload(
                    lastMessage: _buildConversationLastMessageValue(
                      pending.bodyText,
                    ),
                    lastMessageType: SupabaseConstants.messageTypeText,
                    senderId: myId,
                    groupMeta: groupMeta,
                  ),
                )
                .eq('id', conversationId);
          } catch (_) {}

          await LocalChatCacheService.to.removeOfflineMessage(pending.id);
          final MessageModel confirmed = MessageModel.fromJson(inserted);
          final int idx =
              messages.indexWhere((MessageModel m) => m.id == pending.id);
          if (idx >= 0) {
            if (messages.any((MessageModel m) => m.id == confirmed.id)) {
              messages.removeAt(idx);
            } else {
              messages[idx] = confirmed;
            }
          }
        } else if (pending.isAudio &&
            pending.localAudioPath != null &&
            pending.localAudioPath!.isNotEmpty) {
          final File audioFile = File(pending.localAudioPath!);
          if (await audioFile.exists()) {
            final int ts = DateTime.now().millisecondsSinceEpoch;
            final String storagePath =
                '$conversationId/$ts.${SupabaseConstants.voiceFileExtension}';

            await supabase.storage
                .from(SupabaseConstants.voiceNotesBucket)
                .upload(
                  storagePath,
                  audioFile,
                  fileOptions: const FileOptions(
                    contentType: SupabaseConstants.voiceContentType,
                    upsert: true,
                  ),
                );

            final String publicUrl = supabase.storage
                .from(SupabaseConstants.voiceNotesBucket)
                .getPublicUrl(storagePath);

            final Map<String, dynamic> inserted = await supabase
                .from(SupabaseConstants.messagesTable)
                .insert(
                  MessageModel.audioPayload(
                    conversationId: conversationId,
                    senderId: myId,
                    mediaUrl: publicUrl,
                    audioDuration: pending.audioDuration,
                  ),
                )
                .select()
                .single();

            try {
              await supabase
                  .from(SupabaseConstants.conversationsTable)
                  .update(
                    ConversationModel.lastMessagePayload(
                      lastMessage: _buildConversationLastMessageValue(
                        SupabaseConstants.voiceMessagePreview,
                      ),
                      lastMessageType: SupabaseConstants.messageTypeAudio,
                      senderId: myId,
                      groupMeta: groupMeta,
                    ),
                  )
                  .eq('id', conversationId);
            } catch (_) {}

            try {
              await audioFile.delete();
            } catch (_) {}

            await LocalChatCacheService.to.removeOfflineMessage(pending.id);
            final MessageModel confirmed = MessageModel.fromJson(inserted);
            final int idx =
                messages.indexWhere((MessageModel m) => m.id == pending.id);
            if (idx >= 0) {
              if (messages.any((MessageModel m) => m.id == confirmed.id)) {
                messages.removeAt(idx);
              } else {
                messages[idx] = confirmed;
              }
            }
          } else {
            await LocalChatCacheService.to.removeOfflineMessage(pending.id);
          }
        }
        await LocalChatCacheService.to.saveMessages(conversationId, messages);
      } catch (e) {
        if (e is PostgrestException && e.code == '23503') {
          await LocalChatCacheService.to.removeOfflineMessage(pending.id);
          continue;
        }
        // Still offline; stop and retry on next cycle
        break;
      }
    }
  }

  // ===========================================================================
  // 2.5) GROUP CHAT & ADMIN PERMISSIONS MANAGEMENT
  // ===========================================================================
  Future<void> loadGroupMembers() async {
    final GroupChatMeta? meta = groupMeta;
    if (meta == null) return;

    isLoadingGroupMembers.value = true;
    try {
      List<dynamic> allRows;
      try {
        allRows = await supabase
            .from(SupabaseConstants.profilesTable)
            .select(SupabaseConstants.publicProfileColumns)
            .limit(150);
      } on PostgrestException {
        allRows = await supabase
            .from(SupabaseConstants.profilesTable)
            .select(SupabaseConstants.fallbackPublicProfileColumns)
            .limit(150);
      }

      final List<ProfileModel> allProfiles = allRows
          .whereType<Map<String, dynamic>>()
          .map(ProfileModel.fromJson)
          .where((ProfileModel p) => p.isComplete)
          .toList();

      final Set<String> memberIdSet = meta.memberIds.toSet();
      groupMembersList.assignAll(
        allProfiles.where((ProfileModel p) => memberIdSet.contains(p.id)),
      );
      addableFriendsList.assignAll(
        allProfiles.where((ProfileModel p) => !memberIdSet.contains(p.id)),
      );
    } catch (_) {
      // Non-fatal offline
    } finally {
      isLoadingGroupMembers.value = false;
    }
  }

  Future<void> _persistUpdatedGroupMeta(GroupChatMeta updatedMeta) async {
    final ConversationModel? currentConv = conversation.value;
    if (currentConv == null) return;

    final ConversationModel updatedConv = currentConv.copyWith(
      groupMeta: updatedMeta,
      lastMessageAt: DateTime.now(),
    );
    conversation.value = updatedConv;

    if (Get.isRegistered<HomeController>()) {
      await Get.find<HomeController>().updateGroupConversationMeta(
        currentConv,
        updatedMeta,
      );
    }
  }

  Future<void> updateGroupPermissions({
    bool? onlyAdminsCanSend,
    bool? onlyAdminsCanEditInfo,
  }) async {
    if (!isCurrentUserGroupAdmin || groupMeta == null) return;

    final GroupChatMeta updated = groupMeta!.copyWith(
      onlyAdminsCanSend: onlyAdminsCanSend ?? groupMeta!.onlyAdminsCanSend,
      onlyAdminsCanEditInfo:
          onlyAdminsCanEditInfo ?? groupMeta!.onlyAdminsCanEditInfo,
    );
    await _persistUpdatedGroupMeta(updated);
    _showSuccess('تم تحديث صلاحيات المجموعة بنجاح 🛡️');
  }

  Future<void> updateGroupInfo({
    required String name,
    required String description,
  }) async {
    if (!canCurrentUserEditGroupInfo || groupMeta == null) return;
    final String cleanName = name.trim();
    if (cleanName.isEmpty) return;

    final GroupChatMeta updated = groupMeta!.copyWith(
      name: cleanName,
      description: description.trim(),
    );
    await _persistUpdatedGroupMeta(updated);
    _showSuccess('تم تحديث معلومات المجموعة ✨');
  }

  Future<void> toggleMemberAdminRole(String memberId) async {
    if (!isCurrentUserGroupAdmin || groupMeta == null) return;
    if (groupMeta!.isOwner(memberId)) return; // Owner always stays admin

    final Set<String> admins = groupMeta!.adminIds.toSet();
    final bool wasAdmin = admins.contains(memberId);
    if (wasAdmin) {
      admins.remove(memberId);
    } else {
      admins.add(memberId);
    }

    final GroupChatMeta updated = groupMeta!.copyWith(
      adminIds: admins.toList(),
    );
    await _persistUpdatedGroupMeta(updated);
    _showSuccess(
      wasAdmin ? 'تم إلغاء صلاحية المشرف عن العضو' : 'تمت ترقية العضو إلى مشرف ⭐',
    );
  }

  Future<void> removeMemberFromGroup(String memberId) async {
    if (!isCurrentUserGroupAdmin || groupMeta == null) return;
    if (groupMeta!.isOwner(memberId)) return;

    final List<String> updatedMembers = groupMeta!.memberIds
        .where((String id) => id != memberId)
        .toList();
    final List<String> updatedAdmins = groupMeta!.adminIds
        .where((String id) => id != memberId)
        .toList();

    final GroupChatMeta updated = groupMeta!.copyWith(
      memberIds: updatedMembers,
      adminIds: updatedAdmins,
    );
    await _persistUpdatedGroupMeta(updated);
    await loadGroupMembers();
    _showSuccess('تمت إزالة العضو من المجموعة');
  }

  Future<void> addMemberToGroup(ProfileModel user) async {
    if (!isCurrentUserGroupAdmin || groupMeta == null) return;

    final Set<String> members = groupMeta!.memberIds.toSet()..add(user.id);
    final GroupChatMeta updated = groupMeta!.copyWith(
      memberIds: members.toList(),
    );
    await _persistUpdatedGroupMeta(updated);
    await loadGroupMembers();
    _showSuccess('تمت إضافة ${user.displayName} إلى المجموعة 👥');
  }

  // ===========================================================================
  // 3) MESSAGE ACTIONS (COPY, STAR, DELETE, IN-CHAT SEARCH)
  // ===========================================================================
  void toggleSearchMode() {
    isSearchMode.value = !isSearchMode.value;
    if (!isSearchMode.value) {
      chatSearchController.clear();
      searchQuery.value = '';
    }
  }

  void onSearchQueryChanged(String value) {
    searchQuery.value = value;
  }

  void toggleStarredFilter() {
    showStarredOnly.value = !showStarredOnly.value;
  }

  bool isMessageStarred(String messageId) {
    if (!Get.isRegistered<AppPreferencesService>()) return false;
    return AppPreferencesService.to.isMessageStarred(messageId);
  }

  Future<void> toggleStarMessage(MessageModel message) async {
    if (!Get.isRegistered<AppPreferencesService>()) return;
    final bool starred =
        await AppPreferencesService.to.toggleStarMessage(message.id);
    messages.refresh();
    _showSuccess(
      starred ? 'تمت إضافة الرسالة إلى المفضلة ⭐' : 'تمت إزالة الرسالة من المفضلة',
    );
  }

  Future<void> copyMessageText(MessageModel message) async {
    if (!message.isText) return;
    await Clipboard.setData(ClipboardData(text: message.bodyText));
    _showSuccess('تم نسخ نص الرسالة إلى الحافظة');
  }

  Future<void> deleteMyMessage(MessageModel message) async {
    if (!message.isMine(currentUserId)) return;

    messages.removeWhere((MessageModel m) => m.id == message.id);
    if (Get.isRegistered<LocalChatCacheService>()) {
      await LocalChatCacheService.to.removeOfflineMessage(message.id);
      await LocalChatCacheService.to.saveMessages(conversationId, messages);
    }
    if (message.isPending) {
      _showSuccess('delete_msg_action'.tr);
      return;
    }
    try {
      await supabase
          .from(SupabaseConstants.messagesTable)
          .delete()
          .eq('id', message.id);
      _showSuccess('delete_msg_action'.tr);
    } catch (_) {
      _showError('تعذّر حذف الرسالة من الخادم');
    }
  }

  void showMessageActionsSheet(MessageModel message) {
    final bool isMine = message.isMine(currentUserId);
    final bool starred = isMessageStarred(message.id);

    Get.bottomSheet(
      GlassBottomSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: const Icon(
                Icons.reply_rounded,
                color: AppColors.aqua,
              ),
              title: Text('reply_action'.tr),
              onTap: () {
                Get.back<void>();
                setReplyMessage(message);
              },
            ),
            if (message.isText)
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(
                  Icons.copy_rounded,
                  color: AppColors.aqua,
                ),
                title: Text('copy_text_action'.tr),
                onTap: () {
                  Get.back<void>();
                  copyMessageText(message);
                },
              ),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: Icon(
                starred ? Icons.star_rounded : Icons.star_border_rounded,
                color: Colors.amber,
              ),
              title: Text(
                starred ? 'unstar_action'.tr : 'star_action'.tr,
              ),
              onTap: () {
                Get.back<void>();
                toggleStarMessage(message);
              },
            ),
            if (isMine)
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                title: Text(
                  'delete_msg_action'.tr,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () {
                  Get.back<void>();
                  deleteMyMessage(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 4) VOICE NOTE RECORDING, OFFLINE QUEUING & UPLOAD (.m4a / AudioEncoder.aacLc)
  // ===========================================================================
  Future<void> startRecording() async {
    if (isRecording.value ||
        isUploadingAudio.value ||
        !canCurrentUserSendMessages) {
      return;
    }

    try {
      // Stop any playing voice note before recording
      if (isAudioPlaying.value) {
        await _audioPlayer.pause();
      }

      final bool hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        _showError('يرجى السماح بصلاحية الميكروفون لتسجيل الرسائل الصوتية');
        return;
      }

      final Directory tempDir = await getTemporaryDirectory();
      final int timestamp = DateTime.now().millisecondsSinceEpoch;
      final String filePath =
          '${tempDir.path}/voice_${conversationId}_$timestamp.${SupabaseConstants.voiceFileExtension}';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      _currentRecordingPath = filePath;
      recordingSeconds.value = 0;
      isRecording.value = true;

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        recordingSeconds.value++;
      });
    } catch (_) {
      isRecording.value = false;
      _recordingTimer?.cancel();
      _showError('تعذّر بدء التسجيل الصوتي');
    }
  }

  Future<void> cancelRecording() async {
    if (!isRecording.value) return;

    _recordingTimer?.cancel();
    isRecording.value = false;
    recordingSeconds.value = 0;

    try {
      final String? path = await _audioRecorder.stop();
      final String? targetPath = path ?? _currentRecordingPath;
      _currentRecordingPath = null;

      if (targetPath != null) {
        final File file = File(targetPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {}
  }

  Future<void> stopAndSendRecording() async {
    if (!isRecording.value || isUploadingAudio.value) return;

    final String? myId = currentUserId;
    if (myId == null || conversationId.isEmpty) {
      await cancelRecording();
      return;
    }

    _recordingTimer?.cancel();
    final int recordedDuration =
        recordingSeconds.value < 1 ? 1 : recordingSeconds.value;
    isRecording.value = false;
    recordingSeconds.value = 0;

    File? localFile;
    String? path;
    try {
      final String? stoppedPath = await _audioRecorder.stop();
      path = stoppedPath ?? _currentRecordingPath;
      _currentRecordingPath = null;

      if (path == null || path.isEmpty) {
        return;
      }

      localFile = File(path);
      if (!await localFile.exists()) {
        return;
      }
    } catch (_) {
      return;
    }

    // Create optimistic pending audio message immediately
    final String tempId =
        'pending_audio_${DateTime.now().microsecondsSinceEpoch}';
    final MessageModel optimisticAudioMsg = MessageModel(
      id: tempId,
      conversationId: conversationId,
      senderId: myId,
      messageType: MessageType.audio,
      content: null,
      mediaUrl: path,
      audioDuration: recordedDuration,
      isRead: false,
      createdAt: DateTime.now(),
      isPending: true,
      localAudioPath: path,
    );

    messages.insert(0, optimisticAudioMsg);
    if (Get.isRegistered<LocalChatCacheService>()) {
      await LocalChatCacheService.to.saveMessages(conversationId, messages);
    }
    scrollToBottom();

    isUploadingAudio.value = true;
    try {
      final int timestamp = DateTime.now().millisecondsSinceEpoch;
      final String storagePath =
          '$conversationId/$timestamp.${SupabaseConstants.voiceFileExtension}';

      // 1) Upload `.m4a` to Supabase Storage bucket `voice-notes/{conversation_id}/{timestamp}.m4a`
      await supabase.storage.from(SupabaseConstants.voiceNotesBucket).upload(
            storagePath,
            localFile,
            fileOptions: const FileOptions(
              contentType: SupabaseConstants.voiceContentType,
              upsert: true,
            ),
          );

      // 2) Retrieve public URL
      final String publicUrl = supabase.storage
          .from(SupabaseConstants.voiceNotesBucket)
          .getPublicUrl(storagePath);

      // 3) Insert audio message into `messages`
      final Map<String, dynamic> insertedRow = await supabase
          .from(SupabaseConstants.messagesTable)
          .insert(
            MessageModel.audioPayload(
              conversationId: conversationId,
              senderId: myId,
              mediaUrl: publicUrl,
              audioDuration: recordedDuration,
            ),
          )
          .select()
          .single();

      final MessageModel confirmed = MessageModel.fromJson(insertedRow);
      final int idx = messages.indexWhere((MessageModel m) => m.id == tempId);
      if (idx >= 0) {
        if (messages.any((MessageModel m) => m.id == confirmed.id)) {
          messages.removeAt(idx);
        } else {
          messages[idx] = confirmed;
        }
      }

      if (Get.isRegistered<LocalChatCacheService>()) {
        await LocalChatCacheService.to.saveMessages(conversationId, messages);
      }

      // 4) Update `conversations.last_message` to "🎵 رسالة صوتية" safely in separate block
      try {
        await supabase
            .from(SupabaseConstants.conversationsTable)
            .update(
              ConversationModel.lastMessagePayload(
                lastMessage: _buildConversationLastMessageValue(
                  SupabaseConstants.voiceMessagePreview,
                ),
                lastMessageType: SupabaseConstants.messageTypeAudio,
                senderId: myId,
                groupMeta: groupMeta,
              ),
            )
            .eq('id', conversationId);
      } catch (_) {}

      try {
        if (await localFile.exists()) {
          await localFile.delete();
        }
      } catch (_) {}
    } catch (_) {
      // Offline: keep local audio file intact and queue in offline outbox!
      if (Get.isRegistered<LocalChatCacheService>()) {
        await LocalChatCacheService.to.enqueueOfflineMessage(
          optimisticAudioMsg,
        );
        await LocalChatCacheService.to.saveMessages(conversationId, messages);
      }
    } finally {
      isUploadingAudio.value = false;
    }
  }

  /// Updates group avatar image from camera or gallery
  Future<void> updateGroupAvatarFromPicker([
    ImageSource source = ImageSource.gallery,
  ]) async {
    if (!isCurrentUserGroupAdmin) return;
    isUpdatingGroupAvatar.value = true;
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (picked == null) return;
      final Uint8List bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;

      String? remoteUrl;
      try {
        final String path =
            'groups/${conversationId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage
            .from(SupabaseConstants.avatarsBucket)
            .uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        remoteUrl = supabase.storage
            .from(SupabaseConstants.avatarsBucket)
            .getPublicUrl(path);
      } catch (_) {}

      final String finalAvatarUrl =
          remoteUrl ?? 'data:image/jpeg;base64,${base64Encode(bytes)}';

      if (groupMeta != null) {
        final GroupChatMeta updated =
            groupMeta!.copyWith(avatarUrl: finalAvatarUrl);
        conversation.value = conversation.value?.copyWith(
          groupMeta: updated,
        );
        if (Get.isRegistered<HomeController>()) {
          await Get.find<HomeController>()
              .updateGroupConversationMeta(conversation.value!, updated);
        }
      }
    } catch (_) {
    } finally {
      isUpdatingGroupAvatar.value = false;
    }
  }

  /// Removes group avatar and restores default icon
  Future<void> removeGroupAvatar() async {
    if (!isCurrentUserGroupAdmin) return;
    isUpdatingGroupAvatar.value = true;
    try {
      if (groupMeta != null) {
        final GroupChatMeta updated = groupMeta!.copyWith(avatarUrl: '');
        conversation.value = conversation.value?.copyWith(
          groupMeta: updated,
        );
        if (Get.isRegistered<HomeController>()) {
          await Get.find<HomeController>()
              .updateGroupConversationMeta(conversation.value!, updated);
        }
      }
    } catch (_) {
    } finally {
      isUpdatingGroupAvatar.value = false;
    }
  }

  // ===========================================================================
  // 5) VOICE NOTE PLAYBACK & SPEED CONTROL (just_audio)
  // ===========================================================================
  void _initAudioPlayerListeners() {
    _positionSub = _audioPlayer.positionStream.listen((Duration pos) {
      audioPosition.value = pos;
    });

    _durationSub = _audioPlayer.durationStream.listen((Duration? dur) {
      if (dur != null && dur > Duration.zero) {
        audioTotalDuration.value = dur;
      }
    });

    _playerStateSub = _audioPlayer.playerStateStream.listen((PlayerState st) {
      isAudioPlaying.value = st.playing;
      isAudioBuffering.value = st.processingState == ProcessingState.loading ||
          st.processingState == ProcessingState.buffering;

      if (st.processingState == ProcessingState.completed) {
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.pause();
        isAudioPlaying.value = false;
        audioPosition.value = Duration.zero;
      }
    });
  }

  /// Cycles voice playback speed between 1.0x → 1.5x → 2.0x → 1.0x.
  Future<void> cyclePlaybackSpeed() async {
    final double current = playbackSpeed.value;
    final double next = current == 1.0
        ? 1.5
        : (current == 1.5 ? 2.0 : 1.0);
    playbackSpeed.value = next;
    try {
      await _audioPlayer.setSpeed(next);
    } catch (_) {}
  }

  /// Plays or pauses [message]. Supports both remote URLs and offline local audio files.
  Future<void> togglePlayVoiceMessage(MessageModel message) async {
    final String? localPath = message.localAudioPath;
    final String? url = message.mediaUrl;
    if ((url == null || url.trim().isEmpty) &&
        (localPath == null || localPath.trim().isEmpty)) {
      return;
    }

    try {
      // Same message is currently loaded
      if (activeAudioMessageId.value == message.id) {
        if (_audioPlayer.playing) {
          await _audioPlayer.pause();
        } else {
          await _audioPlayer.setSpeed(playbackSpeed.value);
          await _audioPlayer.play();
        }
        return;
      }

      // Switching to a different voice note: stop current and load new source
      await _audioPlayer.stop();
      activeAudioMessageId.value = message.id;
      audioPosition.value = Duration.zero;
      audioTotalDuration.value = Duration(seconds: message.audioDuration);
      isAudioBuffering.value = true;

      Duration? loadedDuration;
      if (localPath != null &&
          localPath.isNotEmpty &&
          await File(localPath).exists()) {
        loadedDuration = await _audioPlayer.setFilePath(localPath);
      } else if (url != null && !url.startsWith('http') && await File(url).exists()) {
        loadedDuration = await _audioPlayer.setFilePath(url);
      } else if (url != null && url.isNotEmpty) {
        loadedDuration = await _audioPlayer.setUrl(url);
      }

      if (loadedDuration != null && loadedDuration > Duration.zero) {
        audioTotalDuration.value = loadedDuration;
      }

      await _audioPlayer.setSpeed(playbackSpeed.value);
      await _audioPlayer.play();
    } catch (_) {
      isAudioBuffering.value = false;
      isAudioPlaying.value = false;
      _showError('تعذّر تشغيل الرسالة الصوتية');
    }
  }

  Future<void> seekVoiceMessage(String messageId, double seconds) async {
    if (activeAudioMessageId.value != messageId) return;
    final int targetMs = (seconds * 1000).round();
    try {
      await _audioPlayer.seek(Duration(milliseconds: targetMs));
    } catch (_) {}
  }

  // ===========================================================================
  // Helpers & Date Formatting
  // ===========================================================================
  void scrollToBottom() {
    if (!scrollController.hasClients) return;
    scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  String formatMessageTime(DateTime dateTime) {
    final String loc = Get.isRegistered<AppPreferencesService>()
        ? AppPreferencesService.to.languageCode.value
        : 'ar';
    return DateFormat('hh:mm a', loc).format(dateTime);
  }

  /// Checks if two dates fall on the same calendar day.
  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Formats a date header separator (`اليوم` / `أمس` / `yyyy/MM/dd`).
  String formatDateHeader(DateTime dateTime) {
    final String loc = Get.isRegistered<AppPreferencesService>()
        ? AppPreferencesService.to.languageCode.value
        : 'ar';
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target =
        DateTime(dateTime.year, dateTime.month, dateTime.day);
    final int diff = today.difference(target).inDays;

    if (diff == 0) return 'today'.tr;
    if (diff == 1) return 'yesterday'.tr;
    if (diff < 7) return DateFormat('EEEE', loc).format(dateTime);
    return DateFormat('yyyy/MM/dd', loc).format(dateTime);
  }

  static String formatSeconds(int totalSeconds) {
    final int safe = totalSeconds < 0 ? 0 : totalSeconds;
    final String minutes = (safe ~/ 60).toString().padLeft(2, '0');
    final String seconds = (safe % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showError(String message) {
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
    }
    Get.snackbar(
      'تنبيه',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.isDark
          ? AppColors.darkInputFill
          : AppColors.lightTextPrimary,
      colorText: Colors.white,
      icon: const Icon(Icons.error_outline_rounded, color: AppColors.error),
      margin: const EdgeInsets.all(16),
      borderRadius: 14,
      duration: const Duration(seconds: 3),
    );
  }

  void _showSuccess(String message) {
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
    }
    Get.snackbar(
      'تم',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.isDark
          ? AppColors.darkInputFill
          : AppColors.lightTextPrimary,
      colorText: Colors.white,
      icon: const Icon(Icons.check_circle_rounded, color: AppColors.online),
      margin: const EdgeInsets.all(16),
      borderRadius: 14,
      duration: const Duration(seconds: 2),
    );
  }

  // ---------------------------------------------------------------------------
  // Per-User / Per-Chat Custom Wallpaper (خلفية المحادثة المخصصة لهذا المستخدم)
  // ---------------------------------------------------------------------------
  Future<void> pickWallpaperFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 75,
      );
      if (picked == null) return;
      final Uint8List bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;

      if (Get.isRegistered<AppPreferencesService>()) {
        await AppPreferencesService.to.setConversationWallpaperImage(
          conversationId,
          bytes,
        );
      }
      _showSuccess(
        Get.isRegistered<AppPreferencesService>() &&
                AppPreferencesService.to.isArabic
            ? 'تم تعيين خلفية مخصصة لهذه المحادثة بنجاح 🖼️'
            : 'Custom chat wallpaper updated 🖼️',
      );
    } catch (_) {}
  }

  Future<void> setWallpaperPreset(String presetId) async {
    if (Get.isRegistered<AppPreferencesService>()) {
      await AppPreferencesService.to.setConversationWallpaperPreset(
        conversationId,
        presetId,
      );
    }
    _showSuccess(
      Get.isRegistered<AppPreferencesService>() &&
              AppPreferencesService.to.isArabic
          ? 'تم تغيير خلفية المحادثة لهذا المستخدم ✨'
          : 'Chat wallpaper updated ✨',
    );
  }

  Future<void> resetWallpaper() async {
    if (Get.isRegistered<AppPreferencesService>()) {
      await AppPreferencesService.to.clearConversationWallpaper(conversationId);
    }
    _showSuccess(
      Get.isRegistered<AppPreferencesService>() &&
              AppPreferencesService.to.isArabic
          ? 'تمت استعادة الخلفية الافتراضية للتطبيق'
          : 'Restored default wallpaper',
    );
  }
}
