import 'package:flutter/material.dart';

import 'app_background.dart';

/// Keeps the last non-null navigator child so GetX transition frames that
/// briefly pass `null` don't flash / stick on an empty grid background.
class AppNavigatorHost extends StatefulWidget {
  const AppNavigatorHost({super.key, required this.child});

  final Widget? child;

  @override
  State<AppNavigatorHost> createState() => _AppNavigatorHostState();
}

class _AppNavigatorHostState extends State<AppNavigatorHost> {
  Widget? _keep;

  @override
  void initState() {
    super.initState();
    _keep = widget.child;
  }

  @override
  void didUpdateWidget(covariant AppNavigatorHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child != null) {
      _keep = widget.child;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(child: _keep ?? const SizedBox.shrink());
  }
}
