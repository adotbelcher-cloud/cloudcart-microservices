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


## Current Local Architecture

CloudCart currently consists of two FastAPI microservices and a PostgreSQL database running as a multi-container application using Docker Compose.

```text
                              Host
                               |
                  +------------+-------------+
                  |                          |
             localhost:8000            localhost:8001
                  |                          |
                  v                          v
            Product Service             Order Service
            FastAPI :8000               FastAPI :8000
                  |                          |
                  |<------ HTTP -------------+
                  |   product-service:8000
                  |
                  +------------+-------------+
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

PostgreSQL 17 currently runs locally as a Docker container managed through Docker Compose.

The local database contains two application tables:

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

For AWS, an Amazon RDS PostgreSQL instance has been defined in Terraform to replace the local PostgreSQL container as the managed database platform.


## Persistent Storage

PostgreSQL data in the local environment is stored using a Docker-managed persistent volume.

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

In AWS, persistent database storage will be managed by Amazon RDS rather than a Docker volume.


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

Amazon ECR repositories have also been defined in Terraform for storing the Product Service and Order Service container images when the AWS environment is deployed.


## Container Health and Readiness

Health checks are configured for the application services and PostgreSQL.

Product Service and Order Service health checks call their respective:

```text
GET /health
```

endpoints.

PostgreSQL readiness is checked locally using:

```text
pg_isready
```

The Product Service is configured to wait for PostgreSQL to become healthy before starting in the local Docker environment.

Health-check behavior has also been tested by deliberately configuring an invalid health endpoint, observing the container become unhealthy, restoring the correct endpoint, and verifying recovery.

The AWS infrastructure extends this concept through an Application Load Balancer target group configured to check:

```text
GET /health
```

on the Product Service.

This allows unhealthy ECS targets to be detected before normal application traffic is routed to them.


## Runtime Configuration

Application configuration is externalized from the container images.

### Local Development

The Product Service can receive:

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

### AWS Runtime Configuration

The Product Service database configuration has been updated to support both local and AWS environments.

When `DATABASE_URL` is available, the application continues to use the complete connection string. This preserves the existing local Docker workflow.

When `DATABASE_URL` is not supplied, the Product Service can build the connection string from:

```text
DB_HOST
DB_PORT
DB_NAME
DB_USER
DB_PASSWORD
```

For the AWS environment:

- `DB_HOST` will come from the Amazon RDS endpoint
- `DB_PORT` will come from the RDS PostgreSQL port
- `DB_NAME` identifies the CloudCart database
- `DB_USER` will be injected from AWS Secrets Manager
- `DB_PASSWORD` will be injected from AWS Secrets Manager

The application then constructs the SQLAlchemy PostgreSQL connection URL at runtime.

This allows the same application image to run across local and AWS environments without embedding environment-specific database configuration or credentials into the image.


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

- Deployed PostgreSQL 17 locally using Docker
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


### AWS Infrastructure — Networking

- Configured the AWS provider for `us-east-1`
- Designed a dedicated `10.0.0.0/16` VPC
- Designed infrastructure across two Availability Zones
- Defined two public subnets
- Defined two private application subnets for ECS/Fargate
- Defined two private database subnets for Amazon RDS
- Configured an Internet Gateway
- Configured a public route table
- Configured a NAT Gateway and Elastic IP for private application egress
- Configured private application routing through the NAT Gateway
- Added route table associations for public and private application subnets
- Kept private database subnets isolated from general internet routing
- Added Terraform outputs for key networking resources


### AWS Infrastructure — Container Registry

- Defined an Amazon ECR repository for Product Service
- Defined an Amazon ECR repository for Order Service
- Enabled image scanning on push
- Configured shared Terraform resource tags


### AWS Infrastructure — Security Groups

Defined a tiered network security model:

```text
Internet
   |
   | TCP 80
   v
ALB Security Group
   |
   | TCP 8000
   v
ECS Security Group
   |
   | TCP 5432
   v
