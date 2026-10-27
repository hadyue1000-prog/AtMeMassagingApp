import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/profile_model.dart';
import '../theme/app_theme.dart';
import 'local_chat_cache_service.dart';

/// Preset built-in app wallpapers that users can pick alongside uploading a
/// custom photo from their device gallery.
class BuiltInWallpaperPreset {
  const BuiltInWallpaperPreset({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.colors,
    required this.orbPrimary,
    required this.orbSecondary,
    required this.icon,
  });

  final String id;
  final String titleAr;
  final String titleEn;
  final List<Color> colors;
  final Color orbPrimary;
  final Color orbSecondary;
  final IconData icon;

  String title(bool isArabic) => isArabic ? titleAr : titleEn;

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors,
      );
}

/// Manages local user session persistence, destruction on sign-out,
/// dark mode preference, language (Arabic / English), custom background
/// wallpaper image, built-in wallpaper presets, viewed status IDs,
/// cached user profile, pinned/muted chats, and starred messages.
class AppPreferencesService extends GetxService {
  static const String _keyIsLoggedIn = 'at_me_is_logged_in';
  static const String _keyUserId = 'at_me_user_id';
  static const String _keyUserProfileJson = 'at_me_user_profile_json';
  static const String _keyIsDarkMode = 'at_me_is_dark_mode';
  static const String _keyLanguageCode = 'at_me_language_code';
  static const String _keyIsProfileDiscoverable =
      'at_me_is_profile_discoverable';
  static const String _keyPinnedConversations =
      'at_me_pinned_conversation_ids';
  static const String _keyMutedConversations = 'at_me_muted_conversation_ids';
  static const String _keyStarredMessages = 'at_me_starred_message_ids';
  static const String _keyDraftMessages = 'at_me_draft_messages_json';
  static const String _keyCustomBackgroundBase64 =
      'at_me_custom_background_base64';
  static const String _keySelectedWallpaperPreset =
      'at_me_selected_wallpaper_preset';
  static const String _keyBackgroundDim = 'at_me_background_dim';
  static const String _keyViewedStatusKeys = 'at_me_viewed_status_keys';
  static const String _keyConversationWallpaperPresets =
      'at_me_conv_wallpaper_presets_json';
  static const String _keyConversationWallpaperBase64 =
      'at_me_conv_wallpaper_base64_json';
  static const String _keyProfileCoverBase64 = 'at_me_profile_cover_base64';

