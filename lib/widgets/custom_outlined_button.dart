import 'package:flutter/material.dart';

class CustomOutlinedButton extends StatelessWidget {
  final Widget? icon;
  final String label;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final double? width;

  const CustomOutlinedButton({
    super.key,
    this.icon,
    required this.label,
    required this.onPressed,
    this.style,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final buttonChild = icon != null
        ? OutlinedButton.icon(
            icon: icon!,
            label: Text(label),
            style:
                style ??
                OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            onPressed: onPressed,
          )
        : OutlinedButton(
            style:
                style ??
                OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            onPressed: onPressed,
            child: Text(label),
          );

    return SizedBox(width: width ?? double.infinity, child: buttonChild);
  }
}
