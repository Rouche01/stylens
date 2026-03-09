import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:io';

class SubscriptionManager extends ChangeNotifier {
  bool _isInitialized = false;
  bool _isLoading = false;
  CustomerInfo? _customerInfo;
  Offerings? _offerings;

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  CustomerInfo? get customerInfo => _customerInfo;
  Offerings? get offerings => _offerings;

  // Checks if the user has the 'premium' entitlement from RevenueCat
  bool get isPro =>
      _customerInfo?.entitlements.all['premium']?.isActive ?? false;

  Future<void> initialize(String dbId) async {
    if (_isInitialized) return;
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
          'appl_api_key',
        ); // TODO: Replace with env vars
      }

      configuration.appUserID = dbId;
      await Purchases.configure(configuration);

      _customerInfo = await Purchases.getCustomerInfo();
      _offerings = await Purchases.getOfferings();

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
