import os

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker


# Load environment variables from a local .env file when developing locally
load_dotenv()


# Read the Order Service database connection string
DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL environment variable is not configured")


# Create the SQLAlchemy connection engine
engine = create_engine(DATABASE_URL)


# Create database sessions used by the Order Service
SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False,
    autocommit=False,
)


# Base class used by Order Service database models
class Base(DeclarativeBase):
    pass