# Self-hosted web test

The self-hosted build uses the existing Flutter staff screens with the FastAPI and PostgreSQL backend. GitHub CI uploads `choudhary-self-hosted-web`, built for `/web/`. The standard cloud build continues to use Supabase.

## Deploy the test bundle

1. Extract the GitHub CI artifact into `mobile/build/web` in the server checkout. Confirm that `mobile/build/web/index.html` exists.
2. Use the existing test Compose project name, its credentials file, and its private port override. Add `-f compose.web.yml` after the existing Compose files, then run `up -d --build --no-deps backend`. Reusing the project name retains its PostgreSQL and documents volumes.
3. Verify `http://127.0.0.1:8000/health` and `http://127.0.0.1:8000/web/` on the ASUS. To open the app on Dell, forward the server port from PowerShell with `ssh -N -L 8080:127.0.0.1:8000 nouman@100.93.217.36`, keep the SSH window open, and browse to `http://127.0.0.1:8080/web/`.
4. Sign in with the test owner account and verify projects, invoices, and a private upload and download. The test build keeps the login in browser memory. Reloading the page requires signing in again.

Applicant self-service and advanced commercial workflows still need FastAPI integration. Existing cloud data needs a separate migration before production cutover.
