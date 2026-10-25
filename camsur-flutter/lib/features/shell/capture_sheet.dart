import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/theme/studio_chrome.dart';
import '../../core/utils/photo_pick.dart';
import '../../core/widgets/noise_overlay.dart';
import 'studio_nav_bar.dart';

/// Pick up to 5 photos and open the studio preview flow.
Future<void> pickAndOpenPreview(ImageSource source) async {
  HapticFeedback.lightImpact();
  final files = await PhotoPick.pick(source: source, alreadyHave: 0);
  if (files.isEmpty) return;

  final args = {
    'photoPath': files.first.path,
    'photoPaths': files.map((f) => f.path).toList(),
    'source': source == ImageSource.camera ? 'camera' : 'upload',
  };
  if (Get.currentRoute == AppRoutes.photoPreview) {
    Get.offNamed(AppRoutes.photoPreview, arguments: args);
  } else {
    Get.toNamed(AppRoutes.photoPreview, arguments: args);
  }
}

/// Soft studio chooser. Pass [anchorKey] (camera FAB) to seat the dock above it.
Future<void> showCaptureToolbar({GlobalKey? anchorKey}) async {
  final ctx = anchorKey?.currentContext ?? Get.overlayContext ?? Get.context;
  if (ctx == null || !ctx.mounted) return;

  final overlay = Overlay.maybeOf(ctx, rootOverlay: true) ??
      Navigator.of(ctx, rootNavigator: true).overlay;
  if (overlay == null) return;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _CaptureToolbarOverlay(
      anchorKey: anchorKey,
      onDismiss: () {
        entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

/// Alias for older call sites.
Future<void> showCaptureSheet({GlobalKey? anchorKey}) =>
    showCaptureToolbar(anchorKey: anchorKey);

/// Shared args for photo → tool flow.
class PhotoSession {
  const PhotoSession({
    required this.files,
    required this.source,
  });

  final List<File> files;
  final String source;

  File get file => files.first;

  static PhotoSession? fromArguments(dynamic args) {
    if (args is! Map) return null;
    final paths = <String>[];
    final multi = args['photoPaths'];
    if (multi is List) {
      for (final p in multi) {
        final s = p?.toString();
        if (s != null && s.isNotEmpty) paths.add(s);
      }
    }
    final single = args['photoPath']?.toString();
    if (single != null && single.isNotEmpty && !paths.contains(single)) {
      paths.insert(0, single);
    }
    if (paths.isEmpty) return null;
    return PhotoSession(
      files: paths.map(File.new).toList(),
      source: args['source']?.toString() ?? 'upload',
    );
  }

  Map<String, dynamic> toArguments() => {
        'photoPath': files.first.path,
        'photoPaths': files.map((f) => f.path).toList(),
        'source': source,
      };
}

class _CaptureToolbarOverlay extends StatefulWidget {
  const _CaptureToolbarOverlay({
    required this.onDismiss,
    this.anchorKey,
  });

  final VoidCallback onDismiss;
  final GlobalKey? anchorKey;

  @override
  State<_CaptureToolbarOverlay> createState() => _CaptureToolbarOverlayState();
}

class _CaptureToolbarOverlayState extends State<_CaptureToolbarOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _rise;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _rise = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _ctrl.reverse();
    if (mounted) widget.onDismiss();
  }

  Future<void> _choose(ImageSource source) async {
    await _ctrl.reverse();
    widget.onDismiss();
    await pickAndOpenPreview(source);
  }

  Rect? _anchorRect() {
    final box =
        widget.anchorKey?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    final isDark = b == Brightness.dark;
    final anchor = _anchorRect();
    final media = MediaQuery.of(context);
    final safeBottom = media.padding.bottom;

    // Seat the dock just above the camera FAB (or above nav when unanchored).
    final dockBottom = anchor != null
        ? media.size.height - anchor.top + 14
        : safeBottom + AppSize.navH + StudioNavBar.fabSize * 0.35 + 20;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _rise.value.clamp(0.0, 1.0);
        final fade = _fade.value.clamp(0.0, 1.0);

        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              // Soft stage dim — readable, not a hard blackout.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: ColoredBox(
                    color: Colors.black.withValues(
                      alpha: (isDark ? 0.55 : 0.38) * fade,
                    ),
                  ),
                ),
              ),

              // Source dock
              Positioned(
                left: AppSpace.lg,
                right: AppSpace.lg,
                bottom: dockBottom,
                child: Opacity(
                  opacity: fade,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 18),
                    child: Transform.scale(
                      scale: 0.96 + (0.04 * t),
                      alignment: Alignment.bottomCenter,
                      child: _CaptureDock(
                        brightness: b,
                        onGallery: () => _choose(ImageSource.gallery),
                        onCamera: () => _choose(ImageSource.camera),
                      ),
                    ),
                  ),
                ),
              ),

              // Close over the FAB seat — soft, no extra ring fighting the camera.
              if (anchor != null)
                Positioned(
                  left: anchor.left,
                  top: anchor.top,
                  width: anchor.width,
                  height: anchor.height,
                  child: Opacity(
                    opacity: fade,
                    child: Transform.rotate(
                      angle: t * (mathPi / 4),
                      child: _CaptureClose(onTap: _close, brightness: b),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

const double mathPi = 3.141592653589793;

/// Soft studio panel — same rim/face language as tool cards.
class _CaptureDock extends StatelessWidget {
  const _CaptureDock({
    required this.brightness,
    required this.onGallery,
    required this.onCamera,
  });

  final Brightness brightness;
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    final rim = StudioChrome.rimWidth;
    final radius = BorderRadius.circular(AppRadius.lg);
    final inner = BorderRadius.circular(AppRadius.lg - rim);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
            blurRadius: 28,
            offset: const Offset(0, 14),
            spreadRadius: -6,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: AppColors.cardRim(brightness),
        ),
        child: Padding(
          padding: EdgeInsets.all(rim),
          child: ClipRRect(
            borderRadius: inner,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? AppColors.cardSheenDark
                          : AppColors.cardSheenLight,
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: NoiseOverlay(opacity: NoiseOverlay.defaultOpacity),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Add photos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: AppColors.text(brightness),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Camera or gallery — up to 5',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Figtree',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted(brightness),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _SourceTile(
                              brightness: brightness,
                              icon: AppIcons.galleryFill,
                              label: 'Gallery',
                              hint: 'Pick photos',
                              onTap: onGallery,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SourceTile(
                              brightness: brightness,
                              icon: AppIcons.cameraFill,
                              label: 'Camera',
                              hint: 'Take a shot',
                              onTap: onCamera,
                              emphasized: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceTile extends StatefulWidget {
  const _SourceTile({
    required this.brightness,
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
    this.emphasized = false,
  });

  final Brightness brightness;
  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  State<_SourceTile> createState() => _SourceTileState();
}

class _SourceTileState extends State<_SourceTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.brightness == Brightness.dark;
    final accent = AppColors.accentOf(widget.brightness);
    final face = isDark
        ? Colors.white.withValues(alpha: widget.emphasized ? 0.08 : 0.05)
        : Colors.black.withValues(alpha: widget.emphasized ? 0.05 : 0.035);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdAll,
            color: face,
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.emphasized
                        ? (isDark
                            ? [
                                const Color(0xFF2A2E36),
                                const Color(0xFF16181C),
                              ]
                            : [
                                Colors.white,
                                const Color(0xFFE8ECF2),
                              ])
                        : (isDark
                            ? [
                                Colors.white.withValues(alpha: 0.1),
                                Colors.white.withValues(alpha: 0.04),
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.9),
                                Colors.black.withValues(alpha: 0.04),
                              ]),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.35 : 0.08,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  size: 22,
                  color: widget.emphasized
                      ? (isDark ? const Color(0xFFF4F5F7) : accent)
                      : AppColors.text(widget.brightness),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text(widget.brightness),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.hint,
                style: TextStyle(
                  fontFamily: 'Figtree',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted(widget.brightness),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureClose extends StatelessWidget {
  const _CaptureClose({
    required this.onTap,
    required this.brightness,
  });

  final VoidCallback onTap;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.chromeRim(brightness),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.14),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(2.6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? const Color(0xFFECEEF2)
                  : const Color(0xFF16181C),
            ),
            child: Center(
              child: Icon(
                AppIcons.close,
                size: 24,
                color: isDark
                    ? const Color(0xFF16181C)
                    : const Color(0xFFF4F5F7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
