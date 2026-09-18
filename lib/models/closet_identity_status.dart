enum ClosetIdentityPhase {
  started,
  settled;

  static ClosetIdentityPhase? fromJson(dynamic value) {
    return switch (value) {
      'started' => started,
      'settled' => settled,
      _ => null,
    };
  }
}

/// GET `/closet/identity/status` and `closet_identity_updated` payload.
///
/// Counts stay on the model for later use. Do not render them.
class ClosetIdentityStatus {
  const ClosetIdentityStatus({
    this.processing = false,
    this.queued = 0,
    this.running = 0,
    this.failed = 0,
    this.phase,
  });

  final bool processing;
  final int queued;
  final int running;
  final int failed;
  final ClosetIdentityPhase? phase;

  factory ClosetIdentityStatus.fromJson(Map<String, dynamic> json) {
    return ClosetIdentityStatus(
      processing: json['processing'] == true,
      queued: _readCount(json['queued']),
      running: _readCount(json['running']),
      failed: _readCount(json['failed']),
      phase: ClosetIdentityPhase.fromJson(json['phase']),
    );
  }

  static ClosetIdentityStatus fromResponse(dynamic data) {
    if (data is Map) {
      return ClosetIdentityStatus.fromJson(Map<String, dynamic>.from(data));
    }
    return const ClosetIdentityStatus();
  }

  static int _readCount(dynamic value) {
    final n = value is num ? value.toInt() : int.tryParse('$value');
    if (n == null || n < 0) return 0;
    return n;
  }
}
