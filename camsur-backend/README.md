# Camsur AI Studio — Backend

The API behind **Camsur AI Studio**, an app that turns everyday selfies into studio-quality photos (headshots, passport photos, background edits and more).

Built with **FastAPI**, **Supabase** (auth, database, storage) and **FLUX** image models from Black Forest Labs.

The mobile app lives next to it in this repo: [camsur-flutter](../camsur-flutter).

## What it does

- **Sign up and log in** with email and password, or Google / Apple.
- **AI photo tools** — each tool is a ready-made recipe (headshot, passport, edit, ...) stored in the database.
- **Credits system** — users spend credits per generation. Failed generations are refunded automatically.
- **Safe by default** — rate limits, daily and hourly generation limits, upload size checks and a kill switch.
- **Admin endpoints** — manage users, tools and credit packages, and view cost and margin reports.
- **Auto cleanup** — old uploads and results are deleted on a schedule.

## Tech stack

| Part | Tool |
|---|---|
| API | FastAPI (Python 3.12) |
| Auth, database, storage | Supabase |
| Image AI | Black Forest Labs FLUX |
| Tests | pytest |
| Deploy | Render (optional, see `render.yaml`) |

## Quick start

You need Python 3.12, a free [Supabase](https://supabase.com) project and a [Black Forest Labs](https://docs.bfl.ai) API key.

```bash
# 1. Get the code
git clone https://github.com/suraj-chavda/Camsur-AI-Studio.git
cd Camsur-AI-Studio/camsur-backend

# 2. Install
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt

# 3. Add your settings
cp .env.example .env
# Open .env and fill in SUPABASE_URL, SUPABASE_KEY, SUPABASE_DB_URL and BFL_API_KEY

# 4. Create the database tables and storage
python scripts/run_schema.py
python scripts/run_storage_policies.py
python scripts/ensure_buckets.py
python scripts/seed_tool_catalog.py

# 5. Run
uvicorn app.main:app --reload
```

The API is now running at `http://localhost:8000/api/v1`.
Open `http://localhost:8000/docs` for the interactive API docs (set `DEBUG=true` in `.env` if the page is hidden).

## Settings

All settings live in `.env`. The four you must set:

| Name | What it is |
|---|---|
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_KEY` | Your Supabase **secret / service role** key. Keep it private. |
| `SUPABASE_DB_URL` | Database connection string (only used by the setup scripts) |
| `BFL_API_KEY` | Your Black Forest Labs API key |

Everything else has a safe default. See [.env.example](.env.example) for the full list (limits, retention, pricing and more).

> **Never commit your `.env` file.** It is already in `.gitignore`.

## Make yourself an admin

Sign up in the app first, then run:

```bash
python scripts/set_admin.py --email you@example.com
```

## Run the tests

```bash
pytest
```

The tests do not need a live Supabase project or API keys.

## Project layout

```text
app/        API code (routes, services, providers, schemas)
sql/        Database schema, migrations and storage policies
scripts/    Setup and maintenance scripts
tests/      Unit tests
docs/       Notes on credits, costs and the generation lifecycle
```

More detail: [ARCHITECTURE.md](ARCHITECTURE.md) and the [docs](docs) folder.

## Deploy

A ready-to-use [render.yaml](render.yaml) is included. Add your secret values (marked `sync: false`) in the Render dashboard. Do not put real secrets in the file.

## License

[MIT](../LICENSE) © 2026 Suraj Chavda
