# Import FastAPI to create our REST API
# HTTPException allows us to return appropriate HTTP errors
from fastapi import FastAPI, HTTPException

# Import BaseModel from Pydantic to define and validate
# the structure of data sent to our API
from pydantic import BaseModel

# Import UUID tools so each product can receive a unique identifier
from uuid import UUID, uuid4


# Create the FastAPI application instance
app = FastAPI()


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


# Temporary in-memory storage for our products
# PostgreSQL will replace this later in the project
products = []


# Health check endpoint
# Eventually the ALB will use a health endpoint to determine
# whether our ECS tasks are healthy and able to receive traffic
@app.get("/health")
def health_check():
    return {"status": "healthy"}


# Return all products currently stored by the Product Service
@app.get("/products")
def get_products():
    return products


# Retrieve a single product using its unique ID
@app.get("/products/{product_id}")
def get_product(product_id: UUID):

    # Search through our temporary in-memory product list
    # and return the product if its ID matches the requested ID
    for product in products:
        if product.id == product_id:
            return product

    # If the loop finishes without finding the product,
    # return an HTTP 404 Not Found response
    raise HTTPException(
        status_code=404,
        detail="Product not found"
    )


# Create a new product
# The client supplies the product details, while the backend generates the ID
@app.post("/products", status_code=201)
def create_product(product_data: ProductCreate):

    # Create the complete Product object and generate a unique UUID
    product = Product(
        id=uuid4(),
        **product_data.model_dump()
    )

    # Temporarily store the product in memory
    products.append(product)

    return product