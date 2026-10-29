import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../services/app_preferences_service.dart';

/// Brand & adaptive Glassmorphism color tokens of AtMe (@Me).
///
/// Built around the reference blue glassmorphism palette:
/// - `backgroundPrimary`: `#07152E` (Deep navy)
/// - `backgroundSecondary`: `#0B2147` (Midnight blue)
/// - `surfaceBlue`: `#123D91` (Royal blue)
/// - `accentCyan`: `#19D5F2` (Electric cyan)
/// - `accentAqua`: `#67F0F0` (Aqua)
/// - `accentViolet`: `#A77BFF` (Soft violet)
/// - `textPrimary`: `#FFFFFF`
/// - `textSecondary`: `#C7D5EB`
class AppColors {
  AppColors._();

  static bool get isDark {
    if (Get.isRegistered<AppPreferencesService>()) {
      return AppPreferencesService.to.isDarkMode.value;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Core Eye-Comfort Glassmorphism Design System Tokens
  // Softer dark slate & calming teal/cyan palette designed for reduced eye strain
  // ---------------------------------------------------------------------------
  static const Color backgroundPrimary = Color(0xFF091426); // Calming deep slate navy
  static const Color backgroundSecondary = Color(0xFF0D1D36); // Soft midnight slate
  static const Color surfaceBlue = Color(0xFF132E5E); // Subdued royal slate
  static const Color accentCyan = Color(0xFF26C6DA); // Soft calming electric cyan
  static const Color accentAqua = Color(0xFF5CE1E6); // Softer aqua
  static const Color accentViolet = Color(0xFF9D8DF1); // Gentle soft violet

  // Semantic aliases
  static const Color deepNavy = backgroundPrimary;
  static const Color midnightBlue = backgroundSecondary;
  static const Color royalBlue = surfaceBlue;
  static const Color electricCyan = accentCyan;
  static const Color aqua = accentAqua;
  static const Color softViolet = accentViolet;

  // Brand aliases used across controllers & widgets
  static const Color primary = accentCyan;
  static const Color primaryDark = surfaceBlue;
  static const Color primaryLight = accentAqua;
  static const Color accent = accentViolet;

  // Light palette constants (Calming Sky Glassmorphism Light mode - no harsh glare)
  static const Color lightPrimarySurface = Color(0xFFE2F0FD);
  static const Color lightBackground = Color(0xFFF1F5F9); // Soothing Slate-100
  static const Color lightChatBackground = Color(0xFFEBF2FA);
  static const Color lightInputFill = Color(0xF2FFFFFF);
  static const Color lightIncomingBubble = Color(0xF2FFFFFF);
  static const Color lightIncomingText = Color(0xFF0F172A); // Slate-900
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569); // Slate-600
  static const Color lightTextHint = Color(0xFF64748B); // Slate-500
  static const Color lightDivider = Color(0x28123D91);
  static const Color lightBorder = Color(0x66B0C8E8);

  // Dark / Glassmorphism palette constants (Comfortable Dark Theme - Anti-Glare)
  static const Color darkPrimarySurface = Color(0x3326C6DA);
  static const Color darkBackground = backgroundPrimary;
  static const Color darkSurface = Color(0x3D132E5E);
  static const Color darkChatBackground = Color(0xFF09162A);
  static const Color darkInputFill = Color(0x38132B54);
  static const Color darkIncomingBubble = Color(0xE0102445);
  static const Color darkIncomingText = Color(0xFFF1F5F9); // Softer off-white (prevents dark mode eye fatigue)
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // High legibility, no blinding glare
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate-400
  static const Color darkTextHint = Color(0xFF64748B); // Slate-500
  static const Color darkDivider = Color(0x1FFFFFFF);
  static const Color darkBorder = Color(0x335CE1E6);
  static const Color glassBorderColor = Color(0x2EFFFFFF);

  // Adaptive design system tokens
  static Color get borderGlass =>
      isDark ? const Color(0x38FFFFFF) : const Color(0xFFB8D0F0);

  static Color get glassSurface =>
      isDark ? const Color(0x42123882) : const Color(0xD9FFFFFF);

  static Color get primarySurface =>
      isDark ? darkPrimarySurface : lightPrimarySurface;

  static Color get background => isDark ? darkBackground : lightBackground;

  static Color get chatBackground =>
      isDark ? darkChatBackground : lightChatBackground;

  static Color get inputFill => isDark ? darkInputFill : lightInputFill;

  // Bubbles (Matches reference: luminous cyan-ice bubble & deep translucent navy bubble)
  static Color get outgoingBubble =>
      isDark ? const Color(0xE6D8F3FF) : const Color(0xFF123D91);

  static Color get outgoingText =>
      isDark ? const Color(0xFF07152E) : const Color(0xFFFFFFFF);

  static Color get incomingBubble =>
      isDark ? darkIncomingBubble : lightIncomingBubble;

  static Color get incomingText =>
      isDark ? darkIncomingText : lightIncomingText;

  // Text
  static Color get textPrimary => isDark ? darkTextPrimary : lightTextPrimary;

  static Color get textSecondary =>
      isDark ? darkTextSecondary : lightTextSecondary;

  static Color get textHint => isDark ? darkTextHint : lightTextHint;

  // Status
  static const Color online = Color(0xFF22E58A);
  static const Color recording = Color(0xFFFF4D67);
  static const Color error = Color(0xFFFF526B);
  static const Color success = Color(0xFF22E58A);

  // Read receipts
  static Color get readTickOnBubble =>
      isDark ? const Color(0xFF0860C4) : const Color(0xFF67F0F0);

  static Color get unreadTickOnBubble =>
      isDark ? const Color(0x9907152E) : const Color(0xB3FFFFFF);

  static const Color readTick = Color(0xFF19D5F2);
  static const Color unreadTick = Color(0xFF8CA6CC);

  // Lines
  static Color get divider => isDark ? darkDivider : lightDivider;
  static Color get border => isDark ? darkBorder : lightBorder;

  // ---------------------------------------------------------------------------
  // Gradients (Comfortable eye-friendly transitions)
  // ---------------------------------------------------------------------------
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF26C6DA), Color(0xFF1976D2)],
  );

  static const LinearGradient cyanButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0x7626C5DA),
      Color.fromARGB(122, 2, 137, 209),
      Color.fromARGB(109, 21, 101, 192),
    ],
    stops: <double>[0.0, 0.55, 1.0],
  );

  static const LinearGradient avatarRingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF5CE1E6),
      Color(0xFF26C6DA),
      Color(0xFF9D8DF1),
    ],
  );

  static const LinearGradient avatarFillGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF15366A),
      Color(0xFF0D2245),
      Color(0xFF091426),
    ],
  );

  static const LinearGradient scaffoldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF0F2648),
      Color(0xFF0B1B33),
      Color(0xFF081322),
    ],
    stops: <double>[0.0, 0.50, 1.0],
  );

  static const LinearGradient chatBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0xFF11294D),
      Color(0xFF0C1D36),
      Color(0xFF081322),
    ],
    stops: <double>[0.0, 0.50, 1.0],
  );

  static const LinearGradient lightScaffoldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFB8DCFF),
      Color(0xFFD8ECFF),
      Color(0xFFEAF3FF),
    ],
    stops: <double>[0.0, 0.50, 1.0],
  );

  static const LinearGradient lightChatBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0xFFB2D8FF),
      Color(0xFFD2E8FF),
      Color(0xFFE6F1FF),
    ],
    stops: <double>[0.0, 0.50, 1.0],
  );

  static const LinearGradient glassCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0x4D2A67DE),
      Color(0x33123270),
      Color(0x260B1E46),
    ],
    stops: <double>[0.0, 0.52, 1.0],
  );

  static const LinearGradient glassHighlightedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0x662482FF),
      Color(0x4219D5F2),
      Color(0x33123D91),
    ],
    stops: <double>[0.0, 0.55, 1.0],
  );

  static const LinearGradient lightGlassCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color.fromARGB(46, 255, 255, 255),
      Color.fromARGB(9, 230, 243, 255),
    ],
  );

  static const LinearGradient lightGlassHighlightedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xE6FFFFFF),
      Color(0xB3BFE8FF),
    ],
  );
}

