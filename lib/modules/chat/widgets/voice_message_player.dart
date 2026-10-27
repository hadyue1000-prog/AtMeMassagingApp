import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/message_model.dart';
import '../chat_controller.dart';

/// Embedded glassmorphism audio player inside a chat bubble matching the
/// visual reference waveform + circular cyan play button + duration & speed.
class VoiceMessagePlayer extends GetView<ChatController> {
  const VoiceMessagePlayer({
    super.key,
    required this.message,
    required this.isMine,
  });

  final MessageModel message;
  final bool isMine;

  static const List<double> _waveformHeights = <double>[
    0.35,
    0.65,
    0.45,
    0.85,
    0.55,
    0.95,
    0.40,
    0.75,
    0.60,
    1.00,
    0.50,
    0.80,
    0.42,
    0.90,
    0.62,
    0.72,
    0.38,
    0.82,
    0.52,
    0.68,
    0.44,
    0.58,
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = AppColors.isDark;
    final Color primaryFg = isMine
        ? (isDark ? const Color(0xFF0A4DA6) : Colors.white)
        : AppColors.aqua;
    final Color secondaryFg = isMine
        ? AppColors.outgoingText.withValues(alpha: 0.75)
        : AppColors.textSecondary;
    final Color inactiveWave = isMine
        ? primaryFg.withValues(alpha: 0.28)
        : Colors.white.withValues(alpha: 0.26);

    return Obx(() {
      final bool isThisActive =
          controller.activeAudioMessageId.value == message.id;
      final bool isPlaying = isThisActive && controller.isAudioPlaying.value;
      final bool isBuffering =
          isThisActive && controller.isAudioBuffering.value;
      final double speed = controller.playbackSpeed.value;

      final double fallbackSeconds =
          math.max(1, message.audioDuration).toDouble();
      final double totalSeconds = isThisActive &&
              controller.audioTotalDuration.value.inMilliseconds > 0
          ? controller.audioTotalDuration.value.inMilliseconds / 1000.0
          : fallbackSeconds;

      final double currentSeconds = isThisActive
          ? (controller.audioPosition.value.inMilliseconds / 1000.0)
              .clamp(0.0, totalSeconds)
          : 0.0;

      final double progress =
          totalSeconds > 0 ? (currentSeconds / totalSeconds).clamp(0.0, 1.0) : 0.0;

      final int displayedSeconds =
          isThisActive && (isPlaying || currentSeconds > 0)
              ? currentSeconds.round()
              : message.audioDuration;

      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 230, maxWidth: 280),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Glowing Play / Pause circle button
            InkWell(
              onTap: () => controller.togglePlayVoiceMessage(message),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: isMine && isDark
                      ? AppColors.cyanButtonGradient
                      : LinearGradient(
                          colors: <Color>[
                            primaryFg.withValues(alpha: 0.28),
                            primaryFg.withValues(alpha: 0.16),
                          ],
                        ),
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.electricCyan.withValues(alpha: 0.28),
                      blurRadius: 10,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: isBuffering
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: isMine && isDark ? Colors.white : primaryFg,
                        size: 26,
                      ),
              ),
            ),
            const SizedBox(width: 10),

            // Waveform + Interactive seek + Duration & Speed Pill
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox(height: 4),
                  // Visual waveform bars with tap/drag seek
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (TapDownDetails d) {
                      if (!isThisActive) {
                        controller.togglePlayVoiceMessage(message);
                        return;
                      }
                      final RenderBox? box =
                          context.findRenderObject() as RenderBox?;
                      if (box != null && box.size.width > 0) {
                        final double ratio =
                            (d.localPosition.dx / (box.size.width - 60))
                                .clamp(0.0, 1.0);
                        controller.seekVoiceMessage(
                          message.id,
                          ratio * totalSeconds,
                        );
                      }
                    },
                    child: SizedBox(
                      height: 26,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: List<Widget>.generate(
                          _waveformHeights.length,
                          (int i) {
                            final double barPos =
                                i / (_waveformHeights.length - 1);
                            final bool activeBar = barPos <= progress;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 120),
                              width: 3,
                              height: 24 * _waveformHeights[i],
                              decoration: BoxDecoration(
                                color: activeBar ? primaryFg : inactiveWave,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.graphic_eq_rounded,
                            size: 13,
                            color: secondaryFg,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'voice_note_label'.tr,
                            style: TextStyle(
                              color: secondaryFg,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          InkWell(
                            onTap: controller.cyclePlaybackSpeed,
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: primaryFg.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  speed == 1.0
                                      ? '1x'
                                      : (speed == 1.5 ? '1.5x' : '2x'),
                                  style: TextStyle(
                                    color: primaryFg,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              ChatController.formatSeconds(displayedSeconds),
                              style: TextStyle(
                                color: secondaryFg,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
