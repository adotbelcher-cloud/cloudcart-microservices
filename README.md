# CloudCart Microservices

**Containerized E-Commerce Infrastructure on AWS | Terraform · ECS Fargate · Docker · PostgreSQL · GitHub Actions**

CloudCart is a hands-on cloud engineering project focused on designing, deploying, securing, and operating containerized workloads on AWS. A lightweight e-commerce application provides a realistic environment for practicing infrastructure provisioning, networking, service discovery, database lifecycle management, troubleshooting, and automation.

**Project status:** AWS infrastructure and both microservices are operational. End-to-end Product and Order workflows are validated, and GitHub Actions CI plus manually triggered ECS deployment are implemented and tested. Monitoring, rollback automation, and security hardening remain future work.

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

The deployment pipeline runs separately: GitHub Actions builds Docker images, publishes commit-SHA-tagged images to Amazon ECR, and deploys selected revisions to ECS using short-lived AWS credentials obtained through OIDC.

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
| AWS IAM / STS | Grants ECS execution permissions and temporary GitHub Actions deployment credentials |
| Amazon CloudWatch | Collects container and migration logs |
| Terraform | Provisions and manages AWS infrastructure |
| GitHub Actions | Builds and publishes container images; manually deploys ECS service revisions |

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

Terraform defines `desired_count = 1` for both services. The ECS service resources use `lifecycle { ignore_changes = [task_definition] }` so later Terraform applies do not automatically revert the task definition revisions deployed by GitHub Actions. Terraform still manages the task definition resources themselves; changes to those resources require coordination with application deployments.

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
| GitHub Actions CI builds and publishes commit-SHA-tagged images | Successful |
| GitHub Actions OIDC authentication and manual ECS deployment | Successful |
| Post-deployment GET `/products` and GET `/orders` through ALB | HTTP 200 for both |
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

## CI/CD with GitHub Actions

CloudCart separates **continuous integration (CI)** from **continuous delivery (CD)**. GitHub Actions workflows live in `.github/workflows/` and run on GitHub-hosted Ubuntu runners. The workflow is responsible for application packaging and deployment; Terraform manages the supporting AWS infrastructure and permissions.

### Continuous integration — `ci.yml`

- Runs for pushes to `main` and pull requests targeting `main`.
- Checks out the repository and builds separate Docker images for Product Service and Order Service.
- On pushes to `main`, authenticates to AWS and pushes both images to their respective ECR repositories.
- Tags published images with the full Git commit SHA (`github.sha`), allowing a deployment to reference a specific source revision.
- Pull request builds do not attempt AWS authentication or publish images.

A successful build confirms the Docker images can be assembled; it does **not** replace application tests or deployment verification. Automated unit/integration test stages are future improvements.

### Secure AWS authentication — GitHub OIDC

GitHub Actions assumes the IAM role `cloudcart-github-actions-ecr-role` using OpenID Connect (OIDC) and AWS STS. Terraform defines the GitHub OIDC provider, the role's repository/branch-restricted trust policy, and the IAM policies for the workflow. **No long-lived AWS access keys are stored in GitHub for this integration.**

The role has permissions scoped to the CloudCart workflow's needs: ECR image publishing and inspection, registering task definitions, describing/updating the two ECS services, and passing the ECS task execution role. Registration requires the `Project=cloudcart-microservices` request tag, with tagging permission restricted to task-definition creation.

The trust policy controls **who** can assume the role; IAM permissions control **what** that role can do after authentication.

### Manual ECS delivery — `deploy.yml`

The deployment workflow uses `workflow_dispatch`, so an operator explicitly starts it from GitHub Actions. This keeps publishing an image separate from releasing it to the running environment.

1. Check out the selected repository revision and assume the GitHub Actions AWS IAM role through OIDC.
2. Verify that the Product and Order images exist in ECR under the selected commit SHA.
3. Retrieve each service's existing ECS task definition and change only its container image URI, preserving environment variables, Secrets Manager references, port mappings, and logging settings.
4. Register a new task definition revision with the required project tag.
5. Update the corresponding ECS service and wait for it to stabilize; deploy Product Service before Order Service.
6. Verify the public endpoints through the ALB after deployment.

```text
Push to main
    |
    v
GitHub Actions CI ---> Build Product + Order images
    |                           |
    |                           v
    |                    Amazon ECR (SHA tags)
    |                           |
    +---- Manual deploy --------+
                                |
                                v
                     GitHub Actions + OIDC
                                |
                                v
                     New ECS task revisions
                                |
                                v
                     ECS Fargate services
                                |
                                v
                     ALB endpoint checks
```

