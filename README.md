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

The project currently contains the first backend microservice:

### Product Service

The Product Service is built with Python and FastAPI and is responsible for managing product data.

Current API endpoints:

- `GET /health`
- `GET /products`
- `GET /products/{product_id}`
- `POST /products`

The API currently uses temporary in-memory product storage while PostgreSQL integration is being implemented.

### PostgreSQL

PostgreSQL 17 is currently running locally as a Docker container using Docker Compose.

A persistent Docker volume is used for database storage so the database lifecycle is separated from the container lifecycle.

Current local architecture:

```text
Product Service (FastAPI)
        |
        | PostgreSQL integration in progress
        |
        v
PostgreSQL 17
Docker Container
        |
        v
Persistent Docker Volume