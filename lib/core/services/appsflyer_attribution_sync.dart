/// Registered by [SubscriptionManager] so tracking can resync after ATT
/// without a circular import.
class AppsFlyerAttributionSyncHook {
  static Future<void> Function()? sync;
}
