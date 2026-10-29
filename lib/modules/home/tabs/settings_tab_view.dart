import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/app_preferences_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../../data/models/profile_model.dart';
import '../home_controller.dart';

/// Glassmorphism Settings Screen closely matching the right-hand phone in the
/// visual reference:
/// - Compact hero header with user avatar, name, `@username`, and status pill
/// - Frosted glass settings group:
///   - الخصوصية والأمان (رؤية حسابي للأشخاص الآخرين)
///   - المظهر (الوضع الداكن / الفاتح)
///   - اللغة (`العربية` / `English`)
/// - Frosted glass Custom App Wallpaper section:
///   - معاينة حية للخلفية + زر رفع صورة من الجهاز + شريط التحكم بدرجة التعتيم + زر استعادة الافتراضية
/// - Frosted glass storage & offline group:
///   - حفظ المحادثات محلياً (Offline Mode)
///   - مسح الذاكرة المؤقتة المحلية
/// - Frosted glass red-accented "تسجيل الخروج" (`Sign Out`) pill button at the bottom
class SettingsTabView extends GetView<HomeController> {
  const SettingsTabView({super.key});

  void _confirmLogout(BuildContext context) {
    Get.dialog(
      GlassDialog(
        title: 'sign_out_confirm_title'.tr,
        message: 'sign_out_confirm_body'.tr,
        confirmLabel: 'sign_out'.tr,
        cancelLabel: 'cancel'.tr,
        isDestructive: true,
        onConfirm: controller.signOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPreferencesService prefs = AppPreferencesService.to;

    return Obx(() {
      final bool isDark = prefs.isDarkMode.value;
      final String currentLang = prefs.languageCode.value;
      final Uint8List? customBg = prefs.customBackgroundBytes.value;
      final String selectedPresetId = prefs.selectedWallpaperPresetId.value;
      final BuiltInWallpaperPreset activePreset = prefs.activeWallpaperPreset;
      final double bgDim = prefs.backgroundDim.value;
      final ProfileModel? me = controller.myProfile.value;

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
        children: <Widget>[
          // Top User Summary Header (Hides @username here; @username only appears in User Info)
          if (me != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: GlassCard(
                borderRadius: 24,
                padding: const EdgeInsets.all(16),
                onTap: () => controller.changeTab(2),
                child: Row(
                  children: <Widget>[
                    GestureDetector(
                      onTap: controller.showAvatarOptionsSheet,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(2.2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.cyanButtonGradient,
                            ),
                            child: ClipOval(
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: buildUniversalAvatarImage(
                                  imageUrl: me.avatarUrl,
                                  fallbackText: me.displayName,
                                  radius: 28,
                                ),
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            bottom: -1,
                            end: -1,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppColors.aqua,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 11,
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
                          Text(
                            me.displayName,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            me.bio.trim().isNotEmpty
                                ? me.bio
                                : 'profile_section_title'.tr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),

          // 1. Main Glass Settings Card (Privacy, Theme, Language) — Matches Reference Stack
          GlassCard(
            borderRadius: 24,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: <Widget>[
                // Privacy & Visibility Switch
                SwitchListTile(
                  secondary: _GlassLeadingIcon(
                    icon: prefs.isProfileDiscoverable.value
                        ? Icons.shield_rounded
                        : Icons.visibility_off_rounded,
                  ),
                  title: Text(
                    'discoverable_title'.tr,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    prefs.isProfileDiscoverable.value
                        ? 'discoverable_on_sub'.tr
                        : 'discoverable_off_sub'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  value: prefs.isProfileDiscoverable.value,
                  activeThumbColor: Colors.white,
                  onChanged: (bool val) =>
                      controller.toggleProfileDiscoverability(val),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppColors.divider,
                ),

                // Dark Mode Switch (Single clean place to toggle theme)
                SwitchListTile(
                  secondary: _GlassLeadingIcon(
                    icon: isDark
                        ? Icons.nightlight_round
                        : Icons.wb_sunny_rounded,
                  ),
                  title: Text(
                    'dark_mode_title'.tr,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    isDark ? 'dark_mode_on'.tr : 'dark_mode_off'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  value: isDark,
                  activeThumbColor: Colors.white,
                  onChanged: (bool val) => controller.toggleDarkMode(val),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppColors.divider,
                ),

                // Language Switcher (العربية / English)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const _GlassLeadingIcon(icon: Icons.language_rounded),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'language_title'.tr,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  prefs.isArabic
                                      ? 'lang_ar'.tr
                                      : 'lang_en'.tr,
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
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _LanguageOptionButton(
                              label: 'lang_ar'.tr,
                              isSelected: currentLang == 'ar',
                              onTap: () => controller.setLanguage('ar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _LanguageOptionButton(
                              label: 'lang_en'.tr,
                              isSelected: currentLang == 'en',
                              onTap: () => controller.setLanguage('en'),
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
          const SizedBox(height: 18),

          // 2. Custom App Wallpaper / Background Image Glass Card
          GlassCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _GlassLeadingIcon(
                      icon: Icons.wallpaper_rounded,
                      iconColor: isDark ? AppColors.aqua : AppColors.royalBlue,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'custom_bg_title'.tr,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'custom_bg_sub'.tr,
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
                const SizedBox(height: 16),

                // Live miniature preview of the active background + glass card overlay
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    height: 118,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        if (customBg != null && customBg.isNotEmpty)
                          Image.memory(
                            customBg,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          )
                        else
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: isDark
                                  ? activePreset.gradient
                                  : AppColors.lightScaffoldGradient,
                            ),
                          ),
                        if (customBg != null && customBg.isNotEmpty)
                          ColoredBox(
                            color: (isDark ? AppColors.deepNavy : Colors.white)
                                .withValues(alpha: bgDim * 0.85),
                          ),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                alpha: isDark ? 0.16 : 0.72,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  customBg != null
                                      ? Icons.photo_rounded
                                      : activePreset.icon,
                                  size: 18,
                                  color: isDark
                                      ? AppColors.aqua
                                      : AppColors.royalBlue,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  customBg != null
                                      ? (prefs.isArabic
                                            ? 'صورة مخصصة من المعرض'
                                            : 'Custom Gallery Photo')
                                      : (prefs.isArabic
                                            ? activePreset.titleAr
                                            : activePreset.titleEn),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Text(
                  prefs.isArabic
                      ? 'خلفيات التطبيق المدمجة (اختر خلفيتك المفضلة):'
                      : 'Built-in App Wallpapers:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                // Horizontal / Grid selector of Built-in Wallpapers
                SizedBox(
                  height: 98,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: AppPreferencesService.builtInWallpapers.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (BuildContext context, int idx) {
                      final BuiltInWallpaperPreset preset =
                          AppPreferencesService.builtInWallpapers[idx];
                      final bool isSelected =
                          (customBg == null || customBg.isEmpty) &&
                          selectedPresetId == preset.id;

                      return GestureDetector(
                        onTap: () =>
                            controller.selectBuiltInWallpaper(preset.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 92,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: preset.gradient,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.aqua
                                  : Colors.white.withValues(alpha: 0.25),
                              width: isSelected ? 2.4 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? <BoxShadow>[
                                    BoxShadow(
                                      color: preset.orbSecondary.withValues(
                                        alpha: 0.45,
                                      ),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Align(
                                alignment: AlignmentDirectional.topEnd,
                                child: isSelected
                                    ? Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: AppColors.aqua,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          size: 13,
                                          color: AppColors.deepNavy,
                                        ),
                                      )
                                    : Icon(
                                        preset.icon,
                                        size: 16,
                                        color: Colors.white70,
                                      ),
                              ),
                              Text(
                                prefs.isArabic
                                    ? preset.titleAr
                                    : preset.titleEn,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Dimming slider when a custom photo is active
                if (customBg != null && customBg.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'bg_dim_label'.tr,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          '${(bgDim * 100).round()}%',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.aqua
                                : AppColors.royalBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: bgDim.clamp(0.10, 0.85),
                    min: 0.10,
                    max: 0.85,
                    onChanged: controller.updateBackgroundDim,
                  ),
                ],

                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: GlowingCyanButton(
                        height: 46,
                        label: customBg != null
                            ? 'change_bg_btn'.tr
                            : 'upload_bg_btn'.tr,
                        icon: Icons.add_photo_alternate_rounded,
                        onPressed: controller.pickCustomBackgroundImage,
                      ),
                    ),
                    if ((customBg != null && customBg.isNotEmpty) ||
                        selectedPresetId != 'default') ...<Widget>[
                      const SizedBox(width: 10),
                      GlassIconButton(
                        size: 46,
                        icon: Icons.restore_rounded,
                        iconColor: AppColors.error,
                        tooltip: 'reset_bg_btn'.tr,
                        onTap: controller.resetCustomBackgroundImage,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3. Offline Storage & Cache Glass Card
          GlassCard(
            borderRadius: 24,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const _GlassLeadingIcon(
                    icon: Icons.offline_pin_rounded,
                    iconColor: AppColors.online,
                  ),
                  title: Text(
                    'offline_storage_title'.tr,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'offline_storage_sub'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppColors.divider,
                ),
                ListTile(
                  onTap: controller.clearLocalCache,
                  leading: _GlassLeadingIcon(
                    icon: Icons.cleaning_services_rounded,
                    iconColor: isDark ? AppColors.aqua : AppColors.royalBlue,
                  ),
                  title: Text(
                    'clear_local_cache'.tr,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'clear_local_cache_sub'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 4. Frosted Glass Sign Out Button (Matches bottom red button in reference)
          GlassCard(
            borderRadius: 999,
            borderColor: AppColors.error.withValues(alpha: 0.55),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            onTap: () => _confirmLogout(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                  size: 21,
                ),
                const SizedBox(width: 10),
                Text(
                  'sign_out'.tr,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _GlassLeadingIcon extends StatelessWidget {
  const _GlassLeadingIcon({
    required this.icon,
    this.iconColor,
  });

  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final Color fg = iconColor ??
        (AppColors.isDark ? Colors.white : AppColors.royalBlue);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: AppColors.isDark ? 0.10 : 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
      child: Icon(icon, color: fg, size: 20),
    );
  }
}

class _LanguageOptionButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOptionButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.cyanButtonGradient : null,
          color: isSelected
              ? null
              : Colors.white.withValues(alpha: AppColors.isDark ? 0.07 : 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.aqua
                : Colors.white.withValues(alpha: 0.25),
          ),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.electricCyan.withValues(alpha: 0.30),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (isSelected) ...<Widget>[
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
