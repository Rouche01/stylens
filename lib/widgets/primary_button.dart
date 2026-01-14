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
    final ButtonStyle effectiveStyle =
        style ??
        ElevatedButton.styleFrom(
          backgroundColor: disabled || isLoading
              ? Colors.grey.shade300
              : Theme.of(context).colorScheme.primary,
          foregroundColor: disabled || isLoading
              ? Colors.grey.shade600
              : Theme.of(context).colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        );

    Widget childContent = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          )
        : Text(label);

    final buttonChild = icon != null && !isLoading
        ? ElevatedButton.icon(
            icon: icon!,
            label: Text(label),
            style: effectiveStyle,
            onPressed: disabled || isLoading ? null : onPressed,
            iconAlignment: iconAlignment ?? IconAlignment.start,
          )
        : ElevatedButton(
            style: effectiveStyle,
            onPressed: disabled || isLoading ? null : onPressed,
            child: childContent,
          );

    return SizedBox(width: width ?? double.infinity, child: buttonChild);
  }
}
