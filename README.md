# CloudCart Microservices

CloudCart is a containerized e-commerce application being built as a hands-on cloud engineering project.

The application provides a realistic workload for designing, deploying, securing, and operating containerized infrastructure across local Docker environments and AWS.

The primary focus of the project is **cloud and infrastructure engineering**, including containerization, networking, compute, database infrastructure, IAM, observability, scaling, CI/CD, and Infrastructure as Code.

The application layer is intentionally kept simple and is used to provide realistic services and dependencies for the infrastructure being built around it.

> **Project Status:** In Development — AWS Infrastructure Definition & Pre-Deployment Validation


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


## Current Local Architecture

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

This allows the Order Service to locate Product Service without depending on a specific container IP address.


## Product Service

The Product Service owns product-related functionality and data.

Current responsibilities include:

- Creating products
- Retrieving products
- Tracking product inventory
- Storing product data in PostgreSQL
- Providing product information to other services
- Exposing an application health endpoint

Current endpoints include:

```text
GET  /health
GET  /products
GET  /products/{product_id}
POST /products
```

Product data includes:

```text
id
name
description
price
inventory
```

The Product Service owns the `products` table.


## Order Service

The Order Service handles order creation and retrieval.

Current responsibilities include:

- Accepting order requests
- Calling Product Service over HTTP
- Validating that a requested product exists
- Checking available inventory
- Retrieving the current product price
- Calculating the order total
- Persisting order data in PostgreSQL
- Returning controlled errors when Product Service is unavailable
- Exposing an application health endpoint

Current endpoints include:

```text
GET  /health
GET  /orders
GET  /orders/{order_id}
POST /orders
```

Order data includes:

```text
id
product_id
product_name
quantity
unit_price
total
status
```

New orders currently begin with:

```text
status = pending
```

The Order Service owns the `orders` table.


## Service Ownership

Although both services currently use the same PostgreSQL instance during development, logical ownership is maintained between the services.

```text
Product Service
      |
      +---- owns ----> products table


Order Service
      |
      +---- owns ----> orders table
```

Order Service does not directly query the `products` table.

Instead, it communicates with Product Service through the Product API:

```text
Order Service
      |
      | HTTP request
      v
Product Service
      |
      v
products table
```

This preserves the service boundary and allows the Product Service implementation to evolve independently.


## Local Service Discovery

Docker Compose provides internal DNS for the local container network.

Order Service uses:

```text
http://product-service:8000
```

instead of a hardcoded container IP address.

Conceptually:

```text
Order Service
      |
      | product-service:8000
      v
Docker DNS
      |
      v
Product Service container
```

Docker can replace a container and assign it a different internal IP without requiring changes to the Order Service configuration.


## Runtime Configuration

Application configuration is externalized using environment variables rather than being hardcoded into the container image.

### Local Database Configuration

Local development can provide a complete SQLAlchemy database URL:

```text
DATABASE_URL
```

Example structure:

```text
postgresql+psycopg://username:password@host:5432/database
```

The local Docker environment uses the PostgreSQL service name when containers communicate internally.

### AWS Database Configuration

The same application code also supports database settings supplied individually:

```text
DB_HOST
DB_PORT
DB_NAME
DB_USER
DB_PASSWORD
```

This allows AWS ECS to provide the RDS endpoint and database settings at runtime while sensitive credentials are retrieved securely from AWS Secrets Manager.

The application constructs the SQLAlchemy database URL from these values.

This design allows the same container image to run in multiple environments:

```text
                    Application Image
                           |
              +------------+------------+
              |                         |
              v                         v
        Local Docker                  AWS ECS
              |                         |
        DATABASE_URL             DB_HOST / DB_PORT
                                 DB_NAME / DB_USER
                                 DB_PASSWORD
              |                         |
              +------------+------------+
                           |
                           v
                       SQLAlchemy
                           |
                           v
                       PostgreSQL
```


## Health Checks

CloudCart uses health endpoints and container health checks to distinguish a running process from a healthy application.

Product Service:

```text
GET /health
```

Example response:

```json
{
  "status": "healthy"
}
```

Order Service:

```text
GET /health
```

Example response:

```json
{
  "status": "healthy",
  "service": "order-service"
}
```

Docker Compose also monitors container health.

