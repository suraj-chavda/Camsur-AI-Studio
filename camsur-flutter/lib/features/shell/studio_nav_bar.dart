import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/studio_chrome.dart';
import '../../core/widgets/noise_overlay.dart';

/// Shell nav — same rim language as [StudioTopBar] / [AppCard], with the
/// top edge following the camera FAB notch via [Scaffold] geometry.
///
/// Geometry is only read during paint/clip (same contract as [BottomAppBar]).
class StudioNavBar extends StatefulWidget {
  const StudioNavBar({
    super.key,
    required this.index,
    required this.onSelect,
  });

  final int index;
  final ValueChanged<int> onSelect;

  static const double fabSize = 60;
  static const double notchMargin = 7;

  /// Spacer under the camera so labels don't collide with the FAB.
  static double get fabGap => fabSize + notchMargin * 2;

  @override
  State<StudioNavBar> createState() => _StudioNavBarState();
}

class _StudioNavBarState extends State<StudioNavBar> {
  final GlobalKey _materialKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final isDark = b == Brightness.dark;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final rim = StudioChrome.rimWidth;
    final height = AppSize.navH + bottom;

    // Do NOT read geometry.value here — only pass the listenable.
    // Access happens in clip/paint (see BottomAppBar).
    final geometry = Scaffold.geometryOf(context);

    final clipper = _StudioNavClipper(
      geometry: geometry,
      materialKey: _materialKey,
      notchMargin: StudioNavBar.notchMargin,
      barRadius: StudioChrome.barRadius,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: StudioChrome.overlayFor(b),
      child: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: PhysicalShape(
          elevation: isDark ? 16 : 10,
          shadowColor: Colors.black.withValues(alpha: isDark ? 0.55 : 0.2),
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          clipper: clipper,
          child: CustomPaint(
            painter: _StudioNavChromePainter(
              geometry: geometry,
              materialKey: _materialKey,
              notchMargin: StudioNavBar.notchMargin,
              barRadius: StudioChrome.barRadius,
              rimGradient: StudioChrome.barRim(b),
              faceTop: StudioChrome.panelFaceTop(b),
              faceBottom: StudioChrome.panelFaceBottom(b),
              rimWidth: rim,
            ),
            child: SizedBox(
              key: _materialKey,
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const Positioned.fill(
                    child: NoiseOverlay(
                      opacity: NoiseOverlay.defaultOpacity,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: bottom),
                    child: SizedBox(
                      height: AppSize.navH,
                      child: Row(
                        children: [
                          _NavItem(
                            icon: AppIcons.home,
                            activeIcon: AppIcons.homeFill,
                            label: 'Home',
                            selected: widget.index == 0,
                            onTap: () => widget.onSelect(0),
                          ),
                          _NavItem(
                            icon: AppIcons.history,
                            activeIcon: AppIcons.historyFill,
                            label: 'History',
                            selected: widget.index == 1,
                            onTap: () => widget.onSelect(1),
                          ),
                          SizedBox(
                            width: StudioNavBar.fabGap,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  'Capture',
                                  style: TextStyle(
                                    fontFamily: 'Figtree',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted(b),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _NavItem(
                            icon: AppIcons.wallet,
                            activeIcon: AppIcons.walletFill,
                            label: 'Wallet',
                            selected: widget.index == 2,
                            onTap: () => widget.onSelect(2),
                          ),
                          _NavItem(
                            icon: AppIcons.profile,
                            activeIcon: AppIcons.profileFill,
                            label: 'Profile',
                            selected: widget.index == 3,
                            onTap: () => widget.onSelect(3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Path _navOutlinePath({
  required Size size,
  required ValueListenable<ScaffoldGeometry> geometry,
  required GlobalKey materialKey,
  required double notchMargin,
  required double barRadius,
}) {
  final host = Offset.zero & size;

  final rounded = Path()
    ..addRRect(
      RRect.fromRectAndCorners(
        host,
        topLeft: Radius.circular(barRadius),
        topRight: Radius.circular(barRadius),
      ),
    );

  final fab = geometry.value.floatingActionButtonArea;
  if (fab == null) return rounded;

  final barTop = geometry.value.bottomNavigationBarTop ??
      (materialKey.currentContext?.findRenderObject() as RenderBox?)
          ?.localToGlobal(Offset.zero)
          .dy ??
      0.0;

  final guest = fab.translate(0, -barTop).inflate(notchMargin);
  final notched = const CircularNotchedRectangle().getOuterPath(host, guest);
  return Path.combine(PathOperation.intersect, notched, rounded);
}

/// Notched path — geometry read only in [getClip] (paint phase).
class _StudioNavClipper extends CustomClipper<Path> {
  _StudioNavClipper({
    required this.geometry,
    required this.materialKey,
    required this.notchMargin,
    required this.barRadius,
  }) : super(reclip: geometry);

  final ValueListenable<ScaffoldGeometry> geometry;
  final GlobalKey materialKey;
  final double notchMargin;
  final double barRadius;

  @override
  Path getClip(Size size) {
    return _navOutlinePath(
      size: size,
      geometry: geometry,
      materialKey: materialKey,
      notchMargin: notchMargin,
      barRadius: barRadius,
    );
  }

  @override
  bool shouldReclip(covariant _StudioNavClipper oldClipper) {
    return geometry != oldClipper.geometry ||
        materialKey != oldClipper.materialKey ||
        notchMargin != oldClipper.notchMargin ||
        barRadius != oldClipper.barRadius;
  }
}

/// Face fill + card-style rim on the exact notched outline.
class _StudioNavChromePainter extends CustomPainter {
  _StudioNavChromePainter({
    required this.geometry,
    required this.materialKey,
    required this.notchMargin,
    required this.barRadius,
    required this.rimGradient,
    required this.faceTop,
    required this.faceBottom,
    required this.rimWidth,
  }) : super(repaint: geometry);

  final ValueListenable<ScaffoldGeometry> geometry;
  final GlobalKey materialKey;
  final double notchMargin;
  final double barRadius;
  final LinearGradient rimGradient;
  final Color faceTop;
  final Color faceBottom;
  final double rimWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = _navOutlinePath(
      size: size,
      geometry: geometry,
      materialKey: materialKey,
      notchMargin: notchMargin,
      barRadius: barRadius,
    );

    canvas.save();
    canvas.clipPath(path);

    final facePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [faceTop, faceBottom],
      ).createShader(rect);
    canvas.drawRect(rect, facePaint);

    // Rim on top (incl. notch) + sides only — no bottom edge (flush to screen).
    final rimPaint = Paint()
      ..shader = rimGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = rimWidth * 2
      ..isAntiAlias = true;
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(0, 0, size.width, size.height - rimWidth),
    );
    canvas.drawPath(path, rimPaint);
    canvas.restore();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StudioNavChromePainter oldDelegate) {
    return geometry != oldDelegate.geometry ||
        materialKey != oldDelegate.materialKey ||
        notchMargin != oldDelegate.notchMargin ||
        barRadius != oldDelegate.barRadius ||
        rimWidth != oldDelegate.rimWidth ||
        faceTop != oldDelegate.faceTop ||
        faceBottom != oldDelegate.faceBottom;
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final isDark = b == Brightness.dark;
    final color = selected ? AppColors.text(b) : AppColors.textMuted(b);

    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: AppRadius.smAll,
                color: selected
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.black.withValues(alpha: 0.05))
                    : null,
              ),
              child: Icon(
                selected ? activeIcon : icon,
                size: 22,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Figtree',
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
