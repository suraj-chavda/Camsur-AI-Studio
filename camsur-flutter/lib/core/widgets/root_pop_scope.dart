import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Stops Android back / iOS swipe from popping the last route into a blank
/// navigator (which only shows [AppBackground]'s grid).
class RootPopScope extends StatelessWidget {
  const RootPopScope({
    super.key,
    required this.child,
    this.exitApp = true,
  });

  final Widget child;
  final bool exitApp;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (exitApp) SystemNavigator.pop();
      },
      child: child,
    );
  }
}
