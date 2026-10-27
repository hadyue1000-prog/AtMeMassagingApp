import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/app_preferences_service.dart';
import '../theme/app_theme.dart';

/// Full-screen layered background that recreates the AtMe Glassmorphism
/// reference ambiance in both Dark Mode (Deep Navy `#07152E` + Royal Blue `#123D91`)
/// and Crystal Sky-Blue Light Mode, AND seamlessly renders any custom wallpaper
/// photo uploaded by the user (`AppPreferencesService.customBackgroundBytes`).
class GlassScaffoldBackground extends StatelessWidget {
  const GlassScaffoldBackground({
    super.key,
    required this.child,
    this.isChatScreen = false,
    this.conversationId,
  });

  final Widget child;
  final bool isChatScreen;
  final String? conversationId;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AppPreferencesService>()) {
      return _buildLayeredBackground(
        isDark: true,
        customBytes: null,
        dimOpacity: 0.45,
      );
    }

    final AppPreferencesService prefs = AppPreferencesService.to;

    return Obx(() {
      final bool isDark = prefs.isDarkMode.value;
      Uint8List? customBytes = prefs.customBackgroundBytes.value;
      final double dimOpacity = prefs.backgroundDim.value;
      String presetId = prefs.selectedWallpaperPresetId.value;
      BuiltInWallpaperPreset preset = prefs.activeWallpaperPreset;

      if (conversationId != null && conversationId!.isNotEmpty) {
        final Uint8List? convBytes =
            prefs.getConversationWallpaperBytes(conversationId!);
        final String? convPresetId =
            prefs.getConversationWallpaperPreset(conversationId!);
        if (convBytes != null && convBytes.isNotEmpty) {
          customBytes = convBytes;
        } else if (convPresetId != null) {
          customBytes = null;
          presetId = convPresetId;
          for (final BuiltInWallpaperPreset p
              in AppPreferencesService.builtInWallpapers) {
            if (p.id == convPresetId) {
              preset = p;
              break;
            }
          }
        }
      }

      return _buildLayeredBackground(
        isDark: isDark,
        customBytes: customBytes,
        dimOpacity: dimOpacity,
        presetId: presetId,
        preset: preset,
      );
    });
  }

  Widget _buildLayeredBackground({
    required bool isDark,
    required Uint8List? customBytes,
    required double dimOpacity,
    String presetId = 'default',
    BuiltInWallpaperPreset? preset,
  }) {
    final bool hasCustom = customBytes != null && customBytes.isNotEmpty;
    final bool hasCustomPreset =
        !hasCustom && preset != null && presetId != 'default';

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: hasCustomPreset
            ? preset.gradient
            : (isDark
                ? (isChatScreen
                    ? AppColors.chatBackgroundGradient
                    : AppColors.scaffoldGradient)
                : (isChatScreen
                    ? AppColors.lightChatBackgroundGradient
                    : AppColors.lightScaffoldGradient)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (hasCustom) ...<Widget>[
            Positioned.fill(
              child: Image.memory(
                customBytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            // Adaptive tint overlay so glass cards and text stay readable over any image
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? <Color>[
                            AppColors.deepNavy.withValues(
                              alpha: (dimOpacity * 0.90).clamp(0.10, 0.88),
                            ),
                            AppColors.deepNavy.withValues(
                              alpha: (dimOpacity * 1.05).clamp(0.15, 0.92),
                            ),
                          ]
                        : <Color>[
                            Colors.white.withValues(
                              alpha: (dimOpacity * 0.72).clamp(0.10, 0.80),
                            ),
                            const Color(0xFFDCEBFF).withValues(
                              alpha: (dimOpacity * 0.82).clamp(0.15, 0.85),
                            ),
                          ],
                  ),
                ),
              ),
            ),
          ] else ...<Widget>[
            // Ambient glowing spheres (Isolated in RepaintBoundary for 60/120fps performance)
            RepaintBoundary(
              child: IgnorePointer(
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Positioned(
                      top: -100,
                      right: -70,
                      child: _AmbientGlowOrb(
                        size: 320,
                        color: (hasCustomPreset
                                ? preset.orbPrimary
                                : AppColors.electricCyan)
                            .withValues(
                          alpha: isDark ? 0.16 : 0.14,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -80,
                      left: -60,
                      child: _AmbientGlowOrb(
                        size: 300,
                        color: (hasCustomPreset
                                ? preset.orbSecondary
                                : AppColors.softViolet)
                            .withValues(
                          alpha: isDark ? 0.14 : 0.12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          child,
        ],
      ),
    );
  }
}

class _AmbientGlowOrb extends StatelessWidget {
  const _AmbientGlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            color,
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

/// Frosted glass container with optional `BackdropFilter` blur, translucent
/// gradient fill, top specular highlight, and thin luminous cyan/white border.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 22,
    this.isHighlighted = false,
    this.onTap,
    this.onLongPress,
    this.customGradient,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  /// When `> 0`, applies `BackdropFilter(filter: ImageFilter.blur)`.
  /// Keep `0` inside long scrolling lists for 60fps performance, and use
  /// `12-18` on headers, bottom bars, composers, and hero cards.
  final bool isHighlighted;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Gradient? customGradient;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final bool hasPrefs = Get.isRegistered<AppPreferencesService>();
    if (!hasPrefs) {
      return _buildCard(isDark: true, hasCustomBg: false);
    }
    return Obx(() {
      final AppPreferencesService prefs = AppPreferencesService.to;
      return _buildCard(
        isDark: prefs.isDarkMode.value,
        hasCustomBg: prefs.hasCustomBackground,
      );
    });
  }

  Widget _buildCard({required bool isDark, required bool hasCustomBg}) {
    final BorderRadius radius = BorderRadius.circular(borderRadius);

    final Gradient fillGradient = customGradient ??
        (isHighlighted
            ? (isDark
                ? AppColors.glassHighlightedGradient
                : AppColors.lightGlassHighlightedGradient)
            : (isDark
                ? AppColors.glassCardGradient
                : AppColors.lightGlassCardGradient));

    final Color effectiveBorder = borderColor ??
        (isHighlighted
            ? (isDark
                ? AppColors.aqua.withValues(alpha: 0.65)
                : AppColors.electricCyan.withValues(alpha: 0.75))
            : (isDark
                ? Colors.white.withValues(alpha: 0.24)
                : Colors.white.withValues(alpha: 0.85)));

    Widget cardBody = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: fillGradient,
        borderRadius: radius,
        border: Border.all(
          color: effectiveBorder,
          width: isHighlighted ? 1.4 : 1.1,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isHighlighted
                ? AppColors.electricCyan.withValues(alpha: isDark ? 0.22 : 0.18)
                : (isDark
                    ? Colors.black.withValues(alpha: 0.28)
                    : AppColors.royalBlue.withValues(alpha: 0.10)),
            blurRadius: isHighlighted ? 20 : 16,
            spreadRadius: isHighlighted ? 0.5 : 0,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.05 : 0.55),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null || onLongPress != null) {
      cardBody = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: radius,
          splashColor: AppColors.electricCyan.withValues(alpha: 0.14),
          highlightColor: AppColors.electricCyan.withValues(alpha: 0.07),
          child: cardBody,
        ),
      );
    }

   

    if (margin != null) {
      return Padding(padding: margin!, child: cardBody);
    }
    return cardBody;
  }
}

