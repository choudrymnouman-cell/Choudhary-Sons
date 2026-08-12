# Supabase setup — Choudhary & Sons

This project now supports Supabase for **PostgreSQL** and **private document storage** while keeping the existing FastAPI business logic and Flutter app.

## 1. Create a Supabase project

Create a project in Supabase and save the database password somewhere secure.

## 2. Database connection

In Supabase, open **Connect** and copy a Postgres connection string.

For a long-running backend, use the direct connection when your host supports IPv6. If your backend host is IPv4-only, use the Supavisor **session mode** connection string on port 5432.

Paste the connection string into the backend environment variable:

```env
DATABASE_URL=postgresql://...
```

The backend automatically converts standard `postgresql://` / `postgres://` URLs to SQLAlchemy's psycopg v3 driver format.

## 3. Create a private Storage bucket

Open **Storage** in Supabase and create a bucket named:

```text
company-documents
```

Keep the bucket **private**. FastAPI uploads with the service-role key and generates short-lived signed URLs for authorized management users.

## 4. Backend Supabase variables

From Supabase Project Settings/API, copy the project URL and server-side service role/secret key.

Set these only on the backend host:

```env
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
SUPABASE_STORAGE_BUCKET=company-documents
```

**Never put the service-role key in Flutter, GitHub Pages, JavaScript, or a public repository.**

Also set:

```env
ENVIRONMENT=production
SECRET_KEY=YOUR_LONG_RANDOM_APP_SECRET
ALLOWED_ORIGINS=https://choudrymnouman-cell.github.io
```

## 5. Database tables

The project already uses Alembic migrations. On backend startup run:

```bash
alembic upgrade head
```

The Dockerfile already runs migrations before Uvicorn starts.

## 6. Document behavior

The Flutter app uploads documents to:

```text
POST /api/v1/documents/supabase
```

Files are placed in folders such as:

```text
project-12/<random-id>.pdf
employee-7/<random-id>.jpg
```

The database stores a private `supabase://bucket/path` reference, not a public URL.

Authorized management users can request a one-hour signed URL with:

```text
GET /api/v1/documents/{document_id}/download-url
```

## 7. Important architecture note

Supabase replaces the project's PostgreSQL database and document file storage. The existing Python FastAPI server still needs a backend host because Supabase does not run a normal FastAPI process. The Flutter Web frontend can remain on GitHub Pages.

Recommended architecture:

```text
Flutter Web (GitHub Pages)
        |
        v
FastAPI (backend host)
        |
        +--> Supabase PostgreSQL
        +--> Supabase Storage
```
