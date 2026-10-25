import 'package:flutter/material.dart';

/// Film grain only — no color wash / tint overlays.
class NoiseOverlay extends StatelessWidget {
  const NoiseOverlay({
    super.key,
    this.opacity = defaultOpacity,
    this.borderRadius,
  });

  /// Shared surface grain for cards, buttons, chrome.
  static const double defaultOpacity = 0.11;

  final double opacity;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    Widget grain = Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: const DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/noise.png'),
            repeat: ImageRepeat.repeat,
            fit: BoxFit.none,
            scale: 1.55,
            opacity: 0.55,
            filterQuality: FilterQuality.low,
          ),
        ),
        child: SizedBox.expand(),
      ),
    );

    if (borderRadius != null) {
      grain = ClipRRect(borderRadius: borderRadius!, child: grain);
    }

    return IgnorePointer(child: grain);
  }
}
