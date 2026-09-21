# CloudCart Microservices

CloudCart is a containerized e-commerce application being built as a hands-on cloud engineering project.

The application provides a realistic workload for designing, deploying, securing, and operating containerized infrastructure across local Docker environments and AWS.

The primary focus of the project is **cloud and infrastructure engineering**, including containerization, networking, compute, database infrastructure, IAM, observability, scaling, CI/CD, and Infrastructure as Code.

The application layer is intentionally kept simple and is used to provide realistic services and dependencies for the infrastructure being built around it.

> **Project Status:** In Development


## Project Goals

CloudCart is being built to develop practical experience with:

- Docker and containerized workloads
- Microservices architecture
- Container networking and service discovery
- Service-to-service communication
- Application health checks and dependency handling
- Amazon ECS and AWS Fargate
- Amazon Elastic Container Registry (ECR)
- Application Load Balancers
- Amazon RDS PostgreSQL
- Amazon SQS
- AWS VPC networking and security
- IAM and secrets management
- Amazon CloudWatch monitoring and logging
- Container health and reliability
- Auto Scaling
- Infrastructure as Code with Terraform
- CI/CD with GitHub Actions


## Project Scope

CloudCart uses a lightweight e-commerce application to simulate the type of workload a cloud engineer may be responsible for deploying and operating.

The Product Service and Order Service provide the application workload for the project. The primary engineering focus is the infrastructure surrounding these services: containerization, networking, AWS deployment, security, observability, reliability, scaling, automation, and Infrastructure as Code.

Application functionality is intentionally limited so the project can remain focused on cloud engineering rather than full-stack application development.


## Current Architecture

CloudCart currently consists of two FastAPI microservices and a PostgreSQL database running as a multi-container application using Docker Compose.

```text
                              Host
                               |
                 +-------------+-------------+
                 |                           |
          localhost:8000              localhost:8001
                 |                           |
                 v                           v
          Product Service              Order Service
          FastAPI :8000                FastAPI :8000
                 |                           |
                 |                           |
                 |<------ HTTP --------------+
                 |   product-service:8000    |
                 |                           |
                 +------------+--------------+
                              |
                              | SQL
                              v
                         PostgreSQL
                           :5432
                              |
                 +------------+------------+
                 |                         |
                 v                         v
           products table             orders table
                 |                         |
                 +------------+------------+
                              |
                              v
                    Persistent Docker Volume
```

Docker Compose provides the shared network and internal DNS used by the services.

The Order Service communicates with the Product Service using the Docker service name:

```text
http://product-service:8000
```

Both application services communicate with PostgreSQL using:

```text
postgres:5432
```

This allows services to communicate without depending on container IP addresses.


## Product Service

The Product Service is a lightweight Python and FastAPI API responsible for product information, pricing, and inventory.

### API Endpoints

- `GET /health`
- `GET /products`
- `GET /products/{product_id}`
- `POST /products`

The service uses:

- **FastAPI** for the HTTP API
- **Pydantic** for request validation
- **SQLAlchemy** for database interaction
- **psycopg** as the PostgreSQL database driver
- **PostgreSQL** for persistent product storage

Product data is stored in the PostgreSQL `products` table.

The Product Service runs independently in its own Docker container.


## Order Service

The Order Service is a separate FastAPI microservice responsible for creating, storing, and retrieving orders.

### API Endpoints

- `GET /health`
- `GET /orders`
- `GET /orders/{order_id}`
- `POST /orders`

When an order is created, the Order Service:

1. Receives the product ID and requested quantity.
2. Sends an HTTP request to the Product Service.
3. Retrieves current product information and inventory.
4. Validates that sufficient inventory exists.
5. Calculates the order total.
6. Stores the order in PostgreSQL.
7. Returns the persisted order to the client.

