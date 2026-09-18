# Provides access to environment variables
import os

# Loads variables from our local .env file into the environment
from dotenv import load_dotenv

# SQLAlchemy function used to create the database connection engine
from sqlalchemy import create_engine

# SQLAlchemy utility used to create database sessions
from sqlalchemy.orm import sessionmaker

# SQLAlchemy base class used to define our database models
from sqlalchemy.orm import DeclarativeBase


# Load environment variables from the .env file
load_dotenv()

# Read the database connection URL from the environment
DATABASE_URL = os.getenv("DATABASE_URL")

# Fail immediately if the database configuration is missing
if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL environment variable is not configured")

# Create SQLAlchemy's connection engine.
# The engine manages communication between our application and PostgreSQL.
engine = create_engine(DATABASE_URL)

# Create a factory for database sessions.
# Each session represents a unit of work with the database.
SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False,
    autocommit=False
)


# Base class that our SQLAlchemy database models will inherit from.
# SQLAlchemy uses these model classes to understand our database tables.
class Base(DeclarativeBase):
    pass