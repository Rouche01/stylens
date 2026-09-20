import 'package:flutter/material.dart';
import 'package:gostylens/pages/closet/closet_browse_layout.dart';

class ClosetBrowseHeader extends StatelessWidget {
  const ClosetBrowseHeader({
    super.key,
    required this.minExtent,
    required this.maxExtent,
    required this.topInset,
    required this.backgroundColor,
    required this.titleColor,
    required this.toolbar,
    this.onTitleLongPress,
  });

  final double minExtent;
  final double maxExtent;
  final double topInset;
  final Color backgroundColor;
  final Color titleColor;
  final Widget toolbar;
  final VoidCallback? onTitleLongPress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final range = maxExtent - minExtent;
        final rawT = range == 0
            ? 0.0
            : ((maxExtent - height) / range).clamp(0.0, 1.0);
        final titleT = Curves.easeInOutCubic.transform(rawT);
        final titleScale = Tween<double>(
          begin: 1,
          end: ClosetHeaderMetrics.titleScale,
        ).transform(titleT);
        final titleWeight = rawT >= 0.98 ? FontWeight.w500 : FontWeight.w600;
        final titleSlot = Tween<double>(
          begin: ClosetHeaderMetrics.expandedTitleSlot,
          end: ClosetHeaderMetrics.collapsedTitleSlot,
        ).transform(rawT);
        final topPad = Tween<double>(begin: 8, end: 6).transform(rawT);
        final gap = Tween<double>(begin: 16, end: 8).transform(rawT);
        final bottomPad = Tween<double>(begin: 16, end: 8).transform(rawT);

        return SizedBox(
          height: height,
          width: double.infinity,
          child: ColoredBox(
            color: backgroundColor,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                topInset + topPad,
                16,
                bottomPad,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: titleSlot,
                    width: double.infinity,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.centerLeft,
                        maxHeight: ClosetHeaderMetrics.expandedTitleSlot,
                        child: Transform.scale(
                          alignment: Alignment.centerLeft,
                          scale: titleScale,
                          child: GestureDetector(
                            onLongPress: onTitleLongPress,
                            child: Text(
                              'Your Closet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'ClashDisplay',
                                fontSize: ClosetHeaderMetrics.expandedTitleSize,
                                fontWeight: titleWeight,
                                height: 1.1,
                                letterSpacing: -0.3,
                                color: titleColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: gap),
                  toolbar,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ClosetBrowseToolbar extends StatelessWidget {
  const ClosetBrowseToolbar({
    super.key,
    required this.searchController,
    required this.searchFocus,
    required this.viewMode,
    required this.onDismissKeyboard,
    required this.onViewModeChanged,
  });

  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ClosetViewMode viewMode;
  final VoidCallback onDismissKeyboard;
  final ValueChanged<ClosetViewMode> onViewModeChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const radius = ClosetBrowseLayout.toolbarControlRadius;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 42,
            child: TextField(
              controller: searchController,
              focusNode: searchFocus,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.search,
              scrollPadding: EdgeInsets.zero,
              onTapOutside: (_) => onDismissKeyboard(),
              onSubmitted: (_) => onDismissKeyboard(),
              style: const TextStyle(
                fontFamily: 'Metropolis',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search pieces',
                hintStyle: TextStyle(
                  fontFamily: 'Metropolis',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.primary.withValues(alpha: 0.4),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: cs.primary.withValues(alpha: 0.45),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 42,
                ),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        onPressed: searchController.clear,
                        icon: Icon(
                          Icons.cancel,
                          size: 18,
                          color: cs.primary.withValues(alpha: 0.45),
                        ),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 42,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(radius),
                  borderSide: BorderSide(
                    color: cs.primary.withValues(alpha: 0.18),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(radius),
                  borderSide: BorderSide(
                    color: cs.primary.withValues(alpha: 0.18),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(radius),
                  borderSide: BorderSide(
                    color: cs.primary.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<ClosetViewMode>(
          initialValue: viewMode,
          onSelected: onViewModeChanged,
          tooltip: 'View',
          offset: const Offset(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          itemBuilder: (context) => const [
            PopupMenuItem(value: ClosetViewMode.all, child: Text('All')),
            PopupMenuItem(
              value: ClosetViewMode.categories,
              child: Text('Categories'),
            ),
          ],
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  viewMode == ClosetViewMode.all ? 'All' : 'Categories',
                  style: TextStyle(
                    fontFamily: 'Metropolis',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.secondary,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.expand_more, size: 18, color: cs.secondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ClosetCategorySectionHeader extends StatelessWidget {
  const ClosetCategorySectionHeader({
    super.key,
    required this.label,
    required this.count,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final int count;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: backgroundColor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'ClashDisplay',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: foregroundColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  count == 1 ? '1 piece' : '$count pieces',
                  style: TextStyle(
                    fontFamily: 'Metropolis',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: foregroundColor.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ),
        IgnorePointer(child: _HeaderEdgeFade(color: backgroundColor)),
      ],
    );
  }
}

class _HeaderEdgeFade extends StatelessWidget {
  const _HeaderEdgeFade({required this.color});

  final Color color;

  static const _height = 16.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color,
              color,
              color.withValues(alpha: 0.7),
              color.withValues(alpha: 0.32),
              color.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.18, 0.48, 0.76, 1.0],
          ),
        ),
      ),
    );
  }
}
