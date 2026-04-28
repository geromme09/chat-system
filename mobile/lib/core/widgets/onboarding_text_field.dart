import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class OnboardingTextField extends StatefulWidget {
  const OnboardingTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.trailing,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.onSubmitted,
    this.maxLines = 1,
    this.minHeight = AppSpacing.inputHeight,
    this.inputFormatters,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final Widget? trailing;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final double minHeight;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;

  @override
  State<OnboardingTextField> createState() => _OnboardingTextFieldState();
}

class _OnboardingTextFieldState extends State<OnboardingTextField> {
  final FocusNode _focusNode = FocusNode();

  bool get _isMultiline => widget.maxLines > 1;

  bool get _isFloating {
    return _focusNode.hasFocus || widget.controller.text.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleStateChanged);
    widget.controller.addListener(_handleStateChanged);
  }

  @override
  void didUpdateWidget(covariant OnboardingTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;

    oldWidget.controller.removeListener(_handleStateChanged);
    widget.controller.addListener(_handleStateChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleStateChanged);
    widget.controller.removeListener(_handleStateChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleStateChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = _focusNode.hasFocus;
    final labelColor = isFocused ? AppColors.primary : AppColors.textTertiary;

    return Opacity(
      opacity: widget.enabled ? 1 : 0.55,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? () => _focusNode.requestFocus() : null,
        child: AnimatedContainer(
          duration: AppMotion.quick,
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints(minHeight: widget.minHeight),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isFocused ? AppColors.primary : AppColors.border,
              width: isFocused ? AppSizes.focusBorder : AppSizes.border,
            ),
            boxShadow: [
              if (isFocused)
                BoxShadow(
                  color:
                      AppColors.primary.withValues(alpha: AppOpacity.focusGlow),
                  blurRadius: AppSpacing.sm,
                ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: _isMultiline ? AppSpacing.md : 0,
          ),
          child: Row(
            crossAxisAlignment: _isMultiline
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  top: _isMultiline ? AppSpacing.xs : 0,
                ),
                child: Icon(
                  widget.icon,
                  color: AppColors.textPrimary,
                  size: AppSizes.icon,
                ),
              ),
              const SizedBox(width: AppSpacing.inputIconGap),
              Expanded(
                child: SizedBox(
                  height: _isMultiline ? null : AppSpacing.inputHeight,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      AnimatedOpacity(
                        duration: AppMotion.quick,
                        curve: Curves.easeOutCubic,
                        opacity: _isFloating ? 1 : 0,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: Text(
                              widget.label,
                              style: TextStyle(
                                color: labelColor,
                                fontSize: AppTypography.label,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          top: _isMultiline
                              ? AppSpacing.lg
                              : (_isFloating ? AppSpacing.lg : 0),
                          right: widget.trailing == null ? 0 : AppSpacing.xs,
                        ),
                        child: TextField(
                          controller: widget.controller,
                          focusNode: _focusNode,
                          enabled: widget.enabled,
                          keyboardType: widget.keyboardType,
                          textInputAction: widget.textInputAction,
                          autofillHints: widget.autofillHints,
                          obscureText: widget.obscureText,
                          onSubmitted: widget.onSubmitted,
                          maxLines: widget.obscureText ? 1 : widget.maxLines,
                          minLines: _isMultiline ? widget.maxLines : 1,
                          inputFormatters: widget.inputFormatters,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: AppTypography.body,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: widget.hint,
                            hintStyle: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: AppTypography.body,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
