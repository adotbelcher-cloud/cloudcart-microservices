import uuid

from sqlalchemy import Float, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


# Database model owned by the Order Service
class Order(Base):
    __tablename__ = "orders"

    # Unique identifier for each order
    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4()),
    )

    # Product being purchased
    product_id: Mapped[str] = mapped_column(
        String(36),
        nullable=False,
    )

    # Product name captured when the order was created
    product_name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    # Number of products ordered
    quantity: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    # Price of one product when the order was created
    unit_price: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    # Total order price
    total: Mapped[float] = mapped_column(
        Float,
        nullable=False,
    )

    # Current state of the order
    status: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        default="pending",
    )