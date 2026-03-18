import 'package:flutter/material.dart';
import 'package:gostylens/core/managers/subscription_manager.dart';
import 'package:gostylens/pages/paywall.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class BillingPlanPage extends StatefulWidget {
  @override
  State<BillingPlanPage> createState() => _BillingPlanPageState();
}

class _BillingPlanPageState extends State<BillingPlanPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionManager>().syncSubscription();
    });
  }

  String _formatTierName(String tier) {
    switch (tier) {
      case 'core':
        return 'Core';
      case 'pro':
        return 'Pro';
      case 'free':
        return 'Free';
      default:
        return tier[0].toUpperCase() + tier.substring(1);
    }
  }

  String _formatDate(int? epochSeconds) {
    if (epochSeconds == null) return '—';
    final date = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
    return DateFormat('MMM d, yyyy').format(date);
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              color: valueColor ?? cs.primary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: cs.primary.withValues(alpha: 0.08),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Billing / Plan',
              style: TextStyle(
                fontFamily: 'ClashDisplay',
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ],
        ),
        titleSpacing: 0,
        backgroundColor: cs.tertiary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          color: cs.primary,
        ),
      ),
      backgroundColor: cs.tertiary,
      body: Consumer<SubscriptionManager>(
        builder: (context, subManager, _) {
          final subscription = subManager.subscription;
          final isPro = subManager.userHasCorePlan;
          final tierName = subscription != null
              ? _formatTierName(subscription.tier)
              : 'Free';

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // Plan info card
                      _buildInfoCard(
                        context,
                        children: [
                          _buildInfoRow(
                            context,
                            label: 'Account Plan',
                            value: tierName,
                          ),
                          if (isPro && subscription != null) ...[
                            _buildInfoRow(
                              context,
                              label: 'Status',
                              value: subscription.status == 'active'
                                  ? 'Active'
                                  : subscription.status[0].toUpperCase() +
                                        subscription.status.substring(1),
                              valueColor: subscription.status == 'active'
                                  ? Colors.green
                                  : null,
                            ),
                            _buildInfoRow(
                              context,
                              label: 'Renewal Date',
                              value: _formatDate(subscription.currentPeriodEnd),
                            ),
                            _buildInfoRow(
                              context,
                              label: 'Plan ID',
                              value: subscription.id.length > 12
                                  ? '${subscription.id.substring(0, 12)}...'
                                  : subscription.id,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Upgrade section (only for free users)
                      if (!isPro) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: cs.primary.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Want more from Stylens?',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Upgrade for more usage and capabilities.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: cs.primary.withValues(alpha: 0.7),
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const PaywallPage(),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: cs.primary,
                                    side: BorderSide(
                                      color: cs.primary.withValues(alpha: 0.3),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 10,
                                    ),
                                  ),
                                  child: const Text(
                                    'Upgrade',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Cancel subscription (only for pro users)
              if (isPro)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Center(
                      child: TextButton(
                        onPressed: subManager.cancelSubscription,
                        child: const Text(
                          'Cancel Subscription',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
