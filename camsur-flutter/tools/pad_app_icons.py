"""Pad Camsur launcher icons so the mark sits in the Android/iOS safe zone."""

from pathlib import Path

from PIL import Image, ImageChops

root = Path(__file__).resolve().parents[1] / 'assets' / 'icons'


def content_bbox(im: Image.Image, threshold: int = 18) -> tuple[int, int, int, int]:
    """Tight box around non-near-black pixels."""
    rgb = im.convert('RGB')
    # Anything brighter than threshold counts as content.
    mask = rgb.point(lambda p: 255 if p > threshold else 0).convert('L')
    # Also keep semi-opaque alpha as content.
    if im.mode == 'RGBA':
        alpha = im.split()[3]
        mask = ImageChops.lighter(mask, alpha.point(lambda a: 255 if a > 12 else 0))
    bbox = mask.getbbox()
    if bbox is None:
        return (0, 0, im.width, im.height)
    return bbox


def fit_content(
    src: Path,
    dst: Path,
    *,
    content_scale: float,
    size: int = 1024,
    bg=(0, 0, 0, 255),
):
    im = Image.open(src).convert('RGBA')
    # Keep an unpadded master once (from the first non-_full source).
    if not src.stem.endswith('_full'):
        bak = src.with_name(f'{src.stem}_full{src.suffix}')
        if not bak.exists():
            im.save(bak)

    left, top, right, bottom = content_bbox(im)
    cropped = im.crop((left, top, right, bottom))

    canvas = Image.new('RGBA', (size, size), bg)
    max_side = max(1, int(round(size * content_scale)))
    cw, ch = cropped.size
    scale = min(max_side / cw, max_side / ch)
    nw = max(1, int(round(cw * scale)))
    nh = max(1, int(round(ch * scale)))
    resized = cropped.resize((nw, nh), Image.Resampling.LANCZOS)
    ox = (size - nw) // 2
    oy = (size - nh) // 2
    canvas.paste(resized, (ox, oy), resized)
    canvas.save(dst, optimize=True)
    print(
        f'{dst.name}: mark {nw}x{nh} on {size} '
        f'(max {content_scale:.0%}, margins ~{(size - max(nw, nh)) / 2 / size:.0%})'
    )


app_src = root / 'app_icon_full.png'
if not app_src.exists():
    app_src = root / 'app_icon.png'
fg_src = root / 'app_icon_foreground_full.png'
if not fg_src.exists():
    fg_src = root / 'app_icon_foreground.png'

# iOS / legacy mipmaps — comfortable margin inside rounded square.
fit_content(app_src, root / 'app_icon.png', content_scale=0.76)
# Android adaptive foreground — stay inside ~66% safe zone (+ a little air).
fit_content(fg_src, root / 'app_icon_foreground.png', content_scale=0.62)
print('done')
