"""
Seed the 19 new tool catalog entries (Professional Headshot already exists)
across 5 categories, each with an AI-generated thumbnail from the cheapest
FLUX model (flux-2-klein-4b) to keep seeding cost low.

Usage:
  python scripts/seed_tool_catalog.py          # dry-run (default) — prints what would happen
  python scripts/seed_tool_catalog.py --yes    # actually generates images + upserts rows
"""

from __future__ import annotations

import argparse
import asyncio
import sys
import uuid
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
load_dotenv(ROOT / ".env")

from app.config import get_settings  # noqa: E402
from app.db.supabase import get_supabase  # noqa: E402
from app.providers.bfl_provider import BflProvider  # noqa: E402

THUMBNAIL_MODEL = "flux-2-klein-4b"  # cheapest catalog entry — see bfl_model_catalog

CATEGORIES = [
    {"slug": "enhance", "name": "Enhance & Restore", "description": "Sharpen, upscale, and repair photos.", "sort_order": 20},
    {"slug": "restore", "name": "Restoration", "description": "Bring old or damaged photos back to life.", "sort_order": 30},
    {"slug": "creative", "name": "Creative", "description": "Cinematic and editorial photo styles.", "sort_order": 40},
    {"slug": "art", "name": "Art Styles", "description": "Turn photos into illustrated and painted art.", "sort_order": 50},
    {"slug": "editing", "name": "Editing", "description": "Background and composition edits.", "sort_order": 60},
]

