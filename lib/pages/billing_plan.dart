import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:gostylens/core/managers/subscription_manager.dart';
import 'package:gostylens/navigation/app_routes.dart';
import 'package:gostylens/navigation/navigation_helpers.dart';
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
    VoidCallback? onCopy,
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: valueColor ?? cs.primary.withValues(alpha: 0.6),
                ),
              ),
              if (onCopy != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onCopy,
                  child: Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: cs.primary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
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
          onPressed: () => popDetailOrGoHome(context),
          color: cs.primary,
        ),
      ),
      backgroundColor: cs.tertiary,
      body: Consumer<SubscriptionManager>(
        builder: (context, subManager, _) {
          final subscription = subManager.subscription;
          final isPro = subManager.userHasCorePlan;

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
                            value: subManager.planDisplayName,
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
                              onCopy: () {
                                Clipboard.setData(
                                  ClipboardData(text: subscription.id),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Plan ID copied'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                      if (subscription?.limits != null) ...[
                        const SizedBox(height: 24),
                        Text(
                          'PLAN ENTITLEMENTS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: cs.primary.withValues(alpha: 0.4),
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoCard(
                          context,
                          children: [
                            _buildInfoRow(
                              context,
                              label: 'Analysis Sessions',
                              value:
                                  '${subscription!.limits!.sessionCountLimit}',
                            ),
                            _buildInfoRow(
                              context,
                              label: 'Messages / Session',
                              value:
                                  '${subscription.limits!.messagePerSessionLimit}',
                            ),
                            _buildInfoRow(
                              context,
                              label: 'Images / Session',
                              value:
                                  '${subscription.limits!.imagePerSessionLimit}',
                            ),
                          ],
                        ),
                      ],
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
                                    context.push(AppRoutes.paywall);
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

              // Cancel subscription / restore purchases (only for pro users)
              if (isPro)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Center(
                      child: TextButton(
                        onPressed: subscription?.status == 'cancelled'
                            ? subManager.restorePurchases
                            : subManager.cancelSubscription,
                        child: Text(
                          subscription?.status == 'cancelled'
                              ? 'Restore Subscription'
                              : 'Cancel Subscription',
                          style: TextStyle(
                            color: subscription?.status == 'cancelled'
                                ? cs.primary
                                : Colors.redAccent,
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