  /// 8 built-in artistic wallpapers available inside the app.
  static const List<BuiltInWallpaperPreset> builtInWallpapers =
      <BuiltInWallpaperPreset>[
    BuiltInWallpaperPreset(
      id: 'default',
      titleAr: 'الزجاج الملكي (الافتراضي)',
      titleEn: 'Royal Glass (Default)',
      colors: <Color>[Color(0xFF123D91), Color(0xFF0B2147), Color(0xFF07152E)],
      orbPrimary: Color(0xFF19D5F2),
      orbSecondary: Color(0xFFA77BFF),
      icon: Icons.auto_awesome_rounded,
    ),
    BuiltInWallpaperPreset(
      id: 'emerald_aurora',
      titleAr: 'شفق الزمرد الأخضر',
      titleEn: 'Emerald Aurora',
      colors: <Color>[Color(0xFF064E3B), Color(0xFF042F2E), Color(0xFF02171A)],
      orbPrimary: Color(0xFF10B981),
      orbSecondary: Color(0xFF2DD4BF),
      icon: Icons.eco_rounded,
    ),
    BuiltInWallpaperPreset(
      id: 'cosmic_amethyst',
      titleAr: 'المجرة البنفسجية',
      titleEn: 'Cosmic Amethyst',
      colors: <Color>[Color(0xFF3B0764), Color(0xFF1E1B4B), Color(0xFF09071D)],
      orbPrimary: Color(0xFFC084FC),
      orbSecondary: Color(0xFFF472B6),
      icon: Icons.nights_stay_rounded,
    ),
    BuiltInWallpaperPreset(
      id: 'sunset_horizon',
      titleAr: 'غروب صحراوي دافئ',
      titleEn: 'Desert Sunset',
      colors: <Color>[Color(0xFF7C2D12), Color(0xFF4C0519), Color(0xFF1A0510)],
      orbPrimary: Color(0xFFFB923C),
      orbSecondary: Color(0xFFF43F5E),
      icon: Icons.wb_twilight_rounded,
    ),
    BuiltInWallpaperPreset(
      id: 'ocean_abyss',
      titleAr: 'أعماق المحيط الهادئ',
      titleEn: 'Ocean Abyss',
      colors: <Color>[Color(0xFF0C4A6E), Color(0xFF082F49), Color(0xFF031424)],
      orbPrimary: Color(0xFF38BDF8),
      orbSecondary: Color(0xFF22D3EE),
      icon: Icons.water_rounded,
    ),
    BuiltInWallpaperPreset(
      id: 'crimson_velvet',
      titleAr: 'المخمل الياقوتي',
      titleEn: 'Crimson Velvet',
      colors: <Color>[Color(0xFF831843), Color(0xFF4A044E), Color(0xFF1A0322)],
      orbPrimary: Color(0xFFFB7185),
      orbSecondary: Color(0xFFE879F9),
      icon: Icons.favorite_rounded,
    ),
    BuiltInWallpaperPreset(
      id: 'midnight_gold',
      titleAr: 'ليل ذهبي فاخر',
      titleEn: 'Midnight Gold',
      colors: <Color>[Color(0xFF422006), Color(0xFF1C1917), Color(0xFF09090B)],
      orbPrimary: Color(0xFFFBBF24),
      orbSecondary: Color(0xFFF59E0B),
      icon: Icons.workspace_premium_rounded,
    ),
    BuiltInWallpaperPreset(
      id: 'cyber_neon',
      titleAr: 'نيون مستقبلي',
      titleEn: 'Cyber Neon',
      colors: <Color>[Color(0xFF1E1B4B), Color(0xFF0F172A), Color(0xFF020617)],
      orbPrimary: Color(0xFF00F5D4),
      orbSecondary: Color(0xFF9B5DE5),
      icon: Icons.bolt_rounded,
    ),
  ];

  SharedPreferences? _prefs;

  /// Defaults to `true` so the signature Deep Navy & Royal Blue Glassmorphism
  /// theme is active out of the box.
  final RxBool isDarkMode = true.obs;
  final RxString languageCode = 'ar'.obs;
  final RxBool isLoggedIn = false.obs;
  final RxBool isProfileDiscoverable = true.obs;
  final Rxn<ProfileModel> cachedProfile = Rxn<ProfileModel>();

  /// Reactive custom wallpaper image bytes (works across Web, Android, iOS, Desktop).
  final Rxn<Uint8List> customBackgroundBytes = Rxn<Uint8List>();

  /// Selected built-in wallpaper preset id (`default`, `emerald_aurora`, etc.).
  final RxString selectedWallpaperPresetId = 'default'.obs;

  /// Overlay dim opacity over custom background (`0.15` to `0.85`) so frosted
  /// glass cards and text remain crisp and readable on any photo.
  final RxDouble backgroundDim = 0.45.obs;

  final RxSet<String> pinnedConversationIds = <String>{}.obs;
  final RxSet<String> mutedConversationIds = <String>{}.obs;
  final RxSet<String> starredMessageIds = <String>{}.obs;
  final RxSet<String> viewedStatusKeys = <String>{}.obs;
  final RxMap<String, String> draftMessages = <String, String>{}.obs;
  final RxMap<String, String> conversationWallpaperPresets =
      <String, String>{}.obs;
  final RxMap<String, String> conversationWallpaperBase64 =
      <String, String>{}.obs;
  final Rxn<Uint8List> profileCoverBytes = Rxn<Uint8List>();

