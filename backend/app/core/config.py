from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Choudhary & Sons API"
    environment: str = "development"
    database_url: str = "sqlite:///./choudhary_sons.db"
    secret_key: str = "change-me-in-production"
    access_token_expire_minutes: int = 60 * 24
    upload_dir: str = "uploads"
    max_upload_mb: int = 10
    allowed_origins: str = "http://localhost:3000,http://localhost:8080,http://localhost:5000"

    @property
    def allowed_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.allowed_origins.split(",") if origin.strip()]

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")


settings = Settings()
