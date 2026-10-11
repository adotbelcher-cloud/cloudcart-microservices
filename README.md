# CloudCart Microservices

**Containerized E-Commerce Infrastructure on AWS | Terraform · ECS Fargate · Docker · PostgreSQL**

CloudCart is a hands-on cloud engineering project focused on designing, deploying, securing, and operating containerized workloads on AWS. A lightweight e-commerce application provides a realistic environment for practicing infrastructure provisioning, networking, service discovery, database lifecycle management, troubleshooting, and automation.

**Project status:** Initial AWS deployment operational; end-to-end Product and Order workflows validated. Further security, reliability, and deployment automation work is planned.

## Architecture

```text
                         Internet
                            |
                         HTTP :80
                            v
                  Application Load Balancer
                      Public Subnets
                            |
                +-----------+-----------+
                |                       |
           /products*                /orders*
                |                       |
                v                       v
          Product Service          Order Service
            ECS Fargate             ECS Fargate
                ^                       |
                |                       |
                +---- ECS Service ------+
                       Connect
                (product-service:8000)
                |                       |
                +-----------+-----------+
                            |
                       TCP 5432
                            v
                   Amazon RDS PostgreSQL
                    Private DB Subnets
```

Both application services run in **private application subnets without public IP addresses**. An internet-facing Application Load Balancer (ALB) routes requests to the appropriate ECS service. The database runs in separate private database subnets. A NAT Gateway supplies outbound connectivity for private application tasks.

### AWS services

| Component | Purpose |
|---|---|
| Amazon ECS / AWS Fargate | Runs the Product and Order containers |
| Amazon ECR | Stores container images |
| Application Load Balancer | Routes `/products*` and `/orders*` traffic |
| Amazon VPC | Isolates public, application, and database tiers |
| NAT Gateway | Enables outbound traffic from private ECS tasks |
| ECS Service Connect | Provides internal service discovery |
| Amazon RDS PostgreSQL | Stores product and order data |
| AWS Secrets Manager | Manages the RDS master credential |
| AWS IAM | Grants ECS execution permissions |
| Amazon CloudWatch | Collects container and migration logs |
| Terraform | Provisions and manages AWS infrastructure |

## Network design

The dedicated VPC uses `10.0.0.0/16`, with six subnets across two Availability Zones.

| Tier | Availability Zone A | Availability Zone B |
|---|---|---|
| Public | `10.0.1.0/24` | `10.0.2.0/24` |
| Private application | `10.0.11.0/24` | `10.0.12.0/24` |
| Private database | `10.0.21.0/24` | `10.0.22.0/24` |

The public subnets host the ALB and NAT Gateway. ECS tasks use private application subnets and are not directly reachable from the internet. RDS uses private database subnets and has public accessibility disabled.

### Security group traffic

| Source | Destination | Port | Purpose |
|---|---|---|---|
| Internet | ALB | TCP 80 | Public API access |
| ALB security group | ECS security group | TCP 8000 | Requests to application containers |
| ECS security group | ECS security group | TCP 8000 | Internal service traffic |
| ECS security group | RDS security group | TCP 5432 | PostgreSQL connections |

Security group references restrict access between tiers rather than exposing application or database ports to the public internet.

## Application services

CloudCart has two FastAPI services, each with its own Docker image, ECS service, target group, and database migration history.

### Product Service

Product Service owns product data, including name, description, price, and inventory.

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/health` | Health check |
| GET | `/products` | List products |
| GET | `/products/{product_id}` | Retrieve a product |
| POST | `/products` | Create a product |

Product Service owns the PostgreSQL `products` table.

### Order Service

Order Service accepts an order request, looks up the product through Product Service, checks the requested quantity against inventory, calculates the total, and saves the order.

| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/health` | Health check |
| GET | `/orders` | List orders |
| GET | `/orders/{order_id}` | Retrieve an order |
| POST | `/orders` | Create an order |

Order Service owns the PostgreSQL `orders` table. New orders start with the status `pending`.

