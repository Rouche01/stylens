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
    this.blurHash,
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
  final String? blurHash;

  String get displayName => ClosetItem.formatDisplayName(label);

  /// Photo crop of the outfit (`cutout=0`), not the SAM silhouette.
  /// Falls back to the signed original. Scores are never part of this.
  String? get thumbUrl {
    final isolate = isolatedImageUrl;
    if (isolate != null) return photoCropUrl(isolate);
    return originalImageUrl;
  }

  /// Short name for “Same {name}?” — keep short labels, else color + kind.
  String get shortAskName {
    final full = displayName.toLowerCase();
    if (full.isEmpty) return '';
    if (full.length <= ClosetPendingMatch.askNameBudget) return full;

    final kind = _askKind;
    final hue = _askHue;
    if (hue != null && kind != null && hue != kind) {
      final paired = '$hue $kind';
      if (paired.length <= ClosetPendingMatch.askNameBudget) return paired;
    }
    if (kind != null && kind.length <= ClosetPendingMatch.askNameBudget) {
      return kind;
    }
    return full.split(ClosetPendingMatch._wordSplit).take(2).join(' ');
  }

  String? get _askKind {
    final fromSub = ClosetItem.formatDisplayName(subcategory).toLowerCase();
    if (fromSub.isNotEmpty) {
      return fromSub.split(ClosetPendingMatch._wordSplit).last;
    }
    if (displayName.isEmpty) return null;
    return displayName.toLowerCase().split(ClosetPendingMatch._wordSplit).last;
  }

  String? get _askHue {
    final fromColor = ClosetItem.formatDisplayName(color).toLowerCase();
    if (fromColor.isNotEmpty) {
      return fromColor.split(ClosetPendingMatch._wordSplit).first;
    }
    if (displayName.isEmpty) return null;
    return displayName.toLowerCase().split(ClosetPendingMatch._wordSplit).first;
  }

  /// Isolate worker crop: keep the box, drop the foreground cutout.
  static String photoCropUrl(String isolateUrl) {
    final uri = Uri.tryParse(isolateUrl);
    if (uri == null || uri.query.isEmpty) return isolateUrl;
    return uri
        .replace(queryParameters: {...uri.queryParameters, 'cutout': '0'})
        .toString();
  }

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
      blurHash:
          _readNonEmpty(json['blur_hash']) ?? _readNonEmpty(json['blurHash']),
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

  /// Max characters for the name inside **Same {name}?** so the banner
  /// does not ellipsize mid-word.
  static const askNameBudget = 18;

  static final _wordSplit = RegExp(r'\s+');

  /// Banner title from a shortened candidate name. Never includes scores.
  String get askTitle {
    final name = candidate.shortAskName;
    if (name.isEmpty) return 'Same piece?';
    return 'Same $name?';
  }

  /// One-line sheet prompt. Uses the short name; never scores or a queue index.
  String get sheetCopy {
    final name = candidate.shortAskName;
    if (name.isEmpty) {
      return 'New outfit, familiar piece. Same piece, or a second one?';
    }
    final blob = '${candidate.subcategory} ${candidate.label}'.toLowerCase();
    if (blob.contains('tee') || blob.contains('t-shirt')) {
      return 'We spotted this on a new outfit. Is it the $name already in your closet?';
    }
    return 'New outfit, familiar $name. Same piece, or a second one?';
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

/// Settle banner after Same / New while more asks remain. Last resolve skips this.
enum ClosetAskSettleKind { savedSame, added }

class ClosetAskSettle {
  const ClosetAskSettle({required this.kind, required this.remaining});

  final ClosetAskSettleKind kind;
  final int remaining;

  String get title => switch (kind) {
    ClosetAskSettleKind.savedSame => 'Saved as the same piece',
    ClosetAskSettleKind.added => 'Added to closet',
  };

  String get remainingLine =>
      remaining == 1 ? '1 left to confirm' : '$remaining left to confirm';
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
