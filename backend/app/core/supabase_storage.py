from urllib.parse import quote

import httpx

from app.core.config import settings


class SupabaseStorageError(RuntimeError):
    pass


def _headers(content_type: str | None = None) -> dict[str, str]:
    if not settings.supabase_service_role_key:
        raise SupabaseStorageError("SUPABASE_SERVICE_ROLE_KEY is not configured")
    headers = {
        "apikey": settings.supabase_service_role_key,
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
    }
    if content_type:
        headers["Content-Type"] = content_type
    return headers


def upload_bytes(path: str, contents: bytes, content_type: str) -> str:
    if not settings.supabase_url:
        raise SupabaseStorageError("SUPABASE_URL is not configured")

    bucket = settings.supabase_storage_bucket
    encoded_path = quote(path, safe="/")
    url = f"{settings.supabase_url.rstrip('/')}/storage/v1/object/{bucket}/{encoded_path}"
    headers = _headers(content_type)
    headers["x-upsert"] = "false"

    with httpx.Client(timeout=60.0) as client:
        response = client.post(url, headers=headers, content=contents)
    if response.status_code < 200 or response.status_code >= 300:
        raise SupabaseStorageError(f"Supabase upload failed ({response.status_code}): {response.text[:300]}")

    return f"supabase://{bucket}/{path}"


def create_signed_url(storage_url: str, expires_in: int = 3600) -> str:
    if not settings.supabase_url:
        raise SupabaseStorageError("SUPABASE_URL is not configured")
    if not storage_url.startswith("supabase://"):
        raise SupabaseStorageError("Document is not stored in Supabase Storage")

    remainder = storage_url.removeprefix("supabase://")
    bucket, separator, path = remainder.partition("/")
    if not separator or not bucket or not path:
        raise SupabaseStorageError("Invalid Supabase storage path")

    encoded_path = quote(path, safe="/")
    url = f"{settings.supabase_url.rstrip('/')}/storage/v1/object/sign/{bucket}/{encoded_path}"
    with httpx.Client(timeout=30.0) as client:
        response = client.post(url, headers={**_headers(), "Content-Type": "application/json"}, json={"expiresIn": expires_in})
    if response.status_code < 200 or response.status_code >= 300:
        raise SupabaseStorageError(f"Could not create signed URL ({response.status_code}): {response.text[:300]}")

    payload = response.json()
    signed = payload.get("signedURL") or payload.get("signedUrl") or payload.get("signed_url")
    if not signed:
        raise SupabaseStorageError("Supabase did not return a signed URL")
    if signed.startswith("http://") or signed.startswith("https://"):
        return signed
    return f"{settings.supabase_url.rstrip('/')}/storage/v1{signed if signed.startswith('/') else '/' + signed}"