A healthy local environment currently includes:

```text
Product Service     healthy
Order Service       healthy
PostgreSQL          healthy
```

This distinction becomes important in AWS because ECS and the Application Load Balancer use health information to determine whether application tasks should receive traffic.


## Dependency Failure Handling

Order Service depends on Product Service when creating orders.

If Product Service becomes unavailable, Order Service handles the dependency failure and returns a controlled service error rather than crashing.

Conceptually:

```text
Client
  |
  v
Order Service
  |
  | request product
  v
Product Service
  X
 unavailable
  |
  v
Order Service remains running
  |
  v
Controlled 503 response
```

This demonstrates an important distributed-systems concept:

> A service can remain healthy while one of its downstream dependencies is unavailable.


## Docker Environment

CloudCart currently runs three containers locally:

```text
cloudcart-product-service
cloudcart-order-service
ecommerce-postgres
```

Host port mappings are:

```text
localhost:8000 -> Product Service :8000
localhost:8001 -> Order Service   :8000
localhost:5432 -> PostgreSQL      :5432
```

Inside the Docker network, services communicate using container service names rather than host ports.


## Persistent Storage

PostgreSQL uses a Docker volume for persistent local data.

This means application containers can be rebuilt or replaced without deleting the existing database.

Conceptually:

```text
Application Containers
        |
        v
PostgreSQL Container
        |
        v
Persistent Docker Volume
        |
        +---- products
        |
        +---- orders
```

This is useful locally, but it also creates an important deployment consideration: a new Amazon RDS database will not contain the tables stored in the local Docker volume.

Database schema initialization is therefore part of the AWS pre-deployment work.


# AWS Architecture

CloudCart is currently being translated from the local Docker environment into AWS infrastructure managed with Terraform.

The AWS environment has been **defined but has intentionally not yet been fully provisioned**.

This allows the architecture, dependencies, runtime configuration, and expected cost to be reviewed before creating billable cloud resources.


## Target AWS Architecture

The current AWS design is:

```text
                              Internet
                                 |
                                 | HTTP
                                 v
                    Application Load Balancer
                         Public Subnets
                                 |
                                 |
                                 v
                         ECS / Fargate
                    Private App Subnets
                                 |
                    +------------+------------+
                    |                         |
                    v                         v
             Product Service            Order Service
                    ^                         |
                    |                         |
                    +---- Service Connect ----+
                    |
                    |
                    +------------+------------+
                                 |
                                 | PostgreSQL :5432
                                 v
                       Amazon RDS PostgreSQL
                       Private DB Subnets
```

Supporting AWS services include:

```text
Amazon ECR
    |
    +---- container images ----> ECS / Fargate


AWS Secrets Manager
    |
    +---- database credentials -> ECS task startup


AWS IAM
    |
    +---- execution permissions


Amazon CloudWatch
    |
    +---- container logs


ECS Service Connect
    |
    +---- internal service discovery
```


## AWS Networking

CloudCart uses a dedicated VPC:

```text
10.0.0.0/16
```

The VPC is divided into three infrastructure tiers across two Availability Zones.

### Public Subnets

```text
Public Subnet A
10.0.1.0/24
us-east-1a

Public Subnet B
10.0.2.0/24
us-east-1b
```

The public subnets are intended for internet-facing infrastructure such as the Application Load Balancer and NAT Gateway.

A subnet is considered public because its route table provides a route to an Internet Gateway. Resources do not automatically need public IP addresses simply because they are placed in a public subnet.

### Private Application Subnets

```text
Private App Subnet A
10.0.11.0/24
us-east-1a

Private App Subnet B
10.0.12.0/24
us-east-1b
```

ECS/Fargate application tasks run in these subnets.

The tasks do not receive public IP addresses.

### Private Database Subnets

```text
Private DB Subnet A
10.0.21.0/24
us-east-1a

Private DB Subnet B
10.0.22.0/24
us-east-1b
```

Amazon RDS is restricted to the private database tier.

The database subnets do not have a general default route to the Internet Gateway or NAT Gateway.


## Internet Gateway

An Internet Gateway provides internet connectivity for resources using the public route table.

The public route table contains:

```text
0.0.0.0/0 -> Internet Gateway
```