RDS Security Group
```

Current security controls include:

- ALB accepts HTTP traffic from the internet on port `80`
- ECS application traffic is restricted to traffic originating from the ALB security group
- RDS PostgreSQL traffic is restricted to traffic originating from the ECS security group
- ECS tasks are configured without public IP addresses
- RDS is configured as not publicly accessible


### AWS Infrastructure — IAM

- Defined an ECS task execution IAM role
- Configured the ECS Tasks service as the trusted principal
- Attached the AWS-managed `AmazonECSTaskExecutionRolePolicy`
- Added least-privilege access to retrieve the CloudCart RDS-managed database secret
- Restricted Secrets Manager access to the specific RDS-managed secret

The ECS task execution role is intended to support infrastructure-level actions such as:

- Pulling container images from Amazon ECR
- Sending container logs to Amazon CloudWatch
- Retrieving configured secrets from AWS Secrets Manager


### AWS Infrastructure — Observability

- Defined a CloudWatch log group for Product Service
- Defined a CloudWatch log group for Order Service
- Configured seven-day log retention for the development environment
- Configured the Product Service task definition to use the `awslogs` logging driver


### AWS Infrastructure — ECS/Fargate

- Defined the CloudCart ECS cluster
- Defined the Product Service Fargate task definition
- Configured Fargate compatibility
- Configured `awsvpc` networking
- Configured Product Service CPU and memory allocation
- Connected the Product Service task definition to its ECR repository
- Exposed container port `8000`
- Connected Product Service container logging to CloudWatch
- Associated the ECS task execution role
- Defined the Product Service ECS service
- Configured a desired task count of one for the development environment
- Configured Product Service tasks to run in private application subnets
- Attached the ECS security group
- Disabled public IP assignment for Product Service tasks


### AWS Infrastructure — Application Load Balancer

- Defined an internet-facing Application Load Balancer
- Placed the ALB across both public subnets
- Attached the ALB security group
- Defined a Product Service target group
- Configured IP-based targets for Fargate
- Configured Product Service traffic on port `8000`
- Configured `/health` target health checks
- Defined an HTTP listener on port `80`
- Configured the listener to forward traffic to the Product Service target group
- Connected the Product Service ECS service to the target group


### AWS Infrastructure — RDS PostgreSQL

- Defined an RDS DB subnet group using both private database subnets
- Defined an Amazon RDS PostgreSQL instance
- Configured a small development-oriented database instance
- Configured GP3 database storage
- Disabled public database accessibility
- Attached the RDS security group
- Disabled Multi-AZ deployment for the development environment
- Configured a short development backup-retention period
- Configured RDS-managed master credentials
- Integrated the RDS-managed secret with the ECS execution role
- Configured the Product Service task definition to receive RDS connection information
- Configured sensitive database credentials to be injected from AWS Secrets Manager


### Terraform Validation

Terraform configuration is regularly formatted and validated using:

```bash
terraform fmt
terraform validate
```

Infrastructure changes are reviewed using:

```bash
terraform plan
```

> **Important:** The AWS infrastructure is currently defined in Terraform but has not yet been provisioned. This avoids leaving billable development resources such as the NAT Gateway, Application Load Balancer, ECS workloads, and RDS database running while the infrastructure design is still being completed.


## Local Development

The local environment requires:

- Docker Desktop
- Docker Compose
- WSL2/Linux environment when developing on Windows

From the repository root, start the application stack with:

```bash
docker compose up -d
```

To rebuild application images after source-code changes:

```bash
docker compose up -d --build
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

Stop the local application:

```bash
docker compose down
```

The PostgreSQL Docker volume remains available after the application containers are stopped.


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

A future Worker Service will support asynchronous order processing.

Planned responsibilities:

- Poll Amazon SQS
- Process asynchronous order tasks
- Update order status

The Worker Service and SQS will provide a workload for implementing asynchronous messaging, IAM permissions, observability, scaling, and failure handling.


## AWS Architecture

The local Docker environment is being translated into the following AWS architecture:

```text
                              Internet
                                 |
                                 | HTTP :80
                                 v
                    Application Load Balancer
                       Public Subnets A/B
                                 |
                                 | HTTP :8000
                                 v
                        Product Target Group
                                 |
                                 v
                           ECS / Fargate
                     Private App Subnets A/B
                                 |
                    +------------+------------+
                    |                         |
                    v                         v
              Product Service           Order Service
                    |                         |
                    |                         +-------> Amazon SQS
                    |                                    |
                    |                                    v
                    |                               Worker Service
                    |                                    |
                    +------------------+-----------------+
                                       |
                                       | PostgreSQL :5432
                                       v
                              Amazon RDS PostgreSQL
                           Private Database Subnets A/B
```

The Product Service portion of this architecture is currently the most developed in Terraform.

The Order Service, service discovery, SQS, and Worker Service remain future implementation stages.


## AWS Network Design

The AWS network architecture is defined with Terraform.