**Validated outcome:** The deployment workflow completed successfully, both ECS services stabilized, and subsequent requests to `GET /products` and `GET /orders` returned HTTP `200` through the ALB. These endpoint checks were performed manually after deployment; automated post-deployment HTTP smoke tests and rollback are not yet implemented.

**Current limitation:** This is manually triggered continuous delivery, **not** automatic deployment on every push. The workflow deploys services sequentially, but does not provide an atomic two-service release or automated rollback if a later step fails.

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

### GitHub Actions deployment permissions

**Issue:** The first deployment run passed an invalid ECR image tag because the GitHub SHA expression had been encoded incorrectly in the workflow YAML.

**Fix:** Corrected the `IMAGE_TAG: ${{ github.sha }}` expression and rebuilt images for the new commit.

**Issue:** A subsequent deployment failed with `AccessDeniedException` on `ecr:DescribeImages` even though GitHub Actions had authenticated to AWS successfully.

**Fix:** Added `ecr:DescribeImages` to the repository-scoped ECR IAM policy using Terraform. After applying the permission change, the manual ECS deployment succeeded.

**Lesson:** Authentication through OIDC and authorization through IAM are separate checks. A successful AWS role assumption does not imply permission to perform every ECR or ECS API operation.

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
- IAM execution role, Secrets Manager permissions, GitHub OIDC provider, and GitHub Actions CI/CD role/policies
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
| Git commit SHA image tags for CI/CD | Traceable deployment image references; the original Terraform task definition resources still specify `latest` |
| Manually triggered deployments | Allows operator review before release; not automatic continuous deployment |
| GitHub OIDC rather than stored access keys | Uses short-lived credentials with repository/branch-scoped trust and IAM permissions |
| Terraform ignores ECS service task-definition drift | Prevents reverting GitHub Actions releases; task-definition resource changes still need coordination |
| HTTP-only ALB | Simple initial testing; HTTPS/TLS is a required hardening step |

## Security and current limitations

CloudCart is a **development and learning environment**, not a production-ready commerce application.

Current controls include private application and database networking, scoped security group traffic, IAM execution permissions, GitHub OIDC with scoped deployment policies, Secrets Manager integration, and CloudWatch logging.

Known gaps and next improvements include:

- Add HTTPS/TLS and API authentication/authorization.
- Use dedicated, least-privilege database users instead of master credentials for application connections.
- Review historical logs for exposed secrets and improve sensitive-data redaction.
- Add automated post-deployment smoke tests, deployment circuit breaker/rollback safeguards, and broader automated application testing.
- Improve monitoring, alerting, backup/recovery testing, and resilience.
- Implement inventory reservation/decrement and stronger order consistency guarantees.
- Coordinate future Terraform task-definition changes with GitHub Actions-managed ECS releases.

**Cost:** The deployed ALB, NAT Gateway, Fargate tasks, RDS, and other AWS resources may incur charges even when idle. AWS Budgets alerts do not automatically cap spending.

## Repository structure

```text
cloudcart-microservices/
├── README.md
├── compose.yaml
├── .gitignore
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── deploy.yml
├── terraform/
│   ├── cloudwatch.tf
│   ├── data.tf
│   ├── ecr.tf
│   ├── ecs.tf
│   ├── github-oidc.tf
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
| CI/CD automation | GitHub Actions, GitHub OIDC, AWS STS |

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
| GitHub Actions CI builds and ECR publishing | Complete |
| GitHub Actions OIDC and manually triggered ECS delivery | Complete |
| Automated deployment smoke tests and rollback | Planned |
| HTTPS and authentication | Planned |
| SQS and background Worker Service | Planned |
| Auto Scaling and advanced observability | Planned |

## Roadmap

1. **Deployment reliability:** Add automated tests, post-deployment smoke checks, ECS deployment rollback safeguards, and clearer release procedures.
2. **Security:** Add HTTPS, API authentication, least-privilege database access, and better secret-safe logging.
3. **Observability:** Introduce CloudWatch alarms, dashboards, and deployment health checks.
4. **Reliability:** Explore ECS Auto Scaling, recovery testing, and resilient service communication.
5. **Asynchronous processing:** Add Amazon SQS and a Worker Service for background order processing.
6. **Cost optimization:** Review actual AWS spending, task sizing, NAT options, and infrastructure lifecycle procedures.

---

**Current milestone:** CloudCart runs on AWS, has completed an end-to-end Product/Order workflow using ECS Service Connect and RDS PostgreSQL, and now has working GitHub Actions CI and manually triggered ECS delivery. Next priorities are observability, deployment safeguards, and security hardening.
