# Global B2B Trading
**Tagline:** Connect. Negotiate. Trade.

A free-to-start international B2B marketplace prototype. This repository is separate from the existing CV website.

## Current files
- `index.html`: homepage, buyer/seller registration and sign-in.
- `dashboard.html`: role-based buyer/seller dashboard.
- `supabase/schema.sql`: initial account profile table, row-level security and profile creation trigger.
- `supabase/dashboard.sql`: product listings and buyer quotation request (RFQ) tables with row-level security.

## Activate the dashboard database
1. Open your Supabase project: https://supabase.com/dashboard/project/koxsrvmzzpnzfgrufcto
2. Open **SQL Editor → New query**.
3. Open `supabase/dashboard.sql` in this GitHub repository, copy all of it, paste into SQL Editor and click **Run**.
4. Wait for **Success. No rows returned**. Do not run the original `schema.sql` again; the profile setup is already complete.

## Sign in and use the dashboard
1. Open the GitHub Pages website and sign in with your confirmed account.
2. Successful sign-in now opens `dashboard.html`.
3. Seller accounts can publish products, pause or reactivate their own listings, review buyer RFQs and update each inquiry status (New, Replied or Closed).
4. Buyer accounts can browse active products, search by product/category, filter by supplier country and send RFQs.

## Free hosting and security
- GitHub Pages hosts the static website for free.
- Supabase Free provides the database/authentication service, subject to its current limits.
- The browser uses only the Supabase publishable key. Never put a Supabase secret/service-role key or database password in website code.
- Row Level Security controls who can read or change records. Keep it enabled.
- Do not enter sensitive financial or identity documents. This is an early prototype.

## Not implemented yet
Real-time chat, file/image uploads, seller verification, shipping integrations, payment collection, order management, dispute handling and admin moderation are not implemented. This is not yet a production-ready marketplace.