```text
Client
   |
   | POST /orders
   v
Order Service
   |
   | HTTP GET /products/{product_id}
   v
Product Service
   |
   | SQL
   v
PostgreSQL / products
   |
   v
Product information
   |
   v
Order Service
   |
   | Validate inventory
   | Calculate total
   |
   | SQL INSERT
   v
PostgreSQL / orders
```

The Order Service does not directly query Product Service's product data. Product information is retrieved through the Product Service API, maintaining a service boundary between product and order responsibilities.

Order records capture relevant product information such as product name and unit price at the time the order is created so historical order information is preserved if product data changes later.


## Service-to-Service Communication

CloudCart uses HTTP communication between independently running containers.

Within the Docker Compose network, the Order Service reaches the Product Service using:

```text
http://product-service:8000
```

The Product Service address is supplied to the Order Service through the `PRODUCT_SERVICE_URL` environment variable rather than being hardcoded into the application.

Docker's internal DNS resolves the `product-service` service name to the appropriate container.

This provides a local introduction to service discovery concepts that will later be translated to AWS.


## Dependency Failure Handling

The Order Service has been tested against Product Service outages.

If Product Service becomes unavailable while Order Service remains healthy, the HTTP client raises a connection exception. Order Service catches the dependency failure and returns:

```text
HTTP 503 Service Unavailable
```

with:

```json
{
  "detail": "Product Service unavailable"
}
```

Once Product Service becomes available again, Order Service can resume communicating with it without requiring an Order Service restart.

This demonstrates the distinction between:

```text
Application healthy
        vs.
Application dependency healthy
```

and introduces failure handling for distributed applications.


## Database

PostgreSQL 17 currently runs as a Docker container managed through Docker Compose.

The database currently contains two application tables:

```text
ecommerce
|
+-- products
|     |
|     +-- Product Service ownership
|
+-- orders
      |
      +-- Order Service ownership
```

Both services currently use the same PostgreSQL instance for local development, but each service interacts only with the data it owns.

The Product Service owns product data.

The Order Service owns order data and retrieves product information through the Product Service API rather than querying the `products` table directly.

Both services communicate with PostgreSQL using SQLAlchemy and psycopg.


## Persistent Storage

PostgreSQL data is stored using a Docker-managed persistent volume.

This separates the database data lifecycle from the PostgreSQL container lifecycle.

```text
Application Containers
        |
        | can be rebuilt/replaced
        v
PostgreSQL Container
        |
        v
Persistent Docker Volume
        |
        | container removed/replaced
        v
Persistent Docker Volume remains
        |
        v
New PostgreSQL Container
        |
        v
Existing data remains available
```

Persistence has been tested by replacing the PostgreSQL container and verifying that previously stored data remained available.

Order persistence has also been verified by creating an order through the Order Service API and querying the stored record directly from PostgreSQL.


## Containerization

The Product Service and Order Service are independently packaged as Docker images using service-specific Dockerfiles.

Each application image:

- Uses a Python 3.12 slim base image
- Installs dependencies from `requirements.txt`
- Copies application source code into the image
- Runs the FastAPI application using Uvicorn
- Listens on container port `8000`
- Receives environment-specific configuration at runtime

Each service also uses a `.dockerignore` file to prevent unnecessary local files, virtual environments, source-control metadata, and local environment configuration from entering the Docker build context.

Docker Compose manages the complete local multi-container environment.


## Container Health and Readiness

Health checks are configured for the application services and PostgreSQL.

Product Service and Order Service health checks call their respective:

```text
GET /health
```

endpoints.

PostgreSQL readiness is checked using:

```text
pg_isready
```

The Product Service is configured to wait for PostgreSQL to become healthy before starting.

Health-check behavior has also been tested by deliberately configuring an invalid health endpoint, observing the container become unhealthy, restoring the correct endpoint, and verifying recovery.

These checks introduce concepts that will later map to ECS and Application Load Balancer health monitoring.


## Runtime Configuration

Application configuration is externalized from the container images.

The Product Service receives:

```text
DATABASE_URL
```

The Order Service receives:

```text
DATABASE_URL
PRODUCT_SERVICE_URL
```

