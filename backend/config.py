import os
from dotenv import load_dotenv

# Load .env file
load_dotenv()

class Settings:
    PROJECT_NAME: str = "Inquestor Backend API"
    VERSION: str = "1.0.0"
    API_V1_PREFIX: str = "/api/v1"
    
    # API Keys
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    TINYFISH_API_KEY: str = os.getenv("TINYFISH_API_KEY", "")
    
    # Demo & Resilience Controls
    MOCK_MODE: bool = os.getenv("MOCK_MODE", "False").lower() in ("true", "1", "t")

settings = Settings()