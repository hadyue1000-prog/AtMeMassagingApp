import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// 6-digit OTP pin input built directly on Flutter's standard `flutter/material.dart`
/// and `EditableText` (avoiding `pinput 7.0.0`'s incompatible `material_ui` dependency).
class OtpPinField extends StatefulWidget {
  const OtpPinField({
    super.key,
    required this.length,
    required this.controller,
    required this.focusNode,
    this.enabled = true,
    this.autofocus = true,
    this.hasError = false,
    this.inputFormatters = const <TextInputFormatter>[],
    this.onChanged,
    this.onCompleted,
  });

  final int length;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool autofocus;
  final bool hasError;
  final List<TextInputFormatter> inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  @override
  State<OtpPinField> createState() => _OtpPinFieldState();
}

class _OtpPinFieldState extends State<OtpPinField>
    implements TextSelectionGestureDetectorBuilderDelegate, AutofillClient {
  @override
  final GlobalKey<EditableTextState> editableTextKey =
      GlobalKey<EditableTextState>();

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => true;

  @override
  String get autofillId =>
      editableTextKey.currentState?.autofillId ?? 'otp_pin_field';

  late final TextSelectionGestureDetectorBuilder _gestureDetectorBuilder;
  late String _recentText;

  EditableTextState? get _editableText => editableTextKey.currentState;

  String get _pin => widget.controller.text;

  int get _currentLength => _pin.characters.length;

  @override
  void initState() {
    super.initState();
    _gestureDetectorBuilder = TextSelectionGestureDetectorBuilder(
      delegate: this,
    );
    _recentText = widget.controller.text;
    widget.controller.addListener(_onControllerChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant OtpPinField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      _recentText = widget.controller.text;
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onControllerChanged() {
    final String current = widget.controller.text;
    if (current != _recentText) {
      _recentText = current;
      widget.onChanged?.call(current);
      if (current.characters.length == widget.length) {
        widget.focusNode.unfocus();
        widget.onCompleted?.call(current);
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _requestKeyboard() {
    if (!widget.enabled) return;
    if (!widget.focusNode.hasFocus) {
      widget.focusNode.requestFocus();
    }
    _editableText?.requestKeyboard();
    final int len = _pin.length;
    widget.controller.selection = TextSelection.collapsed(offset: len);
  }

  void _handleSelectionChanged(
    TextSelection selection,
    SelectionChangedCause? cause,
  ) {
    final int len = _currentLength;
    final bool allSelected = selection.start == 0 && selection.end == len;
    final bool lastSelected =
        selection.start == len - 1 && selection.end == len;
    if (!allSelected && !lastSelected) {
      widget.controller.selection = TextSelection.collapsed(offset: len);
    }
  }

  TextSelectionControls _resolveSelectionControls(TargetPlatform platform) {
    switch (platform) {
      case TargetPlatform.iOS:
        return cupertinoTextSelectionHandleControls;
      case TargetPlatform.macOS:
        return cupertinoDesktopTextSelectionHandleControls;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return materialTextSelectionHandleControls;
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return desktopTextSelectionHandleControls;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<TextInputFormatter> formatters = <TextInputFormatter>[
      ...widget.inputFormatters,
      LengthLimitingTextInputFormatter(
        widget.length,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
      ),
    ];

    return Directionality(
      textDirection: TextDirection.ltr,
      child: IntrinsicWidth(
        child: MouseRegion(
          cursor: widget.enabled
              ? SystemMouseCursors.text
              : SystemMouseCursors.basic,
          child: TextFieldTapRegion(
            child: IgnorePointer(
              ignoring: !widget.enabled,
              child: _gestureDetectorBuilder.buildGestureDetector(
                behavior: HitTestBehavior.translucent,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _requestKeyboard,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Positioned.fill(
                        child: EditableText(
                          key: editableTextKey,
                          controller: widget.controller,
                          focusNode: widget.focusNode,
                          readOnly: !widget.enabled,
                          autofocus: widget.autofocus,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          enableSuggestions: false,
                          enableInteractiveSelection: true,
                          showCursor: false,
                          showSelectionHandles: false,
                          rendererIgnoresPointer: true,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          inputFormatters: formatters,
                          autofillClient: this,
                          autofillHints: const <String>[
                            AutofillHints.oneTimeCode,
                          ],
                          selectionColor: Colors.transparent,
                          cursorColor: Colors.transparent,
                          backgroundCursorColor: Colors.transparent,
                          selectionControls: _resolveSelectionControls(
                            theme.platform,
                          ),
                          onSelectionChanged: _handleSelectionChanged,
                          contextMenuBuilder: (
                            BuildContext ctx,
                            EditableTextState editableState,
                          ) {
                            return AdaptiveTextSelectionToolbar.editableText(
                              editableTextState: editableState,
                            );
                          },
                          style: const TextStyle(
                            color: Colors.transparent,
                            fontSize: 1,
                            height: 1,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List<Widget>.generate(
                          widget.length * 2 - 1,
                          (int i) {
                            if (i.isOdd) {
                              return const SizedBox(width: 8);
                            }
                            final int index = i ~/ 2;
                            return Flexible(
                              child: _buildCell(index),
                            );
                          },
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

  Widget _buildCell(int index) {
    final String text = _pin;
    final bool isSubmitted = index < text.length;
    final int activeIndex = text.length.clamp(0, widget.length - 1);
    final bool isFocused =
        widget.enabled && widget.focusNode.hasFocus && index == activeIndex;
    final bool showCursor =
        widget.enabled && widget.focusNode.hasFocus && index == text.length;

    final bool isDark = AppColors.isDark;
    Gradient? cellGradient = isDark
        ? AppColors.glassCardGradient
        : AppColors.lightGlassCardGradient;
    Color bgColor = AppColors.inputFill;
    Border border = Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.24)
          : AppColors.lightBorder,
      width: 1.2,
    );
    List<BoxShadow>? shadows;

    if (!widget.enabled) {
      cellGradient = null;
      bgColor = AppColors.inputFill.withValues(alpha: 0.6);
    } else if (widget.hasError) {
      cellGradient = null;
      bgColor = AppColors.error.withValues(alpha: 0.12);
      border = Border.all(color: AppColors.error, width: 1.6);
    } else if (isFocused) {
      cellGradient = AppColors.glassHighlightedGradient;
      border = Border.all(color: AppColors.aqua, width: 1.8);
      shadows = <BoxShadow>[
        BoxShadow(
          color: AppColors.electricCyan.withValues(alpha: 0.35),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];
    } else if (isSubmitted) {
      cellGradient = AppColors.glassHighlightedGradient;
      border = Border.all(color: AppColors.electricCyan.withValues(alpha: 0.65));
    }

    final String char = isSubmitted ? text[index] : '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 50,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cellGradient == null ? bgColor : null,
        gradient: cellGradient,
        borderRadius: BorderRadius.circular(16),
        border: border,
        boxShadow: shadows,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(scale: animation, child: child);
        },
        child: isSubmitted
            ? Text(
                char,
                key: ValueKey<String>('digit_${index}_$char'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              )
            : showCursor
                ? const _BlinkingPinCursor(key: ValueKey<String>('cursor'))
                : const SizedBox.shrink(key: ValueKey<String>('empty')),
      ),
    );
  }

  @override
  void autofill(TextEditingValue newEditingValue) {
    _editableText?.autofill(newEditingValue);
  }

  @override
  TextInputConfiguration get textInputConfiguration {
    final AutofillConfiguration autofillConfig = AutofillConfiguration(
      uniqueIdentifier: autofillId,
      autofillHints: const <String>[AutofillHints.oneTimeCode],
      currentEditingValue: widget.controller.value,
    );
    return _editableText!.textInputConfiguration.copyWith(
      autofillConfiguration: autofillConfig,
    );
  }
}

class _BlinkingPinCursor extends StatefulWidget {
  const _BlinkingPinCursor({super.key});

  @override
  State<_BlinkingPinCursor> createState() => _BlinkingPinCursorState();
}

class _BlinkingPinCursorState extends State<_BlinkingPinCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2.2,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
