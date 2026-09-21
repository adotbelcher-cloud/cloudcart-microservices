import os

import httpx
from fastapi import Depends, FastAPI, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app import models
from app.database import SessionLocal


# Create the Order Service application
app = FastAPI()


# Read the Product Service address from the runtime environment
PRODUCT_SERVICE_URL = os.getenv("PRODUCT_SERVICE_URL")

if not PRODUCT_SERVICE_URL:
    raise RuntimeError("PRODUCT_SERVICE_URL environment variable is not configured")


# Create a database session for each request
def get_db():
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()


# Define the data required to create an order
class OrderCreate(BaseModel):
    product_id: str
    quantity: int


# Health endpoint used to verify that the service is running
@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "order-service"}

# Retrieve all orders
@app.get("/orders")
def get_orders(db: Session = Depends(get_db)):
    orders = db.query(models.Order).all()
    return orders

# Retrieve a specific order by its ID
@app.get("/orders/{order_id}")
def get_order(order_id: str, db: Session = Depends(get_db)):
    order = (
        db.query(models.Order)
        .filter(models.Order.id == order_id)
        .first()
    )

    if order is None:
        raise HTTPException(
            status_code=404,
            detail="Order not found",
        )

    return order

# Create a new order
@app.post("/orders", status_code=201)
def create_order(
    order_data: OrderCreate,
    db: Session = Depends(get_db),
):
    # Ask Product Service for information about the requested product
    try:
        response = httpx.get(
            f"{PRODUCT_SERVICE_URL}/products/{order_data.product_id}",
            timeout=5.0,
        )

    # Handle cases where Product Service cannot be reached
    except httpx.RequestError:
        raise HTTPException(
            status_code=503,
            detail="Product Service unavailable",
        )

    # Product Service could not find the requested product
    if response.status_code == 404:
        raise HTTPException(
            status_code=404,
            detail="Product not found",
        )

    # Handle unexpected responses from Product Service
    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail="Product Service request failed",
        )

    product = response.json()

    # Make sure enough inventory exists for the requested quantity
    if order_data.quantity > product["inventory"]:
        raise HTTPException(
            status_code=400,
            detail="Insufficient inventory",
        )

    # Calculate the order total using the price owned by Product Service
    total = product["price"] * order_data.quantity

    # Create the database record owned by Order Service
    order = models.Order(
        product_id=order_data.product_id,
        product_name=product["name"],
        quantity=order_data.quantity,
        unit_price=product["price"],
        total=total,
        status="pending",
    )

    # Save the order to PostgreSQL
    db.add(order)
    db.commit()
    db.refresh(order)

    # Return the persisted order
    return order