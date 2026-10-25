import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../extensions/context_x.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_network_image.dart';
import 'before_after_compare.dart';
import '../../core/theme/app_icons.dart';

/// Result hero that keeps before/after as the main surface.
///
/// When multiple originals exist, a quiet strip under the compare lets the
/// user pick which source photo is the "before" side — no second hero.
class ResultOriginalsCompare extends StatefulWidget {
  const ResultOriginalsCompare({
    super.key,
    required this.afterUrl,
    this.beforeFiles = const [],
    this.beforeUrls = const [],
    this.aspectRatio = 1,
    this.displayWidth = 1200,
    this.afterError,
    this.personLabels = false,
  });

  final String afterUrl;
  final List<File> beforeFiles;
  final List<String> beforeUrls;
  final double aspectRatio;
  final int displayWidth;
  final Widget? afterError;
  final bool personLabels;

  @override
  State<ResultOriginalsCompare> createState() => _ResultOriginalsCompareState();
}

class _ResultOriginalsCompareState extends State<ResultOriginalsCompare> {
  var _index = 0;

  List<_OriginalSource> get _sources {
    final files = widget.beforeFiles
        .where((f) => f.existsSync())
        .map((f) => _OriginalSource.file(f))
        .toList();
    if (files.isNotEmpty) return files;

    return widget.beforeUrls
        .where((u) => u.trim().isNotEmpty && u.startsWith('http'))
        .map(_OriginalSource.url)
        .toList();
  }

  @override
  void didUpdateWidget(covariant ResultOriginalsCompare oldWidget) {
    super.didUpdateWidget(oldWidget);
    final n = _sources.length;
    if (n == 0) {
      _index = 0;
    } else if (_index >= n) {
      _index = n - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources = _sources;
    final selected =
        sources.isEmpty ? null : sources[_index.clamp(0, sources.length - 1)];
    final multi = sources.length > 1;
    final b = Theme.of(context).brightness;
    final radius = BorderRadius.circular(AppRadius.lg - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: multi
              ? const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg - 1),
                )
              : radius,
          child: BeforeAfterCompare(
            afterUrl: widget.afterUrl,
            beforeUrl: selected?.url,
            beforeFile: selected?.file,
            aspectRatio: widget.aspectRatio,
            displayWidth: widget.displayWidth,
            afterError: widget.afterError,
          ),
        ),
        if (multi) ...[
          const SizedBox(height: AppSpace.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            child: Row(
              children: [
                Text(
                  'Originals',
                  style: context.texts.labelLarge?.copyWith(
                    color: AppColors.textMuted(b),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '· tap to compare',
                  style: context.texts.labelSmall?.copyWith(
                    color: AppColors.textMuted(b),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(
                AppSpace.md,
                0,
                AppSpace.md,
                AppSpace.sm,
              ),
              itemCount: sources.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final src = sources[i];
                final selectedNow = i == _index;
                final label = widget.personLabels
                    ? 'P${i + 1}'
                    : (i == 0 ? 'Main' : '${i + 1}');

                return Semantics(
                  button: true,
                  selected: selectedNow,
                  label: 'Original $label',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        if (i == _index) return;
                        HapticFeedback.selectionClick();
                        setState(() => _index = i);
                      },
                      borderRadius: AppRadius.smAll,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutCubic,
                        width: 56,
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.smAll,
                          border: Border.all(
                            color: selectedNow
                                ? AppColors.accentOf(b)
                                : AppColors.border(b).withValues(alpha: 0.65),
                            width: selectedNow ? 2 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm - 1),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (src.file != null)
                                Image.file(
                                  src.file!,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.medium,
                                )
                              else
                                AppNetworkImage(
                                  url: src.url,
                                  fit: BoxFit.cover,
                                  displayWidth: 160,
                                  logicalWidth: 56,
                                  logicalHeight: 64,
                                  error: ColoredBox(
                                    color: AppColors.border(b).withValues(
                                      alpha: 0.2,
                                    ),
                                    child: Icon(
                                      AppIcons.photo,
                                      size: 18,
                                      color: AppColors.textMuted(b),
                                    ),
                                  ),
                                ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: ColoredBox(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Text(
                                      label,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
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
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _OriginalSource {
  const _OriginalSource._({this.file, this.url});

  factory _OriginalSource.file(File file) => _OriginalSource._(file: file);

  factory _OriginalSource.url(String url) => _OriginalSource._(url: url);

  final File? file;
  final String? url;
}
