import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/app_preferences_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/widgets/other_user_profile_sheet.dart';
import '../../data/models/message_model.dart';
import '../../data/models/profile_model.dart';
import 'chat_controller.dart';
import 'widgets/group_info_sheet.dart';
import 'widgets/message_bubble.dart';

/// 1-on-1 Glassmorphism chat screen (`/chat`) matching the reference image:
/// - Frosted glass header with contact avatar, name, online status, search,
///   starred filter, and info button.
/// - Atmospheric blue glassmorphism background with frosted date chips.
/// - Distinct incoming and outgoing glass message bubbles with read ticks.
/// - Frosted glass composer bar with `+` attachment tray (`الصور`, `الكاميرا`,
///   `الملفات`, `الموقع`, `صوت`), emoji picker, and glowing cyan send/mic button.
class ChatView extends GetView<ChatController> {
  const ChatView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPreferencesService prefs = AppPreferencesService.to;

    return Obx(() {
      final bool isDark = prefs.isDarkMode.value;
      final String _ = prefs.languageCode.value;
      return GlassScaffoldBackground(
        isChatScreen: true,
        conversationId: controller.conversationId,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.deepNavy.withValues(alpha: 0.50)
                        : Colors.white.withValues(alpha: 0.78),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : AppColors.lightBorder,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          tooltip: 'رجوع',
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          onPressed: () => Get.back<void>(),
                        ),
                        Expanded(
                          child: Obx(() {
                            if (controller.isSearchMode.value) {
                              return TextField(
                                controller: controller.chatSearchController,
                                autofocus: true,
                                onChanged: controller.onSearchQueryChanged,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'search_in_chat_hint'.tr,
                                  hintStyle: TextStyle(
                                    color: AppColors.textHint,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                              );
                            }

                            final ProfileModel? user =
                                controller.otherUser.value;
                            final bool isGroup = controller.isGroupChat;
                            final String displayName = isGroup
                                ? (controller.groupMeta?.name ?? 'مجموعة')
                                : ((user?.displayName.trim().isNotEmpty ??
                                          false)
                                      ? user!.displayName
                                      : '@Me');
                            final bool discoverable =
                                !isGroup && (user?.isProfileDiscoverable ?? true);
                            final bool isOnline =
                                discoverable && (user?.isOnline ?? false);
                            final bool isTyping =
                                controller.isOtherUserTyping.value;

                            String statusLabel = '';
                            if (isTyping) {
                              statusLabel = 'typing_now'.tr;
                            } else if (isGroup) {
                              final int count =
                                  controller.groupMeta?.memberIds.length ?? 0;
                              statusLabel = prefs.isArabic
                                  ? '$count عضو • اضغط لمعلومات المجموعة'
                                  : '$count members • Tap for group info';
                            } else if (discoverable) {
                              statusLabel = isOnline
                                  ? 'online_now'.tr
                                  : formatLastSeenLocalized(user?.lastSeen);
                            }

                            return InkWell(
                              onTap: isGroup
                                  ? () => showGroupInfoSheet(controller)
                                  : (user != null
                                        ? () => showOtherUserProfileSheet(
                                            user: user,
                                          )
                                        : null),
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 4,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    if (isGroup)
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: const BoxDecoration(
                                          gradient:
                                              AppColors.cyanButtonGradient,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.groups_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      )
                                    else
                                      _ChatHeaderAvatar(
                                        profile: user,
                                        isOnline: isOnline,
                                      ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Row(
                                            children: <Widget>[
                                              Flexible(
                                                child: Text(
                                                  displayName,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                ),
                                              ),

                                            ],
                                          ),
                                          if (statusLabel.isNotEmpty) ...<Widget>[
                                            const SizedBox(height: 2),
                                            Text(
                                              statusLabel,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight:
                                                    isTyping || isOnline
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                color: isTyping
                                                    ? AppColors.aqua
                                                    : (isOnline
                                                        ? AppColors.online
                                                        : AppColors
                                                            .textSecondary),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                        Obx(() {
                          final bool searching = controller.isSearchMode.value;
                          final bool starredOnly =
                              controller.showStarredOnly.value;
                          final ProfileModel? user = controller.otherUser.value;

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                tooltip: searching
                                    ? 'إغلاق البحث'
                                    : 'بحث في الرسائل',
                                onPressed: controller.toggleSearchMode,
                                icon: Icon(
                                  searching
                                      ? Icons.close_rounded
                                      : Icons.search_rounded,
                                  size: 22,
                                ),
                              ),
                              IconButton(
                                tooltip: starredOnly
                                    ? 'clear_filter'.tr
                                    : 'star_action'.tr,
                                onPressed: controller.toggleStarredFilter,
                                icon: Icon(
                                  starredOnly
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: starredOnly
                                      ? Colors.amber
                                      : AppColors.textPrimary,
                                  size: 22,
                                ),
                              ),
                              IconButton(
                                tooltip: AppPreferencesService.to.isArabic
                                    ? 'خلفية المحادثة'
                                    : 'Chat Wallpaper',
                                onPressed: () =>
                                    _openChatWallpaperSheet(context, controller),
                                icon: const Icon(
                                  Icons.wallpaper_rounded,
                                  size: 22,
                                ),
                              ),
                              if ((user != null || controller.isGroupChat) &&
                                  !searching)
                                IconButton(
                                  tooltip: 'view_profile'.tr,
                                  onPressed: () => controller.isGroupChat
                                      ? showGroupInfoSheet(controller)
                                      : showOtherUserProfileSheet(user: user!),
                                  icon: const Icon(
                                    Icons.info_outline_rounded,
                                    size: 22,
                                  ),
                                ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: Stack(
            children: <Widget>[
              Column(
                children: <Widget>[
                  // Starred filter active banner
                  Obx(() {
                    if (!controller.showStarredOnly.value) {
                      return const SizedBox.shrink();
                    }
                    return GlassCard(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      borderRadius: 16,
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'starred_only_banner'.tr,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: controller.toggleStarredFilter,
                            child: Text('clear_filter'.tr),
                          ),
                        ],
                      ),
                    );
                  }),

                  // Realtime messages list with frosted glass date separators
                  Expanded(
                    child: Obx(() {
                      if (controller.isLoadingMessages.value &&
                          controller.messages.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final List<MessageModel> list =
                          controller.visibleMessages;
                      final Set<String> starredSet = prefs.starredMessageIds;

                      if (list.isEmpty) {
                        return _EmptyChatPlaceholder(
                          isFiltered:
                              controller.searchQuery.value.isNotEmpty ||
                                  controller.showStarredOnly.value,
                        );
                      }

                      final String? myId = controller.currentUserId;

                      return ListView.builder(
                        controller: controller.scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: list.length,
                        itemBuilder: (BuildContext context, int index) {
                          final MessageModel msg = list[index];
                          final bool isMine = msg.isMine(myId);
                          final bool isStarred = starredSet.contains(msg.id);

                          String? senderName;
                          if (!isMine && controller.isGroupChat) {
                            final ProfileModel? senderProfile = controller
                                .groupMembersList
                                .firstWhereOrNull(
                              (ProfileModel p) => p.id == msg.senderId,
                            );
                            senderName = senderProfile?.displayName ??
                                msg.replySenderOverride;
                          }

                          final bool showDateHeader = index ==
                                  list.length - 1 ||
                              !controller.isSameDay(
                                msg.createdAt,
                                list[index + 1].createdAt,
                              );

                          final Widget bubbleWidget = MessageBubble(
                            key: ValueKey<String>(msg.id),
                            message: msg,
                            isMine: isMine,
                            isStarred: isStarred,
                            senderDisplayName: senderName,
                            timeLabel: controller.formatMessageTime(
                              msg.createdAt,
                            ),
                            onLongPress: () =>
                                controller.showMessageActionsSheet(msg),
                            onReplySwipe: () => controller.setReplyMessage(msg),
                          );

                          if (!showDateHeader) return bubbleWidget;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              _DateSeparatorChip(
                                label: controller.formatDateHeader(
                                  msg.createdAt,
                                ),
                              ),
                              bubbleWidget,
                            ],
                          );
                        },
                      );
                    }),
                  ),

                  // Uploading voice note indicator
                  Obx(() {
                    if (!controller.isUploadingAudio.value) {
                      return const SizedBox.shrink();
                    }
                    return GlassCard(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      borderRadius: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'uploading_voice'.tr,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // Active Reply Preview Banner
                  const _ReplyPreviewBanner(),

                  // Quick Emoji Picker Bar
                  const _QuickEmojiBar(),

                  // Bottom Input Bar
                  const _ChatBottomBar(),

                  // Frosted Glass Attachment Tray (الصور / الكاميرا / الملفات / الموقع) matching reference
                  const _GlassAttachmentTray(),
                ],
              ),

              // Floating Scroll-to-Bottom Button
              PositionedDirectional(
                bottom: 84,
                end: 16,
                child: Obx(() {
                  if (!controller.showScrollToBottomBtn.value) {
                    return const SizedBox.shrink();
                  }
                  return GlowingCyanCircleButton(
                    icon: Icons.keyboard_double_arrow_down_rounded,
                    size: 42,
                    iconSize: 22,
                    onTap: controller.scrollToBottom,
                  );
                }),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _DateSeparatorChip extends StatelessWidget {
  const _DateSeparatorChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: GlassCard(
          borderRadius: 999,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplyPreviewBanner extends GetView<ChatController> {
  const _ReplyPreviewBanner();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final MessageModel? target = controller.replyingToMessage.value;
      if (target == null) return const SizedBox.shrink();

      final bool isMine = target.isMine(controller.currentUserId);
      final String senderName = isMine
          ? 'you'.tr
          : (controller.otherUser.value?.displayName.trim().isNotEmpty == true
              ? controller.otherUser.value!.displayName
              : (controller.otherUser.value?.handle ?? '@Me'));

      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
        child: GlassCard(
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.reply_rounded,
                size: 18,
                color: AppColors.aqua,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${'reply_to'.tr} $senderName',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.aqua,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      target.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: controller.cancelReply,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _QuickEmojiBar extends GetView<ChatController> {
  const _QuickEmojiBar();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.showEmojiBar.value || controller.isRecording.value) {
        return const SizedBox.shrink();
      }
      return GlassCard(
        margin: const EdgeInsets.fromLTRB(14, 2, 14, 4),
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: ChatController.quickEmojis.length,
            separatorBuilder: (_, _) => const SizedBox(width: 4),
            itemBuilder: (BuildContext context, int index) {
              final String emoji = ChatController.quickEmojis[index];
              return InkWell(
                onTap: () => controller.insertEmoji(emoji),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 21),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }
}

class _ChatBottomBar extends GetView<ChatController> {
  const _ChatBottomBar();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool isDark = AppPreferencesService.to.isDarkMode.value;
      return ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.deepNavy.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.85),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.16)
                      : AppColors.lightBorder,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              bottom: !controller.showAttachmentBar.value,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Obx(() {
                  // Group: only admins can send → show read-only banner for members
                  final bool _ = controller.conversation.value?.isGroup ?? false;
                  if (!controller.canCurrentUserSendMessages) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: isDark ? 0.08 : 0.6,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppColors.aqua.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Icon(
                            Icons.lock_rounded,
                            size: 18,
                            color: AppColors.aqua,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'only_admins_can_send_banner'.tr,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (controller.isRecording.value) {
                    return _ActiveRecordingBar(
                      timerLabel: controller.recordingTimerLabel,
                      onCancel: controller.cancelRecording,
                      onSend: controller.stopAndSendRecording,
                    );
                  }

                  final bool hasText = controller.hasTypedText;
                  final bool busy = controller.isSendingText.value ||
                      controller.isUploadingAudio.value;
                  final bool emojiOpen = controller.showEmojiBar.value;
                  final bool attachOpen = controller.showAttachmentBar.value;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      // Circular `+` Attachment Toggle Button (matches reference)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: InkWell(
                          onTap: controller.toggleAttachmentBar,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: attachOpen
                                  ? AppColors.electricCyan
                                      .withValues(alpha: 0.25)
                                  : Colors.white.withValues(
                                      alpha: isDark ? 0.10 : 0.7,
                                    ),
                              border: Border.all(
                                color: attachOpen
                                    ? AppColors.aqua
                                    : Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Icon(
                              attachOpen
                                  ? Icons.close_rounded
                                  : Icons.add_rounded,
                              color: AppColors.textPrimary,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Frosted Glass Message Input Pill
                      Expanded(
                        child: TextField(
                          key: const Key('chat_message_input'),
                          controller: controller.messageInputController,
                          enabled: !busy,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          onChanged: controller.onTextChanged,
                          style: TextStyle(
                            fontSize: 15.5,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'type_message_hint'.tr,
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withValues(alpha: 0.09)
                                : Colors.white,
                            suffixIcon: IconButton(
                              tooltip: 'رموز تعبيرية',
                              onPressed: controller.toggleEmojiBar,
                              icon: Icon(
                                emojiOpen
                                    ? Icons.keyboard_rounded
                                    : Icons.sentiment_satisfied_alt_rounded,
                                color: emojiOpen
                                    ? AppColors.aqua
                                    : AppColors.textSecondary,
                                size: 22,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 11,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(26),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(26),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.22)
                                    : AppColors.lightBorder,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(26),
                              borderSide: const BorderSide(
                                color: AppColors.electricCyan,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Glowing Cyan Send OR Voice Recording Button
                      GlowingCyanCircleButton(
                        key: Key(
                          hasText ? 'send_text_btn' : 'record_voice_btn',
                        ),
                        icon: hasText ? Icons.send_rounded : Icons.mic_rounded,
                        size: 46,
                        iconSize: 21,
                        onTap: busy
                            ? null
                            : (hasText
                                ? controller.sendTextMessage
                                : controller.startRecording),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// Frosted glass attachment tray matching the bottom of the middle phone in
/// the visual reference (`الصور`, `الكاميرا`, `الملفات`, `رسالة صوتية`).
class _GlassAttachmentTray extends GetView<ChatController> {
  const _GlassAttachmentTray();

  @override
  Widget build(BuildContext context) {
    final bool isAr = AppPreferencesService.to.isArabic;

    return Obx(() {
      if (!controller.showAttachmentBar.value || controller.isRecording.value) {
        return const SizedBox.shrink();
      }

      return ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.isDark
                  ? AppColors.deepNavy.withValues(alpha: 0.68)
                  : Colors.white.withValues(alpha: 0.90),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _AttachmentTile(
                    icon: Icons.mic_rounded,
                    label: isAr ? 'صوتية' : 'Voice',
                    onTap: () {
                      controller.showAttachmentBar.value = false;
                      controller.startRecording();
                    },
                  ),
                  _AttachmentTile(
                    icon: Icons.photo_library_rounded,
                    label: isAr ? 'الصور' : 'Photos',
                    onTap: () {
                      controller.showAttachmentBar.value = false;
                      controller.insertEmoji('🖼️ ');
                    },
                  ),
                  _AttachmentTile(
                    icon: Icons.camera_alt_rounded,
                    label: isAr ? 'الكاميرا' : 'Camera',
                    onTap: () {
                      controller.showAttachmentBar.value = false;
                      controller.insertEmoji('📷 ');
                    },
                  ),
                  _AttachmentTile(
                    icon: Icons.insert_drive_file_rounded,
                    label: isAr ? 'الملفات' : 'Files',
                    onTap: () {
                      controller.showAttachmentBar.value = false;
                      controller.insertEmoji('📎 ');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: GlassCard(
          borderRadius: 18,
          padding: const EdgeInsets.symmetric(vertical: 12),
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: AppColors.textPrimary, size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveRecordingBar extends StatelessWidget {
  const _ActiveRecordingBar({
    required this.timerLabel,
    required this.onCancel,
    required this.onSend,
  });

  final String timerLabel;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.recording.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: AppColors.recording.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: <Widget>[
          TextButton.icon(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.recording,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            label: Text(
              'cancel'.tr,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.recording,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  timerLabel,
                  style: const TextStyle(
                    color: AppColors.recording,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          GlowingCyanCircleButton(
            key: const Key('send_voice_note_btn'),
            icon: Icons.send_rounded,
            size: 40,
            iconSize: 19,
            onTap: onSend,
          ),
        ],
      ),
    );
  }
}

class _ChatHeaderAvatar extends StatelessWidget {
  const _ChatHeaderAvatar({
    required this.profile,
    required this.isOnline,
  });

  final ProfileModel? profile;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            gradient: AppColors.cyanButtonGradient,
            shape: BoxShape.circle,
          ),
          child: ClipOval(
            child: buildUniversalAvatarImage(
              imageUrl: profile?.avatarUrl,
              fallbackText: profile?.displayName ?? '@',
              radius: 20,
            ),
          ),
        ),
        if (isOnline)
          PositionedDirectional(
            bottom: 0,
            end: 0,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.deepNavy, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyChatPlaceholder extends StatelessWidget {
  const _EmptyChatPlaceholder({this.isFiltered = false});

  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassCard(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        borderRadius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isFiltered
                  ? Icons.search_off_rounded
                  : Icons.waving_hand_rounded,
              size: 38,
              color: AppColors.aqua,
            ),
            const SizedBox(height: 10),
            Text(
              isFiltered ? 'no_matching_messages'.tr : 'start_chat_now'.tr,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isFiltered ? 'clear_filter'.tr : 'start_chat_Sub'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Frosted Glass bottom sheet to pick or change the wallpaper for this specific user / chat.
void _openChatWallpaperSheet(
  BuildContext context,
  ChatController controller,
) {
  final AppPreferencesService prefs = AppPreferencesService.to;
  final bool isDark = prefs.isDarkMode.value;
  final bool isAr = prefs.isArabic;
  final String convId = controller.conversationId;

  Get.bottomSheet(
    ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0xEB102E6B), Color(0xF507152E)],
                  )
                : AppColors.lightScaffoldGradient,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? AppColors.aqua.withValues(alpha: 0.38)
                    : AppColors.lightBorder,
                width: 1.2,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          gradient: AppColors.cyanButtonGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.wallpaper_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              isAr
                                  ? 'تغيير خلفية هذا المستخدم'
                                  : 'Chat Wallpaper for this user',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              isAr
                                  ? 'اختر خلفية مخصصة لهذا المستخدم أو صورة من المعرض'
                                  : 'Choose a custom wallpaper or photo for this chat',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  // Gallery photo option
                  GlassCard(
                    borderRadius: 18,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    onTap: () {
                      Get.back<void>();
                      controller.pickWallpaperFromGallery();
                    },
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.photo_library_rounded,
                          color: AppColors.aqua,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isAr
                                ? 'اختيار صورة من المعرض لهذا المستخدم 🖼️'
                                : 'Pick photo from gallery for this user 🖼️',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: AppColors.aqua,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isAr ? 'الخلفيات المدمجة المتاحة:' : 'Built-in Wallpapers:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 85,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: AppPreferencesService.builtInWallpapers.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (BuildContext _, int index) {
                        final BuiltInWallpaperPreset preset =
                            AppPreferencesService.builtInWallpapers[index];
                        final String? currentPreset =
                            prefs.getConversationWallpaperPreset(convId);
                        final bool isSelected = currentPreset == preset.id;
                        return GestureDetector(
                          onTap: () {
                            Get.back<void>();
                            controller.setWallpaperPreset(preset.id);
                          },
                          child: Container(
                            width: 82,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: preset.gradient,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.aqua
                                    : Colors.white.withValues(alpha: 0.25),
                                width: isSelected ? 2.5 : 1.0,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(preset.icon,
                                    color: Colors.white, size: 20),
                                const SizedBox(height: 4),
                                Text(
                                  preset.title(isAr),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Reset button
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        Get.back<void>();
                        controller.resetWallpaper();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(
                        isAr
                            ? 'استعادة الخلفية الافتراضية للتطبيق'
                            : 'Reset to default app wallpaper',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    isScrollControlled: true,
  );
}
