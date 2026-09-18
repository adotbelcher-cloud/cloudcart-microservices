# UUID support for unique product identifiers
import uuid

# SQLAlchemy column data types
from sqlalchemy import String, Float, Integer

# Modern SQLAlchemy ORM mapping tools
from sqlalchemy.orm import Mapped, mapped_column

# Import the shared Base class used by our database models
from app.database import Base


# Represents the "products" table in PostgreSQL
class Product(Base):
    # Name of the table that PostgreSQL will create
    __tablename__ = "products"

    # Unique identifier for each product
    # UUID is stored as a string for now to keep the model simple
    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4())
    )

    # Product name
    name: Mapped[str] = mapped_column(
        String(100),
        nullable=False
    )

    # Product description
    description: Mapped[str] = mapped_column(
        String(500),
        nullable=False
    )

    # Product price
    price: Mapped[float] = mapped_column(
        Float,
        nullable=False
    )

    # Number of products currently available
    inventory: Mapped[int] = mapped_column(
        Integer,
        nullable=False
    )