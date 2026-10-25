"""Replace Material Icons.* with AppIcons.* across lib/."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'lib'

# Longest Material names first so shorter ones don't steal prefixes.
REPLACEMENTS: list[tuple[str, str]] = [
    ('Icons.face_retouching_natural_rounded', 'AppIcons.headshot'),
    ('Icons.account_balance_wallet_outlined', 'AppIcons.wallet'),
    ('Icons.account_balance_wallet_rounded', 'AppIcons.walletFill'),
    ('Icons.add_photo_alternate_outlined', 'AppIcons.photoAdd'),
    ('Icons.image_not_supported_outlined', 'AppIcons.photoBroken'),
    ('Icons.broken_image_outlined', 'AppIcons.photoBroken'),
    ('Icons.auto_fix_high_outlined', 'AppIcons.magic'),
    ('Icons.auto_awesome_outlined', 'AppIcons.sparkle'),
    ('Icons.auto_awesome_rounded', 'AppIcons.sparkleFill'),
    ('Icons.brightness_auto_outlined', 'AppIcons.themeAuto'),
    ('Icons.keyboard_arrow_down_rounded', 'AppIcons.chevronDown'),
    ('Icons.person_outline_rounded', 'AppIcons.profile'),
    ('Icons.person_rounded', 'AppIcons.profileFill'),
    ('Icons.photo_library_outlined', 'AppIcons.gallery'),
    ('Icons.photo_library_rounded', 'AppIcons.galleryFill'),
    ('Icons.photo_camera_outlined', 'AppIcons.camera'),
    ('Icons.photo_camera_rounded', 'AppIcons.cameraFill'),
    ('Icons.layers_clear_outlined', 'AppIcons.removeBg'),
    ('Icons.diversity_3_rounded', 'AppIcons.together'),
    ('Icons.badge_outlined', 'AppIcons.passport'),
    ('Icons.home_outlined', 'AppIcons.home'),
    ('Icons.home_rounded', 'AppIcons.homeFill'),
    ('Icons.history_rounded', 'AppIcons.history'),
    ('Icons.mail_outline_rounded', 'AppIcons.mail'),
    ('Icons.lock_outline_rounded', 'AppIcons.lock'),
    ('Icons.visibility_off_outlined', 'AppIcons.eyeOff'),
    ('Icons.visibility_outlined', 'AppIcons.eye'),
    ('Icons.light_mode_outlined', 'AppIcons.sun'),
    ('Icons.dark_mode_outlined', 'AppIcons.moon'),
    ('Icons.notifications_outlined', 'AppIcons.bell'),
    ('Icons.help_outline_rounded', 'AppIcons.help'),
    ('Icons.card_giftcard_outlined', 'AppIcons.gift'),
    ('Icons.chevron_right_rounded', 'AppIcons.chevronRight'),
    ('Icons.arrow_forward_rounded', 'AppIcons.arrowForward'),
    ('Icons.swap_horiz_rounded', 'AppIcons.swap'),
    ('Icons.ios_share_rounded', 'AppIcons.share'),
    ('Icons.download_rounded', 'AppIcons.download'),
    ('Icons.close_rounded', 'AppIcons.close'),
    ('Icons.add_rounded', 'AppIcons.add'),
    ('Icons.remove_rounded', 'AppIcons.remove'),
    ('Icons.refresh_rounded', 'AppIcons.refresh'),
    ('Icons.search_off_rounded', 'AppIcons.searchOff'),
    ('Icons.search_rounded', 'AppIcons.search'),
    ('Icons.check_circle_rounded', 'AppIcons.checkCircle'),
    ('Icons.check_rounded', 'AppIcons.check'),
    ('Icons.delete_outline_rounded', 'AppIcons.trash'),
    ('Icons.error_outline_rounded', 'AppIcons.error'),
    ('Icons.info_outline_rounded', 'AppIcons.info'),
    ('Icons.cloud_off_outlined', 'AppIcons.offline'),
    ('Icons.inbox_outlined', 'AppIcons.empty'),
    ('Icons.grid_view_rounded', 'AppIcons.tools'),
    ('Icons.bolt_rounded', 'AppIcons.credits'),
    ('Icons.receipt_long_rounded', 'AppIcons.receipt'),
    ('Icons.photo_outlined', 'AppIcons.photo'),
    ('Icons.layers_outlined', 'AppIcons.layers'),
    ('Icons.schedule_rounded', 'AppIcons.schedule'),
    ('Icons.flag_outlined', 'AppIcons.flag'),
    ('Icons.tag_rounded', 'AppIcons.tag'),
    ('Icons.language_rounded', 'AppIcons.language'),
    ('Icons.logout_rounded', 'AppIcons.logout'),
]

IMPORT_LINE = "import '../../core/theme/app_icons.dart';"
# Depth-relative import variants
IMPORT_PATTERNS = [
    re.compile(r"import ['\"].*core/theme/app_icons\.dart['\"];"),
]


def import_for(path: Path) -> str:
    rel = path.relative_to(ROOT).as_posix()
    depth = rel.count('/')
    prefix = '../' * depth
    return f"import '{prefix}core/theme/app_icons.dart';"


def process(path: Path) -> bool:
    text = path.read_text(encoding='utf-8')
    if 'Icons.' not in text:
        return False
    original = text
    for old, new in REPLACEMENTS:
        text = text.replace(old, new)
    if text == original:
        return False
    if 'AppIcons.' in text and not IMPORT_PATTERNS[0].search(text):
        # Insert after last import
        lines = text.splitlines(keepends=True)
        last_import = -1
        for i, line in enumerate(lines):
            if line.startswith('import '):
                last_import = i
        if last_import >= 0:
            lines.insert(last_import + 1, import_for(path) + '\n')
            text = ''.join(lines)
    path.write_text(text, encoding='utf-8')
    print(f'updated {path.relative_to(ROOT)}')
    return True


def main() -> None:
    n = 0
    for path in ROOT.rglob('*.dart'):
        if path.name == 'app_icons.dart':
            continue
        if process(path):
            n += 1
    print(f'done — {n} files')
    # leftover Material Icons
    left = []
    for path in ROOT.rglob('*.dart'):
        t = path.read_text(encoding='utf-8')
        for m in re.finditer(r'Icons\.\w+', t):
            left.append(f'{path.relative_to(ROOT)}:{m.group(0)}')
    if left:
        print('remaining:')
        for x in sorted(set(left)):
            print(' ', x)


if __name__ == '__main__':
    main()
