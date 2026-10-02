# Provides access to environment variables
import os

# Safely encodes usernames and passwords when building a database URL
from urllib.parse import quote_plus

# Loads variables from our local .env file into the environment
from dotenv import load_dotenv

# SQLAlchemy function used to create the database connection engine
from sqlalchemy import create_engine

# SQLAlchemy utilities for creating database sessions and model base classes
from sqlalchemy.orm import DeclarativeBase, sessionmaker

# Load environment variables from the local .env file when one is available
load_dotenv()

# First check for a complete database connection URL.
# This allows our existing local Docker environment to continue using DATABASE_URL.
DATABASE_URL = os.getenv("DATABASE_URL")

# If DATABASE_URL is not provided, build it from individual database settings.
# This supports our AWS deployment, where RDS and Secrets Manager will provide
# the database connection information separately.
if not DATABASE_URL:
    # RDS endpoint that identifies where the PostgreSQL database is running
    db_host = os.getenv("DB_HOST")

    # PostgreSQL listens on port 5432 by default
    db_port = os.getenv("DB_PORT", "5432")

    # Name of the PostgreSQL database the application should connect to
    db_name = os.getenv("DB_NAME")

    # Database credentials that will be supplied securely in AWS
    db_user = os.getenv("DB_USER")
    db_password = os.getenv("DB_PASSWORD")

    # Fail immediately if any required database configuration is missing
    if not all([db_host, db_name, db_user, db_password]):
        raise RuntimeError("Database configuration is incomplete")

    # Build the SQLAlchemy PostgreSQL connection URL from the individual values.
    # quote_plus safely encodes special characters that may appear in the credentials.
    DATABASE_URL = (
        f"postgresql+psycopg://"
        f"{quote_plus(db_user)}:{quote_plus(db_password)}"
        f"@{db_host}:{db_port}/{db_name}"
    )

# Create SQLAlchemy's connection engine.
# The engine manages communication between our application and PostgreSQL.
engine = create_engine(DATABASE_URL)

# Create a factory for database sessions.
# Each session represents a unit of work between the application and database.
SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False,
    autocommit=False,
)

# Base class that our SQLAlchemy database models will inherit from.
# SQLAlchemy uses these model classes to understand our database tables.
class Base(DeclarativeBase):
    pass