/// Alias for `GlassCard` with default frosted `BackdropFilter` blur (`blurSigma: 14`)
/// for larger panels, form sections, and settings groups.
class GlassPanel extends GlassCard {
  const GlassPanel({
    super.key,
    required super.child,
    super.padding = const EdgeInsets.all(20),
    super.margin,
    super.borderRadius = 24,
    super.isHighlighted = false,
    super.onTap,
    super.onLongPress,
    super.customGradient,
    super.borderColor,
  });
}

/// Safely extracts and decodes an ImageProvider for any avatar representation:
/// - Base64 Data URI (`data:image/...;base64,...`)
/// - Raw Base64 string
/// - Remote HTTPS / HTTP URL (CachedNetworkImageProvider)
/// - Local File path (FileImage)
ImageProvider? getUniversalAvatarImageProvider(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  final String trimmed = url.trim();

  // 1) Data URI or Raw Base64
  if (trimmed.startsWith('data:image/') ||
      (!trimmed.startsWith('http') &&
          !trimmed.startsWith('/') &&
          trimmed.length > 50)) {
    try {
      final String rawB64 =
          trimmed.contains(',') ? trimmed.split(',').last.trim() : trimmed;
      return MemoryImage(base64Decode(rawB64));
    } catch (_) {
      return null;
    }
  }

  // 2) Local file
  if (trimmed.startsWith('/') || (trimmed.length > 3 && trimmed[1] == ':')) {
    try {
      return FileImage(File(trimmed));
    } catch (_) {
      return null;
    }
  }

  // 3) Network URL
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return CachedNetworkImageProvider(trimmed);
  }

  return null;
}

