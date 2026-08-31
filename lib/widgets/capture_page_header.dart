import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gostylens/core/managers/subscription_manager.dart';
import 'package:gostylens/navigation/app_routes.dart';
import 'package:provider/provider.dart';

/// Capture tab top bar — subscription [Consumer] is scoped here so the hero
/// card below does not rebuild when subscription state changes.
class CapturePageHeader extends StatelessWidget {
  const CapturePageHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
        child: Row(
          children: [
            Image.asset('assets/imgs/logo_primary.png', height: 28),
            const _CaptureUpgradeChip(),
            const Spacer(),
            IconButton(
              onPressed: () {
                context.push(AppRoutes.profile);
              },
              icon: const Icon(Icons.account_circle_rounded),
              iconSize: 39,
              color: cs.primary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureUpgradeChip extends StatelessWidget {
  const _CaptureUpgradeChip();

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionManager>(
      builder: (context, subManager, _) {
        final subscription = subManager.subscription;
        final showUpgrade =
            !subManager.userHasCorePlan &&
            subscription != null &&
            !subscription.hasUnlimitedSessions;

        if (!showUpgrade) return const SizedBox.shrink();

        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(left: 10),
          child: FilledButton(
            onPressed: () {
              context.push(AppRoutes.paywall);
            },
            style: FilledButton.styleFrom(
              backgroundColor: cs.secondary.withValues(alpha: 0.55),
              foregroundColor: cs.primary,
              elevation: 0,
              shadowColor: Colors.transparent,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: cs.primary.withValues(alpha: 0.35)),
              ),
            ),
            child: const Text(
              'Upgrade',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }
}
