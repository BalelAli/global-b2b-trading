# Global B2B Trading
**Tagline:** Connect. Negotiate. Trade.

A free-to-start international B2B marketplace project. This repository is separate from the existing CV website.

## Current files
- `index.html`: responsive homepage with buyer/seller sign-up and sign-in forms.
- `supabase/schema.sql`: initial profile table, row-level security and profile creation trigger.

## Important status
The website files are prepared, but real account registration is **not active** until a Supabase project is connected and configured. Do not enter real customer information until setup and testing are complete.

## Activate free account registration
1. Create a free project at https://supabase.com/.
2. In the Supabase project, open **SQL Editor**.
3. Open this repository's `supabase/schema.sql`, copy all its contents into the SQL Editor and run it.
4. In Supabase, open **Project Settings → API**. Copy the Project URL and the anon/publishable key.
5. In this repository, open `index.html` and replace:
   - `PASTE_SUPABASE_PROJECT_URL_HERE` with the Project URL.
   - `PASTE_SUPABASE_ANON_KEY_HERE` with the anon/publishable key.
6. Save/commit the change. Never put a Supabase service-role key in website code.
7. In Supabase **Authentication → URL Configuration**, add your GitHub Pages website URL to the allowed redirect/site URLs.
8. Test with an email address you can access. If email confirmation is enabled, confirm the message before signing in.

## Publish free with GitHub Pages
1. Open repository **Settings → Pages**.
2. Under **Build and deployment**, choose **Deploy from a branch**.
3. Select branch `main` and folder `/(root)`, then save.
4. Wait for GitHub Pages to finish deployment. The site URL will appear on the Pages settings screen.

## Security notes
- The browser uses only the Supabase anon/publishable key. Row Level Security is enabled for profiles.
- Never publish a service-role key or database password.
- This first version does not yet include product listings, RFQs, chat, order processing, seller verification or payment collection.

## Next development stage
After account registration is configured and tested, add buyer/seller dashboards, seller product listings and buyer RFQ workflows.
