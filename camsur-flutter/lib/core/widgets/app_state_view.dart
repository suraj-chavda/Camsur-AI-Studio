import 'package:flutter/material.dart';

import 'studio_state_card.dart';
import '../../core/theme/app_icons.dart';

/// Empty / loading / error placeholders — home-aligned via [StudioStateCard].
class AppStateView extends StatelessWidget {
  const AppStateView.loading({super.key})
      : message = null,
        icon = null,
        onRetry = null,
        title = null,
        _loading = true,
        _error = false;

  const AppStateView.empty({
    super.key,
    this.message = 'Nothing here yet',
    this.icon = AppIcons.empty,
    this.onRetry,
    this.title = 'Nothing here yet',
  })  : _loading = false,
        _error = false;

  const AppStateView.error({
    super.key,
    required this.message,
    this.icon = AppIcons.offline,
    this.onRetry,
    this.title = 'Something went wrong',
  })  : _loading = false,
        _error = true;

  final String? title;
  final String? message;
  final IconData? icon;
  final VoidCallback? onRetry;
  final bool _loading;
  final bool _error;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: StudioLoadingBlock(),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: StudioStateCard(
            title: title ?? (_error ? 'Something went wrong' : 'Nothing here yet'),
            message: message ?? '',
            icon: icon ??
                (_error ? AppIcons.offline : AppIcons.empty),
            onRetry: onRetry,
          ),
        ),
      ),
    );
  }
}
