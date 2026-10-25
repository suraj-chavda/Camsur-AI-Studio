# Security Policy

## Reporting a vulnerability

Please **do not** open a public issue for security problems.

Report it privately using GitHub's
[private vulnerability reporting](https://github.com/suraj-chavda/Camsur-AI-Studio/security/advisories/new)
(Security tab → Report a vulnerability). Include what you found, how to reproduce it, and the impact.

You can expect a first reply within a few days.

## Keeping your own deployment safe

- Never commit `.env` files, API keys, keystores or signing files. They are in `.gitignore`.
- Keep the Supabase **service role / secret key** on the server only. Never put it in the mobile app.
- Use your own Supabase project and AI provider keys, and rotate them if they are ever exposed.
- Keep `DEBUG=false` and set explicit `CORS_ORIGINS` in production.
