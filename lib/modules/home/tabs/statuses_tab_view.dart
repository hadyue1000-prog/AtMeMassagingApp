import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/services/app_preferences_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../../core/widgets/other_user_profile_sheet.dart';
import '../../../data/models/message_model.dart';
import '../../../data/models/profile_model.dart';
import '../home_controller.dart';

/// LRU in-memory cache for status base64 images to eliminate frame jank
final Map<String, Uint8List> _statusBase64Cache = <String, Uint8List>{};

Uint8List? _getCachedStatusImage(String? base64Str) {
  if (base64Str == null || base64Str.trim().isEmpty) return null;
  final Uint8List? cached = _statusBase64Cache[base64Str];
  if (cached != null) return cached;
  try {
    final Uint8List decoded = base64Decode(base64Str);
    if (_statusBase64Cache.length > 60) {
      _statusBase64Cache.remove(_statusBase64Cache.keys.first);
    }
    _statusBase64Cache[base64Str] = decoded;
    return decoded;
  } catch (_) {
    return null;
  }
}

class StatusesTabView extends GetView<HomeController> {
  const StatusesTabView({super.key});

  String _formatStatusTime(DateTime? dt) {
    if (dt == null) return '';
    final String lang = Get.isRegistered<AppPreferencesService>()
        ? AppPreferencesService.to.languageCode.value
        : 'ar';
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'online_now'.tr;
    if (diff.inMinutes < 60) {
      return lang == 'ar'
          ? 'منذ ${diff.inMinutes} دقيقة'
          : '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24 && DateTime.now().day == dt.day) {
      return DateFormat('hh:mm a', lang).format(dt);
    }
    return DateFormat('MM/dd hh:mm a', lang).format(dt);
  }

  void _openStoryViewer({
    required List<ProfileModel> profilesList,
    required int initialProfileIndex,
  }) {
    if (profilesList.isEmpty) return;
    Get.to<void>(
      () => _WhatsAppStoryViewerScreen(
        profiles: profilesList,
        initialProfileIndex: initialProfileIndex,
        controller: controller,
      ),
      fullscreenDialog: true,
      transition: Transition.fadeIn,
      duration: const Duration(milliseconds: 220),
    );
  }

