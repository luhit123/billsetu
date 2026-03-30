import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Responsive breakpoints for adaptive layouts.
///
/// - compact : phones (< 600)
/// - medium  : tablets / small browser (600–1024)
/// - expanded: desktop browser (> 1024)
enum WindowSize { compact, medium, expanded }

WindowSize windowSizeOf(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 1024) return WindowSize.expanded;
  if (w >= 600) return WindowSize.medium;
  return WindowSize.compact;
}

/// Whether the current layout is wide enough for a side navigation rail.
bool isWideScreen(BuildContext context) =>
    windowSizeOf(context) != WindowSize.compact;

/// Maximum content width for centered layouts on wide screens.
const double kWebContentMaxWidth = 1200;
const double kWebFormMaxWidth = 720;
const double kWebNarrowMaxWidth = 520;

/// Wraps [child] in a centered ConstrainedBox on wide screens.
/// On phone screens, returns [child] as-is.
Widget webContentWrap(BuildContext context, Widget child,
    {double maxWidth = kWebContentMaxWidth}) {
  if (windowSizeOf(context) == WindowSize.compact) return child;
  return Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Shows a modal bottom sheet on mobile, a centered dialog on web/desktop.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  Color? backgroundColor,
}) {
  if (kIsWeb || isWideScreen(context)) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
          child: builder(ctx),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: backgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: builder,
  );
}
