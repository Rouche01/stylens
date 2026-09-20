import 'package:flutter/material.dart';
import 'package:gostylens/core/config/env_config.dart';
import 'package:gostylens/models/closet_pending_match.dart';

/// Compact pending-match chrome under the closet toolbar.
///
/// Ask is tappable (sheet comes next). Settle is not. Never a dock chip.
class ClosetAskBanner extends StatelessWidget {
  const ClosetAskBanner({super.key, this.ask, this.settle, this.onOpenAsk});

  static const askKey = ValueKey('closet-ask-banner');
  static const settleKey = ValueKey('closet-settle-banner');

  final ClosetPendingMatch? ask;
  final ClosetAskSettle? settle;
  final VoidCallback? onOpenAsk;

  @override
  Widget build(BuildContext context) {
    final settle = this.settle;
    if (settle != null) {
      return Padding(
        key: settleKey,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: _SettleCard(settle: settle),
      );
    }

    final ask = this.ask;
    if (ask == null) return const SizedBox.shrink();

    return Padding(
      key: askKey,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: _AskCard(ask: ask, onOpenAsk: onOpenAsk),
    );
  }
}

class _AskCard extends StatelessWidget {
  const _AskCard({required this.ask, this.onOpenAsk});

  final ClosetPendingMatch ask;
  final VoidCallback? onOpenAsk;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: '${ask.askTitle}. ${ClosetPendingMatch.askSubtitle}',
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onOpenAsk,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: Color.lerp(Colors.white, cs.secondary, 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
              child: Row(
                children: [
                  _AskThumbs(probe: ask.probe, candidate: ask.candidate),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BannerCopy(
                      title: ask.askTitle,
                      subtitle: ClosetPendingMatch.askSubtitle,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: cs.secondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettleCard extends StatelessWidget {
  const _SettleCard({required this.settle});

  final ClosetAskSettle settle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      label: '${settle.title}. ${settle.remainingLine}',
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color.lerp(Colors.white, cs.secondary, 0.55),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.check, size: 18, color: cs.secondary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BannerCopy(
                    title: settle.title,
                    subtitle: settle.remainingLine,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerCopy extends StatelessWidget {
  const _BannerCopy({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Metropolis',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: cs.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Metropolis',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: cs.primary.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _AskThumbs extends StatelessWidget {
  const _AskThumbs({required this.probe, required this.candidate});

  final ClosetMatchSide probe;
  final ClosetMatchSide candidate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 40,
      child: Stack(
        children: [
          Positioned(left: 0, child: _AskThumb(side: probe)),
          Positioned(left: 20, child: _AskThumb(side: candidate)),
        ],
      ),
    );
  }
}

class _AskThumb extends StatelessWidget {
  const _AskThumb({required this.side});

  final ClosetMatchSide side;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = side.thumbUrl;
    final fill = ColoredBox(color: cs.primary.withValues(alpha: 0.12));

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 32,
          height: 40,
          child: url == null
              ? fill
              : Image.network(
                  EnvConfig.resolvePlatformUrl(url),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => fill,
                ),
        ),
      ),
    );
  }
}