  void _openStatusComposerSheet(BuildContext context, {bool pickImage = false}) {
    if (pickImage) {
      controller.pickStatusImage();
    }
    Get.bottomSheet(
      _WhatsAppStatusComposerSheet(controller: controller),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  void _openManageMyStatusesSheet(BuildContext context, ProfileModel me) {
    Get.bottomSheet(
      GlassBottomSheet(
        child: Obx(() {
          final ProfileModel currentMe = controller.myProfile.value ?? me;
          final List<StatusSegmentItem> segments =
              currentMe.statusSegments;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.layers_rounded,
                    color: AppColors.aqua,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'my_status'.tr,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (segments.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        Get.back<void>();
                        controller.clearMyWrittenStatus();
                      },
                      icon: const Icon(
                        Icons.delete_sweep_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                      label: Text(
                        'clear_status'.tr,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (segments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'no_statuses_yet'.tr,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: segments.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 12, color: AppColors.divider),
                    itemBuilder: (BuildContext context, int idx) {
                      final StatusSegmentItem seg = segments[idx];
                      final Uint8List? imgBytes =
                          _getCachedStatusImage(seg.imageBase64);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        onTap: () {
                          Get.back<void>();
                          _openStoryViewer(
                            profilesList: <ProfileModel>[currentMe],
                            initialProfileIndex: 0,
                          );
                        },
                        leading: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: parseStatusColor(seg.colorHex),
                            borderRadius: BorderRadius.circular(14),
                            image: imgBytes != null
                                ? DecorationImage(
                                    image: MemoryImage(imgBytes),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: imgBytes == null
                              ? Center(
                                  child: Text(
                                    seg.text.isNotEmpty
                                        ? seg.text.characters.first
                                        : '✨',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          seg.text.isNotEmpty
                              ? seg.text
                              : (seg.hasImage ? '📷 صورة حالة' : 'حالة نصية'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          _formatStatusTime(seg.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.error,
                          ),
                          onPressed: () =>
                              controller.deleteStatusSegment(seg.id),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPreferencesService prefs = AppPreferencesService.to;

    return Obx(() {
      final bool _ = prefs.isDarkMode.value;
      final String lang = prefs.languageCode.value;
      final bool isAr = lang == 'ar';
      // Subscribe to viewedStatusSegmentIds so UI updates immediately when a story is viewed
      final int _ = prefs.viewedStatusKeys.length;

      final ProfileModel? me = controller.myProfile.value;
      final List<ProfileModel> others = controller.activeCommunityStatuses;

      final List<ProfileModel> unseenProfiles = others
          .where((ProfileModel p) => !prefs.hasViewedAllStatusSegments(p))
          .toList();
      final List<ProfileModel> viewedProfiles = others
          .where((ProfileModel p) => prefs.hasViewedAllStatusSegments(p))
          .toList();

      return RefreshIndicator(
        onRefresh: () async {
          await controller.loadMyProfile();
          await controller.loadCommunityStatuses();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: <Widget>[
            // 1) WhatsApp-Style "My Status" Card
            _buildWhatsAppMyStatusHeader(context, me, isAr),
            const SizedBox(height: 16),

            // 2) Quick Inline Composer Card (Text + Gallery Image)
            _buildQuickStatusComposerCard(context, isAr),
            const SizedBox(height: 22),

            // 3) Friends Statuses (Unseen + Viewed)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  isAr ? 'تحديثات الحالات الحديثة' : 'Recent updates',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: controller.loadCommunityStatuses,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: AppColors.isDark
                      ? AppColors.aqua
                      : AppColors.royalBlue,
                ),
              ],
            ),
            const SizedBox(height: 6),

            if (others.isEmpty)
              GlassCard(
                padding: const EdgeInsets.all(28),
                borderRadius: 24,
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: AppColors.cyanButtonGradient,
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.electricCyan.withValues(
                              alpha: 0.35,
                            ),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.donut_large_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'no_statuses_yet'.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'no_statuses_subtitle'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else ...<Widget>[
              if (unseenProfiles.isNotEmpty) ...<Widget>[
                ...unseenProfiles.map((ProfileModel profile) {
                  final int indexInAll = others.indexOf(profile);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _WhatsAppStatusListTile(
                      profile: profile,
                      timeText: _formatStatusTime(
                        profile.latestStatusSegment?.createdAt ??
                            profile.statusCreatedAt,
                      ),
                      onTapStory: () => _openStoryViewer(
                        profilesList: others,
                        initialProfileIndex: indexInAll < 0 ? 0 : indexInAll,
                      ),
                      onTapUserInfo: () => showOtherUserProfileSheet(
                        user: profile,
                        onMessageTap: () =>
                            controller.openOrStartChatWithUser(profile),
                      ),
                    ),
                  );
                }),
              ],
              if (viewedProfiles.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: Text(
                    isAr ? 'الحالات التي تمت مشاهدتها' : 'Viewed updates',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                ...viewedProfiles.map((ProfileModel profile) {
                  final int indexInAll = others.indexOf(profile);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _WhatsAppStatusListTile(
                      profile: profile,
                      timeText: _formatStatusTime(
                        profile.latestStatusSegment?.createdAt ??
                            profile.statusCreatedAt,
                      ),
                      onTapStory: () => _openStoryViewer(
                        profilesList: others,
                        initialProfileIndex: indexInAll < 0 ? 0 : indexInAll,
                      ),
                      onTapUserInfo: () => showOtherUserProfileSheet(
                        user: profile,
                        onMessageTap: () =>
                            controller.openOrStartChatWithUser(profile),
                      ),
                    ),
                  );
                }),
              ],
            ],
          ],
        ),
      );
    });
  }

  Widget _buildWhatsAppMyStatusHeader(
    BuildContext context,
    ProfileModel? me,
    bool isAr,
  ) {
    final bool hasStatus = me != null && me.hasActiveStatus;
    final List<StatusSegmentItem> mySegments =
        me?.statusSegments ?? <StatusSegmentItem>[];

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      borderRadius: 22,
      onTap: () {
        if (hasStatus) {
          _openStoryViewer(
            profilesList: <ProfileModel>[me],
            initialProfileIndex: 0,
          );
        } else {
          _openStatusComposerSheet(context);
        }
      },
      child: Row(
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              _WhatsAppStoryRingAvatar(
                profile: me,
                radius: 28,
                forceUnseenGlow: hasStatus,
              ),
              PositionedDirectional(
                bottom: -2,
                end: -2,
                child: GestureDetector(
                  onTap: () => _openStatusComposerSheet(context),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: AppColors.cyanButtonGradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.deepNavy, width: 2),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isAr ? 'حالتي' : 'My Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasStatus
                      ? '${mySegments.length} ${isAr ? "حالات نشطة • اضغط للعرض" : "active updates • Tap to view"}'
                      : (isAr
                            ? 'اضغط لإضافة حالة نصية أو صورة'
                            : 'Tap to add text or photo status'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: hasStatus ? AppColors.aqua : AppColors.textSecondary,
                    fontWeight: hasStatus ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isAr ? 'إضافة صورة للحالة' : 'Add photo status',
            onPressed: () => _openStatusComposerSheet(context, pickImage: true),
            icon: const Icon(
              Icons.camera_alt_rounded,
              color: AppColors.aqua,
              size: 21,
            ),
          ),
          if (hasStatus)
            IconButton(
              tooltip: isAr ? 'إدارة حالاتي' : 'Manage my statuses',
              onPressed: () => _openManageMyStatusesSheet(context, me),
              icon: Icon(
                Icons.more_horiz_rounded,
                color: AppColors.textPrimary,
                size: 22,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickStatusComposerCard(BuildContext context, bool isAr) {
    return Obx(() {
      final String selectedHex = controller.selectedStatusColor.value;
      final Color cardColor = parseStatusColor(selectedHex);
      final Uint8List? pickedImage = controller.selectedStatusImageBytes.value;

      return GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.aqua,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAr ? 'إنشاء حالة جديدة (نص أو صورة)' : 'Create New Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: controller.pickStatusImage,
                  icon: const Icon(
                    Icons.add_photo_alternate_rounded,
                    size: 18,
                    color: AppColors.aqua,
                  ),
                  label: Text(
                    isAr ? 'صورة من المعرض' : 'Gallery Photo',
                    style: const TextStyle(
                      color: AppColors.aqua,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (pickedImage != null) ...<Widget>[
              Stack(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.memory(
                      pickedImage,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  PositionedDirectional(
                    top: 8,
                    end: 8,
                    child: GestureDetector(
                      onTap: controller.clearSelectedStatusImage,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // Colored status or photo caption input
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    cardColor,
                    cardColor.withValues(alpha: 0.82),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              child: TextField(
                controller: controller.statusInputController,
                maxLines: 3,
                minLines: 1,
                maxLength: 180,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
                decoration: InputDecoration(
                  hintText: pickedImage != null
                      ? (isAr
                            ? 'أضف تعليقاً على الصورة (اختياري)...'
                            : 'Add a caption to your photo...')
                      : 'write_status_hint'.tr,
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.80),
                    fontSize: 13.5,
                    fontWeight: FontWeight.normal,
                  ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  counterStyle: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Color Palette Selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: HomeController.statusColorPalette.map((String hex) {
                  final Color color = parseStatusColor(hex);
                  final bool isSelected = selectedHex == hex;
                  return GestureDetector(
                    onTap: () => controller.selectedStatusColor.value = hex,
                    child: Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsetsDirectional.only(end: 9),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.3),
                          width: isSelected ? 2.5 : 1.0,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: GlowingCyanButton(
                height: 46,
                label: 'publish_status'.tr,
                icon: Icons.send_rounded,
                loading: controller.isPublishingStatus.value,
                onPressed: () => controller.publishWrittenStatus(
                  text: controller.statusInputController.text,
                  colorHex: controller.selectedStatusColor.value,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// WhatsApp-style Status List Tile:
/// - Segmented circular ring around avatar (green/cyan for unseen segments, grey for viewed)
/// - Shows ONLY `displayName` (hides `@username` as requested by user!)
/// - Shows latest status preview + timestamp
class _WhatsAppStatusListTile extends StatelessWidget {
  const _WhatsAppStatusListTile({
    required this.profile,
    required this.timeText,
    required this.onTapStory,
    required this.onTapUserInfo,
  });

  final ProfileModel profile;
  final String timeText;
  final VoidCallback onTapStory;
  final VoidCallback onTapUserInfo;

  @override
  Widget build(BuildContext context) {
    final StatusSegmentItem? latest = profile.latestStatusSegment;
    final int count = profile.statusSegments.length;

    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      onTap: onTapStory,
      child: Row(
        children: <Widget>[
          _WhatsAppStoryRingAvatar(
            profile: profile,
            radius: 27,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // ONLY displayName is shown here — @username is hidden outside User Info!
                Text(
                  profile.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    if (latest != null && latest.hasImage) ...<Widget>[
                      const Icon(
                        Icons.photo_camera_rounded,
                        size: 14,
                        color: AppColors.aqua,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        profile.latestStatusDisplayText.isNotEmpty
                            ? profile.latestStatusDisplayText
                            : '📷 صورة حالة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                timeText,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              if (count > 1) ...<Widget>[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.electricCyan.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.aqua,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 4),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'view_profile'.tr,
            onPressed: onTapUserInfo,
            icon: Icon(
              Icons.info_outline_rounded,
              size: 19,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom-painted WhatsApp-style segmented ring around user's avatar.
class _WhatsAppStoryRingAvatar extends StatelessWidget {
  const _WhatsAppStoryRingAvatar({
    required this.profile,
    this.radius = 27,
    this.forceUnseenGlow = false,
  });

  final ProfileModel? profile;
  final double radius;
  final bool forceUnseenGlow;

  @override
  Widget build(BuildContext context) {
    final List<StatusSegmentItem> segments =
        profile?.statusSegments ?? <StatusSegmentItem>[];
    final AppPreferencesService prefs = AppPreferencesService.to;

    final List<bool> seenFlags = segments.map((StatusSegmentItem seg) {
      if (forceUnseenGlow) return false;
      if (profile == null) return false;
      return prefs.isStatusSegmentViewed(profile!.id, seg.id);
    }).toList();

    final StatusSegmentItem? latest = profile?.latestStatusSegment;
    final Uint8List? statusThumbBytes =
        _getCachedStatusImage(latest?.imageBase64);

    return CustomPaint(
      painter: _SegmentedRingPainter(
        seenFlags: seenFlags,
        activeColor: const Color(0xFF25D366),
        accentColor: AppColors.electricCyan,
        seenColor: Colors.grey.withValues(alpha: 0.55),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4.5),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: profile != null && profile!.hasActiveStatus
              ? parseStatusColor(profile!.latestStatusColor)
              : AppColors.deepNavy,
          backgroundImage: statusThumbBytes != null
              ? MemoryImage(statusThumbBytes)
              : ((profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty)
                    ? CachedNetworkImageProvider(profile!.avatarUrl!)
                    : null),
          child:
              (statusThumbBytes == null &&
                  (profile?.avatarUrl == null || profile!.avatarUrl!.isEmpty))
              ? Text(
                  (profile?.displayName.isNotEmpty ?? false)
                      ? profile!.displayName[0].toUpperCase()
                      : '@',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: radius * 0.72,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _SegmentedRingPainter extends CustomPainter {
  _SegmentedRingPainter({
    required this.seenFlags,
    required this.activeColor,
    required this.accentColor,
    required this.seenColor,
  });

  final List<bool> seenFlags;
  final Color activeColor;
  final Color accentColor;
  final Color seenColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (seenFlags.isEmpty) return;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (math.min(size.width, size.height) / 2) - 1.8;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    final int count = seenFlags.length;
    final double gapAngle = count == 1 ? 0.0 : 0.14;
    final double sweepAngle = (2 * math.pi - (count * gapAngle)) / count;
    double startAngle = -math.pi / 2;

    for (int i = 0; i < count; i++) {
      final bool isSeen = seenFlags[i];
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      if (isSeen) {
        paint.color = seenColor;
      } else {
        paint.shader = SweepGradient(
          colors: <Color>[activeColor, accentColor, activeColor],
        ).createShader(rect);
      }

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentedRingPainter oldDelegate) {
    return oldDelegate.seenFlags.length != seenFlags.length ||
        oldDelegate.seenFlags != seenFlags;
  }
}

/// Bottom sheet composer for adding a WhatsApp-style text or photo status.
class _WhatsAppStatusComposerSheet extends StatelessWidget {
  const _WhatsAppStatusComposerSheet({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final bool isAr = AppPreferencesService.to.isArabic;

    return GlassBottomSheet(
      child: Obx(() {
        final String selectedHex = controller.selectedStatusColor.value;
        final Color cardColor = parseStatusColor(selectedHex);
        final Uint8List? pickedImage =
            controller.selectedStatusImageBytes.value;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.aqua,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAr ? 'إضافة حالة واتساب جديدة' : 'New Status Update',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: controller.pickStatusImage,
                  icon: const Icon(
                    Icons.photo_library_rounded,
                    color: AppColors.aqua,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (pickedImage != null) ...<Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.memory(
                  pickedImage,
                  height: 190,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: TextField(
                controller: controller.statusInputController,
                maxLines: 3,
                minLines: 2,
                maxLength: 180,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  hintText: 'write_status_hint'.tr,
                  hintStyle: const TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: HomeController.statusColorPalette.map((String hex) {
                  final Color c = parseStatusColor(hex);
                  final bool sel = selectedHex == hex;
                  return GestureDetector(
                    onTap: () => controller.selectedStatusColor.value = hex,
                    child: Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsetsDirectional.only(end: 8),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: sel ? Colors.white : Colors.white38,
                          width: sel ? 2.5 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GlowingCyanButton(
                label: 'publish_status'.tr,
                icon: Icons.send_rounded,
                loading: controller.isPublishingStatus.value,
                onPressed: () async {
                  await controller.publishWrittenStatus(
                    text: controller.statusInputController.text,
                    colorHex: controller.selectedStatusColor.value,
                  );
                  if (Get.isBottomSheetOpen ?? false) {
                    Get.back<void>();
                  }
                },
              ),
            ),
          ],
        );
      }),
    );
  }
}

/// Full-Screen WhatsApp Story Viewer:
/// - Segmented animated 5s progress bars at the top
/// - Auto-advances through each segment of a user, then moves to next user
/// - Tap left/right to navigate, hold to pause
/// - Bottom bar to reply directly to the status or send a quick emoji reaction
class _WhatsAppStoryViewerScreen extends StatefulWidget {
  const _WhatsAppStoryViewerScreen({
    required this.profiles,
    required this.initialProfileIndex,
    required this.controller,
  });

  final List<ProfileModel> profiles;
  final int initialProfileIndex;
  final HomeController controller;

  @override
  State<_WhatsAppStoryViewerScreen> createState() =>
      _WhatsAppStoryViewerScreenState();
}

class _WhatsAppStoryViewerScreenState extends State<_WhatsAppStoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late int _profileIndex;
  late int _segmentIndex;
  late AnimationController _progressController;
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();

  ProfileModel get _currentProfile => widget.profiles[_profileIndex];

  List<StatusSegmentItem> get _currentSegments =>
      _currentProfile.statusSegments;

  StatusSegmentItem get _currentSegment => _currentSegments[_segmentIndex];

  bool get _isMyOwnStatus =>
      _currentProfile.id == widget.controller.currentUserId;

  @override
  void initState() {
    super.initState();
    _profileIndex = widget.initialProfileIndex.clamp(
      0,
      widget.profiles.length - 1,
    );
    _segmentIndex = _findFirstUnseenSegmentIndex(_currentProfile);

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          _nextSegment();
        }
      });

    _replyFocusNode.addListener(() {
      if (_replyFocusNode.hasFocus) {
        _progressController.stop();
      } else {
        _progressController.forward();
      }
    });

    _startCurrentSegment();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  int _findFirstUnseenSegmentIndex(ProfileModel profile) {
    final List<StatusSegmentItem> segs = profile.statusSegments;
    if (segs.isEmpty) return 0;
    if (!Get.isRegistered<AppPreferencesService>()) return 0;

    for (int i = 0; i < segs.length; i++) {
      if (!AppPreferencesService.to.isStatusSegmentViewed(
        profile.id,
        segs[i].id,
      )) {
        return i;
      }
    }
    return 0;
  }

  void _startCurrentSegment() {
    if (_currentSegments.isEmpty) {
      Get.back<void>();
      return;
    }
    if (Get.isRegistered<AppPreferencesService>()) {
      AppPreferencesService.to.markStatusSegmentViewed(
        _currentProfile.id,
        _currentSegment.id,
      );
    }
    _progressController
      ..reset()
      ..forward();
    setState(() {});
  }

  void _nextSegment() {
    if (_segmentIndex < _currentSegments.length - 1) {
      _segmentIndex++;
      _startCurrentSegment();
    } else if (_profileIndex < widget.profiles.length - 1) {
      _profileIndex++;
      _segmentIndex = _findFirstUnseenSegmentIndex(_currentProfile);
      _startCurrentSegment();
    } else {
      Get.back<void>();
    }
  }

  void _prevSegment() {
    if (_segmentIndex > 0) {
      _segmentIndex--;
      _startCurrentSegment();
    } else if (_profileIndex > 0) {
      _profileIndex--;
      _segmentIndex = math.max(0, _currentSegments.length - 1);
      _startCurrentSegment();
    } else {
      _startCurrentSegment();
    }
  }

  Future<void> _sendStatusReply(String replyText) async {
    final String clean = replyText.trim();
    if (clean.isEmpty) return;

    _replyController.clear();
    _replyFocusNode.unfocus();
    Get.back<void>();

    final String quoteHeader = _currentSegment.text.isNotEmpty
        ? _currentSegment.text
        : (_currentSegment.hasImage ? '📷 صورة في الحالة' : 'حالة');
    final String formattedReply = MessageModel.encodeWithReply(
      text: clean,
      replySender: 'حالة ${_currentProfile.displayName}',
      replyText: quoteHeader,
    );

    await widget.controller.openOrStartChatWithUser(
      _currentProfile,
      initialMessage: formattedReply,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentSegments.isEmpty) {
      return const SizedBox.shrink();
    }

    final StatusSegmentItem segment = _currentSegment;
    final Color bgColor = parseStatusColor(segment.colorHex);
    final Uint8List? imageBytes = _getCachedStatusImage(segment.imageBase64);

    final bool isAr = Get.isRegistered<AppPreferencesService>()
        ? AppPreferencesService.to.isArabic
        : true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onLongPressStart: (_) => _progressController.stop(),
        onLongPressEnd: (_) {
          if (!_replyFocusNode.hasFocus) {
            _progressController.forward();
          }
        },
        onTapUp: (TapUpDetails details) {
          if (_replyFocusNode.hasFocus) {
            _replyFocusNode.unfocus();
            return;
          }
          final double width = MediaQuery.sizeOf(context).width;
          final bool tappedLeft = details.globalPosition.dx < width * 0.33;
          if (isAr) {
            // In RTL, tapping left advances, tapping right goes back
            if (tappedLeft) {
              _nextSegment();
            } else {
              _prevSegment();
            }
          } else {
            if (tappedLeft) {
              _prevSegment();
            } else {
              _nextSegment();
            }
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 1) Full-screen Story Background (Colored Gradient or Gallery Photo)
            if (imageBytes != null)
              Container(
                color: Colors.black,
                child: Center(
                  child: Image.memory(
                    imageBytes,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              )
            else
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      bgColor,
                      bgColor.withValues(alpha: 0.78),
                      const Color(0xFF061126),
                    ],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      segment.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ),

            // Photo Caption Overlay at Bottom
            if (imageBytes != null && segment.text.trim().isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: _isMyOwnStatus ? 40 : 110,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    segment.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

            // 2) Top Segmented Progress Bars + Contact Header (No @username shown here!)
            SafeArea(
              child: Column(
                children: <Widget>[
                  // Segmented Progress Bars
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Row(
                      children: List<Widget>.generate(
                        _currentSegments.length,
                        (int idx) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2.5,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: SizedBox(
                                  height: 3.5,
                                  child: AnimatedBuilder(
                                    animation: _progressController,
                                    builder: (BuildContext context, _) {
                                      double value;
                                      if (idx < _segmentIndex) {
                                        value = 1.0;
                                      } else if (idx == _segmentIndex) {
                                        value = _progressController.value;
                                      } else {
                                        value = 0.0;
                                      }
                                      return LinearProgressIndicator(
                                        value: value,
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.30),
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Contact Header Row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: () => Get.back<void>(),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            _progressController.stop();
                            showOtherUserProfileSheet(
                              user: _currentProfile,
                              onMessageTap: () {
                                Get.back<void>();
                                widget.controller.openOrStartChatWithUser(
                                  _currentProfile,
                                );
                              },
                            );
                          },
                          child: Row(
                            children: <Widget>[
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.white24,
                                backgroundImage:
                                    (_currentProfile.avatarUrl != null &&
                                        _currentProfile.avatarUrl!.isNotEmpty)
                                    ? CachedNetworkImageProvider(
                                        _currentProfile.avatarUrl!,
                                      )
                                    : null,
                                child:
                                    (_currentProfile.avatarUrl == null ||
                                        _currentProfile.avatarUrl!.isEmpty)
                                    ? Text(
                                        _currentProfile.initials,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    _currentProfile.displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('hh:mm a').format(
                                      segment.createdAt,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (_isMyOwnStatus)
                          IconButton(
                            tooltip: 'clear_status'.tr,
                            onPressed: () async {
                              await widget.controller.deleteStatusSegment(
                                segment.id,
                              );
                              Get.back<void>();
                            },
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3) Bottom WhatsApp Reply Bar (for friends' statuses)
            if (!_isMyOwnStatus)
              Positioned(
                left: 12,
                right: 12,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Quick Emoji Reactions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <String>['❤️', '😂', '🔥', '👏', '😍', '😢']
                          .map((String emoji) {
                            return GestureDetector(
                              onTap: () => _sendStatusReply(emoji),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white38),
                            ),
                            child: TextField(
                              controller: _replyController,
                              focusNode: _replyFocusNode,
                              style: const TextStyle(color: Colors.white),
                              onSubmitted: _sendStatusReply,
                              decoration: InputDecoration(
                                hintText: isAr
                                    ? 'الرد على الحالة...'
                                    : 'Reply to status...',
                                hintStyle: const TextStyle(
                                  color: Colors.white70,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: false,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GlowingCyanCircleButton(
                          icon: Icons.send_rounded,
                          size: 46,
                          onTap: () => _sendStatusReply(
                            _replyController.text.isEmpty
                                ? '👍'
                                : _replyController.text,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
