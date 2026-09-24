import 'package:flutter/material.dart';
import 'package:gostylens/core/config/env_config.dart';
import 'package:gostylens/pages/closet/closet_item_hero_layout.dart';
import 'package:gostylens/widgets/custom_outlined_button.dart';

/// Catalog / shoppable still for “Looks like yours?”. Not closet identity.
class ClosetItemRec {
  const ClosetItemRec({
    required this.id,
    required this.title,
    required this.imageUrl,
  });

  final String id;
  final String title;
  final String imageUrl;
}

class ClosetItemRecs extends StatefulWidget {
  const ClosetItemRecs({
    super.key,
    required this.displayName,
    this.recs = const [],
  });

  final String displayName;
  final List<ClosetItemRec> recs;

  static const heading = 'Looks like yours?';

  static String bodyFor(String displayName) {
    final name = displayName.trim().isEmpty ? 'piece' : displayName.trim();
    return 'Tap a photo if it’s this $name. We’ll use it for a cleaner '
        'presentation, or to try it on your twin.';
  }

  @override
  State<ClosetItemRecs> createState() => _ClosetItemRecsState();
}

class _ClosetItemRecsState extends State<ClosetItemRecs> {
  String? _selectedId;

  @override
  void didUpdateWidget(ClosetItemRecs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedId == null) return;
    if (widget.recs.any((rec) => rec.id == _selectedId)) return;
    _selectedId = null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final recs = widget.recs;

    return Padding(
      key: const ValueKey('closet-item-recs'),
      padding: const EdgeInsets.fromLTRB(
        ClosetItemHeroLayout.horizontalInset,
        18,
        ClosetItemHeroLayout.horizontalInset,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ClosetItemRecs.heading,
            style: TextStyle(
              fontFamily: 'ClashDisplay',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ClosetItemRecs.bodyFor(widget.displayName),
            style: TextStyle(
              fontFamily: 'Metropolis',
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w400,
              color: cs.primary.withValues(alpha: 0.58),
            ),
          ),
          if (recs.isNotEmpty) ...[
            const SizedBox(height: 16),
            _grid(recs),
            const SizedBox(height: 12),
            CustomOutlinedButton(
              key: const ValueKey('closet-item-recs-none'),
              label: 'None of these',
              onPressed: () => setState(() => _selectedId = null),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.primary,
                side: BorderSide(color: cs.primary.withValues(alpha: 0.22)),
                minimumSize: const Size.fromHeight(44),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Metropolis',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _grid(List<ClosetItemRec> recs) {
    return GridView.builder(
      key: const ValueKey('closet-item-recs-grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recs.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.62,
      ),
      itemBuilder: (context, index) {
        final rec = recs[index];
        final selected = rec.id == _selectedId;
        return _RecTile(
          rec: rec,
          selected: selected,
          onTap: () => setState(() => _selectedId = rec.id),
        );
      },
    );
  }
}

class _RecTile extends StatelessWidget {
  const _RecTile({
    required this.rec,
    required this.selected,
    required this.onTap,
  });

  final ClosetItemRec rec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      key: ValueKey('closet-item-rec-${rec.id}'),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: selected
                ? Border.all(color: cs.primary, width: 2)
                : Border.all(color: Colors.transparent, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                  child: Image.network(
                    EnvConfig.resolvePlatformUrl(rec.imageUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        ColoredBox(color: cs.primary.withValues(alpha: 0.08)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: Text(
                  rec.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Metropolis',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
