class EmailPrefs {
  final bool marketingOptIn;
  final int? marketingOptInAt;
  final int? marketingUnsubscribedAt;

  const EmailPrefs({
    required this.marketingOptIn,
    this.marketingOptInAt,
    this.marketingUnsubscribedAt,
  });

  /// GET with no prefs row: opted out, no timestamps.
  static const optedOut = EmailPrefs(
    marketingOptIn: false,
    marketingOptInAt: null,
    marketingUnsubscribedAt: null,
  );

  factory EmailPrefs.fromJson(Map<String, dynamic> json) {
    return EmailPrefs(
      marketingOptIn: json['marketingOptIn'] == true,
      marketingOptInAt: _asInt(json['marketingOptInAt']),
      marketingUnsubscribedAt: _asInt(json['marketingUnsubscribedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'marketingOptIn': marketingOptIn,
      'marketingOptInAt': marketingOptInAt,
      'marketingUnsubscribedAt': marketingUnsubscribedAt,
    };
  }

  EmailPrefs copyWith({
    bool? marketingOptIn,
    int? marketingOptInAt,
    int? marketingUnsubscribedAt,
  }) {
    return EmailPrefs(
      marketingOptIn: marketingOptIn ?? this.marketingOptIn,
      marketingOptInAt: marketingOptInAt ?? this.marketingOptInAt,
      marketingUnsubscribedAt:
          marketingUnsubscribedAt ?? this.marketingUnsubscribedAt,
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}
