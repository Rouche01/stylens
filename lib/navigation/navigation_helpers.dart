import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:gostylens/navigation/app_routes.dart';

/// Pops a full-screen detail route, or lands on its semantic parent tab when
/// there is no stack beneath (e.g. broken deep-link stack).
void popDetailOrGoHome(BuildContext context, {Object? result}) {
  if (context.canPop()) {
    context.pop(result);
    return;
  }
  final location = GoRouterState.of(context).matchedLocation;
  context.go(semanticShellForLocation(location));
}
