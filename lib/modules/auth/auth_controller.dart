import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/app_preferences_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/glass_widgets.dart';
import '../../data/models/profile_model.dart';

/// Live state of the `@username` availability check.
enum UsernameStatus { idle, invalid, checking, available, taken, error }

/// Handles: Email → OTP → (Home | Setup profile).
class AuthController extends GetxController {
  // ---------------------------------------------------------------------------
  // Text inputs
  // ---------------------------------------------------------------------------
  final TextEditingController emailController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  final TextEditingController displayNameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final FocusNode otpFocusNode = FocusNode();

  // ---------------------------------------------------------------------------
  // Email step
  // ---------------------------------------------------------------------------
  final RxString email = ''.obs;
  final RxString emailError = ''.obs;
  final RxBool isSendingOtp = false.obs;

  // ---------------------------------------------------------------------------
  // OTP step
  // ---------------------------------------------------------------------------
  final RxString otpCode = ''.obs;
  final RxString otpError = ''.obs;
  final RxBool isVerifying = false.obs;
  final RxBool isResending = false.obs;
  final RxInt resendCountdown = 0.obs;
  Timer? _resendTimer;

  // ---------------------------------------------------------------------------
  // Setup profile step
  // ---------------------------------------------------------------------------
  final RxString displayName = ''.obs;
  final RxString username = ''.obs;
  final Rx<UsernameStatus> usernameStatus = UsernameStatus.idle.obs;
  final RxBool isSavingProfile = false.obs;
  final Rx<Uint8List?> avatarBytes = Rx<Uint8List?>(null);
  final RxBool isUploadingAvatar = false.obs;
  Worker? _usernameWorker;

  // ---------------------------------------------------------------------------
  // Derived getters (read inside Obx)
  // ---------------------------------------------------------------------------
  bool get isEmailValid =>
      SupabaseConstants.emailRegex.hasMatch(email.value.trim());

  bool get isOtpComplete =>
      otpCode.value.length == SupabaseConstants.otpLength;

  bool get canSaveProfile =>
      displayName.value.trim().isNotEmpty &&
      usernameStatus.value == UsernameStatus.available &&
      !isSavingProfile.value;

