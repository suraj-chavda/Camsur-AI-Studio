import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

enum AppLogoShape { circle, squircle, raw }

/// Camsur CS monogram (transparent chrome mark).
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 96,
    this.showGlow = true,
    this.shape = AppLogoShape.raw,
    /// Slight scale if the mark needs to sit larger in the frame.
    this.zoom = 1.0,
  });

  final double size;
  final bool showGlow;
  final AppLogoShape shape;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      AppConstants.logoAsset,
      width: size * zoom,
      height: size * zoom,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      alignment: Alignment.center,
    );

    if (zoom != 1.0) {
      image = SizedBox(
        width: size,
        height: size,
        child: ClipRect(
          child: OverflowBox(
            maxWidth: size * zoom,
            maxHeight: size * zoom,
            alignment: Alignment.center,
            child: image,
          ),
        ),
      );
    } else {
      image = SizedBox(width: size, height: size, child: image);
    }

    image = switch (shape) {
      AppLogoShape.circle => ClipOval(child: image),
      AppLogoShape.squircle => ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: image,
        ),
      AppLogoShape.raw => image,
    };

    if (!showGlow) {
      return SizedBox(width: size, height: size, child: image);
    }

    return SizedBox(
      width: size * 1.2,
      height: size * 1.2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 1.12,
            height: size * 1.12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: image,
          ),
        ],
      ),
    );
  }
}
