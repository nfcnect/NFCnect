# NFCnect backend configuration and operator guide

## Deployment and identity

This is a Vinext/Cloudflare Worker application using a Sites-provisioned D1 database (`DB`). Keep `.openai/hosting.json`, the complete `drizzle/` migration history, the Sites Vite integration and the ChatGPT authentication helper in source control. Build using the Sites build helper; publish the same pushed commit and its archive. Sites applies D1 migrations before the Worker is published.

Runtime configuration:

| Name | Purpose |
|---|---|
| DB | Provisioned D1 binding, declared by `d1: "DB"` in hosting.json |
| SITE_ORIGIN | Exact HTTPS site origin, without trailing slash; used for links and write-request origin checks |
| BOOTSTRAP_ADMIN_EMAIL | Secret runtime setting identifying the site owner's verified ChatGPT email; only this account can create businesses |

Sites supplies `oai-authenticated-user-id` and `oai-authenticated-user-email` after authentication. The server uses the stable site-specific user ID as ownership key. Verified email is used only to match invitations and bootstrap the first business. Never expose this Worker through another public endpoint that bypasses Sites' authenticated identity boundary. Do not accept identity or role claims in JSON or client-controlled application cookies.

Sessions, sign-in cookies, and sign-out are owned by Sites. The application does not store passwords or implement a second OAuth provider. A normal top-level link to `/signin-with-chatgpt?return_to=...` starts sign-in. The return path remains same-origin. Responses containing account data use Cache-Control: no-store, private. Writes require JSON and the exact configured Origin. Application rate limiting allows 90 authenticated requests per minute per identity.

## Existing access restriction

The site currently admits only its owner. This restriction was preserved. Other customers and employees cannot use invitation links until the owner explicitly grants them permission to visit. Business invitations grant application roles, not site access. The supported access configuration includes custom allowlisting of visitors and, if the owner later requests it, broader site access. Do not share the owner's account or silently make the site public. If visitor invitations are used, confirm the intended recipients and grant access through Sites.

## Setup and operation

1. Sign in as the configured owner. Click Initialize your business. This atomically creates the first business and its administrator, with three proposed starter rewards. No members, balances, demo transactions or sample links are imported.
2. Administrator: Enroll member. Enter the display name and the intended customer's ChatGPT sign-in email after explaining program and privacy terms. Copy the private claim link and the card link. Tokens are randomly generated; only SHA-256 hashes are stored. Raw links are shown once.
3. Share the claim link privately with the intended customer. Do not write it on the card. It expires in seven days, is bound to the email and can be accepted only once after sign-in. The owner must separately authorize site access before other people can reach it.
4. Write only the `/?card=<opaque token>` URL to the NFC card. The same URL can be printed as a QR code. The card contains no balance, password or contact information. Card URLs are public identifiers, not login credentials.
5. Customer: accept invitation while signed in with the invited email, then open the card URL or My membership. The server checks ownership before returning account data.
6. Cashier: sign in with an invited employee account, select the assigned business, identify the member, verify completed payment and enter eligible net paid amount and receipt. Points are calculated by the server. Even purchases below the earning threshold are recorded as zero-point purchases.
7. Customer: request an available reward while signed in. This creates a request valid for 15 minutes; it does not reserve stock or deduct points. Cashier: review identity, request, basket minimum and stock, approve the request, then mark fulfillment separately.
8. Administrator: record partial or full refunds against the original purchase, including a reason. The system appends the difference between points on the previous and new remaining eligible amount, using the original earning rule. It never deletes the original purchase. A negative balance blocks further redemption.
9. Administrator: cancel a redemption only after verifying that the reward was canceled or returned. A single linked cancellation restores its points and finite stock. Cancellation never sends money.
10. Administrator: verify ownership before replacing a lost card. All previous active card tokens for that membership are revoked. Membership, balance and history remain. Unclaimed memberships can receive a replacement email-bound invitation. A claimed membership cannot be reassigned through this flow.

Employee roles can be disabled or changed by an administrator. The last active administrator cannot be disabled or demoted. The configured site owner may create additional businesses; roles, customers, receipts, rewards and reports remain business-specific. Customers may have one membership per business and multiple memberships across businesses.

## Rules and accounting

The default rule is 1 point per full 5,000 centavos (₱50) per receipt. Money is stored as integer centavos; points as integers. Future rule edits increment the rule version and do not rewrite earlier purchases. Starter rewards (20 points for ₱20 off a ₱100 basket, 35 for a pastry, 50 for coffee) and costs are assumptions requiring business approval.

The append-only ledger is authoritative; balances are computed as SUM(delta), without a separately mutable cache. Credits, redemptions, refunds and approved cancellations write their ledger and audit records in SQLite triggers within the originating transaction. Unique constraints retain receipt uniqueness even after refunds. Redemption approval rechecks available balance and stock inside its transaction. Original financial records, ledger rows and audit records cannot be updated or deleted by normal application operations.

