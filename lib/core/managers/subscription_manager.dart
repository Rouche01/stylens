import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gostylens/constants/revenue_cat.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:async';

import 'package:gostylens/core/services/api_service/index.dart';
import 'package:gostylens/models/api_responses/subscription.dart';
import 'package:gostylens/core/config/env_config.dart';

class SubscriptionManager extends ChangeNotifier {
  final SubscriptionApiService _subscriptionApiService;

  SubscriptionManager({SubscriptionApiService? apiService})
    : _subscriptionApiService = apiService ?? SubscriptionApiService();

  bool _isInitialized = false;
  bool _isLoading = false;
  CustomerInfo? _customerInfo;
  Offerings? _offerings;
  Subscription? _subscription;
  String? _currentUserId;
  Timer? _syncTimer;

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
        RevenueCatConstants.coreAnnualProductIdentifier;
  }

  Future<void> initialize(
    String dbId, {
    Subscription? initialSubscription,
  }) async {
    if (_isInitialized && _currentUserId == dbId) return;
    _currentUserId = dbId;
    _subscription = initialSubscription;

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

      // Listen for changing entitlements (e.g. background renewals)
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        print('Customer info updated: $customerInfo');
        _customerInfo = customerInfo;
        notifyListeners();

        // 🟢 Robustness: Sync with our backend 1 minute after a RC update
        // This ensures that our own DB session/subscription state reflects the purchase
        // after the webhook has likely been processed.
        Future.delayed(const Duration(minutes: 1), () => syncSubscription());
      });

      // 🟢 Periodically sync every 5 minutes for additional safety
      _syncTimer?.cancel();
      _syncTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => syncSubscription(),
      );

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

  Future<bool> purchasePackage(Package package) async {
    try {
      _isLoading = true;
      notifyListeners();

      // ignore: deprecated_member_use
      final result = await Purchases.purchasePackage(package);
      _customerInfo = result.customerInfo;
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
    _syncTimer?.cancel();
    _syncTimer = null;
    notifyListeners();
  }
}
