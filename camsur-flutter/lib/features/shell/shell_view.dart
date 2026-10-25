import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/extensions/context_x.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/studio_chrome.dart';
import '../../core/widgets/root_pop_scope.dart';
import '../credits/credits_view.dart';
import '../history/history_view.dart';
import '../home/home_view.dart';
import '../profile/profile_view.dart';
import 'capture_sheet.dart';
import 'shell_binding.dart';
import 'shell_controller.dart';
import 'studio_nav_bar.dart';
import 'studio_top_bar.dart';
import '../../core/theme/app_icons.dart';

class ShellView extends GetView<ShellController> {
  const ShellView({super.key});

  static final GlobalKey cameraFabKey = GlobalKey(debugLabel: 'studio_camera');

  @override
  Widget build(BuildContext context) {
    final wide = context.responsive.isWide;
    final overlay = StudioChrome.overlayFor(Theme.of(context).brightness);

    if (wide) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlay,
        child: RootPopScope(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Row(
              children: [
                Obx(
                  () => NavigationRail(
                    selectedIndex: controller.index.value,
                    onDestinationSelected: _select,
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.only(bottom: 12, top: 8),
                      child: FloatingActionButton(
                        mini: true,
                        onPressed: () => showCaptureToolbar(),
                        child: const Icon(AppIcons.cameraFill),
                      ),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(AppIcons.home),
                        selectedIcon: Icon(AppIcons.homeFill),
                        label: Text('Home'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(AppIcons.history),
                        selectedIcon: Icon(AppIcons.historyFill),
                        label: Text('History'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(AppIcons.wallet),
                        selectedIcon:
                            Icon(AppIcons.walletFill),
                        label: Text('Wallet'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(AppIcons.profile),
                        selectedIcon: Icon(AppIcons.profileFill),
                        label: Text('Profile'),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      const StudioTopBar(),
                      Expanded(child: Obx(() => _tabBody())),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: RootPopScope(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          // Scaffold FAB layer sits above body + nav, so taps always win.
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          floatingActionButton: StudioCameraFab(
            key: cameraFabKey,
            onTap: () => showCaptureToolbar(anchorKey: cameraFabKey),
          ),
          body: Column(
            children: [
              const StudioTopBar(),
              Expanded(child: Obx(() => _tabBody())),
            ],
          ),
          bottomNavigationBar: Obx(
            () => StudioNavBar(
              index: controller.index.value,
              onSelect: _select,
            ),
          ),
        ),
      ),
    );
  }

  void _select(int i) {
    ensureShellTab(i);
    controller.setIndex(i);
  }

  Widget _tabBody() {
    return IndexedStack(
      index: controller.index.value,
      children: [
        const HomeView(),
        controller.hasOpened(1) ? const HistoryView() : const SizedBox.shrink(),
        controller.hasOpened(2) ? const CreditsView() : const SizedBox.shrink(),
        controller.hasOpened(3) ? const ProfileView() : const SizedBox.shrink(),
      ],
    );
  }
}

/// Center-docked camera — chrome white rim (matches premium nav edge).
class StudioCameraFab extends StatelessWidget {
  const StudioCameraFab({super.key, required this.onTap});

  final VoidCallback onTap;

  static const double size = StudioNavBar.fabSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final b = Theme.of(context).brightness;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.chromeRim(b),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            // Thick chrome ring — the visible “white border”.
            padding: const EdgeInsets.all(2.6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? const Color(0xFFECEEF2)
                    : const Color(0xFF16181C),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Icon(
                AppIcons.cameraFill,
                size: 26,
                color: isDark
                    ? const Color(0xFF111318)
                    : const Color(0xFFF6F7F9),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
