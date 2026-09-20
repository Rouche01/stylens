import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final Widget? icon;
  final IconAlignment? iconAlignment;
  final double? width;
  final bool disabled;
  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style,
    this.icon,
    this.iconAlignment,
    this.width,
    this.disabled = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ButtonStyle effectiveStyle =
        style ??
        ElevatedButton.styleFrom(
          backgroundColor: disabled || isLoading
              ? Colors.grey.shade300
              : cs.primary,
          foregroundColor: disabled || isLoading
              ? Colors.grey.shade600
              : cs.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        );

    final spinnerColor =
        style?.foregroundColor?.resolve(const <WidgetState>{}) ?? cs.onPrimary;

    Widget childContent = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: spinnerColor,
            ),
          )
        : Text(label);

    // Keep onPressed non-null while loading so M3 does not fade the button
    // (and the spinner) into the disabled colors.
    final VoidCallback? effectiveOnPressed = disabled
        ? null
        : isLoading
        ? () {}
        : onPressed;

    final buttonChild = icon != null && !isLoading
        ? ElevatedButton.icon(
            icon: icon!,
            label: Text(label),
            style: effectiveStyle,
            onPressed: effectiveOnPressed,
            iconAlignment: iconAlignment ?? IconAlignment.start,
          )
        : ElevatedButton(
            style: effectiveStyle,
            onPressed: effectiveOnPressed,
            child: childContent,
          );

    return AbsorbPointer(
      absorbing: disabled || isLoading,
      child: SizedBox(width: width ?? double.infinity, child: buttonChild),
    );
  }
}
