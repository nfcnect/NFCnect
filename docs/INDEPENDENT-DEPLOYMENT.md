# NFCnect independent deployment

Status: migration code implemented locally. Real account setup, hosted email delivery, live multi-user checks, production import and physical NFC testing are separate acceptance gates. No existing hosted Site or customer data is changed by this branch.

## Architecture
Cloudflare Workers runs the Vinext application. Cloudflare D1 stores operational data. Supabase handles authentication only; do not paste the SQLite migrations into Supabase's Postgres SQL editor.

## Account setup
1. Create your Supabase project. Enable email/password sign-in and email confirmations. Configure custom SMTP for delivery to actual customers; default email delivery has provider restrictions and rate limits.
2. Save the project URL and publishable key from its Connect dialog or Settings → API Keys. No service_role, Supabase secret key or database password is needed by this app.
3. Create a Cloudflare D1 database named nfcnect-db. Put its actual database_id in wrangler.jsonc. Keep binding DB and migrations_dir drizzle.
4. Choose the permanent HTTPS origin (workers.dev or your own domain). Set SITE_ORIGIN exactly, without a trailing slash. Configure Supabase Authentication → URL Configuration with that Site URL.
5. In Supabase's confirmation email template, use this link:
   `<a href="{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=email">Confirm email</a>`
6. In the password recovery email template, use this link:
   `<a href="{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=recovery">Reset password</a>`
   These links open a page with a Continue button; GET requests do not consume a one-time token. After signup confirmation, sign in and reopen the original private membership invitation if needed.
7. Configure runtime variables SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY and SITE_ORIGIN. Set BOOTSTRAP_ADMIN_EMAIL to the confirmed email you will use as owner. Store it as a Cloudflare runtime secret if desired. Keep access/refresh tokens and private keys out of source and build logs.

## Build and deploy
Requires Node >=22.13.0 and npm. Dependencies are pinned by package-lock.json.
```
npm ci
npm test
npx tsc --noEmit
npm run build:cloudflare
```
Authenticate Wrangler to your own Cloudflare account. For a new empty test database:
```
npm run db:migrate:remote
npm run deploy:cloudflare
```
The deploy command reads `.wrangler/deploy/config.json` written by the build. Do not run the old Sites deployment flow. Cloudflare Git builds can use `npm run build:cloudflare` as the build command and `npm run deploy:cloudflare` as the deploy command, after the database is created and migrations are applied. Match the dashboard Worker name to wrangler.jsonc. Preserve runtime variables/secrets in Cloudflare across deployments.

Use an isolated test Worker, D1 database and Supabase project for staging. Configure their values before deployment. Never use production D1 for trial migrations or tests. Migration application against existing imported data requires a backup and review of which migrations have already been applied; do not replay the original schema over an existing database.

## Existing account and data migration
The uploaded source archive contains no live records. If starting fresh, initialize a new business after signing in as BOOTSTRAP_ADMIN_EMAIL and skip legacy links.

For existing data:
1. Obtain a supported full export and retain an encrypted backup. Inventory businesses, employees, memberships, ledger, purchase totals, invitations and active card tokens before cutover. Keep exports private; do not commit them to GitHub.
2. Restore the database to an isolated test D1. Reconcile counts, balances and financial totals before and after applying only pending migrations.
3. Have users create and confirm their own Supabase accounts. Registration does not migrate ownership.
4. Independently verify each existing person's ownership, not just a claimed email. Verify staff assignments for every affected business and the new Supabase UUID and confirmed email in the Supabase dashboard. An operator controls the account-linking process; the public app has no mapping-write endpoint.
5. Prepare a private JSON manifest. Each row needs supabase_user_id, actor_id (the original Sites ownership ID), verified_email, verification_reference, ownership_verified:true, and email_confirmed:true. The verification_reference identifies your actual review record; do not include raw identification documents.
6. Run `node scripts/prepare-identity-links.mjs reviewed-manifest.json reviewed-links.sql`. Review the SQL, then apply it through your approved D1 operator channel. Unique constraints prevent multiple subjects sharing an actor. A guard rejects nonexistent legacy actors and subjects already used for new memberships or staff accounts. Resolve such account collisions through a separately reviewed migration rather than relinking them automatically.
7. Confirm each mapped user can see only their existing records and assigned businesses. The mapping changes no legacy user_id or financial record.
8. Revoke or reissue outstanding old-domain invitation links during cutover. Generate new card URLs on the final domain and program/reprint cards/QR codes as needed. Do not assume the old ChatGPT domain redirects to the new site. Unclaimed legacy memberships can use the existing email-bound reinvitation process after an administrator verifies ownership.
9. Perform the final backed-up data transfer and reconciliation during a controlled cutover window. Avoid writes to both systems during migration. Retain the original service until rollback criteria and recovery tests have passed.

## Acceptance checks before real use
- Separate confirmed owner, cashier, customer A and customer B accounts.
- Invalid, expired, unconfirmed and forged sessions denied; signout and password recovery work.
- Customer A cannot read B by membership ID or NFC URL; staff in another business cannot access or change records.
- Paid purchase credits once, including retry; duplicate receipt rejected across NFC and manual entry.
- Redemption, refund, expiration and cancellation preserve the ledger; concurrent redemptions do not overspend.
- Replacement card revokes the old token; claimed and unclaimed membership ownership remain correct.
- Verify setup, invitation delivery, backups and a restore rehearsal in the actual hosted environment.
- Test the physical NFC reader on the intended Android phone and Chrome. No physical NFC compatibility is certified by automated tests.
