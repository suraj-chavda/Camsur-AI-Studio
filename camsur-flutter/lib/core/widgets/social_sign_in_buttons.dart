import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../extensions/context_x.dart';
import '../theme/app_icons.dart';
import 'app_button.dart';

/// "Or continue with" divider + Google/Apple buttons, shared by the login
/// and register screens. Apple only renders on iOS/macOS — Apple requires
/// offering it wherever other social logins appear on those platforms, but
/// it isn't a native flow on Android.
class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({
    super.key,
    required this.loading,
    required this.onGoogle,
    required this.onApple,
  });

  final bool loading;
  final VoidCallback onGoogle;
  final VoidCallback onApple;

  bool get _showApple =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: context.colors.outlineVariant)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or continue with', style: context.texts.bodySmall),
            ),
            Expanded(child: Divider(color: context.colors.outlineVariant)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Google',
                icon: AppIcons.google,
                gradient: false,
                loading: loading,
                onPressed: loading ? null : onGoogle,
              ),
            ),
            if (_showApple) ...[
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Apple',
                  icon: AppIcons.apple,
                  gradient: false,
                  loading: loading,
                  onPressed: loading ? null : onApple,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
