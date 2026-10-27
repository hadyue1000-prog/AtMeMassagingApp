import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/services/app_preferences_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../core/widgets/other_user_profile_sheet.dart';
import '../../data/models/profile_model.dart';
import 'search_controller.dart';

/// Glassmorphism screen to search for friends by `@username` OR add friends
/// privately via Private Invite Code / Link (even if they enabled hidden mode).
class SearchView extends GetView<UserSearchController> {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppPreferencesService prefs = AppPreferencesService.to;

    return Obx(() {
      final bool _ = prefs.isDarkMode.value;
      final String lang = prefs.languageCode.value;
      final bool isAr = lang == 'ar';

      return GlassScaffoldBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            titleSpacing: 0,
            leading: IconButton(
              tooltip: 'رجوع',
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Get.back<void>(),
            ),
            title: Text(
              isAr
                  ? 'إضافة الأصدقاء والبحث'
                  : 'Add Friends & Search',
            ),
          ),
          body: Column(
            children: <Widget>[
              // 1) Private Friend Invite Code / Link Card (for Hidden Users)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: GlassCard(
                  borderRadius: 22,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.vpn_key_rounded,
                            color: AppColors.aqua,
                            size: 19,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isAr
                                  ? 'إضافة صديق عبر كود أو رابط خاص (للحسابات المخفية)'
                                  : 'Add Friend via Private Code or Link (Hidden Users)',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: TextField(
                                controller: controller.privateCodeController,
                                textInputAction: TextInputAction.go,
                                onSubmitted:
                                    controller.addFriendByPrivateCodeOrLink,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: isAr
                                      ? 'أدخل الكود الخاص أو الرابط...'
                                      : 'Paste private code or link...',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.link_rounded,
                                    size: 18,
                                    color: AppColors.aqua,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Obx(
                            () => GlowingCyanButton(
                              height: 42,
                              label: isAr ? 'إضافة' : 'Add',
                              icon: Icons.person_add_alt_1_rounded,
                              loading: controller.isAddingByPrivateCode.value,
                              onPressed: () =>
                                  controller.addFriendByPrivateCodeOrLink(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              isAr
                                  ? 'كودك الخاص: ${controller.myPrivateInviteCode}'
                                  : 'Your Code: ${controller.myPrivateInviteCode}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              InkWell(
                                onTap: controller.copyMyPrivateCode,
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      const Icon(
                                        Icons.copy_rounded,
                                        size: 14,
                                        color: AppColors.aqua,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isAr ? 'نسخ الكود' : 'Copy Code',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.aqua,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: controller.copyMyPrivateLink,
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      const Icon(
                                        Icons.share_rounded,
                                        size: 14,
                                        color: AppColors.aqua,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isAr ? 'نسخ الرابط' : 'Copy Link',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.aqua,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 2) Frosted Glass Public Search Bar Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Obx(() {
                  final bool hasText = controller.query.value.isNotEmpty;
                  return GlassCard(
                    borderRadius: 28,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: TextField(
                        key: const Key('search_username_input'),
                        controller: controller.searchInputController,
                        focusNode: controller.searchFocusNode,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.search,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[@a-zA-Z0-9_]'),
                          ),
                        ],
                        onChanged: controller.onQueryChanged,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'username...',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.aqua,
                          ),
                          suffixIcon: hasText
                              ? IconButton(
                                  tooltip: 'مسح',
                                  onPressed: controller.clearSearch,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 20,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  );
                }),
              ),

              // 3) Body State
              Expanded(
                child: Obx(() {
                  final String currentQuery = controller.query.value;
                  final bool loading = controller.isSearching.value;
                  final String error = controller.errorMessage.value;
                  final List<ProfileModel> items = controller.results;
                  final String busyUserId =
                      controller.startingChatWithUserId.value;

                  if (currentQuery.isEmpty) {
                    final List<ProfileModel> suggested =
                        controller.suggestedUsers;
                    if (suggested.isEmpty) {
                      return const _SearchIdleState();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.explore_outlined,
                                size: 18,
                                color: AppColors.aqua,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Suggested_users'.tr,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: suggested.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (BuildContext context, int index) {
                              final ProfileModel user = suggested[index];
                              final bool isOpening = busyUserId == user.id;

                              return _UserResultTile(
                                user: user,
                                isOpening: isOpening,
                                onTap: () =>
                                    controller.startOrOpenConversation(user),
                                onAvatarTap: () => showOtherUserProfileSheet(
                                  user: user,
                                  onMessageTap: () =>
                                      controller.startOrOpenConversation(user),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }

                  if (loading && items.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (error.isNotEmpty && items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          error,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }

                  if (items.isEmpty) {
                    return _NoResultsState(query: currentQuery);
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final ProfileModel user = items[index];
                      final bool isOpening = busyUserId == user.id;

                      return _UserResultTile(
                        user: user,
                        isOpening: isOpening,
                        onTap: () => controller.startOrOpenConversation(user),
                        onAvatarTap: () => showOtherUserProfileSheet(
                          user: user,
                          onMessageTap: () =>
                              controller.startOrOpenConversation(user),
                        ),
                      );
                    },
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

class _UserResultTile extends StatelessWidget {
  const _UserResultTile({
    required this.user,
    required this.isOpening,
    required this.onTap,
    required this.onAvatarTap,
  });

  final ProfileModel user;
  final bool isOpening;
  final VoidCallback onTap;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: isOpening ? null : onTap,
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: onAvatarTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    gradient: AppColors.cyanButtonGradient,
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: buildUniversalAvatarImage(
                    imageUrl: user.avatarUrl,
                    fallbackText: user.displayName,
                    radius: 24,
                  ),
                ),
                if (user.isOnline)
                  PositionedDirectional(
                    bottom: 1,
                    end: 1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: AppColors.online,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.deepNavy, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // ONLY displayName is shown here — @username is only visible when clicking User Info!
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  user.bio.trim().isNotEmpty
                      ? user.bio
                      : (user.isOnline ? 'online_now'.tr : 'view_profile'.tr),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: user.isOnline
                        ? AppColors.online
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'view_profile'.tr,
            onPressed: onAvatarTap,
            icon: Icon(
              Icons.info_outline_rounded,
              color: AppColors.textSecondary,
              size: 21,
            ),
          ),
          if (isOpening)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.3),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                gradient: AppColors.cyanButtonGradient,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.send_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'message_btn'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchIdleState extends StatelessWidget {
  const _SearchIdleState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassCard(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(28),
        borderRadius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 74,
              height: 74,
              decoration: const BoxDecoration(
                gradient: AppColors.cyanButtonGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_search_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'search_by_username'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'no_chats_subtitle'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassCard(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(28),
        borderRadius: 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.person_off_outlined,
              size: 48,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              'no_filter_matches'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
