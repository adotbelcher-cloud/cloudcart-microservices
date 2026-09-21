import os

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel


# Create the Order Service application
app = FastAPI()


# Read the Product Service address from the runtime environment
PRODUCT_SERVICE_URL = os.getenv("PRODUCT_SERVICE_URL")

if not PRODUCT_SERVICE_URL:
    raise RuntimeError("PRODUCT_SERVICE_URL environment variable is not configured")


# Define the data required to create an order
class OrderCreate(BaseModel):
    product_id: str
    quantity: int


# Health endpoint used to verify that the service is running
@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "order-service"}


# Create a new order
@app.post("/orders", status_code=201)
def create_order(order_data: OrderCreate):

    # Ask Product Service for information about the requested product
    try:
        response = httpx.get(
            f"{PRODUCT_SERVICE_URL}/products/{order_data.product_id}",
            timeout=5.0
        )

    # Handle cases where Product Service cannot be reached
    except httpx.RequestError:
        raise HTTPException(
            status_code=503,
            detail="Product Service unavailable"
        )

    # Product Service could not find the requested product
    if response.status_code == 404:
        raise HTTPException(
            status_code=404,
            detail="Product not found"
        )

    # Handle unexpected responses from Product Service
    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail="Product Service request failed"
        )

    product = response.json()

    # Make sure enough inventory exists for the requested quantity
    if order_data.quantity > product["inventory"]:
        raise HTTPException(
            status_code=400,
            detail="Insufficient inventory"
        )

    # Calculate the order total using the price owned by Product Service
    total = product["price"] * order_data.quantity

    # Temporary response until order persistence is added
    return {
        "product_id": order_data.product_id,
        "product_name": product["name"],
        "quantity": order_data.quantity,
        "unit_price": product["price"],
        "total": total,
        "status": "pending"
    }