The Application Load Balancer uses the public subnets so it can serve as CloudCart's public application entry point.


## NAT Gateway

CloudCart currently defines one NAT Gateway in Public Subnet A.

Private ECS application workloads use the NAT Gateway for outbound connectivity:

```text
Private ECS Task
      |
      v
Private App Route Table
      |
      v
NAT Gateway
      |
      v
Internet Gateway
      |
      v
External Destination
```

The NAT Gateway does not make ECS tasks directly reachable from the internet.

Using one NAT Gateway is a development and cost-conscious design decision. A more highly available production architecture could use a NAT Gateway per Availability Zone.


## Security Groups

CloudCart separates network permissions between the load balancer, application, and database tiers.

### ALB Security Group

The Application Load Balancer accepts HTTP traffic from the internet:

```text
Internet
   |
   | TCP :80
   v
ALB Security Group
```

### ECS Security Group

Application traffic from the ALB is allowed to reach ECS tasks on port `8000`:

```text
ALB Security Group
        |
        | TCP :8000
        v
ECS Security Group
```

CloudCart ECS tasks can also communicate with other tasks using the same ECS security group on port `8000`.

This supports internal service-to-service communication:

```text
Order Service
ECS Security Group
        |
        | TCP :8000
        v
Product Service
ECS Security Group
```

### RDS Security Group

PostgreSQL access is restricted to application workloads using the ECS security group:

```text
ECS Security Group
        |
        | TCP :5432
        v
RDS Security Group
```

This produces the primary security path:

```text
Internet
   |
   | :80
   v
ALB SG
   |
   | :8000
   v
ECS SG
   |
   | :5432
   v
RDS SG
```

Security group references are used instead of broadly allowing the entire VPC CIDR where possible.


## Amazon ECR

CloudCart defines separate Amazon Elastic Container Registry repositories for:

```text
cloudcart-product-service
cloudcart-order-service
```

The intended container deployment flow is:

```text
Application Source
       |
       v
docker build
       |
       v
Container Image
       |
       v
Amazon ECR
       |
       v
ECS / Fargate
```

ECR image scanning on push is enabled.

The current task definitions reference the `latest` image tag during the initial development phase.

Versioned or immutable image-tagging strategies can be introduced later as part of CI/CD improvements.


## Amazon ECS

CloudCart uses Amazon ECS with AWS Fargate.

The ECS architecture consists of:

```text
CloudCart ECS Cluster
        |
        +---- Product ECS Service
        |          |
        |          v
        |     Product Task Definition
        |
        +---- Order ECS Service
                   |
                   v
              Order Task Definition
```

### Task Definitions

Task definitions describe how containers should run.

They currently define:

- Container image
- CPU allocation
- Memory allocation
- Fargate compatibility
- `awsvpc` networking
- Application port
- Runtime environment variables
- Secrets
- CloudWatch logging
- ECS execution role

Current development task sizing is:

```text
CPU:    256 CPU units / 0.25 vCPU
Memory: 512 MiB
```

### ECS Services

ECS services maintain the desired number of running tasks.

The current development configuration uses:

```text
desired_count = 1
```

ECS services place application tasks inside the private application subnets and do not assign public IP addresses.

Conceptually:

```text
Task Definition
      |
      | describes
      v
ECS Task
      ^
      |
      | maintained by
      |
ECS Service
```

AWS Fargate provides the underlying compute without requiring CloudCart to manage EC2 instances.


## ECS Service Connect

CloudCart uses ECS Service Connect for internal service discovery.

ECS tasks can receive different private IP addresses as they are replaced or rescheduled.

Order Service therefore should not depend on a hardcoded Product Service IP.

Product Service is registered with the stable Service Connect alias:

```text
product-service:8000
```

Order Service receives:

```text
PRODUCT_SERVICE_URL=http://product-service:8000
```

Conceptually:

```text
Order Service
      |
      | http://product-service:8000
      v
ECS Service Connect
      |
      | locates current Product workload
      v
Product Service
```

This mirrors the local Docker Compose design:

```text
LOCAL                         AWS

Docker Compose                ECS / Fargate
      |                            |
Docker DNS                    Service Connect
      |                            |
      v                            v
product-service:8000          product-service:8000
```

Service discovery and network authorization remain separate concerns.

