"""Reframe an input photo to a tool's target aspect ratio before it's sent
to the AI provider.

Why: if the uploaded photo's aspect ratio is very different from the
requested output canvas (e.g. a tall 922x2048 phone photo into a square
1024x1024 headshot), BFL has to recompose the whole frame to fit the new
shape rather than make a localized edit (swap background/attire) — and that
large-scale recomposition is a common cause of the model regenerating the
face instead of preserving it. Center-cropping to the target aspect first
means BFL receives an image already framed close to the desired output, so
it only needs to touch background/attire/lighting.
"""

from __future__ import annotations

import io

from PIL import Image, ImageOps

JPEG_QUALITY = 92
# For a portrait-oriented crop (taller input than target), bias the crop
# window upward rather than dead-center — a person's face in a phone photo
# is typically in the upper portion of the frame, not the vertical middle.
VERTICAL_CROP_BIAS = 0.35


def fit_to_aspect(data: bytes, target_width: int, target_height: int) -> bytes:
    """Center-crop `data` to match target_width/target_height's aspect ratio,
    then resize to exactly that size. Returns re-encoded JPEG bytes."""
    with Image.open(io.BytesIO(data)) as img:
        img = ImageOps.exif_transpose(img)  # undo phone-camera rotation tags
        img = img.convert("RGB")

        width, height = img.size
        target_ratio = target_width / target_height
        current_ratio = width / height

        if current_ratio > target_ratio + 1e-6:
            # Wider than target — crop the sides, keep full height.
            new_width = round(height * target_ratio)
            left = (width - new_width) // 2
            img = img.crop((left, 0, left + new_width, height))
        elif current_ratio < target_ratio - 1e-6:
            # Taller than target — crop top/bottom, biased toward the top.
            new_height = round(width / target_ratio)
            excess = height - new_height
            top = round(excess * VERTICAL_CROP_BIAS)
            img = img.crop((0, top, width, top + new_height))

        img = img.resize((target_width, target_height), Image.LANCZOS)

        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=JPEG_QUALITY)
        return buf.getvalue()
