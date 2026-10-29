import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../data/models/profile_model.dart';
import '../services/app_preferences_service.dart';
import '../theme/app_theme.dart';
import 'glass_widgets.dart';

/// Shows a Glassmorphism read-only profile sheet for another user, respecting
/// their `isProfileDiscoverable` privacy setting, with written status, bio,
/// last seen, and copyable `@username`.
void showOtherUserProfileSheet({
  required ProfileModel user,
  VoidCallback? onMessageTap,
}) {
  final bool discoverable = user.isProfileDiscoverable;
  final bool isAr = Get.isRegistered<AppPreferencesService>()
      ? AppPreferencesService.to.isArabic
      : true;
  final bool isDark = AppColors.isDark;

  Get.bottomSheet(
    ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0xEB0E2B68),
                      Color(0xF507152E),
                    ],
                  )
                : AppColors.lightScaffoldGradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? AppColors.aqua.withValues(alpha: 0.35)
                    : AppColors.lightBorder,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Avatar + Online badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Container(
                        width: 84,
                        height: 84,
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          gradient: AppColors.cyanButtonGradient,
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AppColors.electricCyan.withValues(
                                alpha: 0.38,
                              ),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: buildUniversalAvatarImage(
                            imageUrl: user.avatarUrl,
                            fallbackText: user.displayName,
                            radius: 40,
                          ),
                        ),
                      ),
                      if (discoverable && user.isOnline)
                        PositionedDirectional(
                          bottom: 2,
                          end: 2,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.online,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.deepNavy,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Display Name
                  Text(
                    user.displayName.trim().isNotEmpty
                        ? user.displayName
                        : (isAr ? 'مستخدم @Me' : '@Me User'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Copyable @username pill
                  GlassCard(
                    borderRadius: 999,
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: user.handle));
                      if (Get.isSnackbarOpen) Get.closeAllSnackbars();
                      Get.snackbar(
                        'copy_username'.tr,
                        '${'username_copied'.tr}: ${user.handle}',
                        snackPosition: SnackPosition.TOP,
                        backgroundColor: const Color(0xE60D234A),
                        colorText: Colors.white,
                        margin: const EdgeInsets.all(16),
                        borderRadius: 14,
                        duration: const Duration(seconds: 2),
                      );
                    },
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: AppColors.aqua,
                        ),
                        const SizedBox(width: 6),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            user.handle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.aqua,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Written Status Card if active
                  if (discoverable && user.hasActiveStatus) ...<Widget>[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: parseStatusColor(user.latestStatusColor),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        user.latestStatusDisplayText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],

                  // Bio / Status text if available and discoverable
                  if (discoverable && user.bio.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    GlassCard(
                      borderRadius: 18,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'bio_label'.tr,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.bio.trim(),
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Details Card (respects `isProfileDiscoverable`)
                  if (discoverable)
                    GlassCard(
                      borderRadius: 18,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: <Widget>[
                          _InfoRow(
                            icon: user.isOnline
                                ? Icons.circle_rounded
                                : Icons.schedule_rounded,
                            iconColor: user.isOnline
                                ? AppColors.online
                                : AppColors.textSecondary,
                            label: isAr ? 'الحالة' : 'Status',
                            value: user.isOnline
                                ? 'online_now'.tr
                                : formatLastSeenLocalized(user.lastSeen),
                          ),
                          if (user.createdAt != null) ...<Widget>[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Divider(
                                height: 1,
                                color: AppColors.divider,
                              ),
                            ),
                            _InfoRow(
                              icon: Icons.calendar_today_rounded,
                              iconColor: AppColors.aqua,
                              label: 'member_since'.tr,
                              value: DateFormat(
                                'yyyy/MM/dd',
                                isAr ? 'ar' : 'en',
                              ).format(user.createdAt!),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    GlassCard(
                      borderRadius: 18,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.lock_outline_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isAr
                                  ? 'قام هذا المستخدم بإخفاء تفاصيل حسابه وحالة ظهوره عن الأشخاص الآخرين.'
                                  : 'This user has hidden their profile details and online status.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (onMessageTap != null) ...<Widget>[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: GlowingCyanButton(
                        label: 'message_btn'.tr,
                        icon: Icons.send_rounded,
                        onPressed: () {
                          Get.back<void>();
                          onMessageTap();
                        },
                      ),
                    ),
                  ],
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

Color parseStatusColor(String hex) {
  String cleaned = hex.replaceAll('#', '').replaceAll('0x', '').trim();
  if (cleaned.length == 6) {
    cleaned = 'FF$cleaned';
  }
  if (cleaned.length == 8) {
    final int? val = int.tryParse(cleaned, radix: 16);
    if (val != null) return Color(val);
  }
  return AppColors.royalBlue;
}

String formatLastSeenLocalized(DateTime? lastSeen) {
  final bool isAr = Get.isRegistered<AppPreferencesService>()
      ? AppPreferencesService.to.isArabic
      : true;
  final String loc = isAr ? 'ar' : 'en';

  if (lastSeen == null) return 'offline'.tr;
  final DateTime now = DateTime.now();
  final Duration diff = now.difference(lastSeen);

  if (diff.inMinutes < 1) {
    return isAr ? 'كان متصلاً منذ لحظات' : 'Last seen just now';
  }
  if (diff.inHours < 1) {
    return isAr
        ? 'آخر ظهور منذ ${diff.inMinutes} دقيقة'
        : 'Last seen ${diff.inMinutes}m ago';
  }
  if (diff.inDays < 1) {
    final String time = DateFormat('hh:mm a', loc).format(lastSeen);
    return isAr ? 'آخر ظهور اليوم $time' : 'Last seen today at $time';
  }
  if (diff.inDays == 1) {
    final String time = DateFormat('hh:mm a', loc).format(lastSeen);
    return isAr ? 'آخر ظهور أمس $time' : 'Last seen yesterday at $time';
  }
  final String date = DateFormat('yyyy/MM/dd', loc).format(lastSeen);
  return isAr ? 'آخر ظهور $date' : 'Last seen $date';
}

String formatLastSeenArabic(DateTime? lastSeen) =>
    formatLastSeenLocalized(lastSeen);

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 17, color: iconColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
