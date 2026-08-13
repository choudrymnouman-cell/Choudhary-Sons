# Choudhary & Sons — Supabase-only architecture

The live application no longer requires Render or FastAPI at runtime.

## Runtime architecture

- Flutter / Flutter Web: `mobile/`
- Web hosting: GitHub Pages
- Authentication: Supabase Auth
- Database/API: Supabase PostgreSQL + PostgREST
- Row-level permissions: Supabase RLS
- Business functions: PostgreSQL RPC + Supabase Edge Functions
- Documents: private Supabase Storage bucket `company-documents`

## Live Supabase modules

The database includes profiles/roles, employees, clients, projects/contracts, attendance, vacancies/applications, leave, payroll, suppliers, materials, purchase orders, BOQ, expenses, invoices, assets, fuel, maintenance, daily site reports, safety, notices and company documents.

## Security

Every business table has Row Level Security enabled. Employee self-service records are limited to the logged-in employee where applicable. Management-only writes use role checks. New auth users cannot self-assign a management role. Employee account creation uses the authenticated `create-employee` Edge Function and is limited to owner/admin/HR callers.

The `company-documents` bucket is private. Do not put a Supabase secret/service-role key in Flutter, GitHub Pages, or source control. The Flutter app uses only the public project URL and publishable key.

## First owner

The database provides a one-time `claim_first_owner()` RPC. It succeeds only while no owner exists. After the first owner is established, subsequent calls fail. This is intended only for initial company setup.

## Deployment

`.github/workflows/deploy-web.yml` builds and deploys Flutter Web directly to GitHub Pages. No `API_BASE_URL` or Render service is required.
