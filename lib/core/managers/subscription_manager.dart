import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gostylens/constants/revenue_cat.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:async';

import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/services/api_service/index.dart';
import 'package:gostylens/models/api_responses/subscription.dart';
import 'package:gostylens/core/config/env_config.dart';
import 'package:gostylens/core/services/realtime_service.dart';
import 'package:flutter/material.dart';

class SubscriptionManager extends ChangeNotifier with WidgetsBindingObserver {
  final SubscriptionApiService _subscriptionApiService;
  final RealtimeService _realtimeService;

  SubscriptionManager()
    : _subscriptionApiService = locator<SubscriptionApiService>(),
      _realtimeService = locator<RealtimeService>() {
    WidgetsBinding.instance.addObserver(this);
  }

  bool _isInitialized = false;
  bool _isLoading = false;
  CustomerInfo? _customerInfo;
  Offerings? _offerings;
  Subscription? _subscription;
  String? _currentUserId;
  StreamSubscription? _realtimeSubscription;

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  CustomerInfo? get customerInfo => _customerInfo;
  Offerings? get offerings => _offerings;
  Subscription? get subscription => _subscription;

  // Checks if the user has the 'gostylens_core' entitlement from RevenueCat
  bool get userHasCorePlan =>
      _subscription?.isCore ??
      _customerInfo
          ?.entitlements
          .all[RevenueCatConstants.gostylensCoreEntitlement]
          ?.isActive ??
      false;

  // Checks if the user is on the monthly plan
  bool get isMonthlyPlan {
    if (!userHasCorePlan) return false;

    // Check RevenueCat state for the specific product ID
    final entitlement = _customerInfo
        ?.entitlements
        // ignore: invalid_use_of_protected_member
        .all[RevenueCatConstants.gostylensCoreEntitlement];
    return entitlement?.productIdentifier ==
        RevenueCatConstants.coreMonthlyProductIdentifier;
  }

  // Checks if the user is on the annual plan
  bool get isAnnualPlan {
    if (!userHasCorePlan) return false;

    // Check RevenueCat state for the specific product ID
    final entitlement = _customerInfo
        ?.entitlements
        // ignore: invalid_use_of_protected_member
        .all[RevenueCatConstants.gostylensCoreEntitlement];
    return entitlement?.productIdentifier ==
        RevenueCatConstants.coreYearlyProductIdentifier;
  }

  /// Returns a formatted display name for the current plan,
  /// e.g. "Free", "Core (Monthly)", or "Pro (Annual)".
  String get planDisplayName {
    if (_subscription == null) return 'Free';

    final tier = _subscription!.tier.toLowerCase();
    final name = switch (tier) {
      'core' => 'Core',
      'pro' => 'Pro',
      'free' => 'Free',
      _ => tier.isNotEmpty ? tier[0].toUpperCase() + tier.substring(1) : tier,
    };

    if (isMonthlyPlan) return '$name (Monthly)';
    if (isAnnualPlan) return '$name (Annual)';

    return name;
  }

  Future<void> initialize(
    String dbId, {
    Subscription? initialSubscription,
  }) async {
    // If already initialized for the same user, just refresh state/backend data
    if (_isInitialized && _currentUserId == dbId) {
      if (initialSubscription != null) {
        _subscription = initialSubscription;
        notifyListeners();
      }
      _pushRevenueCatState().then((_) => syncSubscription());
      return;
    }

    _currentUserId = dbId;
    _subscription = initialSubscription;

    // Listen for subscription updates in realtime
    _realtimeSubscription?.cancel();
    _realtimeSubscription = _realtimeService
        .onBroadcast(channel: 'user-limits:$dbId', event: 'limit_updated')
        .listen((payload) {
          final newLimit = payload['hasReachedLimit'] as bool?;
          if (newLimit != null && _subscription != null) {
            _subscription = _subscription!.copyWith(hasReachedLimit: newLimit);
            notifyListeners();
          }

          syncSubscription();
        });

    try {
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      late PurchasesConfiguration configuration;
      if (Platform.isAndroid) {
        configuration = PurchasesConfiguration(EnvConfig.revenueCatApiKey);
      } else if (Platform.isIOS) {
        configuration = PurchasesConfiguration(EnvConfig.revenueCatApiKey);
      }

      configuration.appUserID = dbId;
      await Purchases.configure(configuration);

      _customerInfo = await Purchases.getCustomerInfo();
      _offerings = await Purchases.getOfferings();

      // 🟢 Push RC state on first init to ensure backend is up-to-date
      await _pushRevenueCatState();
      await syncSubscription();

      // Listen for changing entitlements (e.g. background renewals)
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        print('Customer info updated: $customerInfo');
        _customerInfo = customerInfo;
        notifyListeners();

        // 🟢 Robustness: Push RC state then sync 1 minute after a RC update.
        // This ensures our DB reflects the purchase even if the webhook was delayed.
        Future.delayed(const Duration(minutes: 1), () {
          _pushRevenueCatState().then((_) => syncSubscription());
        });
      });

