import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/models/closet_pending_match.dart';

void main() {
  Map<String, dynamic> pendingJson({
    String id = 'm1',
    String outfitId = 'o1',
    Map<String, dynamic>? probe,
    Map<String, dynamic>? candidate,
    Object? score = 0.91,
    Object? cosine = 0.88,
    Object? colorDistance = 12.4,
    Object? createdAt = 1710000000000,
  }) {
    return {
      'id': id,
      'outfit_id': outfitId,
      'score': score,
      'cosine': cosine,
      'color_distance': colorDistance,
      'created_at': createdAt,
      'probe':
          probe ??
          {
            'label': 'white tee',
            'category': 'top',
            'subcategory': 't-shirt',
            'color': 'white',
            'pattern': 'solid',
            'image_key': 'users/u1/look.jpg',
            'bounding_box': {'x': 0.1, 'y': 0.2, 'width': 0.3, 'height': 0.4},
            'original_image_url': 'https://r2.example/look.jpg',
            'isolated_image_url': 'https://api.example/isolate?probe=1',
          },
      'candidate':
          candidate ??
          {
            'closet_item_id': 'c1',
            'label': 'white tee',
            'category': 'top',
            'subcategory': 't-shirt',
            'color': 'white',
            'bounding_box': {'x': 0.2, 'y': 0.2, 'width': 0.3, 'height': 0.4},
            'original_image_url': 'https://r2.example/closet.jpg',
            'isolated_image_url': 'https://api.example/isolate?cand=1',
          },
    };
  }

  group('ClosetPendingMatch.fromJson', () {
    test(
      'parses GET /closet/matches/pending row and keeps scores off the title',
      () {
        final match = ClosetPendingMatch.fromJson(pendingJson());

        expect(match.id, 'm1');
        expect(match.outfitId, 'o1');
        expect(match.score, 0.91);
        expect(match.cosine, 0.88);
        expect(match.colorDistance, 12.4);
        expect(match.createdAt, 1710000000000);
        expect(match.probe.label, 'white tee');
        expect(match.probe.pattern, 'solid');
        expect(match.probe.imageKey, 'users/u1/look.jpg');
        expect(match.probe.boundingBox?.x, 0.1);
        expect(
          match.probe.thumbUrl,
          'https://api.example/isolate?probe=1&cutout=0',
        );
        expect(match.candidate.closetItemId, 'c1');
        expect(
          match.candidate.thumbUrl,
          'https://api.example/isolate?cand=1&cutout=0',
        );
        expect(match.askTitle, 'Same white tee?');
        expect(match.askTitle, isNot(contains('0.91')));
        expect(
          ClosetPendingMatch.askSubtitle,
          'Looks like one already in your closet',
        );
      },
    );

    test('uses isolate photo crops, not cutouts, and falls back to original', () {
      final match = ClosetPendingMatch.fromJson(
        pendingJson(
          probe: {
            'label': 'navy jacket',
            'isolated_image_url':
                'https://api.example/assets/isolate?key=p.jpg&x=0.1&y=0.2&w=0.3&h=0.4',
          },
          candidate: {
            'closet_item_id': 'c2',
            'label': 'navy jacket',
            'isolated_image_url': '  ',
            'original_image_url': 'https://r2.example/cand.jpg',
          },
        ),
      );

      expect(match.probe.thumbUrl, contains('cutout=0'));
      expect(match.probe.thumbUrl, contains('key=p.jpg'));
      expect(match.candidate.thumbUrl, 'https://r2.example/cand.jpg');
      expect(match.askTitle, 'Same navy jacket?');
    });

    test('parses optional blur hashes on probe and candidate', () {
      final match = ClosetPendingMatch.fromJson(
        pendingJson(
          probe: {
            'label': 'white tee',
            'isolated_image_url': 'https://api.example/isolate?probe=1',
            'blur_hash': 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
          },
          candidate: {
            'closet_item_id': 'c1',
            'label': 'white tee',
            'isolated_image_url': 'https://api.example/isolate?cand=1',
            'blurHash': 'LKO2?U%2Tw=w]~RBVZRi};RPxuwH',
          },
        ),
      );

      expect(match.probe.blurHash, 'LEHV6nWB2yk8pyo0adR*.7kCMdnj');
      expect(match.candidate.blurHash, 'LKO2?U%2Tw=w]~RBVZRi};RPxuwH');
    });

    test('shortens long ask names to color + kind', () {
      final match = ClosetPendingMatch.fromJson(
        pendingJson(
          candidate: {
            'closet_item_id': 'c3',
            'label': 'olive green button-up jacket',
            'subcategory': 'button-up jacket',
            'color': 'olive green',
          },
        ),
      );

      expect(match.candidate.displayName, 'Olive Green Button-Up Jacket');
      expect(match.askTitle, 'Same olive jacket?');
      expect(
        match.askTitle.length,
        lessThan(match.candidate.displayName.length),
      );
    });

    test('uses tee and default sheet copy without scores', () {
      final tee = ClosetPendingMatch.fromJson(pendingJson());
      final jacket = ClosetPendingMatch.fromJson(
        pendingJson(
          candidate: {
            'closet_item_id': 'c4',
            'label': 'leather jacket',
            'subcategory': 'jacket',
            'color': 'black',
          },
        ),
      );

      expect(
        tee.sheetCopy,
        'We spotted this on a new outfit. Is it the white tee already in your closet?',
      );
      expect(
        jacket.sheetCopy,
        'New outfit, familiar leather jacket. Same piece, or a second one?',
      );
      expect(tee.sheetCopy, isNot(contains('0.91')));
    });

    test('defaults missing sides and drops empty ask names to Same piece?', () {
      final match = ClosetPendingMatch.fromJson({'id': 'm2'});

      expect(match.outfitId, isEmpty);
      expect(match.score, isNull);
      expect(match.probe.thumbUrl, isNull);
      expect(match.candidate.closetItemId, isNull);
      expect(match.askTitle, 'Same piece?');
      expect(
        match.sheetCopy,
        'New outfit, familiar piece. Same piece, or a second one?',
      );
    });

    test('coerces numeric strings and drops negative created_at', () {
      final match = ClosetPendingMatch.fromJson(
        pendingJson(score: '0.5', cosine: 1, createdAt: -3),
      );

      expect(match.score, 0.5);
      expect(match.cosine, 1);
      expect(match.createdAt, 0);
    });
  });

  group('ClosetPendingMatch.listFromResponse', () {
    test('reads matches newest-first as given and skips empty ids', () {
      final matches = ClosetPendingMatch.listFromResponse({
        'matches': [
          pendingJson(id: 'newer'),
          pendingJson(id: 'older', outfitId: 'o2'),
          {'id': '', 'outfit_id': 'ghost'},
          'skip',
        ],
      });

      expect(matches.map((m) => m.id), ['newer', 'older']);
    });

    test('returns empty when the payload is not a match list', () {
      expect(ClosetPendingMatch.listFromResponse(null), isEmpty);
      expect(ClosetPendingMatch.listFromResponse('busy'), isEmpty);
      expect(ClosetPendingMatch.listFromResponse({'items': []}), isEmpty);
    });
  });

  group('ClosetAskSettle', () {
    test('uses remaining copy without a queue index', () {
      expect(
        const ClosetAskSettle(
          kind: ClosetAskSettleKind.savedSame,
          remaining: 2,
        ).title,
        'Saved as the same piece',
      );
      expect(
        const ClosetAskSettle(
          kind: ClosetAskSettleKind.added,
          remaining: 1,
        ).remainingLine,
        '1 left to confirm',
      );
      expect(
        const ClosetAskSettle(
          kind: ClosetAskSettleKind.added,
          remaining: 2,
        ).remainingLine,
        '2 left to confirm',
      );
    });
  });

  group('ClosetMatchResolveResult.fromJson', () {
    test('parses same and new resolve payloads', () {
      final same = ClosetMatchResolveResult.fromJson({
        'decision': 'same',
        'match_id': 'm1',
        'closet_item_id': 'c1',
        'candidate_closet_item_id': 'c1',
        'identity_status': 'created',
        'identity_reason': 'same',
        'identity_score': 0.91,
      });
      final asNew = ClosetMatchResolveResult.fromJson({
        'decision': 'new',
        'match_id': 'm2',
        'closet_item_id': 'c9',
        'candidate_closet_item_id': 'c1',
        'identity_status': 'created',
        'identity_reason': 'no_neighbor',
        'identity_score': null,
      });

      expect(same.decision, ClosetMatchDecision.same);
      expect(same.decision?.apiValue, 'same');
      expect(same.identityStatus, ClosetMatchIdentityStatus.created);
      expect(same.closetItemId, 'c1');
      expect(asNew.decision, ClosetMatchDecision.asNew);
      expect(asNew.decision?.apiValue, 'new');
      expect(asNew.closetItemId, 'c9');
    });

    test('parses ask and unknown decision without inventing a third API', () {
      final ask = ClosetMatchResolveResult.fromJson({
        'decision': 'ask',
        'match_id': 'm3',
        'identity_status': 'ask',
        'identity_reason': 'ask',
      });
      final unknown = ClosetMatchResolveResult.fromJson({
        'decision': 'merge',
        'identity_status': 'running',
      });

      expect(ask.decision, ClosetMatchDecision.ask);
      expect(ask.identityStatus, ClosetMatchIdentityStatus.ask);
      expect(unknown.decision, isNull);
      expect(unknown.identityStatus, isNull);
    });
  });

  group('ClosetMatchResolveResult.fromResponse', () {
    test('reads a map payload', () {
      final result = ClosetMatchResolveResult.fromResponse({
        'decision': 'same',
        'match_id': 'm1',
        'identity_status': 'created',
      });

      expect(result.decision, ClosetMatchDecision.same);
      expect(result.matchId, 'm1');
    });

    test('returns empty when the payload is not a map', () {
      expect(ClosetMatchResolveResult.fromResponse(null).matchId, isEmpty);
      expect(ClosetMatchResolveResult.fromResponse([]).decision, isNull);
    });
  });
}