/// Renders an avatar image widget safely across all types of URLs/Base64/Files
/// with smooth placeholders and fallback initials.
Widget buildUniversalAvatarImage({
  required String? imageUrl,
  required String fallbackText,
  double radius = 26,
  BoxFit fit = BoxFit.cover,
}) {
  final String initial = fallbackText.trim().isNotEmpty
      ? String.fromCharCode(fallbackText.trim().runes.first).toUpperCase()
      : '@';

  final Widget fallbackWidget = Center(
    child: Text(
      initial,
      style: TextStyle(
        fontSize: radius * 0.76,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        shadows: <Shadow>[
          Shadow(
            color: AppColors.electricCyan.withValues(alpha: 0.6),
            blurRadius: 8,
          ),
        ],
      ),
    ),
  );

  if (imageUrl == null || imageUrl.trim().isEmpty) {
    return fallbackWidget;
  }

  final String trimmed = imageUrl.trim();

  // Case 1: Data URI or raw Base64
  if (trimmed.startsWith('data:image/') ||
      (!trimmed.startsWith('http') &&
          !trimmed.startsWith('/') &&
          trimmed.length > 50)) {
    try {
      final String rawB64 =
          trimmed.contains(',') ? trimmed.split(',').last.trim() : trimmed;
      final Uint8List bytes = base64Decode(rawB64);
      return Image.memory(
        bytes,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallbackWidget,
      );
    } catch (_) {
      return fallbackWidget;
    }
  }

  // Case 2: Local File
  if (trimmed.startsWith('/') || (trimmed.length > 3 && trimmed[1] == ':')) {
    try {
      return Image.file(
        File(trimmed),
        fit: fit,
        errorBuilder: (_, _, _) => fallbackWidget,
      );
    } catch (_) {
      return fallbackWidget;
    }
  }

  // Case 3: Network URL
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return CachedNetworkImage(
      imageUrl: trimmed,
      fit: fit,
      placeholder: (_, _) => fallbackWidget,
      errorWidget: (_, _, _) => fallbackWidget,
    );
  }

  return fallbackWidget;
}

/// Reusable 3D luminous circular avatar with gradient ring, inner gradient fill,
/// and optional online status dot.
class GlassAvatar extends StatelessWidget {
  const GlassAvatar({
    super.key,
    this.imageUrl,
    required this.fallbackText,
    this.radius = 26,
    this.isOnline = false,
    this.onTap,
    this.showGlow = true,
  });

  final String? imageUrl;
  final String fallbackText;
  final double radius;
  final bool isOnline;
  final VoidCallback? onTap;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    Widget avatar = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: radius * 2 + 5,
          height: radius * 2 + 5,
          padding: const EdgeInsets.all(2.3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isOnline
                ? const LinearGradient(
                    colors: <Color>[
                      AppColors.online,
                      AppColors.aqua,
                      AppColors.electricCyan,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : AppColors.avatarRingGradient,
            boxShadow: showGlow
                ? <BoxShadow>[
                    BoxShadow(
                      color: (isOnline
                              ? AppColors.online
                              : AppColors.electricCyan)
                          .withValues(alpha: 0.32),
                      blurRadius: 12,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.avatarFillGradient,
            ),
            clipBehavior: Clip.antiAlias,
            child: buildUniversalAvatarImage(
              imageUrl: imageUrl,
              fallbackText: fallbackText,
              radius: radius,
            ),
          ),
        ),
        if (isOnline)
          PositionedDirectional(
            bottom: 1,
            end: 1,
            child: Container(
              width: (radius * 0.50).clamp(11.0, 16.0),
              height: (radius * 0.50).clamp(11.0, 16.0),
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.deepNavy,
                  width: 2.2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.online.withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }
    return avatar;
  }
}

/// Frosted glass icon button used in headers, toolbars, and action rows.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 40,
    this.iconSize = 20,
    this.iconColor,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDark;
    final Color fg = iconColor ??
        (isActive ? AppColors.aqua : AppColors.textPrimary);

    final Widget btn = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: isActive
                ? AppColors.glassHighlightedGradient
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? <Color>[
                            Colors.white.withValues(alpha: 0.14),
                            Colors.white.withValues(alpha: 0.05),
                          ]
                        : <Color>[
                            Colors.white.withValues(alpha: 0.85),
                            Colors.white.withValues(alpha: 0.65),
                          ],
                  ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? AppColors.aqua.withValues(alpha: 0.7)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.22)
                      : AppColors.lightBorder),
            ),
          ),
          child: Center(
            child: Icon(icon, size: iconSize, color: fg),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

/// Frosted glass text field for forms (Email, Profile, Bio, Username).
class GlassTextField extends StatelessWidget {
  const GlassTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.textDirection,
  });

  final TextEditingController controller;
  final String? hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    Widget field = TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 15.5,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon,
      ),
    );

    if (textDirection != null) {
      field = Directionality(textDirection: textDirection!, child: field);
    }
    return field;
  }
}

