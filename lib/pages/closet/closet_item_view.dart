import 'package:flutter/material.dart';

/// Full-screen closet item detail, pushed over the tab shell.
///
/// Layout lands in later slices; this shell is enough to route and pop Back.
class ClosetItemView extends StatelessWidget {
  const ClosetItemView({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceDim,
      appBar: AppBar(
        backgroundColor: cs.surfaceDim,
        foregroundColor: cs.primary,
        elevation: 0,
        centerTitle: false,
      ),
    );
  }
}
