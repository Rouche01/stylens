import 'package:flutter/material.dart';

class SettingsMenuItem {
  const SettingsMenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final Widget? trailing;
}

class SettingsMenuGroup extends StatelessWidget {
  const SettingsMenuGroup({super.key, required this.items});

  final List<SettingsMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Material(
              color: Colors.transparent,
              child: ListTile(
                leading: Icon(
                  items[i].icon,
                  color: items[i].color ?? cs.primary.withValues(alpha: 0.7),
                  size: 22,
                ),
                title: Text(
                  items[i].label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: items[i].color ?? cs.primary,
                  ),
                ),
                trailing:
                    items[i].trailing ??
                    Icon(
                      Icons.chevron_right,
                      color: cs.primary.withValues(alpha: 0.3),
                      size: 20,
                    ),
                onTap: items[i].onTap,
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (i < items.length - 1)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: cs.primary.withValues(alpha: 0.06),
              ),
          ],
        ],
      ),
    );
  }
}
