import 'package:flutter/material.dart';

/// Soft entrance — fade + slight rise.
/// Skips controllers past [maxAnimated] so long grids stay cheap.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 360),
    this.offset = 12,
    this.animate = true,
    this.maxAnimated = 8,
  });

  final Widget child;
  final int index;
  final Duration duration;
  final double offset;
  final bool animate;

  /// Items at or above this index render immediately (no ticker).
  final int maxAnimated;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;
  Animation<double>? _fade;
  Animation<Offset>? _slide;
  late final bool _shouldAnimate;

  @override
  void initState() {
    super.initState();
    _shouldAnimate =
        widget.animate && widget.index < widget.maxAnimated;
    if (!_shouldAnimate) return;

    _c = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _c!, curve: Curves.easeOutCubic);
    _slide = Tween(
      begin: Offset(0, widget.offset / 100),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c!, curve: Curves.easeOutCubic));

    final delay = Duration(milliseconds: 32 * widget.index);
    Future<void>.delayed(delay, () {
      if (mounted) _c?.forward();
    });
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldAnimate) return widget.child;
    return FadeTransition(
      opacity: _fade!,
      child: SlideTransition(position: _slide!, child: widget.child),
    );
  }
}
