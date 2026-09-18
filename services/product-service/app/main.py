# Import FastAPI to create our REST API
# HTTPException allows us to return appropriate HTTP errors
# Depends allows us to inject dependencies into our endpoints
from fastapi import FastAPI, HTTPException, Depends

# Import BaseModel from Pydantic to define and validate
# the structure of data sent to our API
from pydantic import BaseModel

# UUID support for unique product identifiers
from uuid import UUID

# SQLAlchemy session type used for database operations
from sqlalchemy.orm import Session

# Import our database session factory
from app.database import SessionLocal

# Import our SQLAlchemy database models
from app import models


# Create the FastAPI application instance
app = FastAPI()

# Create a database session for each request that needs one.
# The session is always closed after the request finishes.
def get_db():
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()


# Defines the data a client must provide when creating a product
class ProductCreate(BaseModel):
    name: str
    description: str
    price: float
    inventory: int


# Defines a complete product stored by our application
# Product inherits the fields from ProductCreate and adds an ID
class Product(ProductCreate):
    id: UUID



# Health check endpoint
# Eventually the ALB will use a health endpoint to determine
# whether our ECS tasks are healthy and able to receive traffic
@app.get("/health")
def health_check():
    return {"status": "healthy"}


# Return all products currently stored in PostgreSQL
@app.get("/products")
def get_products(db: Session = Depends(get_db)):
    # Query the products table and return every product
    products = db.query(models.Product).all()

    return products


# Retrieve a single product from PostgreSQL using its unique ID
@app.get("/products/{product_id}")
def get_product(
    product_id: UUID,
    db: Session = Depends(get_db)
):
    # Search PostgreSQL for a product whose ID matches the requested UUID
    product = (
        db.query(models.Product)
        .filter(models.Product.id == str(product_id))
        .first()
    )

    # Return 404 if no matching product exists
    if product is None:
        raise HTTPException(
            status_code=404,
            detail="Product not found"
        )

    return product


# Create a new product and store it in PostgreSQL
@app.post("/products", status_code=201)
def create_product(
    product_data: ProductCreate,
    db: Session = Depends(get_db)
):
    # Convert the validated API request into a SQLAlchemy database object
    product = models.Product(
        **product_data.model_dump()
    )

    # Stage the new product for insertion
    db.add(product)

    # Commit the transaction to PostgreSQL
    db.commit()

    # Refresh our Python object with the values stored by PostgreSQL/SQLAlchemy
    db.refresh(product)

    return product