/// Global ThemeData of AtMe (@Me) for both Light and Dark Glassmorphism modes.
class AppTheme {
  AppTheme._();

  static const double radiusSmall = 14;
  static const double radiusMedium = 18;
  static const double radiusLarge = 24;

  static const SystemUiOverlayStyle lightOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.lightBackground,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

  static const SystemUiOverlayStyle darkOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.deepNavy,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static ThemeData get light => _buildTheme(isDark: false);

  static ThemeData get dark => _buildTheme(isDark: true);

  static ThemeData _buildTheme({required bool isDark}) {
    final Color bg =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final Color surfaceContainer =
        isDark ? AppColors.darkPrimarySurface : AppColors.lightPrimarySurface;
    final Color onPrimaryContainer =
        isDark ? AppColors.aqua : AppColors.royalBlue;
    final Color textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final Color textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final Color textHint =
        isDark ? AppColors.darkTextHint : AppColors.lightTextHint;
    final Color inputFill =
        isDark ? AppColors.darkInputFill : AppColors.lightInputFill;
    final Color border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color divider =
        isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final SystemUiOverlayStyle overlay = isDark ? darkOverlay : lightOverlay;

    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.electricCyan,
      brightness: isDark ? Brightness.dark : Brightness.light,
    ).copyWith(
      primary: AppColors.electricCyan,
      onPrimary: Colors.white,
      primaryContainer: surfaceContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: AppColors.softViolet,
      onSecondary: Colors.white,
      surface: bg,
      onSurface: textPrimary,
      error: AppColors.error,
      onError: Colors.white,
      outline: border,
      outlineVariant: divider,
    );

