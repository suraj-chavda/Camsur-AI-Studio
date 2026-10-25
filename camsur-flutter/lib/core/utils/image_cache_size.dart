import 'package:flutter/widgets.dart';

/// Decode network images only as large as they are displayed.
int imageCachePx(BuildContext context, double logicalCssPx) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return (logicalCssPx * dpr).round().clamp(64, 1400);
}
