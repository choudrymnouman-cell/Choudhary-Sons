from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Choudhary & Sons API"
    environment: str = "development"
    database_url: str = "sqlite:///./choudhary_sons.db"
    secret_key: str = "change-me-in-production"
    access_token_expire_minutes: int = 60 * 24

    # Local upload fallback. Production can use Supabase Storage instead.
    upload_dir: str = "uploads"
    max_upload_mb: int = 10

    # Browser origins allowed to call FastAPI.
    allowed_origins: str = "http://localhost:3000,http://localhost:8080,http://localhost:5000"

    # Supabase Storage. Keep service role key only on the backend/server.
    supabase_url: str | None = None
    supabase_service_role_key: str | None = None
    supabase_storage_bucket: str = "company-documents"

    @property
    def allowed_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.allowed_origins.split(",") if origin.strip()]

    @property
    def sqlalchemy_database_url(self) -> str:
        """Normalize Supabase/Postgres URLs for SQLAlchemy + psycopg v3."""
        if self.database_url.startswith("postgresql+psycopg://"):
            return self.database_url
        if self.database_url.startswith("postgresql://"):
            return self.database_url.replace("postgresql://", "postgresql+psycopg://", 1)
        if self.database_url.startswith("postgres://"):
            return self.database_url.replace("postgres://", "postgresql+psycopg://", 1)
        return self.database_url

    @property
    def supabase_storage_enabled(self) -> bool:
        return bool(self.supabase_url and self.supabase_service_role_key)

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")


settings = Settings()
