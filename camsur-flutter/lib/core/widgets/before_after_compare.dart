import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../extensions/context_x.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_network_image.dart';
import '../../core/theme/app_icons.dart';

/// Interactive left/right compare: drag the handle to reveal
/// original (left) vs generated (right).
class BeforeAfterCompare extends StatefulWidget {
  const BeforeAfterCompare({
    super.key,
    required this.afterUrl,
    this.beforeUrl,
    this.beforeFile,
    this.aspectRatio = 1,
    this.initialPosition = 0.5,
    this.afterError,
    this.displayWidth = 1200,
  });

  final String afterUrl;
  final String? beforeUrl;
  final File? beforeFile;
  final double aspectRatio;
  final double initialPosition;
  final Widget? afterError;
  final int displayWidth;

  bool get hasBefore {
    final url = beforeUrl;
    if (url != null && url.isNotEmpty && url.startsWith('http')) return true;
    final file = beforeFile;
    return file != null && file.existsSync();
  }

  @override
  State<BeforeAfterCompare> createState() => _BeforeAfterCompareState();
}

class _BeforeAfterCompareState extends State<BeforeAfterCompare> {
  late double _pos;

  @override
  void initState() {
    super.initState();
    _pos = widget.initialPosition.clamp(0.08, 0.92);
  }

  void _setFromDx(double dx, double width) {
    if (width <= 0) return;
    setState(() => _pos = (dx / width).clamp(0.08, 0.92));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.hasBefore) {
      return AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: AppNetworkImage(
          url: widget.afterUrl,
          fit: BoxFit.cover,
          optimize: false,
          displayWidth: widget.displayWidth,
          memCacheWidth: widget.displayWidth,
          error: widget.afterError,
        ),
      );
    }

    final b = Theme.of(context).brightness;
    final accent = AppColors.accentOf(b);

    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final handleX = _pos * w;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => HapticFeedback.selectionClick(),
            onHorizontalDragUpdate: (d) => _setFromDx(d.localPosition.dx, w),
            onTapDown: (d) => _setFromDx(d.localPosition.dx, w),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Generated (full)
                AppNetworkImage(
                  url: widget.afterUrl,
                  fit: BoxFit.cover,
                  optimize: false,
                  displayWidth: widget.displayWidth,
                  memCacheWidth: widget.displayWidth,
                  error: widget.afterError,
                ),

                // Original revealed on the left
                ClipRect(
                  clipper: _LeftRevealClipper(_pos),
                  child: _BeforeLayer(
                    url: widget.beforeUrl,
                    file: widget.beforeFile,
                    displayWidth: widget.displayWidth,
                  ),
                ),

                // Edge fade on the reveal line
                Positioned(
                  left: handleX - 0.5,
                  top: 0,
                  bottom: 0,
                  width: 1,
                  child: ColoredBox(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),

                // Drag handle
                Positioned(
                  left: handleX - 22,
                  top: 0,
                  bottom: 0,
                  width: 44,
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.95),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.55),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        AppIcons.swap,
                        size: 20,
                        color: AppColors.text(Brightness.light),
                      ),
                    ),
                  ),
                ),

                // Labels
                Positioned(
                  left: 10,
                  top: 10,
                  child: _CompareLabel(
                    text: 'Original',
                    dim: _pos < 0.18,
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: _CompareLabel(
                    text: 'Generated',
                    dim: _pos > 0.82,
                  ),
                ),

                // Hint chip (subtle)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Center(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        opacity: (_pos > 0.42 && _pos < 0.58) ? 1 : 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: AppRadius.smAll,
                          ),
                          child: Text(
                            'Slide to compare',
                            style: context.texts.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BeforeLayer extends StatelessWidget {
  const _BeforeLayer({
    required this.url,
    required this.file,
    required this.displayWidth,
  });

  final String? url;
  final File? file;
  final int displayWidth;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty && url!.startsWith('http')) {
      return AppNetworkImage(
        url: url,
        fit: BoxFit.cover,
        optimize: false,
        displayWidth: displayWidth,
        memCacheWidth: displayWidth,
      );
    }
    if (file != null && file!.existsSync()) {
      return Image.file(file!, fit: BoxFit.cover);
    }
    return const SizedBox.shrink();
  }
}

class _LeftRevealClipper extends CustomClipper<Rect> {
  _LeftRevealClipper(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(covariant _LeftRevealClipper old) =>
      old.fraction != fraction;
}

class _CompareLabel extends StatelessWidget {
  const _CompareLabel({required this.text, required this.dim});

  final String text;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: dim ? 0.25 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: AppRadius.smAll,
        ),
        child: Text(
          text,
          style: context.texts.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
