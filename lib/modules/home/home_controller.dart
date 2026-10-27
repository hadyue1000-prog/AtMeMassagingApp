import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_preferences_service.dart';
import '../../core/services/local_chat_cache_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../data/models/conversation_model.dart';
import '../../data/models/message_model.dart';
import '../../data/models/profile_model.dart';

/// Filter tabs on the home conversations screen.
enum ConversationFilter { all, unread, groups, online, pinned }

/// Controller for the main shell (`/home`) with 4 dedicated scalable tabs:
/// 0: Chats (`المحادثات`)
/// 1: Written Statuses (`الحالات المكتوبة`)
/// 2: My Profile (`حسابي`)
/// 3: Settings (`الإعدادات`)
class HomeController extends GetxController with WidgetsBindingObserver {
  // ---------------------------------------------------------------------------
  // Navigation & Core State
  // ---------------------------------------------------------------------------
  final RxInt selectedTabIndex = 0.obs;
  final Rxn<ProfileModel> myProfile = Rxn<ProfileModel>();
  final RxList<ConversationModel> conversations = <ConversationModel>[].obs;
  final RxList<ProfileModel> statusUsers = <ProfileModel>[].obs;

  final RxBool isLoading = true.obs;
  final RxBool isOfflineMode = false.obs;
  final RxBool isSyncingOutbox = false.obs;
  final RxBool isUpdatingDiscoverability = false.obs;
  final RxBool isSavingProfileEdit = false.obs;
  final RxBool isPublishingStatus = false.obs;
  final RxBool isCreatingGroup = false.obs;
  final RxString errorMessage = ''.obs;

  // ---------------------------------------------------------------------------
  // Tab 0: Chats Filter & Search
  // ---------------------------------------------------------------------------
  final TextEditingController homeSearchController = TextEditingController();
  final RxString homeSearchQuery = ''.obs;
  final Rx<ConversationFilter> activeFilter = ConversationFilter.all.obs;

  // ---------------------------------------------------------------------------
  // Tab 1: Written & Photo Statuses (الحالات كما في الواتس)
  // ---------------------------------------------------------------------------
  final TextEditingController statusInputController = TextEditingController();
  final RxString selectedStatusColor = '#123D91'.obs;
  final Rxn<Uint8List> selectedStatusImageBytes = Rxn<Uint8List>();

  static const List<String> statusColorPalette = <String>[
    '#123D91', // Royal Blue
    '#0EA5E9', // Calming Sky Cyan
    '#8B5CF6', // Soft Violet
    '#DB2777', // Soft Rose Pink
    '#EA580C', // Warm Amber Orange
    '#0D9488', // Deep Calming Teal
    '#0F172A', // Eye-friendly Slate Navy
  ];

  // ---------------------------------------------------------------------------
  // Tab 2: Dedicated Profile Editor Controllers
  // ---------------------------------------------------------------------------
  final TextEditingController profileDisplayNameController =
      TextEditingController();
  final TextEditingController profileBioController = TextEditingController();

  RealtimeChannel? _realtimeChannel;
  Timer? _refreshDebounce;
  Timer? _outboxSyncTimer;

  String? get currentUserId => supabase.auth.currentUser?.id;

  AppPreferencesService get prefs => AppPreferencesService.to;

  /// Total unread messages across all conversations.
  int get totalUnreadCount => conversations.fold<int>(
        0,
        (int sum, ConversationModel c) => sum + c.unreadCount,
      );

  /// Number of currently online contacts in the conversations list.
  int get onlineContactsCount => conversations
      .where(
        (ConversationModel c) =>
            (c.otherUser?.isProfileDiscoverable ?? true) &&
            (c.otherUser?.isOnline ?? false),
      )
      .length;