/// Frosted glass search/text pill matching the top search bar in the reference.
class GlassSearchField extends StatelessWidget {
  const GlassSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
    this.showClear = false,
    this.autofocus = false,
    this.focusNode,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool showClear;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDark;

    return GlassCard(
      borderRadius: 28,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      borderColor: isDark
          ? Colors.white.withValues(alpha: 0.26)
          : AppColors.lightBorder,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: autofocus,
        onChanged: onChanged,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.85),
            fontSize: 14,
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? AppColors.aqua : AppColors.primary,
            size: 21,
          ),
          suffixIcon: showClear
              ? IconButton(
                  onPressed: onClear,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 19,
                    color: AppColors.textSecondary,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Glowing cyan-to-blue pill button matching the reference "بدء محادثة جديدة" button.
class GlowingCyanButton extends StatelessWidget {
  const GlowingCyanButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.enabled = true,
    this.height = 54,
  });

  final String label;
  final IconData? icon;
  final bool loading;
  final bool enabled;
  final double height;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool active = enabled && !loading && onPressed != null;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled || loading ? 1.0 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.cyanButtonGradient,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.42),
            width: 1.1,
          ),
          boxShadow: active
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.electricCyan.withValues(alpha: 0.45),
                    blurRadius: 22,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: active ? onPressed : null,
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: height,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (icon != null) ...<Widget>[
                              Icon(icon, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                ),
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
}

/// Alias for `GlowingCyanButton` to support `GlassButton` naming across the design system.
typedef GlassButton = GlowingCyanButton;

