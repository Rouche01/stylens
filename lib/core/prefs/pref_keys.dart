class PrefKey<T> {
  const PrefKey(this.name);

  final String name;
}

/// Canonical SharedPreferences keys. Keep [name] values stable so installs
/// do not reset existing flags.
abstract class PrefKeys {
  static const introWalkthroughCompleted = PrefKey<bool>(
    'intro_walkthrough_completed',
  );
  static const marketingEmailReaskShown = PrefKey<bool>(
    'marketing_email_reask_shown',
  );
  static const pendingInviteCode = PrefKey<String>('pending_invite_code');
  static const closetNotified = PrefKey<bool>('closet_notified');
  static const locationExplainerShown = PrefKey<bool>(
    'location_explainer_shown',
  );
  static const locationUserDeclined = PrefKey<bool>('location_user_declined');
  static const locationCachedLat = PrefKey<double>('location_cached_lat');
  static const locationCachedLng = PrefKey<double>('location_cached_lng');
  static const locationCachedAt = PrefKey<int>('location_cached_at');
  static const stylistOpenersPool = PrefKey<String>('stylist_openers_pool');
  static const stylistOpenersCheckedAt = PrefKey<int>(
    'stylist_openers_checked_at',
  );
  static const stylistOpenersRecentIds = PrefKey<List<String>>(
    'stylist_openers_recent_ids',
  );

  static const all = <PrefKey<dynamic>>[
    introWalkthroughCompleted,
    marketingEmailReaskShown,
    pendingInviteCode,
    closetNotified,
    locationExplainerShown,
    locationUserDeclined,
    locationCachedLat,
    locationCachedLng,
    locationCachedAt,
    stylistOpenersPool,
    stylistOpenersCheckedAt,
    stylistOpenersRecentIds,
  ];
}
