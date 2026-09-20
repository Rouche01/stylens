import 'package:flutter/material.dart';
import 'package:gostylens/core/managers/closet_manager.dart';
import 'package:gostylens/models/closet_pending_match.dart';
import 'package:gostylens/pages/closet/closet_ask_image.dart';
import 'package:gostylens/widgets/custom_outlined_button.dart';
import 'package:gostylens/widgets/primary_button.dart';
import 'package:provider/provider.dart';

/// Resolve sheet for one pending ask. Same / New live here, not on the banner.
class ClosetAskSheet extends StatefulWidget {
  const ClosetAskSheet({super.key, required this.manager, required this.ask});

  static const sheetKey = ValueKey('closet-ask-sheet');
  static const sameKey = ValueKey('closet-ask-same');
  static const newKey = ValueKey('closet-ask-new');

  final ClosetManager manager;
  final ClosetPendingMatch ask;

  static Future<void> show(
    BuildContext context, {
    required ClosetManager manager,
    required ClosetPendingMatch ask,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    final cs = Theme.of(context).colorScheme;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: cs.surfaceDim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return ChangeNotifierProvider.value(
          value: manager,
          child: ClosetAskSheet(manager: manager, ask: ask),
        );
      },
    );
  }

  @override
  State<ClosetAskSheet> createState() => _ClosetAskSheetState();
}

class _ClosetAskSheetState extends State<ClosetAskSheet> {
  ClosetMatchDecision? _pendingDecision;

  Future<void> _resolve(ClosetMatchDecision decision) async {
    if (_pendingDecision != null) return;
    setState(() => _pendingDecision = decision);
    final closed = await widget.manager.resolveCurrentAsk(decision);
    if (!mounted) return;
    if (closed) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _pendingDecision = null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ask = widget.ask;
    final error = context.watch<ClosetManager>().matchResolveError;
    final sameLoading = _pendingDecision == ClosetMatchDecision.same;
    final newLoading = _pendingDecision == ClosetMatchDecision.asNew;
    final busy = sameLoading || newLoading;

    return PopScope(
      canPop: !busy,
      child: SafeArea(
        key: ClosetAskSheet.sheetKey,
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const SizedBox(width: 40, height: 4),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Same piece?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'ClashDisplay',
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ask.sheetCopy,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Metropolis',
                  fontSize: 14,
                  height: 1.45,
                  color: cs.primary.withValues(alpha: 0.58),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SheetCrop(side: ask.probe, caption: 'New photo'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SheetCrop(
                      side: ask.candidate,
                      caption: 'In closet',
                    ),
                  ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Metropolis',
                    fontSize: 13,
                    height: 1.35,
                    color: cs.primary.withValues(alpha: 0.7),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              PrimaryButton(
                key: ClosetAskSheet.sameKey,
                label: "It's the same",
                isLoading: sameLoading,
                disabled: newLoading,
                onPressed: () => _resolve(ClosetMatchDecision.same),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              CustomOutlinedButton(
                key: ClosetAskSheet.newKey,
                label: "It's new",
                isLoading: newLoading,
                disabled: sameLoading,
                onPressed: () => _resolve(ClosetMatchDecision.asNew),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cs.primary,
                  minimumSize: const Size.fromHeight(44),
                  side: BorderSide(color: cs.primary.withValues(alpha: 0.22)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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

class _SheetCrop extends StatelessWidget {
  const _SheetCrop({required this.side, required this.caption});

  final ClosetMatchSide side;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ClosetAskNetworkImage(
            side: side,
            width: double.infinity,
            height: 168,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          caption,
          style: TextStyle(
            fontFamily: 'Metropolis',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cs.primary,
          ),
        ),
      ],
    );
  }
}