Within Docker Compose, database connections use the general format:

```text
postgresql+psycopg://<user>:<password>@postgres:5432/<database>
```

The Order Service reaches Product Service through:

```text
http://product-service:8000
```

This allows the same application images to receive environment-specific configuration without rebuilding the images.

The current local environment uses development database credentials. The AWS deployment will move sensitive configuration to appropriate AWS configuration and secrets-management services.


## Current Progress

### Application Foundation

- Created the CloudCart repository and microservice structure
- Built the Product Service with Python and FastAPI
- Implemented product creation and retrieval endpoints
- Added Pydantic request validation
- Added SQLAlchemy ORM integration
- Added psycopg PostgreSQL connectivity
- Migrated product storage from application memory to PostgreSQL
- Built the Order Service with Python and FastAPI
- Implemented order creation and retrieval endpoints
- Implemented persistent order storage
- Added product inventory validation during order creation

### Containerization

- Installed and configured Docker Desktop with WSL2 integration
- Created independent Dockerfiles for Product Service and Order Service
- Built and tested both application images
- Added `.dockerignore` files to control Docker build contexts
- Verified Docker build layer caching
- Externalized runtime configuration from container images

### Multi-Container Environment

- Deployed PostgreSQL 17 using Docker
- Configured persistent PostgreSQL storage
- Configured Docker Compose to manage Product Service, Order Service, and PostgreSQL
- Created a shared Docker network
- Configured Docker DNS-based service discovery
- Configured Product Service to connect to `postgres:5432`
- Configured Order Service to connect to `postgres:5432`
- Configured Order Service to communicate with `product-service:8000`
- Verified Product Service-to-PostgreSQL connectivity
- Verified Order Service-to-Product Service communication
- Verified Order Service-to-PostgreSQL persistence
- Verified PostgreSQL data survives container replacement

### Reliability and Failure Testing

- Added application container health checks
- Added PostgreSQL readiness checks
- Tested healthy and unhealthy container states
- Tested Product Service dependency failure
- Added HTTP timeout handling for service-to-service requests
- Added controlled `503 Service Unavailable` responses when Product Service cannot be reached
- Verified Order Service automatically resumes communication after Product Service recovery


## Local Development

The local environment requires:

- Docker Desktop
- Docker Compose
- WSL2/Linux environment when developing on Windows

From the repository root, start the application stack with:

```bash
docker compose up -d
```

Check container health:

```bash
docker compose ps
```

The Product Service is available at:

```text
http://localhost:8000
```

Product Service API documentation:

```text
http://localhost:8000/docs
```

The Order Service is available at:

```text
http://localhost:8001
```

Order Service API documentation:

```text
http://localhost:8001/docs
```

Product Service health:

```bash
curl http://localhost:8000/health
```

Order Service health:

```bash
curl http://localhost:8001/health
```

Retrieve products:

```bash
curl http://localhost:8000/products
```

Retrieve orders:

```bash
curl http://localhost:8001/orders
```


## Service Responsibilities

### Product Service

Responsible for:

- Product information
- Pricing
- Inventory
- Persistent product storage

### Order Service

Responsible for:

- Creating orders
- Retrieving orders
- Communicating with Product Service
- Validating available inventory
- Calculating order totals
- Persisting order data
- Handling Product Service availability failures

### Worker Service — Planned

The next application component will support asynchronous order processing.

Planned responsibilities:

- Poll Amazon SQS
- Process asynchronous order tasks
- Update order status

The Worker Service and SQS will provide a workload for implementing asynchronous messaging, IAM permissions, observability, scaling, and failure handling.


## Planned AWS Architecture

The local Docker environment will be translated into AWS infrastructure.

