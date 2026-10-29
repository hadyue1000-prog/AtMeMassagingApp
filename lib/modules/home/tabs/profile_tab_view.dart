import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/routes/app_routes.dart';
import '../../../core/services/app_preferences_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_widgets.dart';
import '../../../core/widgets/other_user_profile_sheet.dart';
import '../../../data/models/profile_model.dart';
import '../home_controller.dart';

/// Dedicated Glassmorphism Profile Screen matching the right-hand phone in the
/// visual reference:
/// - Large glowing circular avatar with camera/status badge
/// - Display Name + `@username` handle pill
/// - Frosted glass status pill (`دائماً نحو الأفضل 🌟` or user's active status)
/// - Frosted glass editable personal info card (`الاسم الظاهر`, `النبذة الشخصية`)
/// - Frosted glass account details card (`@username`, `البريد الإلكتروني`, `تاريخ الانضمام`)
class ProfileTabView extends GetView<HomeController> {
  const ProfileTabView({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ProfileModel? profile = controller.myProfile.value;
      final bool _ = Get.isRegistered<AppPreferencesService>()
          ? AppPreferencesService.to.isDarkMode.value
          : true;
      final String lang = Get.isRegistered<AppPreferencesService>()
          ? AppPreferencesService.to.languageCode.value
          : 'ar';

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: <Widget>[
          // 1) Profile Cover Background Banner + Glowing Avatar + @handle
          GlassCard(
            borderRadius: 26,
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                // Cover Background Image / Gradient Header
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: <Widget>[

                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(26),
                      ),

                      child: SizedBox(
                        height: 125,
                        width: double.infinity,
                      
                      ),
                    ),

                    // Overlapping Avatar with Camera update button
                    Positioned(
                      bottom: -46,
                      child: GestureDetector(
                        onTap: controller.showAvatarOptionsSheet,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: <Widget>[
                            Container(
                              width: 150,
                              height: 150,
                              padding: const EdgeInsets.all(3.0),

                              child: ClipOval(
                                child: buildUniversalAvatarImage(
                                  imageUrl: profile?.avatarUrl,
                                  fallbackText: profile?.displayName ?? '@',
                                  radius: 46,
                                ),
                              ),
                            ),
                            if (controller.isUploadingAvatar.value)
                              Container(
                                width: 130,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.8,
                                    color: AppColors.aqua,
                                  ),
                                ),
                              ),
                            PositionedDirectional(
                              bottom: 0,
                              end: 0,
                              child: Container(
                                width: 50,
                                height: 34,
                                decoration: BoxDecoration(
                                  gradient: AppColors.cyanButtonGradient,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 17,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 54),

                // Display Name
                Text(
                  profile?.displayName ?? '@Me',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),

                // Copyable @username
                if (profile != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: controller.copyMyUsername,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              profile.handle,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: AppColors.aqua,
                          ),
                        ],
                      ),
                    ),
                  ),


             

                const SizedBox(height: 12),

                
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2) Editable Personal Information Glass Card
          GlassCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.badge_outlined,
                      color: AppColors.aqua,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'personal_info'.tr,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Display Name Input
                Text(
                  'display_name_label'.tr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: controller.profileDisplayNameController,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    hintText: 'display_name_hint'.tr,
                  ),
                ),
                const SizedBox(height: 16),

                // Bio Input
                Text(
                  'bio_label'.tr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: controller.profileBioController,
                  maxLines: 3,
                  maxLength: 140,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.info_outline_rounded),
                    hintText: 'bio_hint'.tr,
                  ),
                ),
                const SizedBox(height: 10),

                // Glowing Save Button
                Obx(
                  () => SizedBox(
                    width: double.infinity,
                    child: GlowingCyanButton(
                      label: 'save_changes'.tr,
                      icon: Icons.check_circle_outline_rounded,
                      loading: controller.isSavingProfileEdit.value,
                      onPressed: controller.saveProfileFromTab,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2.5) Private Invite Code & Link Card (Works even when Hidden Mode is enabled!)
          if (profile != null) ...<Widget>[
            GlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.qr_code_2_rounded,
                        color: AppColors.aqua,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lang == 'ar'
                              ? 'إضافة الأصدقاء عبر الخاص (كود ورابط الدعوة)'
                              : 'Private Friend Invite Code & Link',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lang == 'ar'
                        ? 'شارك هذا الكود أو الرابط مع أصدقائك ليتمكنوا من إضافتك ومراسلتك عبر الخاص حتى لو كنت مفعّلاً وضع عدم الظهور.'
                        : 'Share this private code or link so friends can add and message you even when your account is hidden.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Private 8-char Code Box
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.electricCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.aqua.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.key_rounded,
                          color: AppColors.aqua,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                lang == 'ar'
                                    ? 'كود الإضافة الخاص بك'
                                    : 'Your Private Invite Code',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  profile.privateInviteCode,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.8,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: controller.copyMyPrivateCode,
                          icon: const Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: AppColors.aqua,
                          ),
                          label: Text(
                            lang == 'ar' ? 'نسخ الكود' : 'Copy Code',
                            style: const TextStyle(
                              color: AppColors.aqua,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Private Link Row + Enter Friend Code Action
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: controller.copyMyPrivateLink,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.aqua,
                            side: BorderSide(
                              color: AppColors.aqua.withValues(alpha: 0.45),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.link_rounded, size: 18),
                          label: Text(
                            lang == 'ar'
                                ? 'نسخ رابط الدعوة'
                                : 'Copy Invite Link',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Get.toNamed(AppRoutes.search),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: AppColors.electricCyan.withValues(
                              alpha: 0.22,
                            ),
                            side: BorderSide(
                              color: AppColors.aqua.withValues(alpha: 0.45),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 18,
                          ),
                          label: Text(
                            lang == 'ar'
                                ? 'إدخال كود صديق'
                                : 'Enter Friend Code',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // 3) Read-only Account Details Glass Card
          if (profile != null)
            GlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: <Widget>[
                  _AccountDetailRow(
                    icon: Icons.alternate_email_rounded,
                    label: 'account_id_readonly'.tr,
                    value: profile.handle,
                    isLtr: true,
                  ),
                  if ((profile.email ?? '').isNotEmpty) ...<Widget>[
                    Divider(height: 24, color: AppColors.divider),
                    _AccountDetailRow(
                      icon: Icons.email_outlined,
                      label: 'email_readonly'.tr,
                      value: profile.email!,
                      isLtr: true,
                    ),
                  ],
                  if (profile.createdAt != null) ...<Widget>[
                    Divider(height: 24, color: AppColors.divider),
                    _AccountDetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'member_since'.tr,
                      value: DateFormat(
                        'yyyy/MM/dd',
                        lang,
                      ).format(profile.createdAt!),
                      isLtr: false,
                    ),
                  ],
                ],
              ),
            ),

          // Active colored status preview if set
          if (profile != null && profile.hasActiveStatus) ...<Widget>[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: parseStatusColor(profile.latestStatusColor),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Text(
                profile.latestStatusDisplayText.isNotEmpty
                    ? profile.latestStatusDisplayText
                    : '📷 صورة حالة نشطة',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _AccountDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLtr;

  const _AccountDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isLtr,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.electricCyan.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppColors.aqua.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, color: AppColors.aqua, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Directionality(
                textDirection: isLtr
                    ? TextDirection.ltr
                    : Directionality.of(context),
                child: Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