**Service boundary:** Order Service accesses product information through the Product API rather than directly querying the `products` table. The current implementation checks inventory but does **not** reserve or decrement stock.

### Service discovery and dependency handling

Order Service connects to Product Service through the stable ECS Service Connect endpoint:

```text
http://product-service:8000
```

The URL is supplied through `PRODUCT_SERVICE_URL`. This avoids hardcoding ECS task IP addresses. If the Product Service cannot be reached, Order Service handles the connection error and returns HTTP `503 Service Unavailable` rather than crashing.

Locally, Docker Compose provides analogous service-name-based networking.

## Containers and local development

Docker Compose runs three containers:

- Product Service — available at `localhost:8000`
- Order Service — available at `localhost:8001`
- PostgreSQL 17 — available at `localhost:5432`

From the repository root:

```bash
# Build and start containers
docker compose up -d --build

# Inspect container status
docker compose ps

# Review logs
docker compose logs

# Stop containers without deleting the persistent database volume
docker compose down
```

PostgreSQL uses a persistent Docker volume. The same application images can run locally and in AWS because database configuration is provided through environment variables. AWS task definitions inject database credentials through Secrets Manager.

## Database and migrations

CloudCart uses **Amazon RDS PostgreSQL** with the following initial development configuration:

| Setting | Value |
|---|---|
| Engine | PostgreSQL 17.11 |
| Instance class | `db.t3.micro` |
| Initial storage | 20 GiB, gp2 |
| Database | `cloudcart` |
| Public accessibility | Disabled |
| Multi-AZ database deployment | Disabled |
| Backup retention | 1 day |

Both services share one database instance to control costs while retaining logical table ownership.

**Alembic migrations** manage schema creation and changes independently:

| Service | Owned table | Migration history table |
|---|---|---|
| Product | `products` | `alembic_version_product` |
| Order | `orders` | `alembic_version_order` |

Migrations were validated against a fresh local PostgreSQL 17 database. Both services' migrations were then executed against private RDS using **one-off ECS Fargate tasks**. They completed successfully with exit code `0`, verified in CloudWatch logs.

This process avoids relying on tables already present in a developer's local Docker volume.

## AWS deployment

The initial deployment was provisioned through Terraform and tested on AWS.

### ECS configuration

- Cluster: `cloudcart-cluster`
- Services: `cloudcart-product-service` and `cloudcart-order-service`
- Compute per application task: **0.25 vCPU / 512 MiB memory**
- Network mode: `awsvpc`
- Placement: private application subnets, no public IPs
- Image source: separate Amazon ECR repositories
- Logging: separate CloudWatch log groups
- Internal discovery: ECS Service Connect

Terraform currently defines `desired_count = 0` for the ECS services, while task counts were scaled up through the AWS CLI for live testing. **Reconcile this difference before future Terraform applies** to avoid unintended scaling changes.

### Load balancing and health checks

The ALB routes:

```text
/products*  -> Product Service target group
/orders*    -> Order Service target group
```

Both target groups use HTTP on port `8000` and check `GET /health`. Healthy targets were confirmed during deployment testing.

### Validated end-to-end tests

| Test | Result |
|---|---|
| Build and push both Docker images to ECR | Successful |
| Start Product and Order tasks on Fargate | Successful |
| Run Product and Order migrations against RDS | Successful |
| Confirm ALB target health | Healthy |
| Route `/products` and `/orders` through ALB | HTTP 200 |
| Create a product through the ALB | HTTP 201 |
| Create an order using Product Service data | HTTP 201 |
| Communicate between services through Service Connect | Successful |
| Persist product and order data in PostgreSQL | Successful |

**Product creation:** `POST /products` created a product named `CloudCart Test Product` with a price of `$29.99` and inventory of `10`.

**Order creation:** `POST /orders` requested two units of that product. Order Service retrieved the product details through Service Connect and returned:

```json
{
  "quantity": 2,
  "product_name": "CloudCart Test Product",
  "unit_price": 29.99,
  "total": 59.98,
  "status": "pending"
}
```

