import 'package:get/get.dart';

class ShellController extends GetxController {
  /// 0 Home · 1 History · 2 Wallet · 3 Profile
  final index = 0.obs;
  final opened = <int>[0].obs;

  void setIndex(int value) {
    index.value = value;
    if (!opened.contains(value)) opened.add(value);
  }

  bool hasOpened(int value) => opened.contains(value);
}
