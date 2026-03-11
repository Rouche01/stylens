import 'package:flutter/material.dart';
import 'package:gostylens/models/style_analysis_session.dart';
import 'package:gostylens/widgets/animated_typing_dots.dart';
import 'package:gostylens/widgets/image_with_fallback.dart';
import 'package:gostylens/widgets/session_actions_menu.dart';
import 'package:gostylens/utils/time_utils.dart';

class SessionCard extends StatefulWidget {
  final StyleAnalysisSession session;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isBusy;
  final bool showFavoriteIndicator;

  const SessionCard({
    super.key,
    required this.session,
    required this.onTap,
    required this.onDelete,
    this.isBusy = false,
    this.showFavoriteIndicator = true,
  });

  @override
  State<SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<SessionCard> {
  final _popupKey = GlobalKey<PopupMenuButtonState>();

  @override
  Widget build(BuildContext context) {
    final isFav = widget.session.isFavorite && widget.showFavoriteIndicator;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isFav
            ? BorderSide(color: primaryColor.withValues(alpha: 0.4), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: () {
          _popupKey.currentState?.showButtonMenu();
        },
        borderRadius: BorderRadius.circular(8),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPress: () {
            _popupKey.currentState?.showButtonMenu();
          },
          child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Outfit image
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ImageWithFallback(
                    remoteImage: widget.session.remoteImage,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(8),
                    fallbackWidget: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[200],
                      ),
                      child: Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
                  if (widget.isBusy)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: AnimatedTypingDots(
                            size: 6,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  if (isFav)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.favorite,
                          size: 12,
                          color: primaryColor,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 16),
              // Session details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.session.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      formatTimeAgo(widget.session.updatedAt),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Status and actions
              Column(
                children: [
                  SessionActionsMenu(
                    popupKey: _popupKey,
                    session: widget.session,
                    onDelete: widget.onDelete,
                    iconSize: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

}