Service Connect determines **where the service is**, while security groups determine **whether the network traffic is permitted**.


## Application Load Balancer

CloudCart defines an internet-facing Application Load Balancer across the two public subnets.

The load balancer provides the controlled public entry point to private ECS workloads.

```text
Internet
   |
   v
Application Load Balancer
   |
   v
Target Group
   |
   v
Private ECS Task
```

The Product Service target group uses:

```text
Protocol: HTTP
Port:     8000
Target:   IP
```

Fargate tasks use `awsvpc` networking, so the ALB registers task IP addresses with the target group.

### Health Checks

The Product Service target group checks:

```text
GET /health
```

Only healthy targets should receive application traffic.

The ALB currently requires additional routing work before deployment so Product and Order requests can be routed independently.

The intended design is:

```text
ALB
 |
 +---- /products* ----> Product Target Group
 |
 +---- /orders* ------> Order Target Group
```


## Amazon RDS PostgreSQL

CloudCart defines an Amazon RDS PostgreSQL database.

Current development configuration includes:

```text
Engine:              PostgreSQL 17
Instance class:      db.t4g.micro
Initial storage:     20 GiB
Maximum storage:     50 GiB
Storage type:        gp3
Database name:       cloudcart
Public access:       disabled
Multi-AZ:            disabled
Backup retention:    1 day
```

RDS is placed inside a DB subnet group containing both private database subnets.

```text
RDS DB Subnet Group
        |
        +---- Private DB Subnet A
        |
        +---- Private DB Subnet B
```

The subnet group determines where RDS may be placed.

`multi_az = false` is currently used to reduce development cost. The presence of multiple database subnets does not itself mean the database is running as a Multi-AZ deployment.


## AWS Secrets Manager

CloudCart does not store the RDS master password directly in Terraform configuration.

RDS is configured to manage the master password through AWS Secrets Manager.

Sensitive database configuration is injected into ECS containers as:

```text
DB_USER
DB_PASSWORD
```

The ECS task definition references the RDS-managed secret rather than embedding credentials directly in the task definition.


## IAM

CloudCart currently defines an ECS task execution role.

The execution role allows ECS/Fargate to perform actions required to start and operate the container.

Conceptually:

```text
                 ECS Execution Role
                        |
          +-------------+-------------+
          |             |             |
          v             v             v
         ECR      Secrets Manager  CloudWatch
    pull images    retrieve secret  send logs
```

The execution role uses the standard Amazon ECS task execution policy along with additional permission to retrieve the CloudCart RDS-managed secret.

An important distinction is maintained between:

```text
Execution Role
      =
AWS permissions required to launch and operate the task


Task Role
      =
AWS permissions used by application code inside the container
```

A task role will become particularly relevant when application components such as the future Worker Service interact directly with AWS services such as Amazon SQS.


## Amazon CloudWatch

CloudCart defines separate CloudWatch log groups for:

```text
/ecs/cloudcart-product-service
/ecs/cloudcart-order-service
```

Current log retention is:

```text
7 days
```

The ECS task definitions use the `awslogs` logging driver.

Conceptually:

```text
Product Container ----+
                      |
                      +----> CloudWatch Logs
                      |
Order Container ------+
```

CloudWatch will become one of the primary troubleshooting tools once the application is deployed to AWS.


# Local-to-AWS Mapping

The local CloudCart environment intentionally introduces concepts that map directly to AWS services.

| Local Environment | AWS Environment |
|---|---|
| Docker image | Amazon ECR image |
| Docker container | ECS task |
| Docker Compose service | ECS service |
| Docker Compose | ECS orchestration |
| Docker networking | VPC networking |
| Docker internal DNS | ECS Service Connect |
| Local port publishing | Application Load Balancer |
| PostgreSQL container | Amazon RDS PostgreSQL |
| Docker volume | RDS-managed persistent storage |
| `.env` / environment variables | ECS runtime configuration |
| Local credentials | AWS Secrets Manager |
| Container health checks | ECS / ALB health checks |
| `docker compose logs` | Amazon CloudWatch Logs |
| Local container compute | AWS Fargate |


# Terraform Infrastructure

AWS infrastructure is managed with Terraform.

The current Terraform configuration includes:

