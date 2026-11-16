# Self-hosted web release

The self-hosted Flutter build uses FastAPI and PostgreSQL for staff and applicant features. It serves the app and API on the same origin. GitHub CI uploads the `choudhary-self-hosted-web` artifact built for `/web/`.

## Prepare the release

1. Use a commit whose Flutter and PostgreSQL CI jobs passed. Download that run's artifact and extract it to `mobile/build/web` in the server checkout for the **same commit**. Confirm that `mobile/build/web/index.html` exists.
2. Keep the existing private Compose project name, environment file, PostgreSQL credentials, JWT secret, and persistent database and upload volumes. Confirm with `docker compose ... config --services` that the release targets the intended stack. Check that the rendered backend port is bound to loopback using your existing private port override.
3. Back up the database with `pg_dump -Fc` and the uploads volume before the rollout. For existing business records in another deployment, verify the import into a separate database before choosing that database for cutover.
4. Check that the production secret is unique and that staff and applicants will access the service through the private network. Applicant signup in the self-hosted build creates a local account and does not send verification email. Review access and email verification separately before making the applicant portal internet-facing.

## Roll out once

Use the current Compose arguments for the chosen deployment, appending `-f compose.web.yml` **after** the existing files. Build the `backend` image first. Then run `up -d --no-deps backend` once against the same project. Startup applies the migrations before serving traffic. Confirm that PostgreSQL and the uploads volume survived by checking existing records and downloading a known document.

On the ASUS, check `http://127.0.0.1:8000/health` and `http://127.0.0.1:8000/web/`. On Dell, run `ssh -N -L 8080:127.0.0.1:8000 nouman@100.93.217.36` in PowerShell, keep it running, and open `http://127.0.0.1:8080/web/`.

Verify staff sign-in, documents, delivery-to-stock balance, a partial invoice receipt, and applicant signup through HR interview scheduling with test data. The web build keeps the login token in browser memory, so reloading requires signing in again.

Keep the previous checkout and image available. If the new container fails startup, inspect its logs and switch the backend to the previous image from the same Compose project. The release adds tables without replacing existing tables. Retain the backups for recovery if database or upload contents need restoration.
