import 'package:get/get.dart';

import 'auth_controller.dart';

/// Shared binding for /email, /otp and /setup-profile.
///
/// The controller is registered as `permanent` so the SAME instance (email,
/// OTP timer, typed values) survives `Get.offAllNamed(AppRoutes.setupProfile)`.
/// It removes itself once the user reaches /home (see
/// `AuthController._disposeAfterLeavingAuth`).
class AuthBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AuthController>()) {
      Get.put<AuthController>(AuthController(), permanent: true);
    }
  }
}
