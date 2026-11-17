# NFCnect

NFC membership, paid-purchase points, rewards and business-specific staff permissions for businesses in Daet.

This migration branch uses Supabase Auth for confirmed email/password accounts and Cloudflare Workers + D1 for the application and operational database. Authentication tokens are verified on the server; browser-provided identity headers and role claims are never trusted.

## Setup
Follow [the independent deployment guide](docs/INDEPENDENT-DEPLOYMENT.md) before deploying. Create your own Supabase project and Cloudflare D1 database, replace the placeholder D1 ID in wrangler.jsonc, and configure runtime variables. No production credentials or customer records are included.

```
npm ci
npm test
npx tsc --noEmit
npm run build:cloudflare
```

After configuring the correct Cloudflare account and a new empty database:
```
npm run db:migrate:remote
npm run deploy:cloudflare
```

Local development: `npm run dev`. Local D1 migrations: `npm run db:migrate:local`. All migration SQL is in drizzle/.

## Existing records
Never automatically match old memberships to a new account by email. Use the operator-reviewed identity-linking procedure in the deployment guide. The mapping retains legacy ownership identifiers and does not rewrite the ledger, balances, purchase records or staff assignments.

## Verification and launch status
See [verification](docs/VERIFICATION.md) and [configuration](docs/CONFIGURATION.md). Automated checks do not certify live Supabase email delivery, hosted account behavior, physical NFC compatibility, database restores or a production data cutover. Complete those checks before using real customer records.

The original Sites configuration, scripts and unused ChatGPT authentication helper are retained as source history. The independent build selects vite.cloudflare.config.ts and worker/cloudflare.ts and does not use the Sites authentication gateway or mock sign-in integration.
