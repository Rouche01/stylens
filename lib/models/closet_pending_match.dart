import 'package:gostylens/models/closet_item.dart';

/// POST `/closet/matches/:id/resolve` body. Response may also be `ask`.
///
/// `asNew` is API `"new"` (`new` is reserved in Dart).
enum ClosetMatchDecision {
  same,
  asNew,
  ask;

  static ClosetMatchDecision? fromJson(dynamic value) {
    return switch (value) {
      'same' => same,
      'new' => asNew,
      'ask' => ask,
      _ => null,
    };
  }

  String get apiValue => switch (this) {
    same => 'same',
    asNew => 'new',
    ask => 'ask',
  };
}

enum ClosetMatchIdentityStatus {
  created,
  ask,
  failed;

  static ClosetMatchIdentityStatus? fromJson(dynamic value) {
    return switch (value) {
      'created' => created,
      'ask' => ask,
      'failed' => failed,
      _ => null,
    };
  }
}

/// Percent box on probe / candidate crops. Kept for later overlay; not rendered
/// on the ask banner.
class ClosetPercentBox {
  const ClosetPercentBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  static ClosetPercentBox? fromJson(dynamic value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final x = _readDouble(json['x']);
    final y = _readDouble(json['y']);
    final width = _readDouble(json['width']);
    final height = _readDouble(json['height']);
    if (x == null || y == null || width == null || height == null) return null;
    return ClosetPercentBox(x: x, y: y, width: width, height: height);
  }
}

/// Probe (new outfit crop) or candidate (piece already in the closet).
class ClosetMatchSide {
  const ClosetMatchSide({
    this.closetItemId,
    this.label = '',
    this.category = '',
    this.subcategory = '',
    this.color = '',
    this.pattern,
    this.imageKey,
    this.boundingBox,
    this.originalImageUrl,
    this.isolatedImageUrl,
  });

  final String? closetItemId;
  final String label;
  final String category;
  final String subcategory;
  final String color;
  final String? pattern;
  final String? imageKey;
  final ClosetPercentBox? boundingBox;
  final String? originalImageUrl;
  final String? isolatedImageUrl;

  String get displayName => ClosetItem.formatDisplayName(label);

  /// Isolated cutout, then the signed original. Scores are never part of this.
  String? get thumbUrl => isolatedImageUrl ?? originalImageUrl;

  factory ClosetMatchSide.fromJson(Map<String, dynamic> json) {
    return ClosetMatchSide(
      closetItemId: _readNonEmpty(json['closet_item_id']),
      label: json['label'] as String? ?? '',
      category: json['category'] as String? ?? '',
      subcategory: json['subcategory'] as String? ?? '',
      color: json['color'] as String? ?? '',
      pattern: _readNonEmpty(json['pattern']),
      imageKey: _readNonEmpty(json['image_key']),
      boundingBox: ClosetPercentBox.fromJson(json['bounding_box']),
      originalImageUrl: _readNonEmpty(json['original_image_url']),
      isolatedImageUrl: _readNonEmpty(json['isolated_image_url']),
    );
  }
}

/// GET `/closet/matches/pending` row.
///
/// Keep [score] / [cosine] / [colorDistance] on the model. Do not render them.
class ClosetPendingMatch {
  const ClosetPendingMatch({
    required this.id,
    required this.outfitId,
    required this.probe,
    required this.candidate,
    this.score,
    this.cosine,
    this.colorDistance,
    this.createdAt = 0,
  });

  final String id;
  final String outfitId;
  final double? score;
  final double? cosine;
  final double? colorDistance;
  final int createdAt;
  final ClosetMatchSide probe;
  final ClosetMatchSide candidate;

  static const askSubtitle = 'Looks like one already in your closet';

  /// Banner title from the candidate label. Never includes scores.
  String get askTitle {
    final name = candidate.displayName.toLowerCase();
    if (name.isEmpty) return 'Same piece?';
    return 'Same $name?';
  }

  factory ClosetPendingMatch.fromJson(Map<String, dynamic> json) {
    return ClosetPendingMatch(
      id: json['id'] as String? ?? '',
      outfitId: json['outfit_id'] as String? ?? '',
      score: _readDouble(json['score']),
      cosine: _readDouble(json['cosine']),
      colorDistance: _readDouble(json['color_distance']),
      createdAt: _readCount(json['created_at']),
      probe: _readSide(json['probe']),
      candidate: _readSide(json['candidate']),
    );
  }

  static List<ClosetPendingMatch> listFromResponse(dynamic data) {
    final raw = data is Map ? data['matches'] : data;
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          ClosetPendingMatch.fromJson(Map<String, dynamic>.from(item)),
    ].where((match) => match.id.isNotEmpty).toList(growable: false);
  }

  static ClosetMatchSide _readSide(dynamic value) {
    if (value is Map) {
      return ClosetMatchSide.fromJson(Map<String, dynamic>.from(value));
    }
    return const ClosetMatchSide();
  }
}

/// POST `/closet/matches/:id/resolve` payload.
class ClosetMatchResolveResult {
  const ClosetMatchResolveResult({
    this.decision,
    this.matchId = '',
    this.closetItemId,
    this.candidateClosetItemId,
    this.identityStatus,
    this.identityReason,
    this.identityScore,
  });

  final ClosetMatchDecision? decision;
  final String matchId;
  final String? closetItemId;
  final String? candidateClosetItemId;
  final ClosetMatchIdentityStatus? identityStatus;
  final String? identityReason;
  final double? identityScore;

  factory ClosetMatchResolveResult.fromJson(Map<String, dynamic> json) {
    return ClosetMatchResolveResult(
      decision: ClosetMatchDecision.fromJson(json['decision']),
      matchId: json['match_id'] as String? ?? '',
      closetItemId: _readNonEmpty(json['closet_item_id']),
      candidateClosetItemId: _readNonEmpty(json['candidate_closet_item_id']),
      identityStatus: ClosetMatchIdentityStatus.fromJson(
        json['identity_status'],
      ),
      identityReason: _readNonEmpty(json['identity_reason']),
      identityScore: _readDouble(json['identity_score']),
    );
  }

  static ClosetMatchResolveResult fromResponse(dynamic data) {
    if (data is Map) {
      return ClosetMatchResolveResult.fromJson(Map<String, dynamic>.from(data));
    }
    return const ClosetMatchResolveResult();
  }
}

String? _readNonEmpty(dynamic value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

double? _readDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

int _readCount(dynamic value) {
  final n = value is num ? value.toInt() : int.tryParse('$value');
  if (n == null || n < 0) return 0;
  return n;
}
