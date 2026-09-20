import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gostylens/core/managers/closet_manager.dart';
import 'package:gostylens/core/navigation/app_navigation_keys.dart';
import 'package:gostylens/pages/closet/closet_item_hero.dart';
import 'package:provider/provider.dart';

/// Full-screen closet item detail, pushed over the tab shell.
class ClosetItemView extends StatefulWidget {
  const ClosetItemView({super.key, required this.itemId});

  final String itemId;

  @override
  State<ClosetItemView> createState() => _ClosetItemViewState();
}

class _ClosetItemViewState extends State<ClosetItemView> {
  var _handledMissing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadDetails());
    });
  }

  Future<void> _loadDetails() async {
    final manager = context.read<ClosetManager>();
    await manager.fetchItemDetails(widget.itemId);
    if (!mounted || _handledMissing) return;
    if (manager.itemDetailsStatusCode(widget.itemId) != 404) return;
    _handledMissing = true;
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('This piece is no longer in your closet')),
    );
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final item = context.select(
      (ClosetManager manager) => manager.itemById(widget.itemId),
    );

    return Scaffold(
      backgroundColor: cs.surfaceDim,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    tooltip: 'Back',
                    color: cs.primary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 42,
                      minHeight: 42,
                    ),
                    icon: const Icon(Icons.chevron_left, size: 28),
                  ),
                  Expanded(
                    child: Text(
                      item?.displayName ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'ClashDisplay',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    tooltip: 'Edit',
                    color: cs.primary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 42,
                      minHeight: 42,
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                ],
              ),
            ),
          ),
          if (item != null)
            ClosetItemHero(
              key: ValueKey('closet-item-hero-${item.id}'),
              item: item,
            ),
        ],
      ),
    );
  }
}