The successful order demonstrated the complete request path:

```text
Client -> ALB -> Order Service -> ECS Service Connect -> Product Service
                                                        |
                                                        v
                                                 RDS product data
                                                        |
                                                        v
Client <- HTTP 201 <- Order Service -> RDS order data
```

## Troubleshooting and operational lessons

### Alembic configuration interpolation

**Issue:** AWS database migrations failed when a URL-encoded database password contained `%` characters that were interpreted by Alembic's configuration parser.

**Fix:** Updated both services' Alembic environments to escape percent signs before setting the SQLAlchemy URL:

```python
config.set_main_option(
    "sqlalchemy.url",
    DATABASE_URL.replace("%", "%%"),
)
```

Both migration sets subsequently completed against RDS.

### Order Service connectivity failure

**Issue:** Initial order creation requests returned HTTP `503` because Order Service could not reach Product Service.

**Investigation:** Reviewed ECS task health, Service Connect settings, service aliases, environment variables, security groups, and ALB target health.

**Outcome:** Added connection exception logging, rebuilt and pushed the Order image, and forced a new ECS deployment. After deployment stabilized, order creation returned HTTP `201`.

The exact cause of the earlier connectivity failure was **not conclusively identified**; redeployment is documented as the observed recovery, not a proven root-cause fix.

### Credential handling

A failed migration exposed sensitive database connection information in CloudWatch logs. The RDS-managed master password was rotated successfully and the database and secret returned to their expected operational states.

**Lesson:** Avoid logging credentials or full database connection strings. Rotating a credential does not automatically remove previously logged sensitive values; historical log review and remediation remain important.

### Terraform validation versus runtime validation

A successful `terraform validate` or `terraform plan` confirms configuration validity or proposed infrastructure changes—not that an application can start, reach its dependencies, or serve requests. Runtime validation required checking ECR image availability, IAM permissions, Secrets Manager injection, ECS events, networking, database migrations, target health, and end-to-end HTTP behavior.

## Infrastructure as Code

Terraform manages the AWS infrastructure, including:

- VPC, subnets, route tables, and Internet Gateway
- NAT Gateway and Elastic IP
- Security groups
- Application Load Balancer, listeners, rules, and target groups
- ECS cluster, task definitions, and services
- ECS Service Connect configuration
- ECR repositories
- RDS PostgreSQL and DB subnet group
- IAM execution role and Secrets Manager permissions
- CloudWatch log groups
- Resource tagging and outputs

Common Terraform workflow, from the `terraform/` directory:

```bash
terraform fmt
terraform validate
terraform plan
# Review the plan carefully before applying changes.
terraform apply
```

**Caution:** This is a live, billable environment. Review plans and state before changing or destroying resources. Avoid committing Terraform state, secrets, or local credentials.

## Engineering decisions and trade-offs

| Decision | Rationale / trade-off |
|---|---|
| Private ECS tasks behind a public ALB | Prevents direct internet access to application tasks |
| Private RDS database | Restricts direct database exposure |
| One NAT Gateway | Lower cost than per-AZ NAT; less resilient to AZ failure |
| Fargate instead of EC2-backed ECS | Avoids managing container host instances |
| Shared RDS instance | Controls cost; logical table ownership maintained per service |
| Independent Alembic histories | Allows service-owned schema changes |
| RDS-managed secret | Avoids embedding the master password in Terraform source |
| CloudWatch logging | Supports deployment troubleshooting and application diagnostics |
| Terraform-managed infrastructure | Provides reviewable, repeatable configuration |
| Mutable `latest` image tags | Convenient for development; immutable versions are planned |
| HTTP-only ALB | Simple initial testing; HTTPS/TLS is a required hardening step |

## Security and current limitations

CloudCart is a **development and learning environment**, not a production-ready commerce application.

Current controls include private application and database networking, scoped security group traffic, IAM execution permissions, Secrets Manager integration, and CloudWatch logging.

