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

Application components such as the Product Service and planned Order Service provide the workload for the project. The primary engineering focus is the infrastructure surrounding those services: containerization, networking, AWS deployment, security, observability, reliability, scaling, automation, and Infrastructure as Code.

The application functionality is intentionally limited so the project can remain focused on cloud engineering rather than full-stack application development.


## Current Architecture

CloudCart currently consists of a FastAPI Product Service and PostgreSQL database running as a multi-container application using Docker Compose.

```text
                         Host
                          |
                          | localhost:8000
                          v
                   Docker Compose
                          |
             +------------+------------+
             |                         |
             v                         v
     Product Service              PostgreSQL
       Container                   Container
     FastAPI :8000             PostgreSQL :5432
             |                         |
             | postgres:5432           |
             +------------------------>|
                                       |
                                       v
                              Persistent Docker Volume
```

Docker Compose provides the shared network and service discovery used for communication between the Product Service and PostgreSQL.


## Product Service

The Product Service is a lightweight Python and FastAPI API used as the first application workload in CloudCart.

It is responsible for basic product data operations and provides a service that can be containerized, networked, deployed, monitored, and scaled as the infrastructure portion of the project develops.

### Current API Endpoints

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

The Product Service runs independently in its own Docker container.


## Database

PostgreSQL 17 currently runs as a Docker container managed through Docker Compose.

The Product Service communicates with PostgreSQL using SQLAlchemy and psycopg.

Database configuration is supplied to the Product Service at runtime rather than being embedded in the container image.

Within the Docker Compose environment, the Product Service reaches PostgreSQL using Docker service discovery:

```text
postgres:5432
```

This allows the application to communicate with the database without depending on container IP addresses.


## Containerization

The Product Service is packaged as a Docker image using a service-specific Dockerfile.

The image:

- Uses a Python 3.12 slim base image
- Installs application dependencies from `requirements.txt`
- Copies the application source into the image
- Runs the FastAPI application using Uvicorn
- Listens on container port `8000`
- Receives database configuration at runtime

A `.dockerignore` file prevents unnecessary local files, development environments, and environment configuration from entering the Docker build context.

Docker Compose currently manages both the Product Service and PostgreSQL as a local multi-container environment.


## Persistent Storage

PostgreSQL data is stored using a Docker-managed persistent volume.

This separates the database data lifecycle from the PostgreSQL container lifecycle.

The persistence behavior has been tested by removing the original PostgreSQL container, creating a replacement container, reattaching the existing volume, and verifying that previously stored product data remained available.

```text
PostgreSQL Container
        |
        v
Persistent Volume
        |
        | Container removed/replaced
        |
        v
Persistent Volume remains
        |
        v
New PostgreSQL Container
        |
        v
Existing data remains available
```


## Runtime Configuration

Application configuration is externalized from the Product Service container image.

Locally, the database connection is supplied using the `DATABASE_URL` environment variable.

The Product Service expects a PostgreSQL connection in the following general form:

```text
postgresql+psycopg://<user>:<password>@<database-host>:5432/<database>
```

The container does not depend on a locally embedded `.env` file when running through Docker Compose. Docker Compose supplies the required runtime configuration to the service.

This design prepares the application for AWS, where environment-specific configuration and sensitive values can be supplied through AWS services rather than embedded in source code or container images.


## Current Progress

### Application Foundation

- Created the CloudCart repository and service structure
- Built the Product Service with Python and FastAPI
- Implemented API request validation with Pydantic
- Implemented product creation and retrieval endpoints
- Added SQLAlchemy ORM integration
- Added psycopg PostgreSQL connectivity
- Created the PostgreSQL `products` table
- Migrated product storage from application memory to PostgreSQL

### Containerization

- Installed and configured Docker Desktop with WSL2 integration
- Created a Dockerfile for the Product Service
- Built and tested the Product Service Docker image
- Added `.dockerignore` to control the Docker build context
- Verified Docker build layer caching
- Verified application configuration is supplied at runtime rather than embedded in the image

### Multi-Container Environment

- Deployed PostgreSQL 17 using Docker
- Configured persistent PostgreSQL storage
- Configured Docker Compose to manage the Product Service and PostgreSQL
- Created a shared Docker network for service communication
- Configured container-to-container communication using Docker service discovery
- Configured the Product Service to connect to `postgres:5432`
- Verified the containerized Product Service can query PostgreSQL
- Verified PostgreSQL data persists across container replacement


## Local Development

The current local environment requires:

- Docker Desktop
- Docker Compose
- WSL2/Linux environment when developing on Windows

From the repository root, the current application stack can be started with:

```bash
docker compose up
```

Once running, the Product Service is available at:

```text
http://localhost:8000
```

The FastAPI interactive API documentation is available at:

```text
http://localhost:8000/docs
```

The health endpoint can be tested with:

```bash
curl http://localhost:8000/health
```

Product data can be retrieved with:

```bash
curl http://localhost:8000/products
```


## Planned Microservices

CloudCart will expand beyond the Product Service as the infrastructure develops.

### Product Service

Responsible for:

- Product information
- Pricing
- Inventory

### Order Service

Planned responsibilities:

- Create orders
- Retrieve order information
- Communicate with the Product Service
- Persist order data
- Publish asynchronous work to Amazon SQS

### Worker Service

Planned responsibilities:

- Poll Amazon SQS
- Process asynchronous order tasks
- Update order status

These services will provide additional workloads for implementing service-to-service networking, asynchronous messaging, observability, scaling, and cloud deployment patterns.


## Planned AWS Architecture

The local Docker environment will eventually be translated into AWS infrastructure.

```text
                              Internet
                                 |
                                 v
                    Application Load Balancer
                                 |
                                 v
                       Amazon ECS / Fargate
                                 |
                    +------------+------------+
                    |                         |
                    v                         v
             Product Service            Order Service
                    |                         |
                    |                         |
                    |                         +-------> Amazon SQS
                    |                                      |
                    v                                      v
          Amazon RDS PostgreSQL                      Worker Service
```

The production-oriented AWS design will expand this architecture with VPC networking, private subnets, security groups, IAM roles, monitoring, secrets management, scaling, and automated deployment.


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
| Local port publishing | Application Load Balancer / target groups |
| PostgreSQL container | Amazon RDS PostgreSQL |
| Docker volume | RDS-managed persistent storage |
| Runtime environment variables | ECS configuration / AWS Secrets Manager |
| Container logs | Amazon CloudWatch Logs |


## Next Steps

The next phase will improve container reliability and expand CloudCart toward a multi-service architecture.

Planned work includes:

- Add PostgreSQL health checks
- Add service readiness dependencies
- Improve local configuration and secret handling
- Add the Order Service
- Implement service-to-service communication
- Add asynchronous order processing
- Introduce Amazon SQS
- Build the AWS VPC architecture
- Create Amazon ECR repositories
- Push CloudCart container images to ECR
- Deploy services to Amazon ECS using AWS Fargate
- Migrate PostgreSQL to Amazon RDS
- Configure Application Load Balancer routing
- Implement AWS security groups and IAM roles
- Add Amazon CloudWatch logging and monitoring
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
    └── product-service/
        ├── README.md
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

**Application Workload**

- Python
- FastAPI
- Pydantic
- SQLAlchemy
- psycopg
- PostgreSQL

**Containers**

- Docker
- Docker Compose

**AWS - Planned / In Progress**

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

**Infrastructure & Automation**

- Terraform
- Git
- GitHub
- GitHub Actions