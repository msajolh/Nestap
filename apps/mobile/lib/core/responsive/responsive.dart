import 'package:flutter/widgets.dart';

/// Material 3 window size classes.
enum WindowSize { compact, medium, expanded }

abstract final class Breakpoints {
  /// Phones in portrait are below this.
  static const medium = 600.0;

  /// Large tablets, foldables open, desktop.
  static const expanded = 1024.0;

  /// Content never stretches wider than this on big screens.
  static const maxContentWidth = 1200.0;
}

extension ResponsiveContext on BuildContext {
  WindowSize get windowSize {
    final width = MediaQuery.sizeOf(this).width;
    if (width >= Breakpoints.expanded) return WindowSize.expanded;
    if (width >= Breakpoints.medium) return WindowSize.medium;
    return WindowSize.compact;
  }

  bool get isCompact => windowSize == WindowSize.compact;

  /// Picks a value per size class; larger classes fall back to smaller ones.
  T responsive<T>({required T compact, T? medium, T? expanded}) =>
      switch (windowSize) {
        WindowSize.compact => compact,
        WindowSize.medium => medium ?? compact,
        WindowSize.expanded => expanded ?? medium ?? compact,
      };

  double get pagePadding => responsive(compact: 16, medium: 24, expanded: 32);
}

/// Centres content and caps its width on tablets and desktop.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    required this.child,
    this.maxWidth = Breakpoints.maxContentWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}
