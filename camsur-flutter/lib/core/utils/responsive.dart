import 'package:flutter/widgets.dart';

import '../constants/app_constants.dart';
import '../theme/app_tokens.dart';

enum ScreenType { mobile, tablet, desktop }

/// Peak responsiveness helpers — use everywhere instead of hardcoded sizes.
class Responsive {
  Responsive._(this.width);

  final double width;

  factory Responsive.of(BuildContext context) =>
      Responsive._(MediaQuery.sizeOf(context).width);

  ScreenType get type {
    if (width >= AppConstants.tablet) return ScreenType.desktop;
    if (width >= AppConstants.mobile) return ScreenType.tablet;
    return ScreenType.mobile;
  }

  bool get isMobile => type == ScreenType.mobile;
  bool get isTablet => type == ScreenType.tablet;
  bool get isDesktop => type == ScreenType.desktop;
  bool get isWide => !isMobile;

  /// Horizontal page padding that scales with width.
  double get pagePadding {
    if (isDesktop) return AppSpace.xxxl;
    if (isTablet) return AppSpace.xl + AppSpace.xxs; // 28
    return AppSpace.lg;
  }

  /// Breathing room under the sticky studio header.
  double get contentTop => AppSpace.pageTop;

  /// Scroll/list bottom inset so last cards clear the shell nav + camera FAB.
  double get contentBottom =>
      isMobile ? AppSpace.shellNavClearance + AppSpace.pageBottom : AppSpace.xxxl;

  /// Standard shell page insets (horizontal + top + bottom).
  EdgeInsets get shellPadding => EdgeInsets.fromLTRB(
        pagePadding,
        contentTop,
        pagePadding,
        contentBottom,
      );

  /// Horizontal + top only — use when the child Column/list owns bottom inset.
  EdgeInsets get shellPaddingTop => EdgeInsets.fromLTRB(
        pagePadding,
        contentTop,
        pagePadding,
        0,
      );

  /// Content max width centered on large screens.
  double get contentWidth {
    if (width > AppConstants.maxContentWidth) {
      return AppConstants.maxContentWidth;
    }
    return width;
  }

  /// Adaptive grid columns for tool / result grids.
  int gridColumns({int mobile = 2, int tablet = 3, int desktop = 4}) {
    return switch (type) {
      ScreenType.desktop => desktop,
      ScreenType.tablet => tablet,
      ScreenType.mobile => mobile,
    };
  }

  /// Scale a base size slightly on larger screens.
  double scale(double base, {double tablet = 1.05, double desktop = 1.1}) {
    return switch (type) {
      ScreenType.desktop => base * desktop,
      ScreenType.tablet => base * tablet,
      ScreenType.mobile => base,
    };
  }

  T value<T>({required T mobile, T? tablet, T? desktop}) {
    return switch (type) {
      ScreenType.desktop => desktop ?? tablet ?? mobile,
      ScreenType.tablet => tablet ?? mobile,
      ScreenType.mobile => mobile,
    };
  }
}

/// Wraps child with centered max-width constraint.
class AdaptiveContainer extends StatelessWidget {
  const AdaptiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.shell = false,
    this.maxWidth = AppConstants.maxContentWidth,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Adds shared top page breathing under the sticky header.
  /// Bottom clearance still belongs on scrollables via [Responsive.contentBottom].
  final bool shell;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final resolved = padding ??
        (shell
            ? r.shellPaddingTop
            : EdgeInsets.symmetric(horizontal: r.pagePadding));
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: resolved,
          child: child,
        ),
      ),
    );
  }
}
