import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_shimmer.dart';
import '../utils/app_image_cache.dart';
import '../utils/catalog_images.dart';
import '../utils/image_cache_size.dart';
import '../../core/theme/app_icons.dart';

/// Reliable network image: resized Supabase URL first, original as fallback.
class AppNetworkImage extends StatefulWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.displayWidth = 720,
    this.memCacheWidth,
    this.memCacheHeight,
    this.logicalWidth,
    this.logicalHeight,
    this.borderRadius,
    this.placeholder,
    this.error,
    this.optimize = true,
    this.fadeIn = const Duration(milliseconds: 200),
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// Target width for Supabase render transform.
  final int displayWidth;

  final int? memCacheWidth;
  final int? memCacheHeight;

  /// Logical CSS size used to derive mem cache when explicit mem sizes omitted.
  final double? logicalWidth;
  final double? logicalHeight;

  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? error;
  final bool optimize;
  final Duration fadeIn;

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  /// 0 = optimized, 1 = original, 2 = failed
  int _attempt = 0;

  String? get _primary {
    // Never rewrite signed private media — tokens live in the query string.
    if (!widget.optimize || CatalogImages.isSigned(widget.url)) {
      return widget.url;
    }
    return CatalogImages.displayUrl(
      widget.url,
      width: widget.displayWidth,
    );
  }

  String? get _original {
    if (CatalogImages.isSigned(widget.url)) return widget.url;
    return CatalogImages.originalUrl(widget.url) ?? widget.url;
  }

  String? get _active {
    if (widget.url == null || widget.url!.isEmpty) return null;
    if (_attempt == 0) return _primary ?? _original;
    if (_attempt == 1) return _original;
    return null;
  }

  void _onError() {
    if (!mounted) return;
    if (_attempt == 0) {
      final primary = _primary;
      final original = _original;
      // Only fall back when the URLs differ.
      if (primary != null &&
          original != null &&
          primary != original) {
        setState(() => _attempt = 1);
        return;
      }
    }
    setState(() => _attempt = 2);
  }

  @override
  void didUpdateWidget(covariant AppNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.displayWidth != widget.displayWidth ||
        oldWidget.optimize != widget.optimize) {
      _attempt = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _active;
    final placeholder = widget.placeholder ?? const _ImageShimmer();
    final error = widget.error ?? const _ImageError();

    if (url == null || url.isEmpty || _attempt >= 2) {
      return _box(error);
    }

    final memW = widget.memCacheWidth ??
        (widget.logicalWidth != null
            ? imageCachePx(context, widget.logicalWidth!)
            : null);
    final memH = widget.memCacheHeight ??
        (widget.logicalHeight != null
            ? imageCachePx(context, widget.logicalHeight!)
            : null);

    final image = CachedNetworkImage(
      key: ValueKey('img-$url-$_attempt'),
      imageUrl: url,
      cacheManager: AppImageCache.instance,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      memCacheWidth: memW,
      memCacheHeight: memH,
      fadeInDuration: widget.fadeIn,
      fadeOutDuration: const Duration(milliseconds: 80),
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) {
        // Schedule fallback outside build.
        WidgetsBinding.instance.addPostFrameCallback((_) => _onError());
        return placeholder;
      },
    );

    return _box(image);
  }

  Widget _box(Widget child) {
    if (widget.borderRadius == null) return child;
    return ClipRRect(borderRadius: widget.borderRadius!, child: child);
  }
}

class _ImageShimmer extends StatelessWidget {
  const _ImageShimmer();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: isDark ? const Color(0xFF161616) : const Color(0xFFE8E8EC),
      child: const Center(
        child: SizedBox(
          width: 120,
          height: 14,
          child: AppShimmerBlock(height: 14, radius: 6),
        ),
      ),
    );
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFE8E8EC),
      child: Center(
        child: Icon(
          AppIcons.photoBroken,
          color: AppColors.textMuted(Theme.of(context).brightness),
          size: AppSize.iconMd,
        ),
      ),
    );
  }
}