  /// Conversations filtered by `homeSearchQuery` and `activeFilter`, sorted
  /// with pinned conversations at the top followed by `lastMessageAt` DESC.
  List<ConversationModel> get filteredConversations {
    final String q = homeSearchQuery.value.trim().toLowerCase();
    final ConversationFilter filter = activeFilter.value;

    final List<ConversationModel> list = conversations.where((
      ConversationModel conv,
    ) {
      switch (filter) {
        case ConversationFilter.all:
          break;
        case ConversationFilter.unread:
          if (conv.unreadCount <= 0) return false;
        case ConversationFilter.groups:
          if (!conv.isGroup) return false;
        case ConversationFilter.online:
          if (conv.isGroup) return false;
          final bool online =
              (conv.otherUser?.isProfileDiscoverable ?? true) &&
              (conv.otherUser?.isOnline ?? false);
          if (!online) return false;
        case ConversationFilter.pinned:
          if (!conv.isPinned) return false;
      }

      if (q.isNotEmpty) {
        final String name = conv.title.toLowerCase();
        final String handle = (conv.otherUser?.username ?? '').toLowerCase();
        final String lastMsg = conv.previewText.toLowerCase();
        if (!name.contains(q) && !handle.contains(q) && !lastMsg.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    list.sort((ConversationModel a, ConversationModel b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.lastMessageAt.compareTo(a.lastMessageAt);
    });

    return list;
  }

  /// Active written statuses from friends / community.
  List<ProfileModel> get activeCommunityStatuses {
    final Map<String, ProfileModel> map = <String, ProfileModel>{};

    for (final ConversationModel c in conversations) {
      final ProfileModel? u = c.otherUser;
      if (u != null && u.isProfileDiscoverable && u.hasActiveStatus) {
        map[u.id] = u;
      }
    }
    for (final ProfileModel u in statusUsers) {
      if (u.id != currentUserId &&
          u.isProfileDiscoverable &&
          u.hasActiveStatus) {
        map[u.id] = u;
      }
    }

    final List<ProfileModel> result = map.values.toList()
      ..sort((ProfileModel a, ProfileModel b) {
        final DateTime ta = a.statusCreatedAt ?? a.lastSeen ?? DateTime(2000);
        final DateTime tb = b.statusCreatedAt ?? b.lastSeen ?? DateTime(2000);
        return tb.compareTo(ta);
      });
    return result;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);

    // 1) Instant load of cached user profile
    if (Get.isRegistered<AppPreferencesService>()) {
      final ProfileModel? cached = prefs.cachedProfile.value;
      if (cached != null &&
          (currentUserId == null || cached.id == currentUserId)) {
        _applyMyProfile(cached);
      }
    }

    // 2) Instant load of offline cached conversations + network sync
    _initializeHome();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshDebounce?.cancel();
    _outboxSyncTimer?.cancel();
    homeSearchController.dispose();
    statusInputController.dispose();
    profileDisplayNameController.dispose();
    profileBioController.dispose();
    _setOnlineStatus(false);
    if (_realtimeChannel != null) {
      supabase.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setOnlineStatus(true);
      flushOfflineOutbox();
      loadConversations(silent: true);
      loadCommunityStatuses();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _setOnlineStatus(false);
    }
  }

  void changeTab(int index) {
    selectedTabIndex.value = index;
    FocusManager.instance.primaryFocus?.unfocus();
    if (index == 1) {
      loadCommunityStatuses();
    } else if (index == 2 && myProfile.value != null) {
      _syncProfileControllers(myProfile.value!);
    }
  }

  void _applyMyProfile(ProfileModel profile) {
    myProfile.value = profile;
    _syncProfileControllers(profile);
    if (profile.statusColor.trim().isNotEmpty) {
      selectedStatusColor.value = profile.statusColor;
    }
  }

  void _syncProfileControllers(ProfileModel profile) {
    if (profileDisplayNameController.text != profile.displayName) {
      profileDisplayNameController.text = profile.displayName;
    }
    if (profileBioController.text != profile.bio) {
      profileBioController.text = profile.bio;
    }
  }

  void onHomeSearchChanged(String value) {
    homeSearchQuery.value = value;
  }

  void clearHomeSearch() {
    homeSearchController.clear();
    homeSearchQuery.value = '';
  }

  void setFilter(ConversationFilter filter) {
    activeFilter.value = filter;
  }

  Future<void> _initializeHome() async {
    // Load local offline cache immediately so chats appear with zero wait
    // and work even when completely offline.
    if (Get.isRegistered<LocalChatCacheService>()) {
      final List<ConversationModel> cachedConvs =
          await LocalChatCacheService.to.getCachedConversations();
      if (cachedConvs.isNotEmpty) {
        final bool hasPrefs = Get.isRegistered<AppPreferencesService>();
        final List<ConversationModel> hydrated = cachedConvs.map(
          (ConversationModel c) {
            return c.copyWith(
              isPinned: hasPrefs && prefs.isConversationPinned(c.id),
              isMuted: hasPrefs && prefs.isConversationMuted(c.id),
            );
          },
        ).toList();
        conversations.assignAll(hydrated);
        isLoading.value = false;
      }
    }

    await _setOnlineStatus(true);
    await Future.wait<void>(<Future<void>>[
      loadMyProfile(),
      loadConversations(silent: conversations.isNotEmpty),
      loadCommunityStatuses(),
    ]);
    _subscribeRealtime();
    flushOfflineOutbox();
    _outboxSyncTimer?.cancel();
    _outboxSyncTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) {
        if (Get.isRegistered<LocalChatCacheService>() &&
            LocalChatCacheService.to.pendingOutbox.isNotEmpty) {
          flushOfflineOutbox();
        }
      },
    );
  }

  /// Automatically sends any offline-queued text/voice messages as soon as
  /// internet connection is available.
  Future<void> flushOfflineOutbox() async {
    if (isSyncingOutbox.value) return;
    if (!Get.isRegistered<LocalChatCacheService>()) return;

    final LocalChatCacheService cache = LocalChatCacheService.to;
    if (cache.pendingOutbox.isEmpty) return;

    final String? myId = currentUserId;
    if (myId == null) return;

    isSyncingOutbox.value = true;
    try {
      final List<MessageModel> queue = List<MessageModel>.from(
        cache.pendingOutbox,
      );

      for (final MessageModel pending in queue) {
        try {
          if (pending.isAudio) {
            String? publicUrl = pending.mediaUrl;
            if ((publicUrl == null ||
                    publicUrl.isEmpty ||
                    !publicUrl.startsWith('http')) &&
                pending.localAudioPath != null &&
                pending.localAudioPath!.isNotEmpty) {
              final File localFile = File(pending.localAudioPath!);
              if (await localFile.exists()) {
                final int timestamp = DateTime.now().millisecondsSinceEpoch;
                final String storagePath =
                    '${pending.conversationId}/$timestamp.${SupabaseConstants.voiceFileExtension}';
                await supabase.storage
                    .from(SupabaseConstants.voiceNotesBucket)
                    .upload(
                      storagePath,
                      localFile,
                      fileOptions: const FileOptions(
                        contentType: SupabaseConstants.voiceContentType,
                        upsert: true,
                      ),
                    );
                publicUrl = supabase.storage
                    .from(SupabaseConstants.voiceNotesBucket)
                    .getPublicUrl(storagePath);
              }
            }
            if (publicUrl == null || publicUrl.isEmpty) {
              await cache.removeOfflineMessage(pending.id);
              continue;
            }
            await supabase.from(SupabaseConstants.messagesTable).insert(
                  MessageModel.audioPayload(
                    conversationId: pending.conversationId,
                    senderId: myId,
                    mediaUrl: publicUrl,
                    audioDuration: pending.audioDuration,
                  ),
                );
            final ConversationModel? conv = conversations.firstWhereOrNull(
              (ConversationModel c) => c.id == pending.conversationId,
            );
            await supabase
                .from(SupabaseConstants.conversationsTable)
                .update(
                  ConversationModel.lastMessagePayload(
                    lastMessage: SupabaseConstants.voiceMessagePreview,
                    lastMessageType: SupabaseConstants.messageTypeAudio,
                    senderId: myId,
                    groupMeta: conv?.groupMeta,
                  ),
                )
                .eq('id', pending.conversationId);
          } else {
            await supabase.from(SupabaseConstants.messagesTable).insert(
                  MessageModel.textPayload(
                    conversationId: pending.conversationId,
                    senderId: myId,
                    content: pending.content ?? '',
                  ),
                );
            final ConversationModel? conv = conversations.firstWhereOrNull(
              (ConversationModel c) => c.id == pending.conversationId,
            );
            await supabase
                .from(SupabaseConstants.conversationsTable)
                .update(
                  ConversationModel.lastMessagePayload(
                    lastMessage: pending.bodyText,
                    lastMessageType: SupabaseConstants.messageTypeText,
                    senderId: myId,
                    groupMeta: conv?.groupMeta,
                  ),
                )
                .eq('id', pending.conversationId);
          }

          // Successfully delivered to Supabase -> remove from outbox & local temp row
          await cache.removeOfflineMessage(pending.id);
          final List<MessageModel> cachedMsgs =
              await cache.getCachedMessages(pending.conversationId);
          cachedMsgs.removeWhere((MessageModel m) => m.id == pending.id);
          await cache.saveMessages(pending.conversationId, cachedMsgs);
          isOfflineMode.value = false;
        } catch (_) {
          // Still offline or temporary error -> keep in outbox for next retry
          break;
        }
      }
    } finally {
      isSyncingOutbox.value = false;
    }
  }

  // ===========================================================================
  // PROFILE & WRITTEN STATUSES
  // ===========================================================================
  Future<void> loadMyProfile() async {
    final String? uid = currentUserId;
    if (uid == null) return;

    try {
      final Map<String, dynamic>? data = await supabase
          .from(SupabaseConstants.profilesTable)
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (data != null) {
        final ProfileModel? previous = myProfile.value;
        ProfileModel parsed = ProfileModel.fromJson(data);
        if (!data.containsKey('is_profile_discoverable') &&
            Get.isRegistered<AppPreferencesService>()) {
          parsed = parsed.copyWith(
            isProfileDiscoverable: prefs.isProfileDiscoverable.value,
          );
        }
        if (!data.containsKey('bio') && previous != null) {
          parsed = parsed.copyWith(bio: previous.bio);
        }
        if (!data.containsKey('status_text') && previous != null) {
          parsed = parsed.copyWith(
            statusText: previous.statusText,
            statusColor: previous.statusColor,
            statusCreatedAt: previous.statusCreatedAt,
          );
        }
        _applyMyProfile(parsed);
        if (Get.isRegistered<AppPreferencesService>()) {
          await prefs.saveUserSession(parsed);
        }
      }
    } catch (_) {
      // Non-fatal: cached profile remains active.
    }
  }

  /// Loads public written statuses from discoverable users.
  Future<void> loadCommunityStatuses() async {
    final String? uid = currentUserId;
    if (uid == null) return;

    try {
      final List<dynamic> rows = await supabase
          .from(SupabaseConstants.profilesTable)
          .select(SupabaseConstants.publicProfileColumns)
          .neq('id', uid)
          .eq('is_profile_discoverable', true)
          .neq('status_text', '')
          .order('last_seen', ascending: false)
          .limit(30);

      final List<ProfileModel> parsed = rows
          .whereType<Map<String, dynamic>>()
          .map(ProfileModel.fromJson)
          .where((ProfileModel p) => p.hasActiveStatus)
          .toList();

      statusUsers.assignAll(parsed);
    } catch (_) {
      // If `status_text` column isn't migrated yet, statuses from cached
      // conversations still work seamlessly.
    }
  }

  /// Picks an optional photo from gallery for a WhatsApp-style photo status.
  Future<void> pickStatusImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 72,
      );
      if (picked == null) return;
      final Uint8List bytes = await picked.readAsBytes();
      if (bytes.isNotEmpty) {
        selectedStatusImageBytes.value = bytes;
      }
    } catch (_) {}
  }

  void clearSelectedStatusImage() {
    selectedStatusImageBytes.value = null;
  }

  /// Publishes a new 24h status segment (text and/or image), appending it to
  /// the user's active status story list just like WhatsApp.
  Future<void> publishWrittenStatus({
    required String text,
    required String colorHex,
  }) async {
    if (isPublishingStatus.value) return;
    final String cleanText = text.trim();
    final Uint8List? imgBytes = selectedStatusImageBytes.value;
    if (cleanText.isEmpty && (imgBytes == null || imgBytes.isEmpty)) return;

    final String? uid = currentUserId;
    final DateTime now = DateTime.now();
    isPublishingStatus.value = true;

    try {
      final List<StatusSegmentItem> currentSegments =
          List<StatusSegmentItem>.from(
        myProfile.value?.statusSegments ?? const <StatusSegmentItem>[],
      );

      final StatusSegmentItem newSegment = StatusSegmentItem(
        id: 'st_${now.millisecondsSinceEpoch}',
        text: cleanText,
        colorHex: colorHex,
        createdAt: now,
        imageBase64: (imgBytes != null && imgBytes.isNotEmpty)
            ? base64Encode(imgBytes)
            : null,
      );

      currentSegments.add(newSegment);
      // Keep up to 12 recent 24h segments
      final List<StatusSegmentItem> capped = currentSegments.length > 12
          ? currentSegments.sublist(currentSegments.length - 12)
          : currentSegments;

      final String serializedSegments = jsonEncode(
        capped.map((StatusSegmentItem s) => s.toJson()).toList(),
      );

      if (uid != null) {
        try {
          await supabase.from(SupabaseConstants.profilesTable).update(
            <String, dynamic>{
              'status_text': serializedSegments,
              'status_color': colorHex,
              'status_created_at': now.toUtc().toIso8601String(),
            },
          ).eq('id', uid);
        } on PostgrestException {
          // Fallback if status columns aren't created on remote DB yet
        }
      }

      if (myProfile.value != null) {
        final ProfileModel updated = myProfile.value!.copyWith(
          statusText: serializedSegments,
          statusColor: colorHex,
          statusCreatedAt: now,
        );
        _applyMyProfile(updated);
        if (Get.isRegistered<AppPreferencesService>()) {
          await prefs.saveUserSession(updated);
        }
      }

      statusInputController.clear();
      selectedStatusImageBytes.value = null;
      _showSnack(
        title: 'statuses_title'.tr,
        message: 'status_published'.tr,
        isError: false,
      );
    } finally {
      isPublishingStatus.value = false;
    }
  }

  /// Deletes a single status segment from the user's 24h story.
  Future<void> deleteStatusSegment(String segmentId) async {
    final ProfileModel? me = myProfile.value;
    if (me == null) return;

    final List<StatusSegmentItem> remaining = me.statusSegments
        .where((StatusSegmentItem s) => s.id != segmentId)
        .toList();

    if (remaining.isEmpty) {
      await clearMyWrittenStatus();
      return;
    }

    final String serialized = jsonEncode(
      remaining.map((StatusSegmentItem s) => s.toJson()).toList(),
    );
    final String latestColor = remaining.last.colorHex;
    final String? uid = currentUserId;

    if (uid != null) {
      try {
        await supabase.from(SupabaseConstants.profilesTable).update(
          <String, dynamic>{
            'status_text': serialized,
            'status_color': latestColor,
          },
        ).eq('id', uid);
      } catch (_) {}
    }

    final ProfileModel updated = me.copyWith(
      statusText: serialized,
      statusColor: latestColor,
    );
    _applyMyProfile(updated);
    if (Get.isRegistered<AppPreferencesService>()) {
      await prefs.saveUserSession(updated);
    }
  }

  /// Clears the user's current written status.
  Future<void> clearMyWrittenStatus() async {
    final String? uid = currentUserId;
    if (uid != null) {
      try {
        await supabase.from(SupabaseConstants.profilesTable).update(
          <String, dynamic>{
            'status_text': '',
          },
        ).eq('id', uid);
      } catch (_) {}
    }

    if (myProfile.value != null) {
      final ProfileModel updated = myProfile.value!.copyWith(statusText: '');
      _applyMyProfile(updated);
      if (Get.isRegistered<AppPreferencesService>()) {
        await prefs.saveUserSession(updated);
      }
    }

    _showSnack(
      title: 'statuses_title'.tr,
      message: 'status_cleared'.tr,
      isError: false,
    );
  }

  /// Saves edits made in the dedicated Profile Tab (`displayName` and `bio`).
  Future<void> saveProfileFromTab() async {
    await updateMyProfileDetails(
      displayName: profileDisplayNameController.text,
      bio: profileBioController.text,
    );
  }

  /// Updates the current user's display name and bio.
  Future<void> updateMyProfileDetails({
    required String displayName,
    required String bio,
  }) async {
    if (isSavingProfileEdit.value) return;

    final String cleanName = displayName.trim();
    final String cleanBio = bio.trim();

    if (cleanName.isEmpty) {
      _showSnack(
        title: 'display_name_label'.tr,
        message: prefs.isArabic
            ? 'الاسم الظاهر لا يمكن أن يكون فارغاً'
            : 'Display name cannot be empty',
        isError: true,
      );
      return;
    }

    final String? uid = currentUserId;
    isSavingProfileEdit.value = true;

    try {
      if (uid != null) {
        try {
          await supabase.from(SupabaseConstants.profilesTable).update(
            <String, dynamic>{
              'display_name': cleanName,
              'bio': cleanBio,
            },
          ).eq('id', uid);
        } on PostgrestException {
          await supabase.from(SupabaseConstants.profilesTable).update(
            <String, dynamic>{
              'display_name': cleanName,
            },
          ).eq('id', uid);
        }
      }

      if (myProfile.value != null) {
        final ProfileModel updated = myProfile.value!.copyWith(
          displayName: cleanName,
          bio: cleanBio,
        );
        _applyMyProfile(updated);
        if (Get.isRegistered<AppPreferencesService>()) {
          await prefs.saveUserSession(updated);
        }
      }

      FocusManager.instance.primaryFocus?.unfocus();
      _showSnack(
        title: 'save_changes'.tr,
        message: prefs.isArabic
            ? 'تم تحديث بيانات ملفك الشخصي بنجاح'
            : 'Your profile has been updated',
        isError: false,
      );
    } catch (_) {
      _showSnack(
        title: 'retry'.tr,
        message: prefs.isArabic
            ? 'تحقّق من اتصالك بالإنترنت وحاول مرة أخرى'
            : 'Check your internet connection and try again',
        isError: true,
      );
    } finally {
      isSavingProfileEdit.value = false;
    }
  }

  /// Copies `@username` to clipboard.
  Future<void> copyMyUsername() async {
    final ProfileModel? me = myProfile.value;
    if (me == null) return;
    await Clipboard.setData(ClipboardData(text: me.handle));
    _showSnack(
      title: 'copy_username'.tr,
      message: '${'username_copied'.tr}: ${me.handle}',
      isError: false,
    );
  }

  /// Copies the user's private 8-char invite code (works even in hidden mode).
  Future<void> copyMyPrivateCode() async {
    final ProfileModel? me = myProfile.value;
    if (me == null) return;
    await Clipboard.setData(ClipboardData(text: me.privateInviteCode));
    _showSnack(
      title: 'private_code_copied'.tr,
      message: me.privateInviteCode,
      isError: false,
    );
  }

  /// Copies the user's private invite link (works even in hidden mode).
  Future<void> copyMyPrivateLink() async {
    final ProfileModel? me = myProfile.value;
    if (me == null) return;
    await Clipboard.setData(ClipboardData(text: me.privateInviteLink));
    _showSnack(
      title: 'private_link_copied'.tr,
      message: me.privateInviteLink,
      isError: false,
    );
  }

  // ===========================================================================
  // SETTINGS ACTIONS (Privacy, Dark Mode, Language, Offline Cache)
  // ===========================================================================

  /// Toggles whether other users can see/find this account in search.
  Future<void> toggleProfileDiscoverability(bool value) async {
    if (isUpdatingDiscoverability.value) return;

    final String? uid = currentUserId;
    final bool previous = myProfile.value?.isProfileDiscoverable ??
        (Get.isRegistered<AppPreferencesService>()
            ? prefs.isProfileDiscoverable.value
            : true);

    isUpdatingDiscoverability.value = true;

    if (myProfile.value != null) {
      myProfile.value = myProfile.value!.copyWith(
        isProfileDiscoverable: value,
      );
    }
    if (Get.isRegistered<AppPreferencesService>()) {
      await prefs.setProfileDiscoverable(value);
    }

    if (uid != null) {
      try {
        await supabase.from(SupabaseConstants.profilesTable).update(
          <String, dynamic>{
            'is_profile_discoverable': value,
          },
        ).eq('id', uid);
      } on PostgrestException catch (e) {
        final String code = (e.code ?? '').toUpperCase();
        final bool missingColumn = code == '42703' ||
            code == 'PGRST204' ||
            e.message.contains('is_profile_discoverable');
        if (!missingColumn) {
          if (myProfile.value != null) {
            myProfile.value = myProfile.value!.copyWith(
              isProfileDiscoverable: previous,
            );
          }
          if (Get.isRegistered<AppPreferencesService>()) {
            await prefs.setProfileDiscoverable(previous);
          }
          isUpdatingDiscoverability.value = false;
          return;
        }
      } catch (_) {
        if (myProfile.value != null) {
          myProfile.value = myProfile.value!.copyWith(
            isProfileDiscoverable: previous,
          );
        }
        if (Get.isRegistered<AppPreferencesService>()) {
          await prefs.setProfileDiscoverable(previous);
        }
        isUpdatingDiscoverability.value = false;
        return;
      }
    }

    isUpdatingDiscoverability.value = false;
    _showSnack(
      title: 'discoverable_title'.tr,
      message: value ? 'discoverable_on_sub'.tr : 'discoverable_off_sub'.tr,
      isError: false,
    );
  }

  /// Toggles Dark Mode and saves preference locally.
  Future<void> toggleDarkMode([bool? value]) async {
    if (!Get.isRegistered<AppPreferencesService>()) return;
    if (value != null) {
      await prefs.setDarkMode(value);
    } else {
      await prefs.toggleDarkMode();
    }
  }

  /// Switches the app language (`ar` or `en`).
  Future<void> setLanguage(String code) async {
    if (!Get.isRegistered<AppPreferencesService>()) return;
    await prefs.setLanguage(code);
    conversations.refresh();
    statusUsers.refresh();
  }

  /// Opens options sheet to capture camera photo, pick gallery photo, or remove avatar.
  void showAvatarOptionsSheet() {
    final bool isAr = prefs.isArabic;
    final bool hasAvatar = myProfile.value?.hasAvatar ?? false;

    Get.bottomSheet(
      GlassBottomSheet(
        title: isAr ? 'صورة الملف الشخصي (الأفاتار)' : 'Profile Picture (Avatar)',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading:
                    const Icon(Icons.camera_alt_rounded, color: AppColors.aqua),
                title: Text(
                  isAr
                      ? 'التقاط صورة بالكاميرا 📷'
                      : 'Take a photo with camera 📷',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () {
                  Get.back<void>();
                  pickAndUpdateAvatar(source: ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.aqua,
                ),
                title: Text(
                  isAr
                      ? 'اختيار صورة من المعرض 🖼️'
                      : 'Choose photo from gallery 🖼️',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () {
                  Get.back<void>();
                  pickAndUpdateAvatar(source: ImageSource.gallery);
                },
              ),
              if (hasAvatar)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                  title: Text(
                    isAr ? 'إزالة الصورة الشخصية' : 'Remove profile picture',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                  onTap: () {
                    Get.back<void>();
                    removeAvatar();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Removes the user's custom avatar and restores default initials.
  Future<void> removeAvatar() async {
    final String? uid = currentUserId;
    if (myProfile.value != null) {
      final ProfileModel updated = myProfile.value!.copyWith(avatarUrl: '');
      myProfile.value = updated;
      if (Get.isRegistered<AppPreferencesService>()) {
        await prefs.saveUserSession(updated);
      }
    }
    if (uid != null) {
      try {
        await supabase.from(SupabaseConstants.profilesTable).update(
          <String, dynamic>{'avatar_url': null},
        ).eq('id', uid);
      } catch (_) {}
    }
    conversations.refresh();
    _showSnack(
      title: 'profile_updated'.tr,
      message: prefs.isArabic
          ? 'تمت إزالة الصورة الشخصية'
          : 'Profile picture removed',
      isError: false,
    );
  }

  /// Picks and updates the user's personal profile picture / avatar.
  Future<void> pickAndUpdateAvatar({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 82,
      );
      if (picked == null) return;
      final Uint8List bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;

      final String? uid = currentUserId;
      String? remoteUrl;

      // 1) Attempt uploading to Supabase Storage bucket 'avatars'
      if (uid != null) {
        try {
          final String path =
              '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
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
      }

      // 2) Fallback to Base64 data URI if storage bucket is not configured
      final String finalAvatarUrl =
          remoteUrl ?? 'data:image/jpeg;base64,${base64Encode(bytes)}';

      if (myProfile.value != null) {
        final ProfileModel updated =
            myProfile.value!.copyWith(avatarUrl: finalAvatarUrl);
        myProfile.value = updated;
        if (Get.isRegistered<AppPreferencesService>()) {
          await prefs.saveUserSession(updated);
        }
      }

      if (uid != null) {
        try {
          await supabase.from(SupabaseConstants.profilesTable).update(
            <String, dynamic>{'avatar_url': finalAvatarUrl},
          ).eq('id', uid);
        } catch (_) {}
      }

      conversations.refresh();
      statusUsers.refresh();

      _showSnack(
        title: 'profile_updated'.tr,
        message: prefs.isArabic
            ? 'تم تحديث صورتك الشخصية بنجاح وتظهر الآن في كل مكان ✨'
            : 'Avatar updated and visible everywhere ✨',
        isError: false,
      );
    } catch (_) {}
  }

  /// Picks and updates the user's profile cover / background image.
  Future<void> pickAndUpdateProfileCover() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 720,
        imageQuality: 80,
      );
      if (picked == null) return;
      final Uint8List bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;

      if (Get.isRegistered<AppPreferencesService>()) {
        await prefs.setProfileCover(bytes);
      }

      _showSnack(
        title: 'profile_updated'.tr,
        message: prefs.isArabic
            ? 'تم تحديث خلفية غلاف بروفايلك بنجاح 🎨'
            : 'Profile background updated successfully 🎨',
        isError: false,
      );
    } catch (_) {}
  }

  /// Removes the user's profile cover background image.
  Future<void> clearProfileCover() async {
    if (Get.isRegistered<AppPreferencesService>()) {
      await prefs.clearProfileCover();
    }
    _showSnack(
      title: 'profile_updated'.tr,
      message: prefs.isArabic
          ? 'تمت استعادة خلفية الغلاف الافتراضية'
          : 'Restored default cover background',
      isError: false,
    );
  }

  /// Opens the device/browser image picker and sets the chosen image as the
  /// global app background wallpaper across all screens.
  Future<void> pickCustomBackgroundImage() async {
    if (!Get.isRegistered<AppPreferencesService>()) return;
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 84,
      );
      if (picked == null) return;

      final Uint8List bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return;

      await prefs.setCustomBackgroundImage(bytes);
      _showSnack(
        title: 'custom_bg_title'.tr,
        message: 'bg_updated_msg'.tr,
        isError: false,
      );
    } catch (_) {
      _showSnack(
        title: 'custom_bg_title'.tr,
        message: prefs.isArabic
            ? 'تعذّر اختيار الصورة، حاول مرة أخرى'
            : 'Could not load image, please try again',
        isError: true,
      );
    }
  }

  /// Selects one of the built-in app wallpapers.
  Future<void> selectBuiltInWallpaper(String presetId) async {
    if (!Get.isRegistered<AppPreferencesService>()) return;
    await prefs.selectBuiltInWallpaper(presetId);
    _showSnack(
      title: 'custom_bg_title'.tr,
      message: 'bg_updated_msg'.tr,
      isError: false,
    );
  }

  /// Restores the default Glassmorphism gradient background.
  Future<void> resetCustomBackgroundImage() async {
    if (!Get.isRegistered<AppPreferencesService>()) return;
    await prefs.clearCustomBackgroundImage();
    _showSnack(
      title: 'custom_bg_title'.tr,
      message: 'bg_reset_msg'.tr,
      isError: false,
    );
  }

  /// Updates the dimming overlay opacity over the custom wallpaper.
  Future<void> updateBackgroundDim(double value) async {
    if (!Get.isRegistered<AppPreferencesService>()) return;
    await prefs.setBackgroundDim(value);
  }

  /// Clears offline cached conversations and messages and re-syncs from server.
  Future<void> clearLocalCache() async {
    if (Get.isRegistered<LocalChatCacheService>()) {
      await LocalChatCacheService.to.clearAllCache();
    }
    _showSnack(
      title: 'clear_local_cache'.tr,
      message: 'cache_cleared_msg'.tr,
      isError: false,
    );
    await loadConversations(silent: true);
  }

  // ===========================================================================
  // CONVERSATIONS MANAGEMENT & OFFLINE PERSISTENCE
  // ===========================================================================

  Future<void> togglePinConversation(ConversationModel conv) async {
    if (!Get.isRegistered<AppPreferencesService>()) return;
    final bool nowPinned = await prefs.togglePinConversation(conv.id);
    final int idx =
        conversations.indexWhere((ConversationModel c) => c.id == conv.id);
    if (idx != -1) {
      conversations[idx] = conversations[idx].copyWith(isPinned: nowPinned);
      if (Get.isRegistered<LocalChatCacheService>()) {
        await LocalChatCacheService.to.saveConversations(conversations);
      }
    }
  }

  Future<void> toggleMuteConversation(ConversationModel conv) async {
    if (!Get.isRegistered<AppPreferencesService>()) return;
    final bool nowMuted = await prefs.toggleMuteConversation(conv.id);
    final int idx =
        conversations.indexWhere((ConversationModel c) => c.id == conv.id);
    if (idx != -1) {
      conversations[idx] = conversations[idx].copyWith(isMuted: nowMuted);
      if (Get.isRegistered<LocalChatCacheService>()) {
        await LocalChatCacheService.to.saveConversations(conversations);
      }
    }
  }

  Future<void> markConversationAsRead(ConversationModel conv) async {
    final String? uid = currentUserId;
    if (uid == null || conv.unreadCount <= 0) return;

    final int idx =
        conversations.indexWhere((ConversationModel c) => c.id == conv.id);
    if (idx != -1) {
      conversations[idx] = conversations[idx].copyWith(unreadCount: 0);
    }

    try {
      await supabase
          .from(SupabaseConstants.messagesTable)
          .update(<String, dynamic>{'is_read': true})
          .eq('conversation_id', conv.id)
          .neq('sender_id', uid)
          .eq('is_read', false);
    } catch (_) {}
  }

  Future<void> markAllConversationsAsRead() async {
    final String? uid = currentUserId;
    if (uid == null || totalUnreadCount <= 0) return;

    final List<String> unreadConvIds = conversations
        .where((ConversationModel c) => c.unreadCount > 0)
        .map((ConversationModel c) => c.id)
        .toList();

    for (int i = 0; i < conversations.length; i++) {
      if (conversations[i].unreadCount > 0) {
        conversations[i] = conversations[i].copyWith(unreadCount: 0);
      }
    }

    try {
      await supabase
          .from(SupabaseConstants.messagesTable)
          .update(<String, dynamic>{'is_read': true})
          .inFilter('conversation_id', unreadConvIds)
          .neq('sender_id', uid)
          .eq('is_read', false);
    } catch (_) {}
  }

  Future<void> deleteConversation(ConversationModel conv) async {
    conversations.removeWhere((ConversationModel c) => c.id == conv.id);
    if (Get.isRegistered<LocalChatCacheService>()) {
      await LocalChatCacheService.to.removeCachedConversation(conv.id);
    }
    try {
      await supabase
          .from(SupabaseConstants.conversationsTable)
          .delete()
          .eq('id', conv.id);
    } catch (_) {
      await loadConversations(silent: true);
    }
  }

  Future<void> loadConversations({bool silent = false}) async {
    final String? uid = currentUserId;
    if (uid == null) return;

    if (!silent && conversations.isEmpty) {
      isLoading.value = true;
      errorMessage.value = '';
    }

    try {
      List<dynamic> rows;
      try {
        rows = await supabase
            .from(SupabaseConstants.conversationsTable)
            .select(
              '*, '
              'user1:${SupabaseConstants.profilesTable}!conversations_user1_id_fkey(${SupabaseConstants.publicProfileColumns}), '
              'user2:${SupabaseConstants.profilesTable}!conversations_user2_id_fkey(${SupabaseConstants.publicProfileColumns})',
            )
            .or('user1_id.eq.$uid,user2_id.eq.$uid')
            .order('last_message_at', ascending: false);
      } on PostgrestException {
        rows = await supabase
            .from(SupabaseConstants.conversationsTable)
            .select(
              '*, '
              'user1:${SupabaseConstants.profilesTable}!conversations_user1_id_fkey(${SupabaseConstants.fallbackPublicProfileColumns}), '
              'user2:${SupabaseConstants.profilesTable}!conversations_user2_id_fkey(${SupabaseConstants.fallbackPublicProfileColumns})',
            )
            .or('user1_id.eq.$uid,user2_id.eq.$uid')
            .order('last_message_at', ascending: false);
      }

      isOfflineMode.value = false;

      final List<ConversationModel> parsed = rows
          .whereType<Map<String, dynamic>>()
          .map(
            (Map<String, dynamic> row) =>
                ConversationModel.fromJson(row, currentUserId: uid),
          )
          .toList();

      if (parsed.isEmpty) {
        conversations.clear();
        if (Get.isRegistered<LocalChatCacheService>()) {
          await LocalChatCacheService.to.saveConversations(const <ConversationModel>[]);
        }
        return;
      }

      final Set<String> missingProfileIds = <String>{};
      for (final ConversationModel conv in parsed) {
        if (conv.isGroup && conv.groupMeta != null) {
          for (final String mId in conv.groupMeta!.memberIds) {
            if (mId.isNotEmpty) missingProfileIds.add(mId);
          }
        } else if (conv.otherUser == null) {
          missingProfileIds.add(conv.otherUserId(uid));
        }
      }

      final Map<String, ProfileModel> profileMap = <String, ProfileModel>{};
      if (missingProfileIds.isNotEmpty) {
        List<dynamic> profRows;
        try {
          profRows = await supabase
              .from(SupabaseConstants.profilesTable)
              .select(SupabaseConstants.publicProfileColumns)
              .inFilter('id', missingProfileIds.toList());
        } on PostgrestException {
          profRows = await supabase
              .from(SupabaseConstants.profilesTable)
              .select(SupabaseConstants.fallbackPublicProfileColumns)
              .inFilter('id', missingProfileIds.toList());
        }

        for (final dynamic p in profRows) {
          if (p is Map<String, dynamic>) {
            final ProfileModel pm = ProfileModel.fromJson(p);
            profileMap[pm.id] = pm;
          }
        }
      }

      final List<String> convIds =
          parsed.map((ConversationModel c) => c.id).toList();

      final List<dynamic> unreadRows = await supabase
          .from(SupabaseConstants.messagesTable)
          .select('conversation_id, sender_id, is_read')
          .inFilter('conversation_id', convIds)
          .eq('is_read', false);

      final Map<String, int> incomingUnreadByConv = <String, int>{};
      final Set<String> convWithUnreadOutgoing = <String>{};

      for (final dynamic r in unreadRows) {
        if (r is Map<String, dynamic>) {
          final String cId = r['conversation_id'] as String;
          final String sId = r['sender_id'] as String;
          if (sId != uid) {
            incomingUnreadByConv[cId] = (incomingUnreadByConv[cId] ?? 0) + 1;
          } else {
            convWithUnreadOutgoing.add(cId);
          }
        }
      }

      final bool hasPrefs = Get.isRegistered<AppPreferencesService>();

      final List<ConversationModel> enriched = parsed.map(
        (ConversationModel conv) {
          final ProfileModel? other = conv.isGroup
              ? null
              : (conv.otherUser ?? profileMap[conv.otherUserId(uid)]);
          final List<ProfileModel> groupProfiles = conv.isGroup &&
                  conv.groupMeta != null
              ? conv.groupMeta!.memberIds
                  .map((String id) => profileMap[id])
                  .whereType<ProfileModel>()
                  .toList()
              : const <ProfileModel>[];
          final bool isMine = conv.isLastMessageMine(uid);
          final bool lastRead =
              isMine && !convWithUnreadOutgoing.contains(conv.id);
          final int unread = incomingUnreadByConv[conv.id] ?? 0;
          final bool pinned =
              hasPrefs && prefs.isConversationPinned(conv.id);
          final bool muted =
              hasPrefs && prefs.isConversationMuted(conv.id);

          return conv.copyWith(
            otherUser: other,
            groupMemberProfiles: groupProfiles,
            lastMessageIsRead: lastRead,
            unreadCount: unread,
            isPinned: pinned,
            isMuted: muted,
          );
        },
      ).toList();

      // Merge any purely-local group conversations that haven't synced to server
      for (final ConversationModel existing in conversations) {
        if (existing.isGroup &&
            !enriched.any((ConversationModel e) => e.id == existing.id)) {
          enriched.add(existing);
        }
      }

      conversations.assignAll(enriched);

      // Persist conversations locally so they open offline next time
      if (Get.isRegistered<LocalChatCacheService>()) {
        await LocalChatCacheService.to.saveConversations(enriched);
      }
    } on PostgrestException catch (e) {
      if (conversations.isEmpty && !silent) {
        errorMessage.value = e.message;
      }
    } catch (_) {
      // Offline fallback: keep displaying locally cached conversations
      isOfflineMode.value = true;
      if (conversations.isEmpty &&
          Get.isRegistered<LocalChatCacheService>()) {
        final List<ConversationModel> cached =
            await LocalChatCacheService.to.getCachedConversations();
        if (cached.isNotEmpty) {
          conversations.assignAll(cached);
        } else if (!silent) {
          errorMessage.value = 'offline_cached_banner'.tr;
        }
      }
    } finally {
      isLoading.value = false;
    }
  }

  void _subscribeRealtime() {
    final String? uid = currentUserId;
    if (uid == null) return;

    _realtimeChannel = supabase
        .channel('home_realtime_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseConstants.conversationsTable,
          callback: (_) => _scheduleSilentRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseConstants.messagesTable,
          callback: (_) => _scheduleSilentRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConstants.profilesTable,
          callback: (PostgresChangePayload payload) {
            final Map<String, dynamic> newRow = payload.newRecord;
            if (newRow.isEmpty) return;
            final String updatedId = (newRow['id'] as String?) ?? '';
            if (updatedId.isEmpty) return;

            if (updatedId == uid && myProfile.value != null) {
              final ProfileModel updatedMe = myProfile.value!.copyWith(
                displayName: (newRow['display_name'] as String?) ??
                    myProfile.value!.displayName,
                username:
                    (newRow['username'] as String?) ?? myProfile.value!.username,
                avatarUrl: (newRow['avatar_url'] as String?) ??
                    myProfile.value!.avatarUrl,
                bio: (newRow['bio'] as String?) ?? myProfile.value!.bio,
                statusText: (newRow['status_text'] as String?) ??
                    myProfile.value!.statusText,
                statusColor: (newRow['status_color'] as String?) ??
                    myProfile.value!.statusColor,
                isOnline:
                    (newRow['is_online'] as bool?) ?? myProfile.value!.isOnline,
                isProfileDiscoverable:
                    (newRow['is_profile_discoverable'] as bool?) ??
                        myProfile.value!.isProfileDiscoverable,
              );
              _applyMyProfile(updatedMe);
              if (Get.isRegistered<AppPreferencesService>()) {
                prefs.saveUserSession(updatedMe);
              }
              return;
            }

            final int index = conversations.indexWhere(
              (ConversationModel c) => c.otherUser?.id == updatedId,
            );
            if (index != -1) {
              final ConversationModel current = conversations[index];
              final ProfileModel? existingOther = current.otherUser;
              if (existingOther != null) {
                conversations[index] = current.copyWith(
                  otherUser: existingOther.copyWith(
                    displayName: (newRow['display_name'] as String?) ??
                        existingOther.displayName,
                    username: (newRow['username'] as String?) ??
                        existingOther.username,
                    avatarUrl: (newRow['avatar_url'] as String?) ??
                        existingOther.avatarUrl,
                    bio: (newRow['bio'] as String?) ?? existingOther.bio,
                    statusText: (newRow['status_text'] as String?) ??
                        existingOther.statusText,
                    statusColor: (newRow['status_color'] as String?) ??
                        existingOther.statusColor,
                    isOnline:
                        (newRow['is_online'] as bool?) ?? existingOther.isOnline,
                    isProfileDiscoverable:
                        (newRow['is_profile_discoverable'] as bool?) ??
                            existingOther.isProfileDiscoverable,
                    lastSeen: newRow['last_seen'] != null
                        ? DateTime.tryParse(newRow['last_seen'].toString())
                            ?.toLocal()
                        : existingOther.lastSeen,
                  ),
                );
              }
            }
          },
        )
        .subscribe();
  }

  void _scheduleSilentRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 280), () {
      loadConversations(silent: true);
    });
  }

  Future<void> _setOnlineStatus(bool online) async {
    final String? uid = currentUserId;
    if (uid == null) return;
    try {
      await supabase.from(SupabaseConstants.profilesTable).update(
        <String, dynamic>{
          'is_online': online,
          'last_seen': DateTime.now().toUtc().toIso8601String(),
        },
      ).eq('id', uid);
    } catch (_) {}
  }

  Future<void> openChat(
    ConversationModel conversation, {
    String? initialMessage,
  }) async {
    final ProfileModel? other = conversation.otherUser;
    await Get.toNamed(
      AppRoutes.chat,
      arguments: <String, dynamic>{
        'conversationId': conversation.id,
        'conversation': conversation,
        'otherUser': other,
        if (initialMessage != null && initialMessage.trim().isNotEmpty)
          'initialMessage': initialMessage.trim(),
      },
    );
    await loadConversations(silent: true);
  }

  /// Starts or opens a conversation directly with a user (e.g., from a Status card).
  Future<void> openOrStartChatWithUser(
    ProfileModel otherUser, {
    String? initialMessage,
  }) async {
    final int existingIdx = conversations.indexWhere(
      (ConversationModel c) => c.otherUser?.id == otherUser.id,
    );
    if (existingIdx != -1) {
      await openChat(
        conversations[existingIdx],
        initialMessage: initialMessage,
      );
      return;
    }

    final String? myId = currentUserId;
    if (myId == null) return;

    try {
      final Map<String, dynamic> inserted = await supabase
          .from(SupabaseConstants.conversationsTable)
          .insert(
            ConversationModel.insertPayload(
              currentUserId: myId,
              otherUserId: otherUser.id,
            ),
          )
          .select()
          .single();

      final ConversationModel conv = ConversationModel.fromJson(
        inserted,
        currentUserId: myId,
      ).copyWith(otherUser: otherUser);

      await openChat(conv, initialMessage: initialMessage);
    } catch (_) {
      await openSearch();
    }
  }

  Future<void> openSearch() async {
    await Get.toNamed(AppRoutes.search);
    await loadConversations(silent: true);
  }

  /// Creates a new Group Conversation with `currentUserId` as the Group Owner & Admin,
  /// customizable permissions (`onlyAdminsCanSend`, `onlyAdminsCanEditInfo`),
  /// and initial selected members.
  Future<void> createGroupConversation({
    required String groupName,
    required String groupDescription,
    required List<ProfileModel> initialMembers,
    required bool onlyAdminsCanSend,
    required bool onlyAdminsCanEditInfo,
  }) async {
    if (isCreatingGroup.value) return;
    final String cleanName = groupName.trim();
    if (cleanName.isEmpty) {
      _showSnack(
        title: prefs.isArabic ? 'إنشاء مجموعة' : 'Create Group',
        message: prefs.isArabic
            ? 'يرجى إدخال اسم المجموعة'
            : 'Please enter a group name',
        isError: true,
      );
      return;
    }

    final String? myId = currentUserId ?? myProfile.value?.id;
    if (myId == null) return;

    isCreatingGroup.value = true;
    try {
      final List<String> memberIds = <String>{
        myId,
        ...initialMembers.map((ProfileModel p) => p.id),
      }.toList();

      final String inviteCode =
          'GRP-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';

      final GroupChatMeta meta = GroupChatMeta(
        name: cleanName,
        description: groupDescription.trim(),
        ownerId: myId,
        adminIds: <String>[myId],
        memberIds: memberIds,
        onlyAdminsCanSend: onlyAdminsCanSend,
        onlyAdminsCanEditInfo: onlyAdminsCanEditInfo,
        inviteCode: inviteCode,
      );

      final String welcomeMsg = prefs.isArabic
          ? 'تم إنشاء المجموعة "$cleanName" 🎉'
          : 'Group "$cleanName" created 🎉';
      final String encodedLastMsg = ConversationModel.encodeGroupLastMessage(
        meta: meta,
        visibleLastMessage: welcomeMsg,
      );

      // Secondary user id for DB compatibility if `user2_id` is required
      final String secondUserId = initialMembers.isNotEmpty
          ? initialMembers.first.id
          : myId;

      ConversationModel? createdConv;

      try {
        final Map<String, dynamic> inserted = await supabase
            .from(SupabaseConstants.conversationsTable)
            .insert(<String, dynamic>{
              'user1_id': myId,
              'user2_id': secondUserId,
              'last_message': encodedLastMsg,
              'last_message_type': SupabaseConstants.messageTypeText,
              'last_message_sender_id': myId,
              'last_message_at': DateTime.now().toUtc().toIso8601String(),
            })
            .select()
            .single();

        createdConv = ConversationModel.fromJson(
          inserted,
          currentUserId: myId,
        ).copyWith(
          isGroup: true,
          groupMeta: meta,
          lastMessage: welcomeMsg,
          groupMemberProfiles: <ProfileModel>[
            if (myProfile.value != null) myProfile.value!,
            ...initialMembers,
          ],
        );
      } catch (_) {
        // Fallback when 1-on-1 unique constraint or offline mode prevents remote insert:
        // create locally cached group conversation immediately so it works 100%.
        createdConv = ConversationModel(
          id: 'grp_${DateTime.now().millisecondsSinceEpoch}',
          user1Id: myId,
          user2Id: secondUserId,
          lastMessage: welcomeMsg,
          lastMessageType: SupabaseConstants.messageTypeText,
          lastMessageSenderId: myId,
          lastMessageAt: DateTime.now(),
          createdAt: DateTime.now(),
          isGroup: true,
          groupMeta: meta,
          groupMemberProfiles: <ProfileModel>[
            if (myProfile.value != null) myProfile.value!,
            ...initialMembers,
          ],
        );
      }

      conversations.insert(0, createdConv);
      if (Get.isRegistered<LocalChatCacheService>()) {
        await LocalChatCacheService.to.saveConversations(conversations);
      }

      _showSnack(
        title: cleanName,
        message: prefs.isArabic
            ? 'تم إنشاء المجموعة بنجاح وأنت مدير المجموعة 👑'
            : 'Group created! You are the group admin 👑',
        isError: false,
      );

      await openChat(createdConv);
    } finally {
      isCreatingGroup.value = false;
    }
  }

  /// Updates an existing Group Conversation's metadata/permissions in memory,
  /// local cache, and remote database.
  Future<void> updateGroupConversationMeta(
    ConversationModel groupConv,
    GroupChatMeta updatedMeta,
  ) async {
    final String? myId = currentUserId;
    final ConversationModel updatedConv = groupConv.copyWith(
      isGroup: true,
      groupMeta: updatedMeta,
    );

    final int idx =
        conversations.indexWhere((ConversationModel c) => c.id == groupConv.id);
    if (idx != -1) {
      conversations[idx] = updatedConv;
      conversations.refresh();
    }

    if (Get.isRegistered<LocalChatCacheService>()) {
      await LocalChatCacheService.to.saveConversations(conversations);
    }

    if (myId != null && !groupConv.id.startsWith('grp_')) {
      try {
        await supabase
            .from(SupabaseConstants.conversationsTable)
            .update(
              ConversationModel.lastMessagePayload(
                lastMessage: groupConv.lastMessage,
                lastMessageType: groupConv.lastMessageType,
                senderId: groupConv.lastMessageSenderId ?? myId,
                groupMeta: updatedMeta,
              ),
            )
            .eq('id', groupConv.id);
      } catch (_) {}
    }
  }

  /// Signs the user out, sets online status to false, destroys all local
  /// session data & offline cache (`AppPreferencesService.destroyUserSession`),
  /// and resets navigation to `/email`.
  Future<void> signOut() async {
    await _setOnlineStatus(false);
    if (_realtimeChannel != null) {
      try {
        await supabase.removeChannel(_realtimeChannel!);
      } catch (_) {}
      _realtimeChannel = null;
    }
    try {
      await supabase.auth.signOut();
    } catch (_) {}
    if (Get.isRegistered<AppPreferencesService>()) {
      await prefs.destroyUserSession();
    }
    myProfile.value = null;
    conversations.clear();
    statusUsers.clear();
    Get.offAllNamed(AppRoutes.email);
  }

  /// Formats conversation timestamp according to the active locale (`ar` / `en`).
  String formatConversationTime(DateTime dateTime) {
    final String loc = Get.isRegistered<AppPreferencesService>()
        ? prefs.languageCode.value
        : 'ar';
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target =
        DateTime(dateTime.year, dateTime.month, dateTime.day);
    final int diffDays = today.difference(target).inDays;

    if (diffDays == 0) {
      return DateFormat('hh:mm a', loc).format(dateTime);
    }
    if (diffDays == 1) {
      return 'yesterday'.tr;
    }
    if (diffDays < 7) {
      return DateFormat('EEEE', loc).format(dateTime);
    }
    return DateFormat('yyyy/MM/dd', loc).format(dateTime);
  }

  /// Shows context options for a conversation tile (Pin, Mute, Mark read, Delete).
  void showConversationOptionsSheet(ConversationModel conv) {
    final String title = conv.title;

    Get.bottomSheet(
      GlassBottomSheet(
        title: title,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: Icon(
                conv.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
                color: AppColors.aqua,
              ),
              title: Text(
                conv.isPinned ? 'unpin_chat'.tr : 'pin_chat'.tr,
              ),
              onTap: () {
                Get.back<void>();
                togglePinConversation(conv);
              },
            ),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: Icon(
                conv.isMuted
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
                color: AppColors.aqua,
              ),
              title: Text(
                conv.isMuted ? 'unmute_chat'.tr : 'mute_chat'.tr,
              ),
              onTap: () {
                Get.back<void>();
                toggleMuteConversation(conv);
              },
            ),
            if (conv.unreadCount > 0)
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: const Icon(
                  Icons.done_all_rounded,
                  color: AppColors.aqua,
                ),
                title: Text('mark_as_read'.tr),
                onTap: () {
                  Get.back<void>();
                  markConversationAsRead(conv);
                },
              ),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              title: Text(
                'delete_chat'.tr,
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onTap: () {
                Get.back<void>();
                deleteConversation(conv);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack({
    required String title,
    required String message,
    required bool isError,
  }) {
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
    }
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppColors.isDark
          ? AppColors.darkInputFill
          : AppColors.lightTextPrimary,
      colorText: Colors.white,
      icon: Icon(
        isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
        color: isError ? AppColors.error : AppColors.online,
      ),
      margin: const EdgeInsets.all(16),
      borderRadius: 16,
      duration: const Duration(seconds: 3),
    );
  }
}
