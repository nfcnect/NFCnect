# NFCnect verification report

## Automated backend checks

Command: node --test tests/backend.test.mjs

20 test groups passed. These exercise the actual request handler, schema migrations and transaction triggers using SQLite, independent authenticated test identities and fresh databases. Identity is supplied by a test harness, not by a login bypass shipped to customers.

| Required behavior | Evidence |
|---|---|
| Purchase update visible to another client | Two independent clients read the same updated membership; fresh database connection retains the balance |
| A cannot read B | Requests by ID and by card URL return generic 404 for another owner |
| Business isolation | Staff assigned to another business cannot query the workspace or credit its members |
| Customer cannot act as employee | Customer purchase attempts denied; cashier admin-only operations denied |
| Duplicate credit / retry | Unique receipts and same-key replay tested; changed-body key reuse rejected |
| Simultaneous redemption | Two eligible customer requests compete for one balance; one succeeds and one fails, with one deduction |
| Refund correctness | Partial refund rounding, full reversal, original rule version, over-refund rejection, duplicate retry and negative-balance block tested |
| Revoked card | Old URL denied; replacement resolves with unchanged history/balance |
| Unknown link | Generic unavailable response, with no account fallback |
| Persistence | Balance survives closing/reopening database and an independent client |

Additional checks cover email-bound single-use claims, last administrator protection, basket minimum, out-of-stock rewards, customer-approved requests, separate fulfillment, linked redemption cancellation, immutable financial records, origin validation, server input validation and rate limiting.

## Build

The Vinext production build passed. D1 migration files are versioned with their generated Drizzle metadata. The current application does not import demo records or balances from local storage.

## Verification boundaries

SQLite tests establish application behavior and transaction integrity under the test harness. They are not a substitute for a hosted multi-user acceptance test. They do not test the actual ChatGPT login service, physical NFC hardware, mobile device compatibility, internet outages or provider backup restoration.

Current site access permits only the owner. No access has been widened and no customer/employee invitation has been sent. Live customer-versus-cashier browser tests are blocked until the owner authorizes the intended visitors and those people sign in with separate accounts. A full production recovery drill and operational validation remain outstanding. The implementation must not be described as production-ready solely because these checks passed.

## D1 runtime integration

Command: node tests/runtime.mjs

Passed against Miniflare’s D1 implementation using the real request handler and both migrations: email-bound claims; unauthorized card access; concurrent purchase retries with one credit; two competing redemptions with one deduction; repeat refund with one reversal; negative balance; revoked card. D1 metadata counts trigger effects differently from the basic SQLite adapter; the integration test caught this and claim confirmation now uses an atomic RETURNING result.

The managed browser preview renders the unauthenticated application and correctly rejects account API calls. The executor could not reach the daemon’s loopback HTTP address, so HTTP route testing from the executor was not counted as passed. No alternate browser automation or login bypass was added. Hosted authenticated multi-user UI checks remain outstanding.

## Profile anonymization checks

Three additional groups verify administrator-only, business-scoped authorization and explicit confirmation; removal of the live name, account binding, invitations, card tokens and customer requester identity; financial-note redaction; unchanged ledger rows; closed status; blocked reactivation, card reissue and reinvitation; retry behavior; continued protection against financial/audit tampering; and preservation of a different customer's data. The D1 integration test also checks atomic redaction and retained ledger equality. Migration-upgrade testing confirms existing names, ownership and ledger rows are unchanged until the administrator explicitly acts. Only fictional test accounts are used; deploying this feature does not erase any live customer.

## Points validity verification

Four additional groups test administrator-only, integer-bounded settings; future-only changes; preservation of legacy non-expiring points; earliest-expiring consumption; exact expiration settlement without repeat deductions; blocked spending of expired points; partial spending; refunded expired points without double deductions; negative debt for spent refunds; and restored credits using the current rule. D1 runtime integration also checks expired batches and refund offsets. These use fictional accounts and controlled test dates.

## Hybrid entry verification

Three additional groups cover read-only card lookup; active-card and selected-member matching; revoked or malformed cards; duplicate receipts across both methods; card-link metadata; required controlled backup reasons; customer self-credit rejection; payment confirmation; unchanged earning and expiry rules; safe same-origin URL parsing and rejection of ambiguous NFC messages. The D1 integration check also exercises NFC-source purchase entry, duplicate receipt backup rejection, revoked cards, and verified receipt fallback. Type checking passed.

No physical NFC hardware was available in the browser test environment. The Web NFC reader must be tested on the intended business phone and browser before live use. Scanner permission handling, device compatibility and counter operations are not certified by backend tests. Existing owner-only hosted access is preserved.
