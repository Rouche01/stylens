import 'package:flutter/material.dart';
import 'package:gostylens/constants/ux_messages.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/managers/push_notification_manager.dart';
import 'package:gostylens/core/managers/user_state_manager.dart';
import 'package:gostylens/core/marketing_email/consent.dart';
import 'package:gostylens/core/services/analytics_service.dart';
import 'package:gostylens/navigation/navigation_helpers.dart';
import 'package:provider/provider.dart';

class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({super.key, this.pushNotifications});

  final PushNotificationManager? pushNotifications;

  @override
  State<NotificationsSettingsPage> createState() =>
      _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends State<NotificationsSettingsPage>
    with WidgetsBindingObserver {
  PushNotificationManager get _push =>
      widget.pushNotifications ?? locator<PushNotificationManager>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _push.addListener(_onPushChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<UserStateManager>().fetchEmailPrefs();
      _push.refreshAuthorization();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _push.removeListener(_onPushChanged);
    super.dispose();
  }

  void _onPushChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _push.refreshAuthorization();
    }
  }

  Future<void> _onMarketingEmailChanged(
    UserStateManager userState,
    bool value,
  ) async {
    final ok = await userState.setMarketingOptIn(value);
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(UxMessages.marketingEmailUpdateFailed)),
        );
      }
      return;
    }
    locator<AnalyticsService>().capture(
      value ? 'marketing_email_opt_in' : 'marketing_email_declined',
      properties: {'source': MarketingEmailConsent.sourceProfile},
    );
  }

  Widget _toggleRow({
    required ColorScheme cs,
    required String label,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ),
          Transform.scale(
            scale: 0.85,
            alignment: Alignment.centerRight,
            child: Switch(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              value: value,
              onChanged: onChanged,
            ),
          ),
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
              'Notifications',
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
      body: Consumer<UserStateManager>(
        builder: (context, userState, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.22)),
                ),
                child: Column(
                  children: [
                    _toggleRow(
                      cs: cs,
                      label: 'In-app notifications',
                      value: _push.isAuthorized,
                      onChanged: _push.setEnabled,
                    ),
                    Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: cs.primary.withValues(alpha: 0.14),
                    ),
                    _toggleRow(
                      cs: cs,
                      label: 'Email tips',
                      value: userState.emailPrefs?.marketingOptIn ?? false,
                      onChanged: userState.isUpdatingEmailPrefs
                          ? null
                          : (value) =>
                                _onMarketingEmailChanged(userState, value),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
