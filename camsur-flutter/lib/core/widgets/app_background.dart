import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Studio stage for Camsur Pro: cool steel orbs, composition grid, soft stage light.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final ink = AppColors.text(brightness);
    final isDark = brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(decoration: AppColors.pageDecoration(brightness)),
        // Soft stage lights — behind the grid so guides sit on atmosphere.
        RepaintBoundary(child: _AmbientOrbs(isDark: isDark)),
        // Composition grid + vignette (static — cheap).
        RepaintBoundary(
          child: CustomPaint(
            painter: _StudioAtmospherePainter(isDark: isDark),
            child: const SizedBox.expand(),
          ),
        ),
        DefaultTextStyle(
          style: TextStyle(
            color: ink,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            decoration: TextDecoration.none,
          ),
          child: IconTheme(
            data: IconThemeData(color: ink, size: 24),
            child: child,
          ),
        ),
      ],
    );
  }
}

/// Slow multi-phase steel orbs — reads as studio key / fill / rim lights.
class _AmbientOrbs extends StatefulWidget {
  const _AmbientOrbs({required this.isDark});

  final bool isDark;

  @override
  State<_AmbientOrbs> createState() => _AmbientOrbsState();
}

class _AmbientOrbsState extends State<_AmbientOrbs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 36),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _OrbPainter(t: _ctrl.value, isDark: widget.isDark),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _OrbSpec {
  const _OrbSpec({
    required this.ax,
    required this.ay,
    required this.rx,
    required this.ry,
    required this.radiusFactor,
    required this.phase,
    required this.speed,
    required this.dark,
    required this.light,
  });

  final double ax;
  final double ay;
  final double rx;
  final double ry;
  final double radiusFactor;
  final double phase;
  final double speed;
  final Color dark;
  final Color light;
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({required this.t, required this.isDark});

  final double t;
  final bool isDark;

  static const _orbs = <_OrbSpec>[
    // Key light — upper left (steel)
    _OrbSpec(
      ax: 0.12,
      ay: 0.14,
      rx: 0.06,
      ry: 0.04,
      radiusFactor: 0.62,
      phase: 0.0,
      speed: 1.0,
      dark: Color(0xFF9AABBF),
      light: Color(0xFF7A8FA8),
    ),
    // Fill — mid right (cooler mist)
    _OrbSpec(
      ax: 0.88,
      ay: 0.36,
      rx: 0.05,
      ry: 0.055,
      radiusFactor: 0.52,
      phase: 0.28,
      speed: 0.85,
      dark: Color(0xFF6E8498),
      light: Color(0xFF9AABBF),
    ),
    // Rim / hair light — lower center-left
    _OrbSpec(
      ax: 0.28,
      ay: 0.82,
      rx: 0.045,
      ry: 0.035,
      radiusFactor: 0.4,
      phase: 0.55,
      speed: 1.15,
      dark: Color(0xFFA89888),
      light: Color(0xFFB8A99A),
    ),
    // Accent pearl — lower right
    _OrbSpec(
      ax: 0.78,
      ay: 0.78,
      rx: 0.04,
      ry: 0.05,
      radiusFactor: 0.3,
      phase: 0.72,
      speed: 1.3,
      dark: Color(0xFFB6C4D4),
      light: Color(0xFF8A9BB0),
    ),
    // Soft overhead wash — top center (keeps stage lit)
    _OrbSpec(
      ax: 0.5,
      ay: 0.02,
      rx: 0.03,
      ry: 0.02,
      radiusFactor: 0.7,
      phase: 0.12,
      speed: 0.55,
      dark: Color(0xFF7A8FA8),
      light: Color(0xFFC5D0DC),
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final baseA = isDark ? 0.11 : 0.16;

    for (final o in _orbs) {
      final angle = (t * o.speed + o.phase) * math.pi * 2;
      final cx = w * (o.ax + math.sin(angle) * o.rx);
      final cy = h * (o.ay + math.cos(angle * 0.9) * o.ry);
      final color = (isDark ? o.dark : o.light).withValues(alpha: baseA);
      _orb(
        canvas,
        center: Offset(cx, cy),
        radius: w * o.radiusFactor,
        color: color,
      );
    }
  }

  void _orb(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Color color,
  }) {
    final a = color.a;
    final paint = Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          color.withValues(alpha: a),
          color.withValues(alpha: a * 0.42),
          color.withValues(alpha: a * 0.12),
          color.withValues(alpha: 0),
        ],
        const [0.0, 0.28, 0.58, 1.0],
      );
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) =>
      old.t != t || old.isDark != isDark;
}

