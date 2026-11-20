# Global B2B Trading

**Tagline:** Connect. Negotiate. Trade.

Website: https://balelali.github.io/global-b2b-trading/

Global B2B Trading is an early-stage international B2B marketplace. The public site is hosted on GitHub Pages and uses Supabase Auth, database tables and Row Level Security (RLS).

## Key files

- `index.html` — public homepage, seller membership explanation and account forms.
- `about.html` — public description of marketplace features, membership and current limitations.
- `dashboard.html` — buyer, seller and administrator dashboards.
- `assets/` — dashboard scenic background styles and script.
- `supabase/` — database setup and security migrations.

## Current implemented features

- Public homepage with buyer/seller email registration, sign-in, Google sign-in, email confirmation, password reset and resend-confirmation controls. After `complete-google-profile.sql` is applied, Google registration saves the selected buyer/seller role and business details through a restricted Supabase RPC.
- Buyer dashboard: browse active supplier products, send quotation requests (RFQs), exchange private RFQ messages with the relevant supplier, publish buyer requirements, review seller bids and use private bid conversations.
- Seller dashboard: publish and manage product listings, review product RFQs, exchange private RFQ messages with the relevant buyer, browse open buyer requirements, submit bids and privately message the buyer.
- Seller bidding and private bid messaging require an active, administrator-approved membership.
- Seller membership plans: **$10 monthly** or **$100 yearly**.
- Admin dashboard: review membership payments, manage buyer requirements, sellers, users and products, review RFQs, export RFQ reports and view private buyer/seller contact details.
- Profile photo upload for signed-in marketplace users (JPG, PNG or WebP; maximum 2 MB). Uploaded photos are stored in a private bucket and displayed to their owner with short-lived signed URLs.

## Payment status — important

The current seller dashboard offers **manual bKash and Nagad Send Money** membership payments. A seller submits a transaction reference; the administrator must verify and approve it before bidding is enabled.

**PayPal checkout/payment links are not connected in the dashboard yet.** The database's allowed payment-method values do not mean that a PayPal checkout or link is configured. Do not select or advertise PayPal as available until a real PayPal payment link or a properly configured payment integration has been added and tested. Payments are not automatically collected or reconciled by this website.

The membership prices are displayed in USD. The current instructions tell sellers to confirm the BDT amount with the administrator before sending a local payment.

## Database setup and migration order

Open the Supabase project SQL Editor and apply only the migrations that are still missing from that project. Do not assume that a file in GitHub has already been executed in Supabase.

### Base setup

1. `supabase/schema.sql` — initial profiles table and Auth profile-creation trigger. Run once on a new database.
2. `supabase/dashboard.sql` — products, RFQs, buyer requirements, bids, private bid messages and seller memberships. Run after the base schema.

### Marketplace/admin/security migrations

After the base setup, apply the following in order if they have not already been applied:

1. `supabase/enable-admin-role.sql` — allows the `admin` profile role and assigns it to the configured administrator Auth account. The administrator account must already exist and have a profile.
2. `supabase/admin-users.sql` — account status and admin user-management functions.
3. `supabase/complete-google-profile.sql` — securely saves the selected Google signup role and initial business details before the account starts marketplace activity.
4. `supabase/admin-contact-directory.sql` — admin-only buyer/seller email and phone directory.
5. `supabase/admin-membership-review.sql` — admin-only seller membership payment history.
6. `supabase/admin-products.sql` — admin product review and status control.
7. `supabase/admin-requirements.sql` — admin requirement management.
8. `supabase/admin-sellers.sql` — admin access to seller profiles.
9. `supabase/admin-rfqs.sql` — admin RFQ visibility policy.
10. `supabase/protect-buyer-privacy.sql` — removes buyer IDs from ordinary authenticated RFQ/requirement column access and provides admin-only reporting.
11. `supabase/admin_rfq_export.sql` — admin RFQ report/export function and profile-directory policy. Apply after the privacy migration so this typed RFQ report definition is the final one.
12. `supabase/enforce-account-suspension.sql` — applies active/suspended account checks and replaces legacy permissive marketplace RLS policies. It also installs buyer-ownership and bid-conversation authorization helpers so bid/bid-message policies remain compatible with the restricted `buyer_id` column grants. Run after `admin-users.sql`, `dashboard.sql`, and the admin/privacy policy migrations above. Re-run it after any later migration that recreates the affected product, RFQ or RFQ-message policies.
13. `supabase/prevent-duplicate-membership-requests.sql` — adds a database trigger to prevent duplicate pending membership requests and overlapping active memberships. Run after `dashboard.sql` and `enforce-account-suspension.sql`.
14. `supabase/profile-photos.sql` — private profile photo storage bucket, owner-only object policies and avatar RPC. If this migration was previously run while the bucket was public, re-run the updated file to make the bucket private.
15. `supabase/lock-marketplace-identities.sql` — prevents RFQ/bid ownership and original request identity fields from being rewritten.
16. `supabase/verification-badges.sql` — adds the admin-managed verification flags, audit log and limited public badge lookup RPCs. Apply it so the Admin verification panel and public badge displays work.

