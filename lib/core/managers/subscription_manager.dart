import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:io';

import 'package:gostylens/core/services/api_service/index.dart';
import 'package:gostylens/models/api_responses/subscription.dart';

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

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  CustomerInfo? get customerInfo => _customerInfo;
  Offerings? get offerings => _offerings;
  Subscription? get subscription => _subscription;

  // Checks if the user has the 'premium' entitlement from RevenueCat
  bool get isPro =>
      _customerInfo?.entitlements.all['premium']?.isActive ?? false;

  Future<void> initialize(
    String dbId, {
    Subscription? initialSubscription,
  }) async {
    if (_isInitialized) return;
    _currentUserId = dbId;
    _subscription = initialSubscription;

    try {
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }

      late PurchasesConfiguration configuration;
      if (Platform.isAndroid) {
        configuration = PurchasesConfiguration(
          'goog_api_key',
        ); // TODO: Replace with env vars
      } else if (Platform.isIOS) {
        configuration = PurchasesConfiguration(
          'test_GLCjlLwYeqaAcxnOycinuoEncoM',
        );
      }

      configuration.appUserID = dbId;
      await Purchases.configure(configuration);

      _customerInfo = await Purchases.getCustomerInfo();
      _offerings = await Purchases.getOfferings();

      print('customer info: ${_customerInfo?.entitlements.all}');

      print('offerings: $_offerings');

      // Listen for changing entitlements (e.g. background renewals)
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _customerInfo = customerInfo;
        notifyListeners();
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

  Future<bool> purchasePackage(Package package) async {
    try {
      _isLoading = true;
      notifyListeners();

      // ignore: deprecated_member_use
      final result = await Purchases.purchasePackage(package);
      _customerInfo = result.customerInfo;
      return isPro;
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
      return isPro;
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
}
