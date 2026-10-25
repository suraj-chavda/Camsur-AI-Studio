import 'package:flutter/widgets.dart';

/// 4pt spacing scale — use these instead of magic numbers.
abstract final class AppSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  /// Rhythm between major screen blocks (hero → section → section).
  static const double section = 28;

  /// Gap between sibling cards / list rows outside a grouped panel.
  static const double listGap = 10;

  /// Space under sticky header before the first card.
  static const double pageTop = 16;

  /// Extra air above the bottom nav / camera FAB.
  static const double pageBottom = 28;

  /// Clears the raised center camera + nav bar on mobile shell tabs.
  static const double shellNavClearance = 130;

  static const EdgeInsets pageH = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets card = EdgeInsets.all(md);
  static const EdgeInsets cardTight = EdgeInsets.symmetric(
    horizontal: sm,
    vertical: sm,
  );
  static const EdgeInsets field = EdgeInsets.symmetric(
    horizontal: md,
    vertical: md,
  );
}

/// Corner radius rules — one language across surfaces.
abstract final class AppRadius {
  /// Chips, pills, status tags
  static const double xs = 10;

  /// Inputs, small controls
  static const double sm = 14;

  /// Buttons, nav indicators
  static const double md = 16;

  /// Cards, sheets, media frames
  static const double lg = 20;

  /// Credit chip / fully rounded pills
  static const double pill = 999;

  static BorderRadius get xsAll => BorderRadius.circular(xs);
  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get pillAll => BorderRadius.circular(pill);
}

/// Touch & control sizing.
abstract final class AppSize {
  static const double touch = 44;
  static const double buttonH = 44;
  static const double navH = 68;
  static const double iconSm = 18;
  static const double iconMd = 22;
  static const double iconLg = 28;
  static const double toolIconBox = 46;
}