- AWS provider configuration
- Availability Zone discovery
- Dedicated VPC
- Public subnets across two Availability Zones
- Private application subnets across two Availability Zones
- Private database subnets across two Availability Zones
- Internet Gateway
- Elastic IP
- NAT Gateway
- Public route table
- Private application route table
- Route table associations
- ALB security group
- ECS security group
- RDS security group
- ECS-to-ECS security group access
- Amazon ECR repositories
- ECS cluster
- Product Service task definition
- Product ECS service
- Order Service task definition
- Order ECS service
- ECS Service Connect namespace and configuration
- ECS task execution IAM role
- Secrets Manager access permissions
- CloudWatch log groups
- Application Load Balancer
- Product Service target group
- HTTP listener
- RDS DB subnet group
- Amazon RDS PostgreSQL instance
- Shared resource tagging
- Terraform outputs

Terraform configuration is formatted and validated using:

```bash
terraform fmt
terraform validate
```

Infrastructure changes are reviewed before deployment using:

```bash
terraform plan
```

The infrastructure has intentionally not yet been fully provisioned.

This prevents billable resources such as the NAT Gateway, Application Load Balancer, RDS instance, and Fargate workloads from being left running while the architecture is still being reviewed.


# Pre-Deployment Architecture Audit

Before the first AWS deployment, CloudCart is undergoing an end-to-end architecture review.

The goal is to identify deployment and runtime problems before provisioning infrastructure rather than assuming that a successful `terraform validate` means the application will operate correctly.

`terraform validate` confirms that the Terraform configuration is structurally valid. It does not prove that:

- Container images exist
- ECS can successfully start the containers
- Application configuration is correct
- Database tables exist
- Network paths function as intended
- IAM permissions are sufficient at runtime
- ALB routing is complete
- Application dependencies are healthy


## Completed Validation

The following checks have been completed:

- Product Service supports local and AWS database configuration
- Order Service supports local and AWS database configuration
- Local `DATABASE_URL` compatibility remains functional
- Product Service container builds successfully
- Order Service container builds successfully
- Product Service reports healthy
- Order Service reports healthy
- PostgreSQL reports healthy
- Product-to-database connectivity works locally
- Order-to-database connectivity works locally
- Order-to-Product HTTP communication works locally
- Controlled Product Service dependency failure behavior has been tested
- ECS Service Connect configuration has been introduced
- Product Service has a stable Service Connect alias
- ECS-to-ECS traffic is explicitly permitted on the application port


## Database Schema Initialization

The local PostgreSQL environment uses a persistent Docker volume.

As a result, rebuilding application containers does not recreate the database:

```text
New Product Container ----+
                          |
New Order Container ------+----> Existing PostgreSQL
                                      |
                                      v
                                Persistent Volume
                                      |
                             +--------+--------+
                             |                 |
                          products           orders
```

A newly provisioned Amazon RDS instance will not contain these existing local tables.

Without schema initialization, an application could successfully reach RDS but still fail with errors such as:

```text
relation "products" does not exist
```

or:

```text
relation "orders" does not exist
```

Database migrations have therefore been identified as a deployment requirement.

The planned approach is to introduce Alembic so database schema changes can be explicitly created, versioned, and applied.


## Remaining Pre-Deployment Checks

Before the initial AWS deployment, the project still needs to address:

- Database schema migrations
- Order Service ALB target group
- ALB path-based routing for Product and Order services
- ECS-to-ALB resource creation dependencies
- Initial ECR repository and image bootstrap sequence
- Initial container image push
- ECS image availability before service startup
- Service Connect deployment validation
- RDS connectivity validation
- Secrets Manager injection validation
- IAM runtime permission validation
- Complete Terraform execution plan review
- AWS cost review
- Initial deployment sequencing


# Troubleshooting Model

CloudCart is being designed with operational troubleshooting in mind.

For example, if Order Service cannot reach Product Service, potential failure layers include:

```text
Is Product Service running?
          |
          v
Is the Product container healthy?
          |
          v
Is PRODUCT_SERVICE_URL correct?
          |
          v
Is Service Connect configured?
          |
          v
Can the service name be resolved?
          |
          v
Does the ECS security group permit traffic?
          |
          v
Is Product listening on port 8000?
          |
          v
Is Product returning a valid response?
```

