from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class AppSettings(BaseSettings):
    """Application configuration loaded from environment variables or .env.

    Environment variables use the ``PI7600_`` prefix, for example
    ``PI7600_DATABASE_URL`` or ``PI7600_AT_COM``.
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="PI7600_",
        extra="ignore",
    )

    database_url: str = "sqlite+aiosqlite:///./cmgl.db"
    at_com: str = "/dev/ttyUSB2"
    at_baudrate: int = 115200
    at_timeout: int = 10
    camera_index: int = -1
    camera_fps: int = 15
    face_detector_model: str = "./ml/face_detection_yunet_2023mar_int8bq.onnx"
    face_recognizer_model: str = "./ml/face_recognition_sface_2021dec.onnx"
    face_embeddings_dir: str = "./data/embeddings"
    face_match_threshold: float = 0.363
    jwt_private_key_path: str = ".keys/private.pem"
    jwt_public_key_path: str = ".keys/public.pem"
    jwt_issuer: str = "pi.daazed.dev"
    jwt_expire_minutes: int = 30
    websocket_auth_timeout: float = 5.0
    log_level: str = "INFO"


@lru_cache
def get_settings() -> AppSettings:
    """Return the process-wide application settings."""
    return AppSettings()