Known gaps and next improvements include:

- Add HTTPS/TLS and API authentication/authorization.
- Use dedicated, least-privilege database users instead of master credentials for application connections.
- Review historical logs for exposed secrets and improve sensitive-data redaction.
- Introduce immutable image versions and automated deployment verification.
- Improve monitoring, alerting, backup/recovery testing, and resilience.
- Implement inventory reservation/decrement and stronger order consistency guarantees.
- Reconcile Terraform-defined desired task counts with the live ECS configuration.

**Cost:** The deployed ALB, NAT Gateway, Fargate tasks, RDS, and other AWS resources may incur charges even when idle. AWS Budgets alerts do not automatically cap spending.

## Repository structure

```text
cloudcart-microservices/
├── README.md
├── compose.yaml
├── .gitignore
├── terraform/
│   ├── cloudwatch.tf
│   ├── data.tf
│   ├── ecr.tf
│   ├── ecs.tf
│   ├── iam.tf
│   ├── internet-gateway.tf
│   ├── load-balancer.tf
│   ├── locals.tf
│   ├── nat-gateway.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── rds.tf
│   ├── route-tables.tf
│   ├── security-groups.tf
│   ├── service-connect.tf
│   └── vpc.tf
└── services/
    ├── product-service/
    │   ├── Dockerfile
    │   ├── .dockerignore
    │   ├── requirements.txt
    │   ├── alembic.ini
    │   ├── app/
    │   │   ├── main.py
    │   │   ├── database.py
    │   │   └── models.py
    │   └── migrations/
    │       ├── env.py
    │       └── versions/
    └── order-service/
        ├── Dockerfile
        ├── .dockerignore
        ├── requirements.txt
        ├── alembic.ini
        ├── app/
        │   ├── main.py
        │   ├── database.py
        │   └── models.py
        └── migrations/
            ├── env.py
            └── versions/
```

## Technology stack

| Area | Technologies |
|---|---|
| Cloud infrastructure | AWS, Terraform |
| Containers | Docker, Docker Compose, ECS, Fargate, ECR |
| Networking | VPC, ALB, NAT Gateway, security groups, Service Connect |
| Database | PostgreSQL, RDS, SQLAlchemy, Alembic |
| Application workload | Python, FastAPI, Pydantic, HTTPX |
| Security | IAM, Secrets Manager |
| Observability | CloudWatch Logs |
| Source control | Git, GitHub |
| Planned automation | GitHub Actions |

## Milestones

| Milestone | Status |
|---|---|
| Local Product and Order services | Complete |
| Docker Compose and PostgreSQL persistence | Complete |
| Independent Alembic migrations | Complete |
| Terraform VPC, ECS, ALB, and RDS deployment | Complete (initial environment) |
| ECR image publishing | Complete |
| RDS schema initialization from ECS tasks | Complete |
| ALB routing and target health | Complete |
| ECS Service Connect communication | Complete |
| Product and Order API integration tests | Complete |
| GitHub Actions CI/CD | Planned |
| HTTPS and authentication | Planned |
| SQS and background Worker Service | Planned |
| Auto Scaling and advanced observability | Planned |

## Roadmap

1. **CI/CD:** Use GitHub Actions to build, test, tag, publish, and deploy container images automatically.
2. **Security:** Add HTTPS, API authentication, least-privilege database access, and better secret-safe logging.
3. **Observability:** Introduce CloudWatch alarms, dashboards, and deployment health checks.
4. **Reliability:** Explore ECS Auto Scaling, recovery testing, and resilient service communication.
5. **Asynchronous processing:** Add Amazon SQS and a Worker Service for background order processing.
6. **Cost optimization:** Review actual AWS spending, task sizing, NAT options, and infrastructure lifecycle procedures.

---

**Current milestone:** CloudCart has been deployed to AWS and has successfully processed an end-to-end order across two ECS Fargate services using Service Connect and RDS PostgreSQL. The next major engineering milestone is automated CI/CD with GitHub Actions.