Similarly, a Product Service startup failure could involve:

```text
Missing ECR image
       |
       v
Image pull failure


Incorrect IAM execution role
       |
       v
ECR / Secrets / Logs unavailable


Secret retrieval failure
       |
       v
Missing DB credentials


RDS connectivity failure
       |
       v
Application cannot reach PostgreSQL


Missing database schema
       |
       v
SQL queries fail


Application error
       |
       v
Container exits


Health endpoint failure
       |
       v
ALB target becomes unhealthy
```

This layered approach helps distinguish application, container, network, IAM, database, and AWS infrastructure problems.


# Repository Structure

```text
cloudcart-microservices/
|
├── README.md
├── compose.yaml
├── .gitignore
|
├── terraform/
|   ├── cloudwatch.tf
|   ├── data.tf
|   ├── ecr.tf
|   ├── ecs.tf
|   ├── iam.tf
|   ├── internet-gateway.tf
|   ├── load-balancer.tf
|   ├── locals.tf
|   ├── nat-gateway.tf
|   ├── outputs.tf
|   ├── providers.tf
|   ├── rds.tf
|   ├── route-tables.tf
|   ├── security-groups.tf
|   ├── service-connect.tf
|   └── vpc.tf
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


# Technologies

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

### AWS — Defined / In Progress

- Amazon VPC
- Amazon ECR
- Amazon ECS
- AWS Fargate
- Application Load Balancer
- Amazon RDS PostgreSQL
- ECS Service Connect
- AWS Cloud Map
- AWS Secrets Manager
- AWS IAM
- Amazon CloudWatch
- NAT Gateway
- Internet Gateway

### AWS — Planned

- Amazon SQS
- ECS Auto Scaling
- Additional CloudWatch monitoring
- HTTPS / TLS configuration

### Infrastructure & Automation

- Terraform
- Git
- GitHub
- GitHub Actions — planned

### Database Lifecycle

- Alembic — planned


# Next Steps

CloudCart is currently undergoing a pre-deployment architecture review before AWS resources are provisioned.

The next phase includes:

- Implement Alembic database migrations for fresh RDS deployments
- Create and validate the initial database schema migration
- Complete Application Load Balancer routing for Product Service and Order Service
- Create the Order Service target group
- Review ECS and ALB Terraform resource dependencies
- Review ECR image bootstrap and initial deployment sequencing
- Build production-targeted Product and Order container images
- Push the initial images to Amazon ECR
- Review ECS Service Connect behavior
- Review RDS connectivity and Secrets Manager integration
- Review IAM permissions
- Review the complete Terraform execution plan
- Review expected AWS infrastructure cost
- Provision the initial AWS infrastructure
- Deploy Product Service and Order Service to ECS/Fargate
- Validate ALB health checks
- Validate Product and Order API routing
- Validate Order-to-Product communication through Service Connect
- Validate ECS-to-RDS connectivity
- Validate CloudWatch logging
- Introduce Amazon SQS
- Build the Worker Service for asynchronous order processing
- Introduce application task roles for AWS API access
- Configure ECS Auto Scaling
- Expand monitoring and operational visibility
- Implement CI/CD workflows with GitHub Actions
- Continue infrastructure and container security hardening


# Current Milestone

CloudCart has progressed from a single local API into a multi-service containerized application with an AWS infrastructure architecture defined through Terraform.

The current environment demonstrates:

```text
Local Application
       |
       +---- Product Service
       |
       +---- Order Service
       |
       +---- PostgreSQL
       |
       +---- Docker networking
       |
       +---- Persistent storage
       |
       +---- Health checks
       |
       +---- Service-to-service communication
       |
       v
AWS Infrastructure Definition
       |
       +---- VPC
       |
       +---- Multi-AZ subnet architecture
       |
       +---- Internet Gateway
       |
       +---- NAT Gateway
       |
       +---- Security groups
       |
       +---- ECR
       |
       +---- ECS / Fargate
       |
       +---- Application Load Balancer
       |
       +---- Service Connect
       |
       +---- RDS PostgreSQL
       |
       +---- Secrets Manager
       |
       +---- IAM
       |
       +---- CloudWatch
```

The next milestone is to complete the pre-deployment requirements and perform the first controlled AWS deployment.