import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/constants/supabase_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo_widget.dart';
import '../../core/widgets/glass_widgets.dart';
import 'auth_controller.dart';
import 'widgets/otp_pin_field.dart';

/// Step 2: Glassmorphism 6-digit OTP verification screen.
class OtpView extends GetView<AuthController> {
  const OtpView({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return GlassScaffoldBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: controller.backToEmail,
          ),
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
                        child: AppLogoWidget(size: 80, showName: false),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'verify_email_title'.tr,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'verify_email_subtitle'.tr,
                        textAlign: TextAlign.center,
                        style:
                            theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Obx(
                          () => GlassCard(
                            borderRadius: 999,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.mail_outline_rounded,
                                  size: 16,
                                  color: AppColors.aqua,
                                ),
                                const SizedBox(width: 6),
                                Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(
                                    controller.email.value,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: controller.backToEmail,
                                  borderRadius: BorderRadius.circular(999),
                                  child: Text(
                                    'edit'.tr,
                                    style: const TextStyle(
                                      color: AppColors.aqua,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // 6-digit OTP Input
                      Obx(() {
                        final bool hasError =
                            controller.otpError.value.trim().isNotEmpty;
                        final bool busy = controller.isVerifying.value;

                        return Directionality(
                          textDirection: TextDirection.ltr,
                          child: Center(
                            child: OtpPinField(
                              key: const Key('otp_pinput'),
                              length: SupabaseConstants.otpLength,
                              controller: controller.otpController,
                              focusNode: controller.otpFocusNode,
                              enabled: !busy,
                              autofocus: true,
                              hasError: hasError,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: controller.onOtpChanged,
                              onCompleted: controller.verifyOtp,
                            ),
                          ),
                        );
                      }),

                      // Error banner
                      Obx(() {
                        final String err = controller.otpError.value;
                        if (err.isEmpty) {
                          return const SizedBox(height: 12);
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 17,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  err,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 24),

                      // Glowing Verify Button
                      Obx(() {
                        final bool enabled = controller.isOtpComplete &&
                            !controller.isVerifying.value;
                        final bool loading = controller.isVerifying.value;

                        return GlowingCyanButton(
                          key: const Key('verify_otp_button'),
                          label: 'verify_otp_btn'.tr,
                          icon: Icons.verified_rounded,
                          enabled: enabled,
                          loading: loading,
                          onPressed: () => controller.verifyOtp(),
                        );
                      }),

                      const SizedBox(height: 20),

                      // Resend countdown / action
                      Obx(() {
                        final int seconds = controller.resendCountdown.value;
                        final bool resending = controller.isResending.value;

                        if (resending) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                ),
                              ),
                            ),
                          );
                        }

                        if (seconds > 0) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(
                                Icons.timer_outlined,
                                size: 17,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'resend_in'.tr,
                                style: theme.textTheme.bodyMedium,
                              ),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  controller.resendCountdownLabel,
                                  style: const TextStyle(
                                    color: AppColors.aqua,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        return Center(
                          child: TextButton.icon(
                            onPressed: controller.resendOtp,
                            icon: const Icon(Icons.refresh_rounded, size: 19),
                            label: Text('resend_code'.tr),
                          ),
                        );
                      }),
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
}