# (slug, name, category, description, edit_prompt, thumbnail_prompt)
TOOLS = [
    (
        "dslr-photo", "DSLR Photo", "enhance",
        "Transform any photo into a professional DSLR photograph.",
        "Transform the photo into a professional DSLR photograph. Preserve the exact person, face, age, gender, body shape, height, weight, hairstyle, facial hair, clothing and natural proportions. Improve lens quality, depth of field, sharpness, lighting and realistic photographic detail without changing the person.",
        "A sharp professional DSLR portrait photo of a person, shallow depth of field, natural bokeh, crisp detail, 85mm lens, photorealistic, professional photography, 8k.",
    ),
    (
        "photo-enhancer", "Photo Enhancer", "enhance",
        "Sharpen and enhance any photo's clarity, color, and detail.",
        "Enhance the attached photo with natural sharpness, detail, lighting, color and clarity. Preserve the exact person, face, age, gender, body shape, hair, facial hair and every important original detail. Do not redesign or alter the person.",
        "A crisp, vivid, naturally enhanced portrait photo of a person, sharp detail, balanced natural color, professional photography, 8k.",
    ),
    (
        "hd-upscaler", "HD Upscaler", "enhance",
        "Restore and upscale low-resolution photos into clean high-res images.",
        "Restore and upscale the attached image into a clean high-resolution photograph. Recover natural facial, hair, clothing and environmental detail while preserving the exact person, proportions, age, gender and original appearance.",
        "A clean, high-resolution, sharply detailed portrait photo of a person, crisp texture, professional photography, 8k, ultra detailed.",
    ),
    (
        "face-enhancer", "Face Enhancer", "enhance",
        "Naturally sharpen and clarify facial detail without changing the face.",
        "Naturally restore and enhance the person's face. Preserve the exact identity, facial structure, eyes, nose, lips, jawline, skin tone, age and facial hair. Improve clarity and realistic skin detail without beautifying or changing the face.",
        "A close-up portrait photo of a person with natural, clear, detailed skin texture, soft even lighting, photorealistic, professional photography, 8k.",
    ),
    (
        "photo-restoration", "Photo Restoration", "restore",
        "Repair scratches, cracks, blur, and fading in old photographs.",
        "Restore the damaged photograph to a clean, natural condition. Repair scratches, cracks, blur, fading and missing image details while preserving every person's exact identity, face, age, body proportions, clothing and original composition.",
        "A beautifully restored vintage family photograph, clean and undamaged, natural tones, sharp detail, professional photo restoration, 8k.",
    ),
    (
        "colorize", "Colorize", "restore",
        "Add realistic natural color to black-and-white photos.",
        "Naturally colorize this photograph while preserving the exact people, faces, ages, body proportions, clothing, hair and original composition. Use realistic skin tones, hair colors, clothing colors and natural photographic color.",
        "A naturally colorized vintage black-and-white photograph, realistic skin tones and warm natural colors, photorealistic, 8k.",
    ),
    (
        "cinematic", "Cinematic", "creative",
        "Give any photo a stunning cinematic look and color grade.",
        "Transform the attached photo into a stunning cinematic photograph. Preserve the exact person, face, age, gender, body proportions, hair, facial hair and clothing. Add cinematic lighting, depth, atmosphere and professional color grading without changing the person.",
        "A cinematic portrait photo of a person, dramatic moody lighting, film color grade, atmospheric depth, professional cinematography, 8k.",
    ),
    (
        "studio-lighting", "Studio Lighting", "enhance",
        "Replace flat lighting with professional studio portrait lighting.",
        "Replace the existing lighting with professional studio lighting. Preserve the exact person, face, age, gender, body proportions, hairstyle, facial hair, clothing and composition. Create realistic soft key light, natural shadows and premium portrait illumination.",
        "A portrait photo of a person lit with professional studio lighting, soft key light, natural shadow falloff, premium portrait photography, 8k.",
    ),
    (
        "background", "Background", "editing",
        "Swap in a beautiful new background while keeping the person untouched.",
        "Replace the background with a beautiful professional environment while keeping the person completely unchanged. Preserve the exact face, identity, age, gender, body shape, height, weight, hair, clothing and pose. Match lighting and shadows naturally.",
        "A portrait photo of a person against a beautifully blurred professional background, natural matched lighting, photorealistic, 8k.",
    ),
    (
        "fashion-editorial", "Fashion Editorial", "creative",
        "Turn any photo into a high-end fashion editorial photograph.",
        "Transform the photo into a high-end fashion editorial photograph. Preserve the exact person, identity, face, age, gender, body proportions, hairstyle, facial hair and clothing details. Use sophisticated lighting, composition and editorial photography without changing the person.",
        "A high-end fashion editorial portrait photo, sophisticated dramatic lighting, magazine-quality composition, professional photography, 8k.",
    ),
    (
        "film-camera", "Film Camera", "creative",
        "Restyle any photo as an authentic analog film photograph.",
        "Restyle the photo as an authentic professional film-camera photograph. Preserve the exact person, face, age, gender, body proportions, hair, facial hair, clothing and composition. Add realistic film grain, natural colors, subtle softness and analog character.",
        "An authentic analog film photograph of a person, natural film grain, warm true-to-life color, subtle softness, professional film photography.",
    ),
    (
        "ghibli-art", "Ghibli Art", "art",
        "Turn any photo into a hand-painted Japanese animated-film illustration.",
        "Transform the photo into a beautiful hand-painted Japanese animated-film illustration. Preserve the exact person, face, age, gender, body proportions, hairstyle, facial hair, clothing and expression. Change only the visual art style.",
        "A beautiful hand-painted Japanese animated film style illustration of a person, soft painterly colors, whimsical warm atmosphere, studio animation art style.",
    ),
    (
        "anime", "Anime", "art",
        "Turn any photo into polished Japanese anime artwork.",
        "Transform the photo into polished Japanese anime artwork. Preserve the exact person's identity, face, age, gender, body proportions, hairstyle, facial hair, clothing and pose. Change only the rendering style while keeping the person recognizable.",
        "A polished Japanese anime style portrait illustration of a person, clean line art, vibrant cel shading, high quality anime artwork.",
    ),
    (
        "3d-portrait", "3D Portrait", "art",
        "Turn any photo into a detailed 3D character portrait.",
        "Transform the photo into a detailed 3D character portrait. Preserve the exact person, face, age, gender, body proportions, height, weight, hairstyle, facial hair and clothing. Use realistic 3D materials, lighting and depth without redesigning the person.",
        "A detailed 3D rendered character portrait of a person, realistic materials and lighting, studio render, octane render quality, 8k.",
    ),
    (
        "oil-painting", "Oil Painting", "art",
        "Turn any photo into a sophisticated traditional oil painting.",
        "Transform the photo into a sophisticated traditional oil painting. Preserve the exact person, face, age, gender, body proportions, hairstyle, facial hair, clothing and pose. Change only the rendering into realistic painted brushwork and canvas texture.",
        "A sophisticated traditional oil painting portrait of a person, rich painted brushwork, visible canvas texture, classical fine art style.",
    ),
    (
        "watercolor", "Watercolor", "art",
        "Turn any photo into an elegant hand-painted watercolor artwork.",
        "Transform the photo into an elegant hand-painted watercolor artwork. Preserve the exact person, face, age, gender, body proportions, hair, facial hair, clothing and pose. Use natural watercolor textures and soft painted details without changing the person.",
        "An elegant hand-painted watercolor portrait of a person, soft natural watercolor textures, delicate painted details, fine art illustration.",
    ),
    (
        "broken-photo-repair", "Broken Photo Repair", "restore",
        "Reconstruct torn, faded, or missing parts of a damaged photo.",
        "Reconstruct and complete the damaged or missing areas of this photograph naturally. Preserve the exact person's identity, face, age, gender, body proportions, hairstyle, facial hair, clothing and original composition. Repair the image without inventing changes to the person.",
        "A fully repaired and reconstructed vintage photograph, clean natural detail, no damage, professional photo restoration, 8k.",
    ),
    (
        "full-body-portrait", "Full-Body Portrait", "portrait",
        "Create a stunning full-body version of any photo.",
        "Create a stunning full-body version of the attached photograph while preserving the exact person, face, age, gender, height, weight, body proportions, hairstyle, facial hair and clothing. Keep the person's natural physique and recognizable identity unchanged.",
        "A stunning full-body portrait photo of a person standing naturally, professional studio lighting, photorealistic, professional photography, 8k.",
    ),
    (
        "pose-composition", "Pose & Composition", "editing",
        "Recompose a photo into a natural, more striking pose.",
        "Recompose the photograph into a natural, visually striking pose while preserving the exact person's identity, face, age, gender, height, weight, body proportions, hairstyle, facial hair and appearance. Keep the person physically consistent and change only the requested pose and composition.",
        "A person in a natural, visually striking pose, dynamic composition, professional portrait photography, photorealistic, 8k.",
    ),
]