CSV reporting exports up to 10,000 ledger entries. Larger exports require an operator database export. Interface lists show the latest 100–200 entries, while overview totals and balances use all business records. Reports are operational summaries, not formal financial statements or proof of incremental profit.

## API reference

Account and write endpoints are under /api and require a Sites-authenticated identity. GET /api/health returns only database/schema readiness, with no customer data; the site’s private visitor gate still applies. All POSTs require Content-Type: application/json and the configured Origin. Provide a unique Idempotency-Key for purchase, request, redeem and refund. Retain the same key and body when retrying an uncertain result. Reusing a key with changed input is rejected. The UI retains only retry keys in session storage, never authoritative customer records.

| Method / endpoint | Authorization / main fields |
|---|---|
| GET /me | Current identity's own roles and memberships only |
| GET /member?card=TOKEN or ?id=ID | Membership owner or active employee of that business |
| GET /workspace?business=ID | Active assigned employee; admin-only fields omitted for cashiers |
| GET /export?business=ID | Administrator; ledger rows for assigned business |
| POST /setup | Configured owner only; initialize first business |
| POST /business | Configured owner only; name; create another separate business |
| POST /enroll | Administrator; business_id, name, email |
| POST /invite | Administrator; business_id, email, role (admin/cashier) |
| POST /claim | Intended signed-in email only; token |
| POST /reinvite | Administrator; business_id, membership_id, email; unclaimed members only |
| POST /card | Administrator; business_id, membership_id, reason |
| POST /anonymize | Administrator; business_id, membership_id, confirmation:"ANONYMIZE", verified:true; irreversible profile redaction |
| POST /status | Administrator; business_id, membership_id, status (active/suspended/closed), reason |
| POST /purchase | Cashier/admin; business_id, membership_id, receipt, amount_centavos, paid:true, entry_method (nfc/card_link/receipt), card_token for card methods, backup_reason for receipt backup |
| POST /request | Membership owner; business_id, membership_id, reward_id |
| POST /redeem | Cashier/admin; business_id, request_id, basket_centavos, confirmed:true |
| POST /fulfill | Cashier/admin; business_id, redemption_id |
| POST /refund | Administrator; business_id, purchase_id, amount_centavos, reason |
| POST /cancel | Administrator; business_id, redemption_id, reason |
| POST /employee | Administrator; business_id, employee_id, role, status |
| POST /reward | Administrator; business_id, optional reward_id, name, points, discount_centavos, minimum_basket_centavos, cost_centavos, stock (-1 unlimited), active:boolean |
| POST /validity | Administrator; business_id, validity_days:null (no expiration) or integer 1–3650; future credits only |
| POST /rules | Administrator; business_id, step_centavos |

400 invalid input; 401 sign-in required; 403 unauthorized action or rejected origin; 404 generic unavailable membership/invitation; 409 duplicate/conflicting operation or failed transaction guard; 429 rate limited; 503 database unavailable. No automatic offline awards or frontend fallback to demo balances are allowed.

## Backup, recovery and reconciliation

The database is provisioned by Sites. No automated backup schedule or operator restore interface has been configured by this implementation. The ledger CSV is not a full backup: memberships, roles, cards, invitations, rewards and other records are also required. Before using real customer data, the operator must confirm the database provider's available retention/restore facilities and obtain supported operator access for complete exports and recovery.

Recommended operating procedure: take a full encrypted database export before schema changes and on a regular approved schedule; restrict access to operators; document retention; test restoration into a separate non-production database. Verify foreign keys, membership ownership, row counts, unique receipts, ledger source uniqueness, redemption deductions and refund totals before any cutover. Never test recovery against the only live copy. Proposed backup frequency and retention must be approved by the business and verified against the hosting provider's actual capabilities.

Reconciliation query: SELECT business_id,membership_id,SUM(delta) AS balance FROM ledger GROUP BY business_id,membership_id. Compare purchase entries to purchases.points, redemption entries to -redemptions.points, refund entries to the remaining-amount calculation, and cancellation entries to the original redemption points. Original purchase/refund/redemption records and the ledger should reconcile without manual balance edits. Correct errors only through reviewed linked operations; there is no arbitrary adjustment endpoint.

## Known limits and launch gate

No payment processing, POS receipt verification, independent email/SMS delivery, or offline writes are implemented. Cashiers verify receipts and share invitation links manually. Account recovery beyond unclaimed invitations and verified card replacement follows the platform account process and requires a separately reviewed operational procedure. The UI is refresh-based, not real-time push.

The source tests use fictional identities and SQLite. The request handler is also tested against Miniflare D1 emulation; the actual hosted authentication boundary is not simulated as proof of live login. Hosted multi-account browser acceptance, production receipt reconciliation, privacy/consumer terms, backup access and a restoration drill must be completed before claiming production readiness. Keep the site private until an explicit access decision is made.

## Customer profile anonymization

Administrator: Members → Anonymize personal data → verify the privacy request → type ANONYMIZE → Permanently anonymize profile. No existing customer is anonymized automatically during deployment.