class _StudioAtmospherePainter extends CustomPainter {
  _StudioAtmospherePainter({required this.isDark});

  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    _paintStageFloor(canvas, size);
    _paintCompositionGrid(canvas, size);
    _paintFocusBloom(canvas, size);
    _paintVignette(canvas, size);
  }

  /// Soft horizon band — like a lit studio backdrop seam.
  void _paintStageFloor(Canvas canvas, Size size) {
    final y = size.height * 0.72;
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, y - size.height * 0.12),
        Offset(0, y + size.height * 0.18),
        [
          const Color(0x00000000),
          (isDark ? const Color(0xFF7A8FA8) : const Color(0xFF9AABBF))
              .withValues(alpha: isDark ? 0.05 : 0.07),
          const Color(0x00000000),
        ],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  /// Viewfinder-style composition grid — fades from content focus.
  void _paintCompositionGrid(Canvas canvas, Size size) {
    final steel = isDark
        ? const [
            Color(0xFF9AABBF),
            Color(0xFF7A8FA8),
            Color(0xFFB6C4D4),
            Color(0xFF6B7C90),
          ]
        : const [
            Color(0xFF7A8FA8),
            Color(0xFF5C6B7C),
            Color(0xFF9AABBF),
            Color(0xFF4A5564),
          ];

    final peakA = isDark ? 0.085 : 0.055;
    final cell = (size.width / 12).clamp(28.0, 40.0);
    final cols = (size.width / cell).ceil() + 1;
    final rows = (size.height / cell).ceil() + 1;
    final focus = Offset(size.width * 0.5, size.height * 0.38);
    final fadeR = size.longestSide * 0.68;

    double fadeAt(Offset p) {
      final d = (p - focus).distance / fadeR;
      final falloff = (1 - d).clamp(0.0, 1.0);
      // Smoothstep — denser near content, quiet toward edges.
      return falloff * falloff * (3 - 2 * falloff);
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDark ? 0.9 : 0.75
      ..isAntiAlias = true;

    final hairline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.45
      ..isAntiAlias = true;

    for (var col = 0; col <= cols; col++) {
      final x = col * cell;
      final fade = fadeAt(Offset(x, focus.dy));
      final a = peakA * (0.12 + 0.88 * fade);
      if (a < 0.008) continue;

      stroke.color = steel[col % steel.length].withValues(alpha: a);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), stroke);

      // Specular twin — every other line, like polished steel guides.
      if (col.isEven) {
        hairline.color = Colors.white.withValues(
          alpha: (isDark ? 0.04 : 0.03) * fade,
        );
        canvas.drawLine(
          Offset(x + 0.7, 0),
          Offset(x + 0.7, size.height),
          hairline,
        );
      }
    }

    for (var row = 0; row <= rows; row++) {
      final y = row * cell;
      final fade = fadeAt(Offset(focus.dx, y));
      final a = peakA * (0.12 + 0.88 * fade);
      if (a < 0.008) continue;

      stroke.color = steel[row % steel.length].withValues(alpha: a);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), stroke);

      if (row.isOdd) {
        hairline.color = const Color(0xFFD8E0EA).withValues(
          alpha: (isDark ? 0.035 : 0.025) * fade,
        );
        canvas.drawLine(
          Offset(0, y + 0.55),
          Offset(size.width, y + 0.55),
          hairline,
        );
      }
    }

    // Rule-of-thirds accents — quiet studio framing marks.
    final thirdX = [size.width / 3, size.width * 2 / 3];
    final thirdY = [size.height / 3, size.height * 2 / 3];
    final mark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = (isDark ? const Color(0xFFB6C4D4) : const Color(0xFF7A8FA8))
          .withValues(alpha: isDark ? 0.1 : 0.08);

    for (final x in thirdX) {
      for (final y in thirdY) {
        const arm = 7.0;
        canvas.drawLine(Offset(x - arm, y), Offset(x + arm, y), mark);
        canvas.drawLine(Offset(x, y - arm), Offset(x, y + arm), mark);
      }
    }
  }

  /// Soft steel bloom behind the main content column.
  void _paintFocusBloom(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.5, size.height * 0.32),
        size.shortestSide * 0.55,
        [
          (isDark ? const Color(0xFF9AABBF) : const Color(0xFF7A8FA8))
              .withValues(alpha: isDark ? 0.055 : 0.07),
          const Color(0x00000000),
        ],
        const [0.0, 1.0],
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _paintVignette(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.5, size.height * 0.4),
        size.longestSide * 0.82,
        [
          const Color(0x00000000),
          Colors.black.withValues(alpha: isDark ? 0.58 : 0.06),
        ],
        const [0.42, 1.0],
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _StudioAtmospherePainter old) =>
      old.isDark != isDark;
}
