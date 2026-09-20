import 'package:flutter/material.dart';

class CustomOutlinedButton extends StatelessWidget {
  final Widget? icon;
  final String label;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final double? width;
  final bool? disabled;
  final bool isLoading;

  const CustomOutlinedButton({
    super.key,
    this.icon,
    required this.label,
    required this.onPressed,
    this.style,
    this.width,
    this.disabled = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDisabled = disabled ?? false;
    final spinnerColor =
        style?.foregroundColor?.resolve(const <WidgetState>{}) ?? cs.primary;
    final VoidCallback? effectiveOnPressed = isDisabled
        ? null
        : isLoading
        ? () {}
        : onPressed;

    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: spinnerColor,
            ),
          )
        : Text(label);

    final buttonStyle =
        style ??
        OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        );

    final buttonChild = icon != null && !isLoading
        ? OutlinedButton.icon(
            icon: icon!,
            label: Text(label),
            style: buttonStyle,
            onPressed: effectiveOnPressed,
          )
        : OutlinedButton(
            style: buttonStyle,
            onPressed: effectiveOnPressed,
            child: child,
          );

    return AbsorbPointer(
      absorbing: isDisabled || isLoading,
      child: SizedBox(width: width ?? double.infinity, child: buttonChild),
    );
  }
}