One atomic database operation replaces the display name with Anonymized member, clears the customer user-ID binding, closes the membership, removes associated invitation emails and claim identities, deletes all membership card identifiers, and redacts customer requester/audit identity references plus free-text refund, cancellation, status and replacement notes. A minimal business-scoped redaction record records who performed the action and when. Repeated requests do not change the ledger again. An anonymized profile cannot be reopened, rebound or issued another card; a later customer enrollment is a separate empty membership.

Purchase amounts, points, receipt references, event IDs, dates and accounting relationships remain for reconciliation. Ledger entries are never changed. Financial immutability rules permit only tightly constrained privacy-field redaction; amounts and relationships cannot be edited. Other business memberships and employee identities are not erased by deleting a customer profile.

This is removal of direct profile identifiers from the live database, not a guarantee of complete anonymity or erasure from backups, logs, exports or previously opened screens. Retained receipt references and timestamps may still be identifying when combined with other records. Do not enter customer names/contact details into receipt references. Review retained records and provider backup retention separately for a full privacy request. The confirmation explicitly discloses these limits.

## Points validity

Administrator: open Administrator settings, reports & audit → Points validity. Choose No expiration, 180 days, 365 days, or Custom number of days (1–3,650), then Save points validity. These are exact elapsed days (24 hours each), not calendar months. Dates are stored in UTC and displayed in the viewer’s local time.

Changes apply prospectively. Each new purchase stores its validity-days rule at earning time; existing purchases keep their previous rule. All points created before this feature have no expiration. Disabling expiration affects only future credits and never restores expired points or extends an earlier batch. Administrator-approved redemption cancellations create restored credit with the rule in effect when restored; customers cannot cancel their own completed rewards to renew validity.

Points with the earliest expiration are spent first; non-expiring batches are used afterward. Account refresh, staff workspace/report access, and points activity evaluate expiration. Expiration is recorded on that activity; there is no unattended midnight scheduler. The effective cutoff is the server verification time. The customer page shows remaining batches and the next expiration.

The server reconstructs batches from the append-only ledger and snapshots. Every points-changing transaction includes a member-ledger version check and any required expiration debit in the same atomic D1 batch. Concurrent changes cause recalculation or a conflict rather than overspending. Expiration entries are immutable. Refunds of already-expired purchase points receive linked ledger offsets so they are not deducted twice; spent refunded points can still create a negative balance. No original ledger row is edited.

The database upgrade adds nullable validity snapshots and a point-check table without rewriting customer balances or backfilling expiration. The feature leaves the existing site audience and identity checks unchanged.

## Option C: Hybrid checkout

The business Overview uses NFC tap as the primary member lookup and receipt-based entry as the backup. Both require an authorized cashier, correct active membership, verified completed payment, eligible amount and a unique receipt. Tapping identifies the account; it never credits points automatically.

### Primary: NFC tap
1. On the business phone, sign in, select the business and open Overview.
2. Select NFC tap · Primary, then Start NFC reader. On a compatible NFC-enabled Android device with Chrome, allow the browser NFC permission and keep the unlocked device and page visible. Web NFC requires a secure context and compatible NDEF tags. The API being present does not guarantee NFC hardware is available.
3. Let the customer tap their membership card. The scanner reads the membership URL without navigating away. It checks the site origin and token format, then the server verifies business, active card, member and employee access. Reading stops after a valid lookup, Stop reader, a mode change, leaving the checkout, or a 45-second timeout.
4. Confirm the member and enter the paid receipt and eligible amount. Verify & credit points records one purchase.

### Supporting card URL lookup
If using an external reader that outputs a URL, or copying a membership link, open Use a copied card URL or a URL-output reader and paste the exact link. It is validated on the server too. These entries are recorded as card_link rather than proof that a physical NFC tap happened. Nothing navigates to an arbitrary URL from an NFC tag. Only one valid same-site membership URL is accepted.

### Backup: receipt entry
Select Receipt entry · Backup. Check the original paid receipt, verify the customer's membership details and select the correct active member. Select a reason: forgot_card, reader_unavailable, card_unreadable, or receipt_claim. Confirm the member and payment, then submit the receipt. Customers cannot self-credit, and receipt numbers are not used as account identifiers. A late claim still requires staff verification; the business must enforce its approved claim-period policy. No offline credits or automatic POS payment verification are enabled.

The database stores entry_method and the controlled backup_reason with each purchase and adds an audit event. It does not retain the scanned card token in the purchase. Original purchases remain receipt entries with legacy metadata; cached older clients are accepted as legacy manual entries. New explicit receipt entries require a reason. The Transactions view shows the method. Existing points, expiry, refunds and uniqueness rules apply unchanged. A copied card can identify a membership: the source label is operational metadata, not cryptographic proof of a physical tap or completed payment.

Reference for implementation and compatibility: https://developer.chrome.com/docs/capabilities/nfc