PROMPT_TEMPLATE_SUFFIX = "\n\n{% if style_notes %}\nAdditional user request: {{ style_notes }}.\n{% endif %}"


async def generate_thumbnail(provider: BflProvider, prompt: str) -> bytes:
    result = await provider.generate_image(prompt, width=960, height=960, guidance=3.0, steps=30)
    return result.image_bytes


async def main() -> None:
    parser = argparse.ArgumentParser(description="Seed the 19 new catalog tools")
    parser.add_argument("--yes", action="store_true", help="Actually generate images and write rows")
    args = parser.parse_args()

    settings = get_settings()
    db = get_supabase()

    print(f"Categories to upsert: {len(CATEGORIES)}")
    for c in CATEGORIES:
        print(f"  {c['slug']:<12} {c['name']}")
    print(f"\nTools to upsert: {len(TOOLS)} (thumbnail model: {THUMBNAIL_MODEL})")
    for slug, name, category, *_ in TOOLS:
        print(f"  {slug:<22} {name:<22} [{category}]")

    if not args.yes:
        print("\nDry run only - re-run with --yes to actually generate images and write rows.")
        return

    for c in CATEGORIES:
        db.table("tool_categories").upsert(c, on_conflict="slug").execute()
    print("\nCategories upserted.")

    provider = BflProvider(settings, model_override=THUMBNAIL_MODEL)
    bucket = settings.assets_bucket

    existing = db.table("tools").select("slug,image_url").execute().data or []
    already_done = {r["slug"] for r in existing if r.get("image_url")}

    for slug, name, category, description, edit_prompt, thumb_prompt in TOOLS:
        if slug in already_done:
            print(f"\n[{slug}] already has an image — skipping (resume-safe, avoids re-spend).")
            continue

        print(f"\n[{slug}] generating thumbnail...")
        image_bytes = await generate_thumbnail(provider, thumb_prompt)

        object_name = f"assets/tools/{slug}-{uuid.uuid4().hex[:8]}.jpg"
        db.storage.from_(bucket).upload(
            object_name, image_bytes, {"content-type": "image/jpeg", "upsert": "false"}
        )
        image_url = db.storage.from_(bucket).get_public_url(object_name)
        print(f"[{slug}] uploaded -> {image_url}")

        db.table("tools").upsert(
            {
                "slug": slug,
                "name": name,
                "description": description,
                "category": category,
                "prompt_template": edit_prompt + PROMPT_TEMPLATE_SUFFIX,
                "settings": [],
                "credit_cost": 10,
                "image_url": image_url,
                "width": 1280 if slug == "full-body-portrait" else 960,
                "height": 1280 if slug == "full-body-portrait" else 960,
                "min_input_images": 1,
                "max_input_images": 1,
                "guidance": 10,
                "steps": 50,
                "seed": None,
                "safety_tolerance": 0,
                "prompt_upsampling": True,
                "output_format": "jpeg",
                "is_active": True,
            },
            on_conflict="slug",
        ).execute()
        print(f"[{slug}] tool row upserted.")

    print("\nDone.")


if __name__ == "__main__":
    asyncio.run(main())