      _isInitialized = true;
      notifyListeners();
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('RevenueCat Initialization Error: ${e.message}');
      }
    }
  }

  /// Refetches the subscription data from our backend
  Future<void> syncSubscription() async {
    if (_currentUserId == null) return;

    try {
      final response = await _subscriptionApiService.getSubscriptionByUserId(
        _currentUserId!,
      );
      if (response.isSuccess && response.data != null) {
        _subscription = response.data;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error syncing UI subscription state: $e');
      }
    }
  }

  /// Pushes the current RevenueCat entitlement state to our backend
  /// so the subscription record stays in sync even if a webhook was missed.
  Future<void> _pushRevenueCatState() async {
    if (_currentUserId == null || _customerInfo == null) return;

    try {
      final entitlement = _customerInfo
          ?.entitlements
          .all[RevenueCatConstants.gostylensCoreEntitlement];

      final body = <String, dynamic>{
        'provider': 'revenuecat',
        'providerCustomerId': _customerInfo!.originalAppUserId,
      };

      if (entitlement != null && entitlement.isActive) {
        body['tier'] = 'core';
        body['status'] = 'active';
        body['providerSubscriptionId'] = entitlement.productIdentifier;
      } else {
        body['tier'] = 'free';
        body['providerSubscriptionId'] = null;
        body['status'] = 'free';
      }

      await _subscriptionApiService.updateSubscription(
        _currentUserId!,
        body: body,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error pushing RevenueCat state to backend: $e');
      }
    }
  }

  Future<bool> purchasePackage(Package package) async {
    try {
      _isLoading = true;
      notifyListeners();

      // ignore: deprecated_member_use
      final result = await Purchases.purchasePackage(package);
      _customerInfo = result.customerInfo;

      // Push RC state to backend and re-fetch subscription
      await _pushRevenueCatState();
      await syncSubscription();

      return userHasCorePlan;
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        if (kDebugMode) {
          print('Purchase error: ${e.message}');
        }
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> restorePurchases() async {
    try {
      _isLoading = true;
      notifyListeners();

      _customerInfo = await Purchases.restorePurchases();

      // Push restored state to backend and re-fetch subscription
      await _pushRevenueCatState();
      await syncSubscription();

      return userHasCorePlan;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Restore error: ${e.message}');
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Directs the user to the subscription management page.
  Future<bool> cancelSubscription() async {
    try {
      final managementUrl = _customerInfo?.managementURL;
      if (managementUrl == null) {
        // Fallback for iOS/Android if managementURL is missing
        final fallbackUrl = Platform.isIOS
            ? 'https://apps.apple.com/account/subscriptions'
            : 'https://play.google.com/store/account/subscriptions';
        return await launchUrl(
          Uri.parse(fallbackUrl),
          mode: LaunchMode.externalApplication,
        );
      }

      final uri = Uri.parse(managementUrl);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (kDebugMode) {
        print('Error launching subscription management: $e');
      }
      return false;
    }
  }

  /// Resets the manager state. Should be called when logging out.
  Future<void> reset() async {
    try {
      if (_isInitialized) {
        await Purchases.logOut();
      }
    } catch (e) {
      if (kDebugMode) {
        print('RevenueCat LogOut Error: $e');
      }
    }
    _isInitialized = false;
    _customerInfo = null;
    _offerings = null;
    _subscription = null;
    _currentUserId = null;
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    _realtimeService.reset();
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isInitialized) {
      if (kDebugMode) {
        print('🔄 [SubscriptionManager] App resumed, syncing subscription...');
      }
      syncSubscription();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}