  static AppPreferencesService get to => Get.find<AppPreferencesService>();

  bool get isArabic => languageCode.value == 'ar';

  bool get hasCustomBackground =>
      customBackgroundBytes.value != null &&
      customBackgroundBytes.value!.isNotEmpty;

  BuiltInWallpaperPreset get activeWallpaperPreset {
    final String id = selectedWallpaperPresetId.value;
    for (final BuiltInWallpaperPreset p in builtInWallpapers) {
      if (p.id == id) return p;
    }
    return builtInWallpapers.first;
  }

  Locale get locale => Locale(languageCode.value);

  TextDirection get textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  Future<AppPreferencesService> init() async {
    _prefs = await SharedPreferences.getInstance();

    isDarkMode.value = _prefs?.getBool(_keyIsDarkMode) ?? true;
    languageCode.value = _prefs?.getString(_keyLanguageCode) ?? 'ar';
    Intl.defaultLocale = languageCode.value;

    backgroundDim.value = _prefs?.getDouble(_keyBackgroundDim) ?? 0.45;
    selectedWallpaperPresetId.value =
        _prefs?.getString(_keySelectedWallpaperPreset) ?? 'default';
    final String? rawBg = _prefs?.getString(_keyCustomBackgroundBase64);
    if (rawBg != null && rawBg.isNotEmpty) {
      try {
        customBackgroundBytes.value = base64Decode(rawBg);
      } catch (_) {
        customBackgroundBytes.value = null;
      }
    }

    isLoggedIn.value = _prefs?.getBool(_keyIsLoggedIn) ?? false;
    isProfileDiscoverable.value =
        _prefs?.getBool(_keyIsProfileDiscoverable) ?? true;

    pinnedConversationIds.assignAll(
      _prefs?.getStringList(_keyPinnedConversations) ?? const <String>[],
    );
    mutedConversationIds.assignAll(
      _prefs?.getStringList(_keyMutedConversations) ?? const <String>[],
    );
    starredMessageIds.assignAll(
      _prefs?.getStringList(_keyStarredMessages) ?? const <String>[],
    );
    viewedStatusKeys.assignAll(
      _prefs?.getStringList(_keyViewedStatusKeys) ?? const <String>[],
    );

    final String? rawCover = _prefs?.getString(_keyProfileCoverBase64);
    if (rawCover != null && rawCover.isNotEmpty) {
      try {
        profileCoverBytes.value = base64Decode(rawCover);
      } catch (_) {
        profileCoverBytes.value = null;
      }
    }

    final String? rawConvPresets =
        _prefs?.getString(_keyConversationWallpaperPresets);
    if (rawConvPresets != null && rawConvPresets.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded =
            jsonDecode(rawConvPresets) as Map<String, dynamic>;
        conversationWallpaperPresets.assignAll(
          decoded.map(
            (String k, dynamic v) => MapEntry<String, String>(k, v.toString()),
          ),
        );
      } catch (_) {}
    }