```text
                              Internet
                                 |
                                 v
                      Application Load Balancer
                                 |
                                 v
                         ECS / Fargate
                       Private App Subnets
                                 |
                    +------------+------------+
                    |                         |
                    v                         v
             Product Service            Order Service
                    |                         |
                    |                         +-------> Amazon SQS
                    |                                      |
                    |                                      v
                    |                                Worker Service
                    |                                      |
                    +------------------+-------------------+
                                       |
                                       v
                            Amazon RDS PostgreSQL
                           Private Database Subnets
```

The AWS environment will introduce VPC networking, private subnets, security groups, IAM roles, ECR, RDS, SQS, CloudWatch, secrets management, scaling, and automated deployment.


## Planned AWS Networking

The target network architecture will separate public-facing infrastructure from application and database workloads.

```text
Internet
   |
   | HTTPS
   v
Application Load Balancer
Public Subnets
   |
   | Application traffic
   v
ECS / Fargate Services
Private Application Subnets
   |
   | PostgreSQL :5432
   v
Amazon RDS PostgreSQL
Private Database Subnets
```

Planned security controls include:

- Public access through the Application Load Balancer
- ECS tasks running without public IP addresses
- Security group references between infrastructure tiers
- Database access restricted to authorized application services
- Private database placement
- IAM roles following least-privilege principles
- Externalized secrets and application configuration


## Local-to-AWS Mapping

The local environment is intentionally designed to introduce concepts that will later map to AWS services.

| Local Environment | AWS Target |
|---|---|
| Docker image | Amazon ECR image |
| Docker container | ECS task |
| Docker Compose service | ECS service |
| Docker networking | VPC networking |
| Docker service discovery | AWS service discovery |
| Local port publishing | Application Load Balancer / target groups |
| PostgreSQL container | Amazon RDS PostgreSQL |
| Docker volume | RDS-managed persistent storage |
| Runtime environment variables | ECS configuration / AWS Secrets Manager |
| Container health checks | ECS / ALB health checks |
| Container logs | Amazon CloudWatch Logs |


## Next Steps

The local containerized microservices foundation is now functional. The next phase will begin translating CloudCart into AWS infrastructure.

Planned work includes:

- Design the AWS VPC architecture
- Create public, private application, and private database subnets
- Configure route tables, Internet Gateway, and NAT connectivity
- Implement security groups between the ALB, ECS services, and RDS
- Create Amazon ECR repositories
- Push CloudCart container images to ECR
- Deploy Product Service and Order Service to Amazon ECS using AWS Fargate
- Configure Application Load Balancer routing
- Migrate PostgreSQL to Amazon RDS
- Implement AWS service discovery between application services
- Externalize sensitive configuration using AWS secrets management
- Add Amazon CloudWatch logging and monitoring
- Introduce Amazon SQS
- Build the Worker Service for asynchronous processing
- Configure ECS Auto Scaling
- Implement AWS infrastructure with Terraform
- Build CI/CD workflows with GitHub Actions
- Perform infrastructure and container security hardening


## Repository Structure

```text
cloudcart-microservices/
|
├── README.md
├── compose.yaml
|
└── services/
    |
    ├── product-service/
    |   ├── Dockerfile
    |   ├── .dockerignore
    |   ├── requirements.txt
    |   |
    |   └── app/
    |       ├── __init__.py
    |       ├── main.py
    |       ├── database.py
    |       └── models.py
    |
    └── order-service/
        ├── Dockerfile
        ├── .dockerignore
        ├── requirements.txt
        |
        └── app/
            ├── __init__.py
            ├── main.py
            ├── database.py
            └── models.py
```


## Technologies

### Application Workload

- Python
- FastAPI
- Pydantic
- SQLAlchemy
- psycopg
- HTTPX
- PostgreSQL

### Containers

- Docker
- Docker Compose

### AWS — Planned / In Progress

- Amazon ECR
- Amazon ECS
- AWS Fargate
- Application Load Balancer
- Amazon RDS
- Amazon SQS
- Amazon CloudWatch
- AWS Secrets Manager
- AWS IAM
- Amazon VPC

### Infrastructure & Automation

- Terraform
- Git
- GitHub
- GitHub Actions