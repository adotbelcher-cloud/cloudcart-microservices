# CloudCart Microservices

CloudCart is a containerized e-commerce microservices platform being built as a hands-on cloud engineering project.

The project focuses on designing, deploying, and operating a modern containerized application using AWS, Docker, microservices, Infrastructure as Code, and CI/CD.

> **Project Status:** In Development


## Project Goals

CloudCart is being built to develop practical experience with:

- Docker and containerized applications
- Microservices architecture
- Amazon ECS and AWS Fargate
- Amazon Elastic Container Registry (ECR)
- Application Load Balancers
- Amazon RDS PostgreSQL
- Amazon SQS
- AWS VPC networking and security
- IAM and secrets management
- Amazon CloudWatch monitoring and logging
- Infrastructure as Code with Terraform
- CI/CD with GitHub Actions


## Current Architecture

The project currently contains the first backend microservice and a PostgreSQL database running locally in Docker.


### Product Service

The Product Service is built with Python and FastAPI and is responsible for managing product data.

Current API endpoints:

- `GET /health`
- `GET /products`
- `GET /products/{product_id}`
- `POST /products`

The Product Service uses SQLAlchemy as the ORM and psycopg as the PostgreSQL database driver.

Product data is now persisted in PostgreSQL rather than temporary in-memory application storage.


### PostgreSQL

PostgreSQL 17 is currently running locally as a Docker container using Docker Compose.

The Product Service connects to PostgreSQL using SQLAlchemy and a PostgreSQL connection string supplied through environment configuration.

A persistent Docker volume is used for database storage so the database lifecycle is separated from the container lifecycle.

Current local architecture:

```text
Product Service (FastAPI)
        |
        | SQLAlchemy ORM
        v
      psycopg
        |
        | localhost:5432
        v
PostgreSQL 17
Docker Container
        |
        v
Persistent Docker Volume
```


## Current Progress

Completed:

- Created the CloudCart project repository and initial service structure
- Built the Product Service with Python and FastAPI
- Implemented API request validation with Pydantic
- Implemented product creation and retrieval endpoints
- Installed and configured Docker Desktop with WSL2 integration
- Deployed PostgreSQL 17 locally using Docker Compose
- Configured persistent PostgreSQL storage using a Docker volume
- Added SQLAlchemy ORM integration
- Added psycopg PostgreSQL database connectivity
- Externalized the database connection using environment configuration
- Created the PostgreSQL `products` table using a SQLAlchemy model
- Migrated product storage from application memory to PostgreSQL
- Verified product data persists across FastAPI application restarts
- Added database-backed `POST /products`, `GET /products`, and `GET /products/{product_id}` operations


## Next Steps

The next phase will containerize the Product Service and run the application and PostgreSQL together as a multi-container environment.

Planned next steps include:

- Create a Dockerfile for the Product Service
- Build the CloudCart Product Service Docker image
- Run the Product Service as a Docker container
- Configure container-to-container networking
- Update Docker Compose to manage the Product Service and PostgreSQL together
- Add the Order Service
- Add asynchronous order processing with Amazon SQS
- Build the AWS networking architecture
- Push container images to Amazon ECR
- Deploy services to Amazon ECS using AWS Fargate
- Migrate PostgreSQL to Amazon RDS
- Add load balancing, monitoring, scaling, and IAM controls
- Implement the AWS infrastructure with Terraform
- Build CI/CD workflows with GitHub Actions


## Planned AWS Architecture

The target AWS architecture will include:

```text
Internet
   |
   v
Application Load Balancer
   |
   v
Amazon ECS / AWS Fargate
   |
   +----------------------+
   |                      |
   v                      v
Product Service       Order Service
   |                      |
   |                      +----> Amazon SQS
   |                              |
   v                              v
Amazon RDS PostgreSQL        Worker Service
```

The application services will run in private subnets, with network access controlled using VPC routing and security groups.

AWS services such as Secrets Manager or Systems Manager Parameter Store will be used for sensitive application configuration rather than storing credentials in source code.