/// Circular glowing cyan icon button (used for FAB, send button, and call actions).
class GlowingCyanCircleButton extends StatelessWidget {
  const GlowingCyanCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 48,
    this.iconSize = 22,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Widget button = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.cyanButtonGradient,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.48),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.electricCyan.withValues(alpha: 0.48),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
        ),
      ),
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Frosted glass modal bottom sheet wrapper used for conversation options,
/// message actions, and profile sheets.
class GlassBottomSheet extends StatelessWidget {
  const GlassBottomSheet({
    super.key,
    required this.child,
    this.title,
  });

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0xEB102E6B),
                      Color(0xF507152E),
                    ],
                  )
                : AppColors.lightScaffoldGradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? AppColors.aqua.withValues(alpha: 0.38)
                    : AppColors.lightBorder,
                width: 1.2,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                if (title != null && title!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    title!,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Frosted glass confirmation dialog used for sign-out and destructive actions.
class GlassDialog extends StatelessWidget {
  const GlassDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onConfirm,
    this.isDestructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: isDark
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Color(0xEB12357A),
                          Color(0xF207152E),
                        ],
                      )
                    : AppColors.lightGlassCardGradient,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark
                      ? AppColors.aqua.withValues(alpha: 0.35)
                      : AppColors.lightBorder,
                  width: 1.2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: (isDestructive
                              ? AppColors.error
                              : AppColors.electricCyan)
                          .withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (isDestructive
                                ? AppColors.error
                                : AppColors.electricCyan)
                            .withValues(alpha: 0.45),
                      ),
                    ),
                    child: Icon(
                      isDestructive
                          ? Icons.logout_rounded
                          : Icons.info_outline_rounded,
                      color: isDestructive
                          ? AppColors.error
                          : AppColors.electricCyan,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Get.back<void>(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                            minimumSize: const Size.fromHeight(46),
                          ),
                          child: Text(cancelLabel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Get.back<void>();
                            onConfirm();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: isDestructive
                                ? AppColors.error
                                : AppColors.electricCyan,
                            minimumSize: const Size.fromHeight(46),
                          ),
                          child: Text(confirmLabel),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating glass island bottom navigation bar (`جزيرة عائمة`) with generous
/// height (`74px`), full rounded capsule borders (`BorderRadius.circular(36)`),
/// backdrop blur, luminous cyan/white border, and deep levitation shadow.
class GlassNavigationBar extends StatelessWidget {
  const GlassNavigationBar({
    super.key,
    required this.currentIndex,
    required this.unreadCount,
    required this.onTap,
  });

  final int currentIndex;
  final int unreadCount;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDark;
    final BorderRadius islandRadius = BorderRadius.circular(36);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: islandRadius,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDark ? 0.48 : 0.10,
                    ),
                    blurRadius: 28,
                    spreadRadius: 1,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: AppColors.electricCyan.withValues(
                      alpha: isDark ? 0.16 : 0.08,
                    ),
                    blurRadius: 22,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: islandRadius,
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: 74,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: islandRadius,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? <Color>[
                                const ui.Color(0x45143A80),
                                const ui.Color(0x390A1F4A),
                                const ui.Color.fromRGBO(7, 21, 46, 0.239),
                              ]
                            : <Color>[
                                Colors.white.withValues(alpha: 0.58),
                                const Color(0xFFDFF0FF).withValues(alpha: 0.6),
                              ],
                      ),
                      border: Border.all(
                        color: isDark
                            ? AppColors.aqua.withValues(alpha: 0.38)
                            : AppColors.lightBorder,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        _GlassNavBarItem(
                          icon: Icons.chat_bubble_outline_rounded,
                          selectedIcon: Icons.chat_bubble_rounded,
                          label: 'nav_chats'.tr,
                          badgeCount: unreadCount,
                          isSelected: currentIndex == 0,
                          onTap: () => onTap(0),
                        ),
                        _GlassNavBarItem(
                          icon: Icons.auto_awesome_outlined,
                          selectedIcon: Icons.auto_awesome_rounded,
                          label: 'nav_statuses'.tr,
                          isSelected: currentIndex == 1,
                          onTap: () => onTap(1),
                        ),
                        _GlassNavBarItem(
                          icon: Icons.person_outline_rounded,
                          selectedIcon: Icons.person_rounded,
                          label: 'nav_profile'.tr,
                          isSelected: currentIndex == 2,
                          onTap: () => onTap(2),
                        ),
                        _GlassNavBarItem(
                          icon: Icons.settings_outlined,
                          selectedIcon: Icons.settings_rounded,
                          label: 'nav_settings'.tr,
                          isSelected: currentIndex == 3,
                          onTap: () => onTap(3),
                        ),
                      ],
                    ),
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

class _GlassNavBarItem extends StatelessWidget {
  const _GlassNavBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDark;
    final Color activeColor = isDark ? AppColors.aqua : AppColors.royalBlue;
    final Color inactiveColor = AppColors.textSecondary;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        AppColors.electricCyan.withValues(alpha: 0.30),
                        AppColors.royalBlue.withValues(alpha: 0.28),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(26),
              border: isSelected
                  ? Border.all(
                      color: AppColors.aqua.withValues(alpha: 0.50),
                      width: 1,
                    )
                  : null,
              boxShadow: isSelected
                  ? <BoxShadow>[
                      BoxShadow(
                        color: AppColors.electricCyan.withValues(alpha: 0.28),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Badge(
                  isLabelVisible: badgeCount > 0,
                  backgroundColor: AppColors.electricCyan,
                  textColor: AppColors.deepNavy,
                  label: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                    ),
                  ),
                  child: Icon(
                    isSelected ? selectedIcon : icon,
                    color: isSelected ? activeColor : inactiveColor,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.2,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    color: isSelected
                        ? (isDark ? Colors.white : AppColors.royalBlue)
                        : inactiveColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
