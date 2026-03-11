import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:gostylens/core/managers/subscription_manager.dart';
import 'package:gostylens/widgets/paywall_feature_card.dart';
import 'package:gostylens/widgets/paywall_toggle_row.dart';
import 'package:gostylens/widgets/primary_button.dart';
import 'package:purchases_flutter/models/package_wrapper.dart';

class PaywallPage extends StatefulWidget {
  final bool isDrawer;

  const PaywallPage({super.key, this.isDrawer = false});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  bool isAnnual = false;
  late SubscriptionManager _subscriptionManager;

  double? _calculateMonthlyPriceForAnnual(Package? annualPackage) {
    if (annualPackage == null) return null;
    return annualPackage.storeProduct.price / 12.0;
  }

  int? _calculateSavingsPercentage(
    Package? monthlyPackage,
    Package? annualPackage,
  ) {
    if (monthlyPackage == null || annualPackage == null) return null;
    final monthlyPrice = monthlyPackage.storeProduct.price;
    final annualPrice = annualPackage.storeProduct.price;

    if (monthlyPrice <= 0 || annualPrice <= 0) return 0;

    final monthlyCostForAnnual = annualPrice / 12.0;
    final savings = (1 - (monthlyCostForAnnual / monthlyPrice)) * 100;

    return savings.round();
  }

  @override
  void initState() {
    super.initState();
    _subscriptionManager = context.read<SubscriptionManager>();
  }

  Future<void> _restoreSubscription() async {
    final isPro = await _subscriptionManager.restorePurchases();
    if (isPro && mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Purchases restored!')));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No subscription available to restore')),
      );
    }
  }

  Future<void> _upgradeToCorePlan(Package? selectedPackage) async {
    if (selectedPackage != null) {
      final isPro = await _subscriptionManager.purchasePackage(selectedPackage);
      if (isPro && mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offerings not loaded yet.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.tertiary,
      extendBodyBehindAppBar: true,
      body: SafeArea(
        bottom: false,
        child: Consumer<SubscriptionManager>(
          builder: (context, subscriptionManager, _) {
            final currentOffering = subscriptionManager.offerings?.current;

            final monthlyPackage = currentOffering?.availablePackages
                .where((p) => p.packageType == PackageType.monthly)
                .firstOrNull;
            final annualPackage = currentOffering?.availablePackages
                .where((p) => p.packageType == PackageType.annual)
                .firstOrNull;

            final selectedPackage = isAnnual ? annualPackage : monthlyPackage;
            final savingsPercentage =
                _calculateSavingsPercentage(monthlyPackage, annualPackage) ?? 0;

            // Formatting raw double manually for reliable $ amounts
            double? price = selectedPackage?.storeProduct.price;
            if (isAnnual && annualPackage != null) {
              price = _calculateMonthlyPriceForAnnual(annualPackage);
            }

            final currencyCode =
                selectedPackage?.storeProduct.currencyCode ?? 'USD';
            final priceString = price != null
                ? NumberFormat.simpleCurrency(name: currencyCode).format(price)
                : (isAnnual ? '\$5.99' : '\$9.99');
            final periodString = isAnnual
                ? '/ month, billed annually'
                : '/ month';

            return Column(
              children: [
                // Header
                PaywallHeader(isDrawer: widget.isDrawer),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                priceString,
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w600,
                                  color: cs.primary,
                                  fontFamily: 'ClashDisplay',
                                  height: 1.0,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Text(
                                  periodString,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 18,
                                color: cs.primary,
                                fontWeight: FontWeight.w500,
                                height: 1.1,
                                letterSpacing: -1.0,
                              ),
                              children: [
                                const TextSpan(text: 'Your stylist, who '),
                                TextSpan(
                                  text: 'actually ',
                                  style: TextStyle(
                                    color: cs.primaryFixed,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const TextSpan(text: 'remembers you.'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Toggle
                          PaywallToggleRow(
                            isAnnual: isAnnual,
                            onChanged: (val) => setState(() => isAnnual = val),
                            activeColor: cs.primary,
                            savingsPercentage: savingsPercentage,
                          ),
                          const SizedBox(height: 16),
                          // Cards
                          PaywallFeatureCard(
                            iconChild: Icon(
                              Icons.all_inclusive,
                              color: Colors.black87.withValues(alpha: 0.6),
                              size: 24,
                            ),
                            title: 'Unlimited outfit analyses',
                            subtitle: 'No caps. Style as much as you want.',
                          ),
                          PaywallFeatureCard(
                            iconChild: const Text(
                              '🧠',
                              style: TextStyle(fontSize: 20),
                            ),
                            title: 'Stylist memory',
                            subtitle:
                                'Remembers your wardrobe, style & past tips.',
                          ),
                          PaywallFeatureCard(
                            iconChild: const Text(
                              '👔',
                              style: TextStyle(fontSize: 20),
                            ),
                            title: 'Full closet + mix & match',
                            subtitle:
                                'Unlimited items. Outfit suggestions from what you own.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Sticky Footer Bottom
                PaywallFooter(
                  selectedPackage: selectedPackage,
                  isLoading: subscriptionManager.isLoading,
                  isAnnual: isAnnual,
                  onRestoreSubscription: _restoreSubscription,
                  onUpgradeToCorePlan: _upgradeToCorePlan,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class PaywallHeader extends StatelessWidget {
  final bool isDrawer;

  const PaywallHeader({super.key, required this.isDrawer});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: TextSpan(
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  baseline: TextBaseline.alphabetic,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 5.0, bottom: 8.0),
                    child: Image.asset(
                      'assets/imgs/logo_primary.png',
                      height: 28,
                    ),
                  ),
                ),
                TextSpan(
                  text: 'Core',
                  style: TextStyle(
                    color: cs.primaryFixed,
                    fontSize: 28,
                    fontFamily: 'ClashDisplay',
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          if (!isDrawer)
            Container(
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.close, color: cs.primary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
    );
  }
}

class PaywallFooter extends StatelessWidget {
  final Package? selectedPackage;
  final bool isAnnual;
  final bool isLoading;
  final VoidCallback onRestoreSubscription;
  final ValueChanged<Package?> onUpgradeToCorePlan;

  const PaywallFooter({
    super.key,
    required this.selectedPackage,
    required this.isAnnual,
    required this.isLoading,
    required this.onRestoreSubscription,
    required this.onUpgradeToCorePlan,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    final currencyCode = selectedPackage?.storeProduct.currencyCode ?? 'USD';
    final price = selectedPackage?.storeProduct.price;
    final priceString = price != null
        ? NumberFormat.simpleCurrency(name: currencyCode).format(price)
        : (isAnnual ? '\$5.99' : '\$79.99');

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 24.0,
      ).copyWith(bottom: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: TextButton(
              onPressed: onRestoreSubscription,
              child: const Text(
                'Restore Subscription',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  decoration: TextDecoration.underline,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          PrimaryButton(
            label: 'Upgrade to Core',
            onPressed: () => onUpgradeToCorePlan(selectedPackage),
            isLoading: isLoading,
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Renews for $priceString/${isAnnual ? 'year' : 'month'}. Cancel anytime.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {},
                child: const Text(
                  'Privacy Policy',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ),
              const Text('  ', style: TextStyle(color: Color(0xFF6B7280))),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'Terms of Use',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
