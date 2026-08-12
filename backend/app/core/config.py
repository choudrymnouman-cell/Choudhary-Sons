from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Choudhary & Sons API"
    environment: str = "development"
    database_url: str = "sqlite:///./choudhary_sons.db"
    secret_key: str = "change-me-in-production"
    access_token_expire_minutes: int = 60 * 24
    upload_dir: str = "uploads"
    max_upload_mb: int = 10

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")


settings = Settings()
