import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gostylens/core/managers/subscription_manager.dart';
import 'package:gostylens/widgets/primary_button.dart';

class PaywallDialog extends StatelessWidget {
  const PaywallDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Theme.of(context).colorScheme.tertiary,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24), // Balance the close button
                Text(
                  'GoStylens Core',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                    fontFamily: 'ClashDisplay',
                  ),
                  textAlign: TextAlign.center,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  color: Theme.of(context).colorScheme.primary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Unlock unlimited AI style analysis sessions, dedicated wardrobe storage, and advanced outfit generation.',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Consumer<SubscriptionManager>(
              builder: (context, subscriptionManager, child) {
                if (subscriptionManager.isLoading ||
                    subscriptionManager.offerings == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final currentOffering = subscriptionManager.offerings!.current;
                if (currentOffering == null ||
                    currentOffering.availablePackages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No subscription packages available right now.',
                    ),
                  );
                }

                final package = currentOffering.availablePackages.first;

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withAlpha(50),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            package.storeProduct.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            package.storeProduct.priceString,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Subscribe Now',
                      onPressed: () async {
                        final isPro = await subscriptionManager.purchasePackage(
                          package,
                        );
                        if (isPro && context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      },
                      isLoading: subscriptionManager.isLoading,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                final subManager = context.read<SubscriptionManager>();
                final isPro = await subManager.restorePurchases();
                if (isPro && context.mounted) {
                  Navigator.of(context).pop(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Purchases restored!')),
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No active subscription found.'),
                    ),
                  );
                }
              },
              child: Text(
                'Restore Purchases',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