    final String? rawConvB64 =
        _prefs?.getString(_keyConversationWallpaperBase64);
    if (rawConvB64 != null && rawConvB64.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded =
            jsonDecode(rawConvB64) as Map<String, dynamic>;
        conversationWallpaperBase64.assignAll(
          decoded.map(
            (String k, dynamic v) => MapEntry<String, String>(k, v.toString()),
          ),
        );
      } catch (_) {}
    }

    final String? rawDrafts = _prefs?.getString(_keyDraftMessages);
    if (rawDrafts != null && rawDrafts.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded =
            jsonDecode(rawDrafts) as Map<String, dynamic>;
        draftMessages.assignAll(
          decoded.map(
            (String k, dynamic v) => MapEntry<String, String>(k, v.toString()),
          ),
        );
      } catch (_) {}
    }

    final String? rawProfile = _prefs?.getString(_keyUserProfileJson);
    if (rawProfile != null && rawProfile.isNotEmpty) {
      try {
        final Map<String, dynamic> decoded =
            jsonDecode(rawProfile) as Map<String, dynamic>;
        final ProfileModel profile = ProfileModel.fromJson(decoded);
        cachedProfile.value = profile;
        isProfileDiscoverable.value = profile.isProfileDiscoverable;
      } catch (_) {
        cachedProfile.value = null;
      }
    }

    _applySystemUiOverlay();
    return this;
  }

  ThemeMode get themeMode =>
      isDarkMode.value ? ThemeMode.dark : ThemeMode.light;

  /// Switches the app language between Arabic (`ar`) and English (`en`) and
  /// persists the choice locally.
  Future<void> setLanguage(String code) async {
    final String normalized = code == 'en' ? 'en' : 'ar';
    languageCode.value = normalized;
    Intl.defaultLocale = normalized;
    if (Get.key.currentState != null) {
      await Get.updateLocale(Locale(normalized));
    }
    await _prefs?.setString(_keyLanguageCode, normalized);
  }

  Future<void> toggleLanguage() =>
      setLanguage(isArabic ? 'en' : 'ar');

  /// Saves the authenticated user's session state and profile locally.
  Future<void> saveUserSession(ProfileModel profile) async {
    isLoggedIn.value = true;
    cachedProfile.value = profile;
    isProfileDiscoverable.value = profile.isProfileDiscoverable;

    await _prefs?.setBool(_keyIsLoggedIn, true);
    await _prefs?.setString(_keyUserId, profile.id);
    await _prefs?.setBool(
      _keyIsProfileDiscoverable,
      profile.isProfileDiscoverable,
    );
    await _prefs?.setString(
      _keyUserProfileJson,
      jsonEncode(profile.toJson()),
    );
  }

  /// Marks the user as logged in even before the full profile row is loaded.
  Future<void> markLoggedIn(String userId) async {
    isLoggedIn.value = true;
    await _prefs?.setBool(_keyIsLoggedIn, true);
    await _prefs?.setString(_keyUserId, userId);
  }

  /// Destroys all saved user session state, user-scoped preferences, and
  /// offline cached conversations/messages upon sign-out.
  /// Keeps app-level theme (`isDarkMode`) and language (`languageCode`) intact.
  Future<void> destroyUserSession() async {
    isLoggedIn.value = false;
    cachedProfile.value = null;
    isProfileDiscoverable.value = true;
    pinnedConversationIds.clear();
    mutedConversationIds.clear();
    starredMessageIds.clear();
    draftMessages.clear();

    await _prefs?.remove(_keyIsLoggedIn);
    await _prefs?.remove(_keyUserId);
    await _prefs?.remove(_keyUserProfileJson);
    await _prefs?.remove(_keyIsProfileDiscoverable);
    await _prefs?.remove(_keyPinnedConversations);
    await _prefs?.remove(_keyMutedConversations);
    await _prefs?.remove(_keyStarredMessages);
    await _prefs?.remove(_keyDraftMessages);
    await _prefs?.remove(_keyProfileCoverBase64);
    await _prefs?.remove(_keyConversationWallpaperPresets);
    await _prefs?.remove(_keyConversationWallpaperBase64);
    conversationWallpaperPresets.clear();
    conversationWallpaperBase64.clear();
    profileCoverBytes.value = null;

    if (Get.isRegistered<LocalChatCacheService>()) {
      await LocalChatCacheService.to.clearAllCache();
    }
  }

  /// Toggles or sets Dark Mode and persists the choice locally.
  Future<void> setDarkMode(bool value) async {
    isDarkMode.value = value;
    Get.changeThemeMode(value ? ThemeMode.dark : ThemeMode.light);
    _applySystemUiOverlay();
    await _prefs?.setBool(_keyIsDarkMode, value);
  }

  Future<void> toggleDarkMode() => setDarkMode(!isDarkMode.value);

  /// Saves a custom background wallpaper image locally (encoded as Base64 so it
  /// persists reliably across Web, Android, iOS, and Desktop).
  Future<void> setCustomBackgroundImage(Uint8List bytes) async {
    customBackgroundBytes.value = bytes;
    await _prefs?.setString(_keyCustomBackgroundBase64, base64Encode(bytes));
  }

  /// Selects one of the built-in app wallpapers and clears any custom gallery image
  /// (or keeps gallery image available when re-picked).
  Future<void> selectBuiltInWallpaper(String presetId) async {
    selectedWallpaperPresetId.value = presetId;
    customBackgroundBytes.value = null;
    await _prefs?.setString(_keySelectedWallpaperPreset, presetId);
    await _prefs?.remove(_keyCustomBackgroundBase64);
  }

  /// Removes the custom background wallpaper and restores the default
  /// Glassmorphism gradient background.
  Future<void> clearCustomBackgroundImage() async {
    customBackgroundBytes.value = null;
    selectedWallpaperPresetId.value = 'default';
    await _prefs?.remove(_keyCustomBackgroundBase64);
    await _prefs?.setString(_keySelectedWallpaperPreset, 'default');
  }

  // ---------------------------------------------------------------------------
  // Per-User / Per-Conversation Wallpaper (خلفية المحادثة المخصصة لمستخدم معين)
  // ---------------------------------------------------------------------------
  String? getConversationWallpaperPreset(String conversationId) =>
      conversationWallpaperPresets[conversationId];

  Uint8List? getConversationWallpaperBytes(String conversationId) {
    final String? b64 = conversationWallpaperBase64[conversationId];
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  Future<void> setConversationWallpaperPreset(
    String conversationId,
    String presetId,
  ) async {
    conversationWallpaperPresets[conversationId] = presetId;
    conversationWallpaperBase64.remove(conversationId);
    await _prefs?.setString(
      _keyConversationWallpaperPresets,
      jsonEncode(conversationWallpaperPresets),
    );
    await _prefs?.setString(
      _keyConversationWallpaperBase64,
      jsonEncode(conversationWallpaperBase64),
    );
  }

  Future<void> setConversationWallpaperImage(
    String conversationId,
    Uint8List bytes,
  ) async {
    final String b64 = base64Encode(bytes);
    conversationWallpaperBase64[conversationId] = b64;
    conversationWallpaperPresets.remove(conversationId);
    await _prefs?.setString(
      _keyConversationWallpaperBase64,
      jsonEncode(conversationWallpaperBase64),
    );
    await _prefs?.setString(
      _keyConversationWallpaperPresets,
      jsonEncode(conversationWallpaperPresets),
    );
  }

  Future<void> clearConversationWallpaper(String conversationId) async {
    conversationWallpaperPresets.remove(conversationId);
    conversationWallpaperBase64.remove(conversationId);
    await _prefs?.setString(
      _keyConversationWallpaperPresets,
      jsonEncode(conversationWallpaperPresets),
    );
    await _prefs?.setString(
      _keyConversationWallpaperBase64,
      jsonEncode(conversationWallpaperBase64),
    );
  }

  // ---------------------------------------------------------------------------
  // Profile Cover Background (خلفية غلاف الملف الشخصي للمستخدم)
  // ---------------------------------------------------------------------------
  Future<void> setProfileCover(Uint8List bytes) async {
    profileCoverBytes.value = bytes;
    await _prefs?.setString(_keyProfileCoverBase64, base64Encode(bytes));
  }

  Future<void> clearProfileCover() async {
    profileCoverBytes.value = null;
    await _prefs?.remove(_keyProfileCoverBase64);
  }

  /// Marks a user's status segment as viewed (WhatsApp-style seen/unseen ring).
  Future<void> markStatusSegmentViewed(String userId, String segmentId) async {
    final String key = '${userId}_$segmentId';
    if (!viewedStatusKeys.contains(key)) {
      viewedStatusKeys.add(key);
      await _prefs?.setStringList(
        _keyViewedStatusKeys,
        viewedStatusKeys.toList(),
      );
    }
  }

  bool isStatusSegmentViewed(String userId, String segmentId) =>
      viewedStatusKeys.contains('${userId}_$segmentId');

  bool hasViewedAllStatusSegments(ProfileModel user) {
    final List<StatusSegmentItem> segs = user.statusSegments;
    if (segs.isEmpty) return true;
    return segs.every(
      (StatusSegmentItem s) => isStatusSegmentViewed(user.id, s.id),
    );
  }

  /// Updates the dim overlay opacity over the custom background wallpaper.
  Future<void> setBackgroundDim(double value) async {
    final double clamped = value.clamp(0.10, 0.85);
    backgroundDim.value = clamped;
    await _prefs?.setDouble(_keyBackgroundDim, clamped);
  }

  /// Updates the local profile discoverability flag and cached profile.
  Future<void> setProfileDiscoverable(bool value) async {
    isProfileDiscoverable.value = value;
    await _prefs?.setBool(_keyIsProfileDiscoverable, value);

    final ProfileModel? current = cachedProfile.value;
    if (current != null) {
      final ProfileModel updated = current.copyWith(
        isProfileDiscoverable: value,
      );
      cachedProfile.value = updated;
      await _prefs?.setString(
        _keyUserProfileJson,
        jsonEncode(updated.toJson()),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Pinned & Muted Conversations
  // ---------------------------------------------------------------------------
  bool isConversationPinned(String conversationId) =>
      pinnedConversationIds.contains(conversationId);

  Future<bool> togglePinConversation(String conversationId) async {
    final bool nowPinned;
    if (pinnedConversationIds.contains(conversationId)) {
      pinnedConversationIds.remove(conversationId);
      nowPinned = false;
    } else {
      pinnedConversationIds.add(conversationId);
      nowPinned = true;
    }
    await _prefs?.setStringList(
      _keyPinnedConversations,
      pinnedConversationIds.toList(),
    );
    return nowPinned;
  }

  bool isConversationMuted(String conversationId) =>
      mutedConversationIds.contains(conversationId);

  Future<bool> toggleMuteConversation(String conversationId) async {
    final bool nowMuted;
    if (mutedConversationIds.contains(conversationId)) {
      mutedConversationIds.remove(conversationId);
      nowMuted = false;
    } else {
      mutedConversationIds.add(conversationId);
      nowMuted = true;
    }
    await _prefs?.setStringList(
      _keyMutedConversations,
      mutedConversationIds.toList(),
    );
    return nowMuted;
  }

  // ---------------------------------------------------------------------------
  // Starred Messages & Drafts
  // ---------------------------------------------------------------------------
  bool isMessageStarred(String messageId) =>
      starredMessageIds.contains(messageId);

  Future<bool> toggleStarMessage(String messageId) async {
    final bool nowStarred;
    if (starredMessageIds.contains(messageId)) {
      starredMessageIds.remove(messageId);
      nowStarred = false;
    } else {
      starredMessageIds.add(messageId);
      nowStarred = true;
    }
    await _prefs?.setStringList(
      _keyStarredMessages,
      starredMessageIds.toList(),
    );
    return nowStarred;
  }

  String getDraft(String conversationId) =>
      draftMessages[conversationId] ?? '';

  Future<void> saveDraft(String conversationId, String text) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      draftMessages.remove(conversationId);
    } else {
      draftMessages[conversationId] = text;
    }
    await _prefs?.setString(_keyDraftMessages, jsonEncode(draftMessages));
  }

  void _applySystemUiOverlay() {
    SystemChrome.setSystemUIOverlayStyle(
      isDarkMode.value ? AppTheme.darkOverlay : AppTheme.lightOverlay,
    );
  }
}
