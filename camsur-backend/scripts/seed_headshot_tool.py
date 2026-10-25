"""
Seed the "Professional Headshot" tool (portrait category) — single-photo
edit, no code changes needed since prompt_template/settings are fully
DB-driven (see app/services/tool_service.py, app/utils/prompt_util.py).

Prompt validated in the BFL playground first (flux-2-pro, guidance 3.0,
steps 50, 1024x1024) before being turned into this Jinja2 template.

Usage:
  python scripts/seed_headshot_tool.py          # dry-run (default) — prints the rows
  python scripts/seed_headshot_tool.py --yes    # actually upserts them
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
load_dotenv(ROOT / ".env")

from app.db.supabase import get_supabase  # noqa: E402

CATEGORY = {
    "slug": "portrait",
    "name": "Portrait",
    "description": "Professional and portrait-style photo tools.",
    "sort_order": 10,
    "is_active": True,
}

PROMPT_TEMPLATE = """Turn this photo into a professional corporate headshot. Keep the exact facial structure, eyes, nose, mouth, jawline, skin tone, hairstyle, and expression unchanged — same person, not a new face. Replace the background with {{ settings.background_prompt }}. Put the subject in {{ settings.attire_prompt }}, naturally fitted to their pose. Add soft Rembrandt studio lighting with a gentle catchlight in the eyes. Shot on an 85mm portrait lens, f/2.8, sharp focus on the face, shallow depth of field, photorealistic, 8k.
{% if style_notes %}
Additional request from the user: {{ style_notes }}.
{% endif %}"""

TOOL = {
    "slug": "professional-headshot",
    "name": "Professional Headshot",
    "description": "Turn any photo into a polished, studio-quality professional headshot.",
    "category": CATEGORY["slug"],
    "prompt_template": PROMPT_TEMPLATE,
    "settings": [
        {
            "key": "background",
            "label": "Background",
            "type": "select",
            "default": "studio_gray",
            "options": [
                {
                    "value": "studio_gray",
                    "label": "Studio Gray",
                    "prompt": "a smoothly blurred neutral gray studio backdrop",
                },
                {
                    "value": "studio_white",
                    "label": "Studio White",
                    "prompt": "a clean bright white studio backdrop",
                },
                {
                    "value": "office",
                    "label": "Office Blur",
                    "prompt": "a softly blurred modern office background",
                },
            ],
        },
        {
            "key": "attire",
            "label": "Attire",
            "type": "select",
            "default": "charcoal_suit",
            "options": [
                {
                    "value": "charcoal_suit",
                    "label": "Charcoal Suit",
                    "prompt": "a tailored charcoal business suit with a white shirt",
                },
                {
                    "value": "navy_suit",
                    "label": "Navy Suit",
                    "prompt": "a tailored navy blue business suit with a white shirt",
                },
                {
                    "value": "business_casual",
                    "label": "Business Casual",
                    "prompt": "a smart business-casual blazer over a collared shirt",
                },
            ],
        },
    ],
    "credit_cost": 10,
    "width": 1024,
    "height": 1024,
    "min_input_images": 1,
    "max_input_images": 1,
    "is_active": True,
    "sort_order": 100,
}


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed the Professional Headshot tool")
    parser.add_argument("--yes", action="store_true", help="Actually upsert the rows")
    args = parser.parse_args()

    db = get_supabase()

    print("Category (tool_categories, upsert on slug):")
    print(json.dumps(CATEGORY, indent=2))
    print()
    print("Tool (tools, upsert on slug):")
    print(json.dumps(TOOL, indent=2))
    print()

    if not args.yes:
        print("Dry run only — re-run with --yes to actually write these rows.")
        return

    db.table("tool_categories").upsert(CATEGORY, on_conflict="slug").execute()
    db.table("tools").upsert(TOOL, on_conflict="slug").execute()
    print("Done — category + tool upserted.")


if __name__ == "__main__":
    main()