The migrations above are source files only until they are run in the correct Supabase project.

**Important re-run warning:** Do not re-run `schema.sql` on an existing database. Although `dashboard.sql` uses `IF NOT EXISTS` and replaces named policies, it recreates some baseline policies without the later membership/suspension restrictions. If you must re-run `dashboard.sql`, immediately re-run `enforce-account-suspension.sql` afterward. Never run `dashboard.sql` after the final security migration and then leave it unapplied.

**Important ordering rule:** `enforce-account-suspension.sql` is the final policy-hardening step for products, RFQs and RFQ messages. Do not run an older policy-creation script after it unless you then re-run this enforcement migration. GitHub commits do not execute SQL in Supabase; each required migration must still be applied in the Supabase SQL Editor, only once where indicated. Several are safe to re-run, but the initial `schema.sql` is a one-time setup. Do not run every file blindly or run a data-repair script unless the specific issue exists.

**RFQ role-check update:** On an existing Supabase project, re-run the current `supabase/enforce-account-suspension.sql` from this repository to apply the buyer-role checks for RFQ creation and private RFQ conversations. This migration is safe to re-run and does not change existing marketplace records. Do not re-run `dashboard.sql` on an existing database.

**Profile-photo privacy update:** Re-run the current `supabase/profile-photos.sql` on an existing project to change the `profile-photos` bucket from public to private. The dashboard now uses a short-lived signed URL to display the signed-in user's own uploaded photo. This migration is safe to re-run.

### Optional repair scripts

- `supabase/fix-buyer-requirement-bids-permission.sql` — older targeted repair for buyer-owned bid reads and private bid messages when the restricted `buyer_id` column caused permission errors. The current `enforce-account-suspension.sql` includes these helper policies, so re-run that current enforcement file instead of applying this repair separately.
- `supabase/fix-membership-approval.sql` — use only if the administrator membership approval function needs repair.
- `supabase/fix-rfq-reply-status.sql` — a targeted data update for RFQs whose status is still `new` despite having a seller reply. It changes existing rows; do not run unless that inconsistency is present.
- `supabase/require-active-membership-for-bid-messages.sql` — a targeted policy repair for older deployments where the bid-message read/send policies do not yet require an active seller membership. The current `supabase/enforce-account-suspension.sql` already installs the same checks, so this separate repair is not needed when the current enforcement migration has been applied successfully.
- `supabase/fix-rfq-conversation-permission.sql` — targeted repair for the RFQ private-chat `permission denied for table rfqs` error caused by the buyer-privacy column grants. It replaces the RFQ-message policies with a restricted boolean helper and does not restore table-level SELECT or expose buyer IDs.

## Privacy and security model

- Buyer identity fields are intended to remain hidden from seller-facing requirement/RFQ queries; the admin has separate privileged reporting functions.
- Requirement bids and their private messages are scoped to the requirement owner and the bidding seller. Buyer-side RFQ creation and RFQ chat require a buyer profile; seller-side RFQ chat requires the relevant seller profile and an active membership.
- RFQs are scoped to the buyer and the seller who owns the relevant product.
- Seller payment references are visible to the seller who submitted them and the administrator, not to public directories.
- Seller bidding and seller-side private bid messages are also gated by active membership in the database policies.
- The configured administrator email is checked by the admin SQL functions. Keep that identity secure.
- The browser must contain only the Supabase publishable key. Never put a Supabase secret/service-role key or database password in website code.

These rules have been reviewed in the repository source. They still require live, separate-account testing in Supabase before the site can be described as security-tested.

## Known launch limitations

- The public About page is published. Contact, Terms and Privacy pages are not yet published.
- A real public support email or other support channel still needs to be supplied before publishing the Contact page.
- PayPal is not available in the current seller payment form; there is no connected PayPal checkout.
- There is no automatic payment reconciliation, escrow, order-management or shipping integration.
- Seller/buyer identity verification and independent trust badges are not implemented.
- Product RFQs now have a private two-way message interface for the buyer and the relevant supplier. The admin RFQ report does not display private RFQ chat content.
- The marketplace has not yet passed end-to-end tests with separate buyer, seller and administrator accounts.

Do not describe the marketplace as verified, escrow-protected, payment-integrated or production-ready until the relevant features and live tests are complete.

## Free hosting and service limits

- GitHub Pages hosts the static frontend, subject to GitHub Pages limits and terms.
- Supabase Auth and database usage are subject to the active Supabase plan and its current limits.
- This is an early-stage marketplace, not a legal, payment, logistics or identity-verification service.
