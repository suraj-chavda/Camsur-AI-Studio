import 'package:flutter/material.dart';

import '../utils/responsive.dart';

extension ContextX on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
  MediaQueryData get mq => MediaQuery.of(this);
  Size get screen => mq.size;
  Responsive get responsive => Responsive.of(this);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