```text
                           Internet
                              |
                              v
                       Internet Gateway
                              |
                  +-----------+-----------+
                  |                       |
          Public Subnet A           Public Subnet B
           10.0.1.0/24               10.0.2.0/24
           us-east-1a                us-east-1b
                  |
             NAT Gateway
                  |
                  v
          Private App Route Table
                  |
          +-------+-------+
          |               |
          v               v
  Private App A      Private App B
  10.0.11.0/24      10.0.12.0/24
   us-east-1a         us-east-1b
          |               |
          +-------+-------+
                  |
                  v
             ECS / Fargate
                  |
                  v
          Private DB Subnets
           /             \
          v               v
  Private DB A       Private DB B
  10.0.21.0/24      10.0.22.0/24
   us-east-1a         us-east-1b
          \               /
           \             /
            v           v
          Amazon RDS PostgreSQL
```

The VPC uses the CIDR range:

```text
10.0.0.0/16
```

The public subnets route internet-bound traffic directly through the Internet Gateway.

The private application subnets route outbound internet traffic through a NAT Gateway located in Public Subnet A. A single NAT Gateway is used for the development environment to reduce infrastructure cost.

The private database subnets are isolated from direct internet routing.

The intended traffic path is:

```text
Internet
   |
   | TCP 80
   v
Application Load Balancer
   |
   | TCP 8000
   v
ECS / Fargate
   |
   | TCP 5432
   v
Amazon RDS PostgreSQL
```

Security groups enforce access between these infrastructure tiers.


## Local-to-AWS Mapping

The local environment is intentionally designed to introduce concepts that map to AWS services.

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


## Infrastructure as Code

CloudCart AWS infrastructure is being defined using Terraform.

The current Terraform configuration includes:

- AWS provider configuration
- Availability Zone discovery
- VPC
- Public subnets across two Availability Zones
- Private application subnets across two Availability Zones
- Private database subnets across two Availability Zones
- Internet Gateway
- Elastic IP
- NAT Gateway
- Public route table
- Private application route table
- Route table associations
- Amazon ECR repositories
- ALB security group
- ECS security group
- RDS security group
- ECS task execution IAM role
- Secrets Manager IAM permissions
- CloudWatch log groups
- ECS cluster
- Product Service Fargate task definition
- Product Service ECS service
- Application Load Balancer
- Product Service target group
- HTTP listener
- RDS DB subnet group
- RDS PostgreSQL instance
- RDS-managed master credentials
- Product Service RDS runtime configuration
- Terraform outputs
- Shared resource tagging

Terraform configuration is formatted and validated using:

```bash
terraform fmt
terraform validate
```

Infrastructure changes are reviewed before deployment using:

```bash
terraform plan
```

The infrastructure has intentionally not yet been provisioned so billable AWS resources are not left running unnecessarily while the design is still being completed.


## Next Steps

The local containerized application foundation is functional, and a substantial portion of the AWS infrastructure is now defined in Terraform.

The next stages of the project are:

1. Define the Order Service ECS/Fargate task definition.
2. Define the Order Service ECS service.
3. Determine Application Load Balancer routing for the Order Service.
4. Implement AWS service discovery for service-to-service communication.
5. Configure the Order Service database runtime configuration and secrets.
6. Review the complete Terraform configuration and execution plan.
7. Review expected AWS infrastructure cost before deployment.
8. Provision the initial AWS infrastructure with Terraform.
9. Build and push Product Service and Order Service images to Amazon ECR.
10. Deploy and validate the application on ECS/Fargate.
11. Verify ALB health checks and application routing.
12. Verify ECS-to-RDS connectivity.
13. Implement Amazon SQS.
14. Build the Worker Service for asynchronous processing.
15. Add additional CloudWatch monitoring and operational visibility.
16. Configure ECS Auto Scaling.
17. Build CI/CD workflows with GitHub Actions.
18. Perform infrastructure and container security hardening.


## Repository Structure

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


### AWS — Defined / In Progress

- Amazon VPC
- Amazon ECR
- Amazon ECS
- AWS Fargate
- Elastic Load Balancing / Application Load Balancer
- Amazon RDS PostgreSQL
- Amazon CloudWatch
- AWS Secrets Manager
- AWS IAM


### AWS — Planned

- Amazon SQS
- AWS service discovery
- ECS Auto Scaling


### Infrastructure & Automation

- Terraform
- Git
- GitHub
- GitHub Actions — Planned