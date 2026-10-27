import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo_widget.dart';
import '../../core/widgets/glass_widgets.dart';
import 'auth_controller.dart';

/// Step 1: Glassmorphism Email-OTP sign-in screen.
class EmailView extends GetView<AuthController> {
  const EmailView({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return GlassScaffoldBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Center(
                      child: AppLogoWidget(size: 100, showName: true),
                    ),
                    const SizedBox(height: 28),
                    GlassCard(
                      borderRadius: 28,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            'welcome_title'.tr,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'welcome_subtitle'.tr,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'email_label'.tr,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Obx(
                            () => Directionality(
                              textDirection: TextDirection.ltr,
                              child: TextField(
                                key: const Key('email_input'),
                                controller: controller.emailController,
                                enabled: !controller.isSendingOtp.value,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                autofillHints: const <String>[
                                  AutofillHints.email,
                                ],
                                autocorrect: false,
                                enableSuggestions: false,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                onChanged: controller.onEmailChanged,
                                onSubmitted: (_) => controller.sendOtp(),
                                decoration: InputDecoration(
                                  hintText: 'name@example.com',
                                  prefixIcon: const Icon(
                                    Icons.alternate_email_rounded,
                                  ),
                                  enabledBorder:
                                      controller.emailError.value.isNotEmpty
                                          ? OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                AppTheme.radiusMedium,
                                              ),
                                              borderSide: const BorderSide(
                                                color: AppColors.error,
                                              ),
                                            )
                                          : null,
                                ),
                              ),
                            ),
                          ),
                          Obx(
                            () => _AnimatedError(
                              message: controller.emailError.value,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Obx(
                            () => GlowingCyanButton(
                              key: const Key('send_otp_button'),
                              label: 'send_otp_btn'.tr,
                              icon: Icons.send_rounded,
                              loading: controller.isSendingOtp.value,
                              enabled: controller.isEmailValid,
                              onPressed: controller.sendOtp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    GlassCard(
                      borderRadius: 20,
                      
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(
                            Icons.verified_user_rounded,
                            color: AppColors.aqua,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'privacy_note'.tr,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedError extends StatelessWidget {
  const _AnimatedError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: message.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 8, right: 4, left: 4),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
