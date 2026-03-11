import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gostylens/core/managers/subscription_manager.dart';
import 'package:gostylens/widgets/primary_button.dart';

class PaywallPage extends StatelessWidget {
  final bool isDrawer;

  const PaywallPage({super.key, this.isDrawer = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceDim,
      appBar: isDrawer
          ? null
          : AppBar(
              backgroundColor: Theme.of(context).colorScheme.tertiary,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close),
                color: Theme.of(context).colorScheme.primary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'GoStylens Core',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                  fontFamily: 'ClashDisplay',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Unlock unlimited AI style analysis sessions, dedicated wardrobe storage, and advanced outfit generation.',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Expanded(
                child: Consumer<SubscriptionManager>(
                  builder: (context, subscriptionManager, child) {
                    if (subscriptionManager.isLoading ||
                        subscriptionManager.offerings == null) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final currentOffering =
                        subscriptionManager.offerings!.current;
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withAlpha(50),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(10),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    package.storeProduct.title,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    package.storeProduct.priceString,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                package.storeProduct.description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withAlpha(150),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        PrimaryButton(
                          label: 'Upgrade to Core',
                          onPressed: () async {
                            final isPro = await subscriptionManager
                                .purchasePackage(package);
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
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