    final OutlineInputBorder baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMedium),
      borderSide: BorderSide(
        color: isDark ? Colors.white.withValues(alpha: 0.24) : border,
      ),
    );

    final TextTheme baseTypography = isDark
        ? Typography.material2021(platform: TargetPlatform.android).white
        : Typography.material2021(platform: TargetPlatform.android).black;

    final TextTheme textTheme = baseTypography.apply(
      fontFamily: 'Tajawal',
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      fontFamily: 'Tajawal',
      colorScheme: colorScheme,
      primaryColor: AppColors.electricCyan,
      scaffoldBackgroundColor: bg,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: textTheme.copyWith(
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        headlineSmall: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: textPrimary,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: textPrimary,
          height: 1.4,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: textSecondary,
          height: 1.4,
        ),
        bodySmall: textTheme.bodySmall?.copyWith(
          color: textSecondary,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),

      // ---------------------------------------------------------------- AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: overlay,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),

      // ---------------------------------------------------------------- Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        hintStyle: TextStyle(color: textHint, fontSize: 14.5),
        labelStyle: TextStyle(color: textSecondary),
        floatingLabelStyle: const TextStyle(color: AppColors.electricCyan),
        prefixIconColor: isDark ? AppColors.aqua : AppColors.royalBlue,
        suffixIconColor: textSecondary,
        border: baseBorder,
        enabledBorder: baseBorder,
        focusedBorder: baseBorder.copyWith(
          borderSide:
              const BorderSide(color: AppColors.electricCyan, width: 1.6),
        ),
        errorBorder: baseBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: baseBorder.copyWith(
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
        errorStyle: const TextStyle(color: AppColors.error, fontSize: 12.5),
      ),

      // --------------------------------------------------------------- Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.electricCyan,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              AppColors.electricCyan.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.electricCyan,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.aqua : AppColors.royalBlue,
          textStyle: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.electricCyan,
          side: const BorderSide(color: AppColors.electricCyan),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.electricCyan,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: CircleBorder(),
      ),

      // ----------------------------------------------------------------- Lists
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: isDark ? AppColors.aqua : AppColors.royalBlue,
        titleTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          color: textPrimary,
          fontSize: 15.5,
          fontWeight: FontWeight.w700,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Tajawal',
          color: textSecondary,
          fontSize: 13,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),

      // -------------------------------------------------------------- Switches
      switchTheme: SwitchThemeData(
        thumbColor:
            WidgetStateProperty.resolveWith<Color>((Set<WidgetState> s) {
          if (s.contains(WidgetState.selected)) return Colors.white;
          return textSecondary;
        }),
        trackColor:
            WidgetStateProperty.resolveWith<Color>((Set<WidgetState> s) {
          if (s.contains(WidgetState.selected)) return AppColors.electricCyan;
          return border;
        }),
      ),

      // ---------------------------------------------------------------- Others
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.electricCyan,
        linearTrackColor: surfaceContainer,
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 3.5,
        activeTrackColor: AppColors.electricCyan,
        inactiveTrackColor: divider,
        thumbColor: AppColors.electricCyan,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xEB0B2147),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xF20B1F44) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.24)
                : AppColors.lightBorder,
          ),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.electricCyan,
        selectionColor: AppColors.electricCyan.withValues(alpha: 0.28),
        selectionHandleColor: AppColors.electricCyan,
      ),
    );
  }
}