  /// `mm:ss` label for the resend countdown.
  String get resendCountdownLabel {
    final int total = resendCountdown.value;
    final String m = (total ~/ 60).toString().padLeft(2, '0');
    final String s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get usernameStatusMessage {
    switch (usernameStatus.value) {
      case UsernameStatus.idle:
        return '';
      case UsernameStatus.invalid:
        return username.value.length < SupabaseConstants.usernameMinLength
            ? 'يجب أن يتكوّن اسم المستخدم من ${SupabaseConstants.usernameMinLength} أحرف على الأقل'
            : 'مسموح فقط بالأحرف الإنجليزية الصغيرة والأرقام والشرطة السفلية _';
      case UsernameStatus.checking:
        return 'جارٍ التحقق من توفّر الاسم...';
      case UsernameStatus.available:
        return 'رائع! @${username.value} متاح لك';
      case UsernameStatus.taken:
        return 'هذا الاسم محجوز، جرّب اسماً آخر';
      case UsernameStatus.error:
        return 'تعذّر التحقق من الاسم، تأكّد من اتصالك بالإنترنت';
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  @override
  void onInit() {
    super.onInit();

    // When the app starts directly on /setup-profile, recover the email.
    final String? currentEmail = supabase.auth.currentUser?.email;
    if (currentEmail != null && currentEmail.isNotEmpty) {
      email.value = currentEmail;
      emailController.text = currentEmail;
    }

    // Live availability check while typing (GetX debounce).
    _usernameWorker = debounce<String>(
      username,
      _checkUsernameAvailability,
      time: const Duration(milliseconds: 500),
    );
  }

  @override
  void onClose() {
    _resendTimer?.cancel();
    _usernameWorker?.dispose();
    emailController.dispose();
    otpController.dispose();
    displayNameController.dispose();
    usernameController.dispose();
    otpFocusNode.dispose();
    super.onClose();
  }

  // ===========================================================================
  // 1) EMAIL → send OTP
  // ===========================================================================
  void onEmailChanged(String value) {
    email.value = value.trim();
    if (emailError.value.isNotEmpty) emailError.value = '';
  }

  Future<void> sendOtp() async {
    if (isSendingOtp.value) return;
    FocusManager.instance.primaryFocus?.unfocus();

    final String value = emailController.text.trim().toLowerCase();
    email.value = value;

    if (!SupabaseConstants.emailRegex.hasMatch(value)) {
      emailError.value = 'يرجى إدخال بريد إلكتروني صحيح';
      return;
    }
    emailError.value = '';
    isSendingOtp.value = true;

    try {
      await supabase.auth.signInWithOtp(
        email: value,
        shouldCreateUser: true,
      );

      _clearOtp();
      _startResendTimer();

      if (Get.currentRoute != AppRoutes.otp) {
        Get.toNamed(AppRoutes.otp);
      }
    } on AuthException catch (e) {
      _showError(_mapAuthError(e));
    } catch (_) {
      _showError('حدث خطأ غير متوقع، حاول مرة أخرى');
    } finally {
      isSendingOtp.value = false;
    }
  }

  // ===========================================================================
  // 2) OTP → verify
  // ===========================================================================
  void onOtpChanged(String value) {
    otpCode.value = value;
    if (otpError.value.isNotEmpty) otpError.value = '';
  }

  Future<void> verifyOtp([String? code]) async {
    if (isVerifying.value) return;

    final String token = (code ?? otpController.text).trim();
    if (token.length != SupabaseConstants.otpLength) {
      otpError.value = 'أدخل الرمز المكوّن من ${SupabaseConstants.otpLength} أرقام';
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    otpError.value = '';
    isVerifying.value = true;

    try {
      final AuthResponse response = await supabase.auth.verifyOTP(
        email: email.value,
        token: token,
        type: OtpType.email,
      );

      if (response.session == null || response.user == null) {
        throw const AuthException('otp_expired');
      }

      _resendTimer?.cancel();
      resendCountdown.value = 0;

      await _routeAfterAuth();
    } on AuthException catch (e) {
      otpError.value = _mapAuthError(e);
      _clearOtp();
      otpFocusNode.requestFocus();
    } on PostgrestException catch (e) {
      _showError('تعذّر تحميل ملفك الشخصي: ${e.message}');
    } catch (_) {
      otpError.value = 'حدث خطأ غير متوقع، حاول مرة أخرى';
    } finally {
      isVerifying.value = false;
    }
  }

  Future<void> resendOtp() async {
    if (resendCountdown.value > 0 || isResending.value) return;
    if (!SupabaseConstants.emailRegex.hasMatch(email.value)) {
      backToEmail();
      return;
    }

    isResending.value = true;
    try {
      await supabase.auth.signInWithOtp(
        email: email.value,
        shouldCreateUser: true,
      );
      _clearOtp();
      _startResendTimer();
      _showSuccess('تم إرسال رمز جديد إلى بريدك الإلكتروني');
    } on AuthException catch (e) {
      _showError(_mapAuthError(e));
    } catch (_) {
      _showError('حدث خطأ غير متوقع، حاول مرة أخرى');
    } finally {
      isResending.value = false;
    }
  }

  void backToEmail() {
    _clearOtp();
    if (Get.previousRoute == AppRoutes.email) {
      Get.back<void>();
    } else {
      Get.offAllNamed(AppRoutes.email);
    }
  }

  /// After a successful OTP: existing user → /home, new user → /setup-profile.
  Future<void> _routeAfterAuth() async {
    final User? user = supabase.auth.currentUser;
    if (user == null) {
      throw const AuthException('session_not_found');
    }

    final Map<String, dynamic>? profile = await supabase
        .from(SupabaseConstants.profilesTable)
        .select()
        .eq('id', user.id)
        .maybeSingle();

    final String? existingUsername = profile?['username'] as String?;

    if (profile != null &&
        existingUsername != null &&
        existingUsername.trim().isNotEmpty) {
      final ProfileModel parsed = ProfileModel.fromJson(profile);
      if (Get.isRegistered<AppPreferencesService>()) {
        await AppPreferencesService.to.saveUserSession(parsed);
      }
      Get.offAllNamed(AppRoutes.home);
      _disposeAfterLeavingAuth();
    } else {
      if (Get.isRegistered<AppPreferencesService>()) {
        await AppPreferencesService.to.markLoggedIn(user.id);
      }
      email.value = user.email ?? email.value;
      Get.offAllNamed(AppRoutes.setupProfile);
    }
  }

  // ===========================================================================
  // 3) SETUP PROFILE
  // ===========================================================================
  void onDisplayNameChanged(String value) {
    displayName.value = value;
  }

  void onUsernameChanged(String value) {
    final String normalized = value.trim().toLowerCase();
    username.value = normalized;

    if (normalized.isEmpty) {
      usernameStatus.value = UsernameStatus.idle;
    } else if (!SupabaseConstants.usernameRegex.hasMatch(normalized)) {
      usernameStatus.value = UsernameStatus.invalid;
    } else {
      // The real request is fired by the debounce worker.
      usernameStatus.value = UsernameStatus.checking;
    }
  }

  Future<void> _checkUsernameAvailability(String value) async {
    if (value.isEmpty || !SupabaseConstants.usernameRegex.hasMatch(value)) {
      return;
    }

    try {
      final Map<String, dynamic>? row = await supabase
          .from(SupabaseConstants.profilesTable)
          .select('id')
          .eq('username', value)
          .maybeSingle();

      // Ignore stale responses (user kept typing).
      if (value != username.value) return;

      final String? myId = supabase.auth.currentUser?.id;
      usernameStatus.value = (row == null || row['id'] == myId)
          ? UsernameStatus.available
          : UsernameStatus.taken;
    } catch (_) {
      if (value == username.value) {
        usernameStatus.value = UsernameStatus.error;
      }
    }
  }

  Future<void> pickAvatar(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
      );
      if (picked == null) return;
      final Uint8List bytes = await picked.readAsBytes();
      if (bytes.isNotEmpty) {
        avatarBytes.value = bytes;
      }
    } catch (_) {}
  }

  void showAvatarPickerSheet() {
    final bool isAr = Get.isRegistered<AppPreferencesService>()
        ? AppPreferencesService.to.isArabic
        : true;
    Get.bottomSheet(
      GlassBottomSheet(
        title: isAr ? 'صورة الملف الشخصي' : 'Profile Picture',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading:
                    const Icon(Icons.camera_alt_rounded, color: AppColors.aqua),
                title: Text(
                  isAr
                      ? 'التقاط صورة بالكاميرا 📷'
                      : 'Take a photo with camera 📷',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () {
                  Get.back<void>();
                  pickAvatar(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: AppColors.aqua,
                ),
                title: Text(
                  isAr
                      ? 'اختيار صورة من المعرض 🖼️'
                      : 'Choose photo from gallery 🖼️',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () {
                  Get.back<void>();
                  pickAvatar(ImageSource.gallery);
                },
              ),
              if (avatarBytes.value != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                  title: Text(
                    isAr ? 'إزالة الصورة' : 'Remove picture',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                  onTap: () {
                    Get.back<void>();
                    avatarBytes.value = null;
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> saveProfile() async {
    if (isSavingProfile.value) return;
    FocusManager.instance.primaryFocus?.unfocus();

    final User? user = supabase.auth.currentUser;
    if (user == null) {
      _showError('انتهت الجلسة، يرجى تسجيل الدخول من جديد');
      await signOutAndRestart();
      return;
    }

    final String name = displayNameController.text.trim();
    final String handle = usernameController.text.trim().toLowerCase();

    if (name.isEmpty) {
      _showError('يرجى إدخال الاسم الظاهر');
      return;
    }
    if (name.length > 50) {
      _showError('الاسم الظاهر يجب ألا يتجاوز 50 حرفاً');
      return;
    }
    if (!SupabaseConstants.usernameRegex.hasMatch(handle)) {
      usernameStatus.value = UsernameStatus.invalid;
      return;
    }

    isSavingProfile.value = true;
    try {
      // Final server-side availability check right before saving.
      final Map<String, dynamic>? existing = await supabase
          .from(SupabaseConstants.profilesTable)
          .select('id')
          .eq('username', handle)
          .maybeSingle();

      if (existing != null && existing['id'] != user.id) {
        usernameStatus.value = UsernameStatus.taken;
        _showError('اسم المستخدم @$handle محجوز بالفعل');
        return;
      }

      final String resolvedEmail = (user.email ?? email.value).toLowerCase();
      final DateTime now = DateTime.now();

      String? avatarUrl;
      final Uint8List? bytes = avatarBytes.value;
      if (bytes != null && bytes.isNotEmpty) {
        try {
          final String path =
              '${user.id}/avatar_${now.millisecondsSinceEpoch}.jpg';
          await supabase.storage
              .from(SupabaseConstants.avatarsBucket)
              .uploadBinary(
                path,
                bytes,
                fileOptions: const FileOptions(
                  contentType: 'image/jpeg',
                  upsert: true,
                ),
              );
          avatarUrl = supabase.storage
              .from(SupabaseConstants.avatarsBucket)
              .getPublicUrl(path);
        } catch (_) {
          avatarUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        }
      }

      final Map<String, dynamic> upsertData = <String, dynamic>{
        'id': user.id,
        'email': resolvedEmail,
        'username': handle,
        'display_name': name,
        'is_online': true,
        'last_seen': now.toUtc().toIso8601String(),
      };
      if (avatarUrl != null) {
        upsertData['avatar_url'] = avatarUrl;
      }

      await supabase.from(SupabaseConstants.profilesTable).upsert(
        upsertData,
        onConflict: 'id',
      );

      final ProfileModel savedProfile = ProfileModel(
        id: user.id,
        email: resolvedEmail,
        username: handle,
        displayName: name,
        avatarUrl: avatarUrl,
        isOnline: true,
        isProfileDiscoverable: true,
        lastSeen: now,
      );
      if (Get.isRegistered<AppPreferencesService>()) {
        await AppPreferencesService.to.saveUserSession(savedProfile);
      }

      Get.offAllNamed(AppRoutes.home);
      _disposeAfterLeavingAuth();
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // unique_violation → someone took the username a moment ago
        usernameStatus.value = UsernameStatus.taken;
        _showError('اسم المستخدم @$handle محجوز بالفعل');
      } else if (e.code == '23514') {
        // check_violation
        usernameStatus.value = UsernameStatus.invalid;
        _showError('البيانات المدخلة غير صالحة');
      } else {
        _showError('تعذّر حفظ الملف الشخصي: ${e.message}');
      }
    } catch (_) {
      _showError('حدث خطأ غير متوقع، حاول مرة أخرى');
    } finally {
      isSavingProfile.value = false;
    }
  }

  /// Leaves the setup screen and returns to the email screen.
  Future<void> signOutAndRestart() async {
    try {
      await supabase.auth.signOut();
    } catch (_) {
      // Even if the network call fails the local session is cleared.
    }
    if (Get.isRegistered<AppPreferencesService>()) {
      await AppPreferencesService.to.destroyUserSession();
    }
    _resetState();
    Get.offAllNamed(AppRoutes.email);
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================
  void _startResendTimer() {
    _resendTimer?.cancel();
    resendCountdown.value = SupabaseConstants.otpResendSeconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (resendCountdown.value <= 1) {
        resendCountdown.value = 0;
        t.cancel();
      } else {
        resendCountdown.value--;
      }
    });
  }

  void _clearOtp() {
    otpController.clear();
    otpCode.value = '';
    otpError.value = '';
  }

  void _resetState() {
    _resendTimer?.cancel();
    resendCountdown.value = 0;

    emailController.clear();
    email.value = '';
    emailError.value = '';

    _clearOtp();

    displayNameController.clear();
    usernameController.clear();
    displayName.value = '';
    username.value = '';
    usernameStatus.value = UsernameStatus.idle;

    isSendingOtp.value = false;
    isVerifying.value = false;
    isResending.value = false;
    isSavingProfile.value = false;
  }

  /// The auth flow is finished: free this permanent controller once the auth
  /// screens have been removed from the tree (after the route transition).
  void _disposeAfterLeavingAuth() {
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (Get.isRegistered<AuthController>()) {
        Get.delete<AuthController>(force: true);
      }
    });
  }

  String _mapAuthError(AuthException e) {
    final String code = (e.code ?? '').toLowerCase();
    final String message = e.message.toLowerCase();

    if (e is AuthRetryableFetchException) {
      return 'تعذّر الاتصال بالخادم، تحقّق من اتصالك بالإنترنت';
    }
    if (e.statusCode == '429' ||
        code.contains('rate_limit') ||
        message.contains('rate limit') ||
        message.contains('security purposes')) {
      return 'محاولات كثيرة، يرجى الانتظار قليلاً ثم المحاولة مجدداً';
    }
    if (code == 'email_address_invalid' || code == 'validation_failed') {
      return 'البريد الإلكتروني غير صالح';
    }
    if (code == 'otp_expired' ||
        message.contains('otp_expired') ||
        message.contains('expired') ||
        message.contains('invalid') ||
        message.contains('token')) {
      return 'الرمز غير صحيح أو انتهت صلاحيته';
    }
    if (code == 'session_not_found' || message.contains('session_not_found')) {
      return 'انتهت الجلسة، يرجى المحاولة من جديد';
    }
    return e.message;
  }

  void _showError(String message) {
    _showSnack(
      title: 'تعذّر إتمام العملية',
      message: message,
      icon: Icons.error_outline_rounded,
      iconColor: AppColors.error,
    );
  }

  void _showSuccess(String message) {
    _showSnack(
      title: 'تم بنجاح',
      message: message,
      icon: Icons.check_circle_rounded,
      iconColor: AppColors.online,
    );
  }

  void _showSnack({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
  }) {
    if (Get.isSnackbarOpen) {
      Get.closeAllSnackbars();
    }
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: const Color(0xEB0B2147),
      colorText: Colors.white,
      icon: Icon(icon, color: iconColor),
      margin: const EdgeInsets.all(16),
      borderRadius: 16,
      duration: const Duration(seconds: 3),
      animationDuration: const Duration(milliseconds: 300),
    );
  }
}
