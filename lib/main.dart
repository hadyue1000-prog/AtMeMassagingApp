import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/supabase_constants.dart';
import 'core/localization/app_translations.dart';
import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'core/services/app_preferences_service.dart';
import 'core/services/local_chat_cache_service.dart';
import 'core/theme/app_theme.dart';
import 'data/models/profile_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Initialize local offline chat database & cache service
  await Get.putAsync<LocalChatCacheService>(
    () => LocalChatCacheService().init(),
    permanent: true,
  );

  // 2) Initialize local persistent preferences (session state, dark mode, language, privacy)
  final AppPreferencesService prefs = await Get.putAsync<AppPreferencesService>(
    () => AppPreferencesService().init(),
    permanent: true,
  );

  // 3) Initialize Arabic & English date/time formatting
  Intl.defaultLocale = prefs.languageCode.value;
  await initializeDateFormatting('ar');
  await initializeDateFormatting('en');

  // 4) Initialize Supabase (Auth, Database, Realtime, Storage)
  // ignore: deprecated_member_use
  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  final String initialRoute = await _resolveInitialRoute(prefs);

  runApp(AtMeApp(initialRoute: initialRoute));
}

/// Decides the first screen and synchronizes local persistent state:
/// - No session & no offline login    → destroy local session → /email
/// - Session + profile with username  → save local session    → /home
/// - Session without profile          → mark logged in        → /setup-profile


Future<String> _resolveInitialRoute(AppPreferencesService prefs) async {
  final Session? session = supabase.auth.currentSession;
  if (session == null) {
    await prefs.destroyUserSession();
    return AppRoutes.email;
  }

  final ProfileModel? cached = prefs.cachedProfile.value;

  try {
    final Map<String, dynamic>? profileData = await supabase
        .from(SupabaseConstants.profilesTable)
        .select()
        .eq('id', session.user.id)
        .maybeSingle()
        .timeout(const Duration(seconds: 6));

    final String? username = profileData?['username'] as String?;
    if (profileData != null &&
        username != null &&
        username.trim().isNotEmpty) {
      final ProfileModel parsed = ProfileModel.fromJson(profileData);
      await prefs.saveUserSession(parsed);
      return AppRoutes.home;
    }

    await prefs.markLoggedIn(session.user.id);
    return AppRoutes.setupProfile;
  } on AuthException {
    // Session is invalid/expired and could not be refreshed → destroy session.
    try {
      await supabase.auth.signOut();
    } catch (_) {}
    await prefs.destroyUserSession();
    return AppRoutes.email;
  } on PostgrestException {
    if (cached != null &&
        cached.id == session.user.id &&
        cached.isComplete) {
      return AppRoutes.home;
    }
    return AppRoutes.setupProfile;
  } on TimeoutException {
    // Offline start with a cached session → let the user into the app immediately.
    if (cached != null &&
        cached.id == session.user.id &&
        cached.isComplete) {
      return AppRoutes.home;
    }
    return AppRoutes.home;
  } catch (_) {
    return AppRoutes.home;
  }
}

class AtMeApp extends StatelessWidget {
  const AtMeApp({super.key, required this.initialRoute});

  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    final AppPreferencesService prefs = AppPreferencesService.to;

    return Obx(
      () => GetMaterialApp(
        title: 'AtMe',
        debugShowCheckedModeBanner: false,

        // ------------------------------------------------------------- Theme
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: prefs.themeMode,

        // ------------------------------------------------------------- Localization (Arabic & English)
        translations: AppTranslations(),
        locale: prefs.locale,
        fallbackLocale: const Locale('ar'),
        supportedLocales: const <Locale>[
          Locale('ar'),
          Locale('en'),
        ],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],

        // ------------------------------------------------------------- Routing
        initialRoute: initialRoute,
        getPages: AppPages.routes,
        defaultTransition: Transition.cupertino,
        unknownRoute: AppPages.routes.first,

        // Dynamic RTL (Arabic) / LTR (English) directionality + safe text scaling
        builder: (BuildContext context, Widget? child) {
          final MediaQueryData mq = MediaQuery.of(context);
          return Obx(
            () => Directionality(
              textDirection: prefs.textDirection,
              child: MediaQuery(
                data: mq.copyWith(
                  textScaler: mq.textScaler.clamp(
                    minScaleFactor: 0.9,
                    maxScaleFactor: 1.3,
                  ),
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
