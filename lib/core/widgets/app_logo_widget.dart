import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Official AtMe (@Me) 3D Glassmorphism brand logo widget.
///
/// Renders the new `@Me` neon glassmorphism speech-bubble icon
/// (`assets/images/app_icon.png` / `assets/images/app_logo.png`) with a
/// glowing cyan/violet aura and optional wordmark underneath.
class AppLogoWidget extends StatelessWidget {
  const AppLogoWidget({
    super.key,
    this.size = 96,
    this.showName = false,
    this.showShadow = true,
    this.nameColor,
    this.nameFontSize,
  });

  /// Width & height of the icon squircle.
  final double size;

  /// When `true`, displays the glowing `AtMe` wordmark below the 3D icon.
  final bool showName;

  /// Adds a soft cyan/violet neon glow under the icon when enabled.
  final bool showShadow;

  /// Optional custom color for the wordmark.
  final Color? nameColor;

  /// Optional custom font size for the wordmark.
  final double? nameFontSize;

  static const String fullLogoAsset = 'assets/images/app_logo.png';
  static const String iconOnlyAsset = 'assets/images/app_icon.png';

  @override
  Widget build(BuildContext context) {
    final Widget iconBox = Container(
      width: size,
      height: size,
      decoration: showShadow
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.24),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.electricCyan.withValues(alpha: 0.35),
                  blurRadius: size * 0.26,
                  spreadRadius: 1,
                  offset: Offset(0, size * 0.05),
                ),
                BoxShadow(
                  color: AppColors.softViolet.withValues(alpha: 0.22),
                  blurRadius: size * 0.30,
                  offset: Offset(0, size * 0.08),
                ),
              ],
            )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          iconOnlyAsset,
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => _FallbackVectorLogo(size: size),
        ),
      ),
    );

    if (!showName) {
      return Semantics(
        label: 'AtMe',
        image: true,
        child: iconBox,
      );
    }

    return Semantics(
      label: 'AtMe',
      image: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          iconBox,
          const SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (Rect bounds) => const LinearGradient(
              colors: <Color>[
                Colors.white,
                AppColors.aqua,
                AppColors.electricCyan,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              'AtMe',
              style: TextStyle(
                fontSize: nameFontSize ?? (size * 0.28).clamp(20.0, 32.0),
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: nameColor ?? Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackVectorLogo extends StatelessWidget {
  const _FallbackVectorLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        gradient: AppColors.primaryGradient,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(size * 0.24),
        ),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: EdgeInsets.all(size * 0.14),
          child: Text(
            '@Me',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.38,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
