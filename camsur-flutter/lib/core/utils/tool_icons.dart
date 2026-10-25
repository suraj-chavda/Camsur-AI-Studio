import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

IconData toolIconFor(String slug) => switch (slug) {
      'headshot' || 'linkedin' => AppIcons.headshot,
      'together' => AppIcons.together,
      'indian_passport' => AppIcons.passport,
      'background_remover' => AppIcons.removeBg,
      _ => AppIcons.sparkle,
    };

String toolTitleFor(String slug) => switch (slug) {
      'headshot' => 'AI Headshots',
      'linkedin' => 'LinkedIn Photo',
      'together' => 'Together',
      'indian_passport' => 'Passport Photo',
      'background_remover' => 'Remove Background',
      _ => slug.replaceAll('_', ' '),
    };

IconData categoryIconFor({String? icon, String slug = ''}) {
  final key = (icon ?? slug).toLowerCase().trim();
  return switch (key) {
    'portrait' || 'headshot' || 'face' || 'user' => AppIcons.headshot,
    'passport' || 'id' || 'identity' => AppIcons.passport,
    'people' || 'together' || 'group' || 'users' => AppIcons.together,
    'edit' || 'enhance' || 'retouch' || 'magic' => AppIcons.magic,
    'background' || 'remove_bg' || 'bg' => AppIcons.removeBg,
    'photo' || 'image' || 'camera' => AppIcons.photo,
    'instagram' || 'trend' || 'trending' => AppIcons.sparkle,
    'art' || 'cartoon' || 'style' => AppIcons.magic,
    'all' => AppIcons.tools,
    _ => AppIcons.tag,
  };
}
