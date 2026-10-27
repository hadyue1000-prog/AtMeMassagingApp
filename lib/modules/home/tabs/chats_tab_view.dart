import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/services/app_preferences_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../../core/widgets/other_user_profile_sheet.dart';
import '../../../data/models/conversation_model.dart';
import '../../../data/models/profile_model.dart';
import '../home_controller.dart';

class ChatsTabView extends GetView<HomeController> {
  const ChatsTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPreferencesService prefs = AppPreferencesService.to;

    return Obx(() {
      final bool isDark = prefs.isDarkMode.value;
      final String _ = prefs.languageCode.value;

      return Column(
        children: <Widget>[
          // Offline cached banner
          Obx(() {
            if (!controller.isOfflineMode.value) {
              return const SizedBox.shrink();
            }
            return GlassCard(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              borderRadius: 16,
              borderColor: Colors.amber.withValues(alpha: 0.45),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 18,
                    color: isDark ? Colors.amberAccent : Colors.amber.shade800,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'offline_cached_banner'.tr,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

        // Frosted Glass Search Pill + Filter Chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            children: <Widget>[
              Obx(
                () => GlassSearchField(
                  controller: controller.homeSearchController,
                  hintText: 'search_chats_hint'.tr,
                  onChanged: controller.onHomeSearchChanged,
                  showClear: controller.homeSearchQuery.value.isNotEmpty,
                  onClear: controller.clearHomeSearch,
                ),
              ),
              const SizedBox(height: 12),
              Obx(() {
                final ConversationFilter activeFilter =
                    controller.activeFilter.value;
                final int unreadTotal = controller.totalUnreadCount;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      _GlassFilterChip(
                        label: 'filter_all'.tr,
                        isSelected: activeFilter == ConversationFilter.all,
                        onTap: () =>
                            controller.setFilter(ConversationFilter.all),
                      ),
                      const SizedBox(width: 8),
                      _GlassFilterChip(
                        label: unreadTotal > 0
                            ? '${'filter_unread'.tr} ($unreadTotal)'
                            : 'filter_unread'.tr,
                        isSelected: activeFilter == ConversationFilter.unread,
                        onTap: () =>
                            controller.setFilter(ConversationFilter.unread),
                      ),
                      const SizedBox(width: 8),
                      _GlassFilterChip(
                        label: prefs.isArabic ? 'المجموعات 👥' : 'Groups 👥',
                        isSelected: activeFilter == ConversationFilter.groups,
                        onTap: () =>
                            controller.setFilter(ConversationFilter.groups),
                      ),
                      const SizedBox(width: 8),
                      _GlassFilterChip(
                        label: 'filter_online'.tr,
                        isSelected: activeFilter == ConversationFilter.online,
                        onTap: () =>
                            controller.setFilter(ConversationFilter.online),
                      ),
                      const SizedBox(width: 8),
                      _GlassFilterChip(
                        label: 'filter_pinned'.tr,
                        isSelected: activeFilter == ConversationFilter.pinned,
                        onTap: () =>
                            controller.setFilter(ConversationFilter.pinned),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        // Main Glass Conversations List
        Expanded(
          child: Obx(() {
            if (controller.isLoading.value &&
                controller.conversations.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<ConversationModel> filtered =
                controller.filteredConversations;

            if (filtered.isEmpty) {
              return RefreshIndicator(
                onRefresh: controller.loadConversations,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: <Widget>[
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.54,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: GlassPanel(
                            
                            padding: const EdgeInsets.all(28),
                            borderRadius: 26,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Container(
                                  width: 78,
                                  height: 78,
                                  decoration: BoxDecoration(
                                    gradient: AppColors.cyanButtonGradient,
                                    shape: BoxShape.circle,
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: AppColors.electricCyan
                                            .withValues(alpha: 0.38),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.forum_rounded,
                                    size: 38,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  controller.conversations.isEmpty
                                      ? 'no_chats_title'.tr
                                      : 'no_filter_matches'.tr,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  controller.conversations.isEmpty
                                      ? 'no_chats_subtitle'.tr
                                      : 'show_all_chats'.tr,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                if (controller.conversations.isEmpty)
                                  GlowingCyanButton(
                                    label: 'search_by_username'.tr,
                                    icon: Icons.send_rounded,
                                    onPressed: () =>
                                        Get.toNamed(AppRoutes.search),
                                  )
                                else
                                  TextButton(
                                    onPressed: () {
                                      controller.clearHomeSearch();
                                      controller.setFilter(
                                        ConversationFilter.all,
                                      );
                                    },
                                    child: Text('show_all_chats'.tr),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final String? myId = controller.currentUserId;

            return RefreshIndicator(
              onRefresh: controller.loadConversations,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (BuildContext context, int index) {
                  final ConversationModel conv = filtered[index];
                  final String draft =
                      Get.isRegistered<AppPreferencesService>()
                          ? AppPreferencesService.to.getDraft(conv.id)
                          : '';
                  return _GlassConversationCard(
                    conversation: conv,
                    currentUserId: myId,
                    draftText: draft,
                    timeLabel: controller.formatConversationTime(
                      conv.lastMessageAt,
                    ),
                    onTap: () => controller.openChat(conv),
                    onLongPress: () =>
                        controller.showConversationOptionsSheet(conv),
                    onAvatarTap: conv.isGroup
                        ? () => controller.openChat(conv)
                        : (conv.otherUser != null
                            ? () => showOtherUserProfileSheet(
                                  user: conv.otherUser!,
                                  onMessageTap: () => controller.openChat(conv),
                                )
                            : null),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
    });
  }
}

class _GlassFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GlassFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7.5),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.cyanButtonGradient : null,
          color: isSelected
              ? null
              : (isDark
                  ? Colors.white.withValues(alpha: 0.09)
                  : Colors.white.withValues(alpha: 0.78)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.aqua
                : (isDark
                    ? Colors.white.withValues(alpha: 0.22)
                    : AppColors.lightBorder),
          ),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.electricCyan.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// Frosted glass conversation card matching the visual reference:
/// - Rounded glass card (`borderRadius: 22`)
/// - Highlighted cyan glow when unread or pinned
/// - 3D `GlassAvatar` with glowing cyan/online ring
/// - Name on the start side, Timestamp strictly in the far corner (`الركن`)
/// - Outgoing message read-receipt tick + Unread glowing cyan circle counter badge
class _GlassConversationCard extends StatelessWidget {
  final ConversationModel conversation;
  final String? currentUserId;
  final String timeLabel;
  final String draftText;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onAvatarTap;

  const _GlassConversationCard({
    required this.conversation,
    required this.currentUserId,
    required this.timeLabel,
    required this.draftText,
    required this.onTap,
    required this.onLongPress,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final ProfileModel? other = conversation.otherUser;
    final bool isGroup = conversation.isGroup;
    final bool hasUnread = conversation.unreadCount > 0;
    final String displayName = conversation.title;
    final bool isOnline = !isGroup &&
        (other?.isProfileDiscoverable ?? true) &&
        (other?.isOnline ?? false);
    final bool isLastMine = conversation.isLastMessageMine(currentUserId);
    final bool isGroupAdmin =
        isGroup && (conversation.groupMeta?.isAdmin(currentUserId) ?? false);
    final bool isAr = Get.isRegistered<AppPreferencesService>()
        ? AppPreferencesService.to.isArabic
        : true;

    return GlassCard(
      borderRadius: 22,
      isHighlighted: hasUnread || conversation.isPinned,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // 3D Glass Avatar with glowing border ring (or Group Icon badge)
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              GlassAvatar(
                imageUrl: conversation.displayAvatarUrl,
                fallbackText: displayName,
                radius: 26,
                isOnline: isOnline,
                onTap: onAvatarTap,
              ),
              if (isGroup)
                PositionedDirectional(
                  bottom: 0,
                  end: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: AppColors.cyanButtonGradient,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.deepNavy,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Content Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Top Row: Display Name ONLY (no @username on main list per user preference),
                // plus group badge if group, and Timestamp strictly in the far corner (الركن)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: hasUnread
                                    ? FontWeight.w900
                                    : FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isGroup) ...<Widget>[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.electricCyan.withValues(
                                  alpha: 0.16,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppColors.aqua.withValues(alpha: 0.32),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    isGroupAdmin
                                        ? Icons.admin_panel_settings_rounded
                                        : Icons.groups_rounded,
                                    size: 11,
                                    color: AppColors.isDark
                                        ? AppColors.aqua
                                        : AppColors.royalBlue,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    isGroupAdmin
                                        ? (isAr ? 'مدير' : 'Admin')
                                        : '${conversation.groupMeta?.memberIds.length ?? 1}',
                                    style: TextStyle(
                                      color: AppColors.isDark
                                          ? AppColors.aqua
                                          : AppColors.royalBlue,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Far Corner (الركن): Pin/Mute icons + Timestamp pinned flush to end edge
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (conversation.isPinned)
                          const Padding(
                            padding: EdgeInsetsDirectional.only(end: 4),
                            child: Icon(
                              Icons.push_pin_rounded,
                              size: 13.5,
                              color: AppColors.aqua,
                            ),
                          ),
                        if (conversation.isMuted)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 4),
                            child: Icon(
                              Icons.notifications_off_rounded,
                              size: 13.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        if (timeLabel.isNotEmpty)
                          Text(
                            timeLabel,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: hasUnread
                                  ? AppColors.aqua
                                  : AppColors.textSecondary,
                              fontWeight: hasUnread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Bottom Row: Last Message / Draft + Unread Glowing Cyan Badge
                Row(
                  children: <Widget>[
                    if (isLastMine && draftText.isEmpty) ...<Widget>[
                      const Icon(
                        Icons.done_all_rounded,
                        size: 16,
                        color: AppColors.aqua,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Expanded(
                      child: draftText.isNotEmpty
                          ? RichText(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                children: <InlineSpan>[
                                  TextSpan(
                                    text: '${'draft_prefix'.tr}: ',
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                  TextSpan(
                                    text: draftText,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      fontFamily: 'Tajawal',
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Text(
                              conversation.previewText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: hasUnread
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                    ),
                    if (hasUnread) ...<Widget>[
                      const SizedBox(width: 8),
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          gradient: conversation.isMuted
                              ? null
                              : AppColors.cyanButtonGradient,
                          color: conversation.isMuted ? Colors.grey : null,
                          shape: BoxShape.circle,
                          boxShadow: conversation.isMuted
                              ? null
                              : <BoxShadow>[
                                  BoxShadow(
                                    color: AppColors.electricCyan.withValues(
                                      alpha: 0.48,
                                    ),
                                    blurRadius: 10,
                                  ),
                                ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          conversation.unreadCount > 99
                              ? '99+'
                              : '${conversation.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
