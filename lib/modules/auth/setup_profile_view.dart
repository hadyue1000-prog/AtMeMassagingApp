import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/constants/supabase_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo_widget.dart';
import '../../core/widgets/glass_widgets.dart';
import 'auth_controller.dart';

/// Step 3 (New users only): Glassmorphism profile setup screen.
class SetupProfileView extends GetView<AuthController> {
  const SetupProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return GlassScaffoldBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text('setup_account_title'.tr),
          actions: <Widget>[
            TextButton.icon(
              onPressed: controller.signOutAndRestart,
              icon: Icon(
                Icons.logout_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              label: Text(
                'switch_account'.tr,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: GlassCard(
                  borderRadius: 28,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Center(
                        child: AppLogoWidget(size: 76, showName: false),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'complete_profile_title'.tr,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'complete_profile_subtitle'.tr,
                        textAlign: TextAlign.center,
                        style:
                            theme.textTheme.bodyMedium?.copyWith(fontSize: 14.5),
                      ),
                      const SizedBox(height: 22),

                      // Live preview glass card
                      Obx(() {
                        final String name =
                            controller.displayName.value.trim().isEmpty
                                ? 'display_name_label'.tr
                                : controller.displayName.value.trim();
                        final String handle =
                            controller.username.value.trim().isEmpty
                                ? 'username'
                                : controller.username.value.trim();

                        return GlassCard(
                          borderRadius: 20,
                          isHighlighted: true,
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 50,
                                height: 50,
                                decoration: const BoxDecoration(
                                  gradient: AppColors.cyanButtonGradient,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _extractInitial(name),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: Text(
                                        '@$handle',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.aqua,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 22),

                      // Display Name Input
                      Text(
                        'display_name_label'.tr,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Obx(
                        () => TextField(
                          key: const Key('display_name_input'),
                          controller: controller.displayNameController,
                          enabled: !controller.isSavingProfile.value,
                          textInputAction: TextInputAction.next,
                          maxLength: 50,
                          onChanged: controller.onDisplayNameChanged,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'display_name_hint'.tr,
                            counterText: '',
                            prefixIcon: const Icon(Icons.person_outline_rounded),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // @username Input
                      Text(
                        'username_label'.tr,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Obx(() {
                        final UsernameStatus status =
                            controller.usernameStatus.value;

                        return Directionality(
                          textDirection: TextDirection.ltr,
                          child: TextField(
                            key: const Key('username_input'),
                            controller: controller.usernameController,
                            enabled: !controller.isSavingProfile.value,
                            textInputAction: TextInputAction.done,
                            autocorrect: false,
                            enableSuggestions: false,
                            maxLength: SupabaseConstants.usernameMaxLength,
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z0-9_]'),
                              ),
                              _LowerCaseTextFormatter(),
                            ],
                            onChanged: controller.onUsernameChanged,
                            onSubmitted: (_) {
                              if (controller.canSaveProfile) {
                                controller.saveProfile();
                              }
                            },
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'ahmed_dev',
                              counterText: '',
                              prefixIcon: const Icon(
                                Icons.alternate_email_rounded,
                                color: AppColors.aqua,
                              ),
                              suffixIcon: _UsernameSuffixIcon(status: status),
                              enabledBorder: _borderForStatus(status),
                              focusedBorder:
                                  _borderForStatus(status, focused: true),
                            ),
                          ),
                        );
                      }),

                      // Live availability feedback
                      Obx(() {
                        final UsernameStatus status =
                            controller.usernameStatus.value;
                        final String message = controller.usernameStatusMessage;

                        if (status == UsernameStatus.idle || message.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'username_rules'.tr,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        }

                        final Color color = _colorForStatus(status);

                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                _iconForStatus(status),
                                size: 17,
                                color: color,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  message,
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 28),

                      // Glowing Submit Button
                      Obx(
                        () => GlowingCyanButton(
                          key: const Key('save_profile_button'),
                          label: 'save_and_start'.tr,
                          icon: Icons.check_circle_outline_rounded,
                          enabled: controller.canSaveProfile,
                          loading: controller.isSavingProfile.value,
                          onPressed: controller.saveProfile,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _extractInitial(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) return '@';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  static OutlineInputBorder? _borderForStatus(
    UsernameStatus status, {
    bool focused = false,
  }) {
    final double width = focused ? 1.8 : 1.3;
    switch (status) {
      case UsernameStatus.available:
        return OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(color: AppColors.online, width: width),
        );
      case UsernameStatus.taken:
      case UsernameStatus.invalid:
      case UsernameStatus.error:
        return OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(color: AppColors.error, width: width),
        );
      case UsernameStatus.idle:
      case UsernameStatus.checking:
        return null;
    }
  }

  static Color _colorForStatus(UsernameStatus status) {
    switch (status) {
      case UsernameStatus.available:
        return AppColors.online;
      case UsernameStatus.checking:
        return AppColors.aqua;
      case UsernameStatus.invalid:
      case UsernameStatus.taken:
      case UsernameStatus.error:
        return AppColors.error;
      case UsernameStatus.idle:
        return AppColors.textSecondary;
    }
  }

  static IconData _iconForStatus(UsernameStatus status) {
    switch (status) {
      case UsernameStatus.available:
        return Icons.check_circle_rounded;
      case UsernameStatus.checking:
        return Icons.hourglass_top_rounded;
      case UsernameStatus.invalid:
      case UsernameStatus.taken:
      case UsernameStatus.error:
        return Icons.cancel_rounded;
      case UsernameStatus.idle:
        return Icons.info_outline_rounded;
    }
  }
}

class _UsernameSuffixIcon extends StatelessWidget {
  const _UsernameSuffixIcon({required this.status});

  final UsernameStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case UsernameStatus.checking:
        return const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.aqua,
            ),
          ),
        );
      case UsernameStatus.available:
        return const Icon(Icons.check_circle_rounded, color: AppColors.online);
      case UsernameStatus.taken:
      case UsernameStatus.invalid:
      case UsernameStatus.error:
        return const Icon(Icons.error_rounded, color: AppColors.error);
      case UsernameStatus.idle:
        return const SizedBox.shrink();
    }
  }
}

class _LowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toLowerCase());
  }
}
