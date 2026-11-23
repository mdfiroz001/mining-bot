# MINING BOT — Telegram Mini App starter

Mobile-first Telegram Mini App with an animated yellow/blue UI, Vercel serverless API, Supabase PostgreSQL, Telegram `initData` verification, and server-calculated mining rewards. The code is structured for real integrations; it does not ship credentials or claim that payment/ad providers are already configured.

## Included

- React/Vite Mini App with dashboard, mining, tasks, wallet, profile, referral, leaderboard/support/settings surfaces, and admin entry surface.
- Server-side Telegram Web App HMAC-SHA-256 signature and freshness validation.
- Supabase service-role access only in Vercel functions; service key is never sent to browser.
- Mining start/claim transactions in PostgreSQL with account-activation checks, configured duration/rate/daily cap, session ownership, unique claim, and idempotency ledger.
- Task listing and submission; submissions do not earn until review. Admin pending queue and review endpoint.
- Telegram webhook with secret-token validation and a Mini App button.
- PostgreSQL tables for accounts, wallet ledger, mining, tasks, quizzes, games, ads, plans, payments, withdrawals, referrals, notifications, support and audit logs.

Some product surfaces are intentionally not enabled until their corresponding production rules/providers are configured. The included admin UI is a secure starter surface, not a complete CRUD console for all 20 modules. No quiz/game/ad payout, deposits, withdrawal payments, paid plan activation, or ad view is simulated or falsely credited.

## Requirements

Node.js 20+, a Supabase project, a Telegram bot created in BotFather, and a Vercel account. The source is designed for Vercel (frontend static build + `/api` functions).

## Local development

```bash
cp .env.example .env.local
# Fill values. Never commit .env.local.
npm install
npm run dev
```

Telegram `initData` auth only works when launched from the configured Telegram Mini App. For local UI-only work, the UI can render the disconnected state, but protected API calls correctly fail without a valid Telegram launch payload.

## Supabase setup

1. Create a Supabase project and open **SQL Editor**.
2. Run `supabase/schema.sql` as the project owner.
3. In Project Settings → API copy the Project URL and **service_role** secret. Set these only as server environment variables, never as `VITE_*` values.
4. Create a Vercel environment variable `ADMIN_TELEGRAM_IDS` containing comma-separated Telegram numeric user IDs for the first admins.
5. Default account status is `pending`. An operator must review and set `profiles.account_status='active'` for eligible accounts. Configure activation workflows before public launch.

RLS is enabled and direct anon/authenticated table access revoked; application database access goes through serverless functions after Telegram initData validation. The service-role key bypasses RLS, so protect Vercel environment access and keep all function queries scoped to the authenticated profile. Never return secrets to client responses.

### Mining configuration

Edit `app_settings` values in Supabase (JSONB):

```sql
update app_settings set value='0.05'::jsonb where key='mining_rate_per_minute';
update app_settings set value='3600'::jsonb where key='mining_duration_seconds';
update app_settings set value='1'::jsonb where key='mining_daily_limit';
```

Reward = server-calculated configured rate × duration. Claims before `ends_at`, duplicates, cross-user session IDs, inactive accounts and daily-limit excess are rejected transactionally. Keep rates conservative and publish clear terms. Coin points are configurable platform points, **not guaranteed income or investment returns**.

## Vercel deployment

1. Import this source directory into Vercel or push it to your Git provider.
2. Set all variables from `.env.example` in Project → Settings → Environment Variables. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` only if you later add safe browser-side public reads; current protected operations use server APIs. Never prefix secrets with `VITE_`.
3. Deploy. Build uses `npm run build`; static output is `dist`; serverless functions are under `api/`.
4. Set `APP_URL` to the final HTTPS URL and `TELEGRAM_BOT_USERNAME` to the bot name.

## Telegram BotFather and webhook

1. Create a bot using `@BotFather` `/newbot`; save its token as `TELEGRAM_BOT_TOKEN` in Vercel only.
2. Configure the Mini App domain with BotFather `/setdomain`; set the Web App URL to the HTTPS Vercel URL.
3. Generate a random webhook secret and set `TELEGRAM_WEBHOOK_SECRET` in Vercel. Register webhook (replace placeholders locally; don't commit token):

```bash
curl -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/setWebhook" \
  -d "url=$APP_URL/api/telegram/webhook" \
  -d "secret_token=$TELEGRAM_WEBHOOK_SECRET"
```

The webhook supports `/start` and basic help/account commands. Extend message flows as required. Telegram launch authentication is verified in each user API request; never accept a client-provided numeric Telegram ID as identity.

## API routes

- `GET /api/dashboard` — Telegram-authenticated dashboard.
- `POST /api/mining/start` and `POST /api/mining/claim` — database-validated mining session flow.
- `GET /api/tasks`, `POST /api/tasks?id=<uuid>` — list and submit tasks; no credit on click.
- `GET /api/wallet` — scoped transaction ledger.
- `GET /api/admin/pending`, `POST /api/admin/review` — server role-checked review flow.
- `POST /api/telegram/webhook` — Telegram secret-token protected webhook.

## Production gaps before launch

- Implement complete admin CRUD/reporting modules and UI with granular role/permission policies.
- Add tested account activation, deposit, payment verification, withdrawal reservation/release, and paid plan flows for the actual licensed provider/payment rails. Never activate from a user-submitted transaction reference alone.
- Integrate an ad network only if it provides signed server callbacks; do not reward client button clicks.
- Complete quiz/game server-issued sessions, answer verification, secure randomness/probability policy, rate limiting and abuse/fraud monitoring.
- Add distributed rate limiting (e.g. managed Redis/Upstash), request payload limits, webhook event deduplication, idempotency and observability appropriate to launch traffic.
- Review privacy, retention, consumer-protection, financial, tax and local Bangladesh requirements with qualified professionals before real-money use.
- Add Bengali translations, localization QA, accessibility and end-to-end tests.

## Security checklist

- [ ] Keep `.env.local` out of Git and archive; rotate any accidentally exposed credentials.
- [ ] Keep bot token, webhook secret, service-role key and admin allowlist server-side in Vercel.
- [ ] Confirm `initData` HMAC and freshness checks stay enabled in all protected endpoints.
- [ ] Use HTTPS; restrict webhook to Telegram's secret token.
- [ ] Keep RLS enabled; never add broad anonymous write policies.
- [ ] Review all service-role queries for ownership scoping.
- [ ] Restrict admin IDs; audit admin decisions and payment references.
- [ ] Test concurrent duplicate claims and policy edges against a non-production Supabase project.
- [ ] Do not represent reward points as guaranteed income or investments.

## Smoke checks

```bash
npm run check
npm run build
```

Manually test in a Telegram test bot: valid/expired/tampered initData; pending account mining rejection; active account session start; early claim rejection; post-duration claim exactly once; repeat claim; other user's session ID; daily limit; task proof submit then admin approval; non-admin access to admin APIs. Use a disposable Supabase project for tests.
