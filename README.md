# CloudCart Microservices

**Building and operating a containerized e-commerce workload with Docker, Terraform, and AWS.**

CloudCart is a hands-on **cloud engineering portfolio project**. Two small FastAPI services provide a realistic workload; the main focus is the infrastructure needed to deploy, secure, connect, monitor, and troubleshoot them.

**Stack:** Python · FastAPI · Docker Compose · PostgreSQL · Alembic · Terraform · AWS VPC · ECR · ECS/Fargate · ALB · RDS · IAM · Secrets Manager · CloudWatch

> **Status: In development.** Both services work locally, migrations have been tested on a clean database, and their images have been published to ECR. AWS foundation resources were provisioned, but the end-to-end ECS deployment is **not yet complete** because RDS capacity errors blocked database creation. The NAT Gateway and ALB were intentionally deleted to limit development costs.

## At a glance

| Validated / completed | In progress | Planned |
| --- | --- | --- |
| Local Product and Order APIs | RDS provisioning and AWS database migrations | SQS worker |
| Docker Compose networking and PostgreSQL | ECS task startup and Service Connect validation | ECS Auto Scaling |
| Independent Alembic migration histories | ALB routing and end-to-end AWS API testing | GitHub Actions CI/CD |
| Images pushed to two ECR repositories | Runtime secret injection and CloudWatch verification | HTTPS and additional monitoring |
| Terraform-managed AWS foundation | Restore deleted networking when ready to deploy | Further security hardening |

## Architecture

CloudCart runs **Product Service** and **Order Service** separately. Order Service retrieves product details through the Product API instead of reading its database table directly. Both services currently share a PostgreSQL instance but maintain distinct table ownership and migration histories.

The diagram below shows the **target AWS deployment**, not an environment currently serving traffic.

```text
                             Internet
                                |
                        HTTP :80 (dev only)
                                |
                      Application Load Balancer
                         Public Subnets A/B
                         /              \
                /products*              /orders*
                     |                      |
              Product target group     Order target group
                     |                      |
              Product ECS task         Order ECS task
                  :8000                    :8000
                     ^                      |
                     +---- Service Connect -+
                          product-service:8000
                     |                      |
                     +-----------+----------+
                                 |
                          PostgreSQL :5432
                                 |
                           Amazon RDS
                       Private DB Subnets A/B

 ECR -> task images    Secrets Manager -> DB credentials
 IAM -> permissions    CloudWatch Logs -> container logs
```

**Supporting services:** ECR supplies container images; IAM and Secrets Manager provide startup permissions and database credentials; CloudWatch receives container logs.

## Run locally

From the repository root, start the Docker Compose environment:

```bash
docker compose up --build -d
docker compose ps
```

When the application and database have been initialized, the APIs are available at:

| Service | Local URL |
| --- | --- |
| Product | `http://localhost:8000/health` |
| Order | `http://localhost:8001/health` |
| PostgreSQL | `localhost:5432` |

The services require database configuration and their Alembic schemas. **First-time setup may require environment variables and running the Product and Order migrations**; see [Runtime configuration](#runtime-configuration) and [Database lifecycle](#database-lifecycle-alembic). This is not yet a fully automated one-command fresh-database bootstrap.

Stop containers without deleting the persistent PostgreSQL volume:

```bash
docker compose down
```

## Engineering decisions

| Decision | Why it matters |
| --- | --- |
| Private application and database subnets | Limits direct exposure of ECS workloads and RDS |
| Separate service-owned tables and migrations | Maintains clear ownership even while sharing a database instance |
| Docker DNS locally; ECS Service Connect in AWS | Avoids relying on changing container/task IP addresses |
| RDS-managed credentials in Secrets Manager | Keeps database passwords out of source code and task-definition literals |
| Terraform and reviewed plans | Makes infrastructure reproducible and changes auditable |
| Controlled deployment sequencing | Ensures images and database schemas exist before application tasks start |
| Targeted shutdown of billable components | Keeps an experimental AWS environment cost-conscious |

## Deployment status

**Locally verified:** Both APIs, database persistence, service-to-service HTTP, health checks, dependency-failure behavior, and migrations against fresh PostgreSQL 17.

**Published:** Product and Order Docker images in Amazon ECR.

**AWS partially provisioned:** VPC, six subnets, Internet Gateway, security groups, ECS cluster, ECR repositories, IAM execution role, CloudWatch log groups, and supporting resources. ALB and NAT were created, then removed during cost shutdown.

**Blocked / unverified:** RDS returned `InsufficientDBInstanceCapacity` for `db.t4g.micro` with both `gp3` and `gp2`. ECS application services and task definitions were not created in that attempt; live Secrets Manager injection, Service Connect, ALB health, and end-to-end application behavior remain unverified.

**Current shutdown:** No ECS services were registered in `cloudcart-cluster` at the last check. NAT Gateway, ALB, and NAT Elastic IP were deleted. ECR and much of the foundation remain; small storage charges may still apply. This is not an account-wide billing audit.

## Application and local environment

### Local architecture

```text
                 Developer / API client
                   |             |
             localhost:8000  localhost:8001
                   |             |
                   v             v
             Product Service   Order Service
               FastAPI:8000     FastAPI:8000
                   ^             |
                   +--- HTTP ----+
                     product-service:8000
                   |             |
                   +------+------+
                          |
                     PostgreSQL:5432
                      /          \
                products         orders
                          |
                  Persistent Docker volume
```

Docker Compose runs three containers: `cloudcart-product-service`, `cloudcart-order-service`, and `ecommerce-postgres`. Its internal DNS lets Order Service call `http://product-service:8000` without knowing Product Service's container IP. The Order Service is published on host port **8001** but listens on container port **8000**. PostgreSQL is published on host port **5432**.

### Product Service

Owns the `products` table, product creation/retrieval, pricing, inventory, and a health endpoint.

| Method | Route | Purpose |
| --- | --- | --- |
| GET | `/health` | Application health |
| GET | `/products` | List products |
| GET | `/products/{product_id}` | Retrieve a product |
| POST | `/products` | Create a product |

Product fields: `id`, `name`, `description`, `price`, `inventory`.

### Order Service

Owns the `orders` table. During order creation, it calls Product Service over HTTP to verify the product, check inventory, retrieve the current price, and calculate the total. If Product Service is unavailable, Order Service returns a controlled **503** rather than crashing.

| Method | Route | Purpose |
| --- | --- | --- |
| GET | `/health` | Application health |
| GET | `/orders` | List orders |
| GET | `/orders/{order_id}` | Retrieve an order |
| POST | `/orders` | Create an order |

Order fields: `id`, `product_id`, `product_name`, `quantity`, `unit_price`, `total`, `status`. New orders start with `status = pending`.

Although both services use the same PostgreSQL instance in development, **each owns its own tables and migrations**. Order Service does not query `products` directly; it uses Product Service's API.

### Runtime configuration

The same application images support local Docker and AWS runtime settings:

| Environment | Database configuration |
| --- | --- |
| Local | `DATABASE_URL` (SQLAlchemy/PostgreSQL connection URL) |
| AWS | `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` |

AWS is designed to supply the database endpoint through ECS environment variables and credentials through the RDS-managed AWS Secrets Manager secret. **Secrets must not be committed to Git.** Runtime injection in AWS is configured but has not yet been validated end to end.

### Health and failure handling

Both services expose `GET /health`; local Docker Compose health checks also cover PostgreSQL. A service can be healthy while a downstream dependency is unavailable. The Order Service's controlled 503 response demonstrates this distinction. On AWS, ECS and ALB health checks will help determine task readiness and traffic routing; their live behavior remains to be tested.

## Database lifecycle: Alembic

Local PostgreSQL persists data in a Docker volume, but a newly created RDS instance starts without CloudCart's tables. CloudCart uses **version-controlled Alembic migrations** rather than depending on local database state.

| Service | Owned table | Alembic version table | Initial revision |
| --- | --- | --- | --- |
| Product | `products` | `alembic_version_product` | `8b989af94884_create_products_table.py` |
| Order | `orders` | `alembic_version_order` | `b42864294bf6_create_orders_table.py` |

Each service has its own `alembic.ini` and `migrations/` directory. Alembic ownership filters prevent one service's autogeneration from modifying or dropping the other service's tables.

**Completed validation:** Both migration sequences were applied to the same fresh PostgreSQL 17 test database. The resulting database contained `products`, `orders`, and both independent version tables. Product Alembic schema comparison reported no unexpected changes after migration. **Running these migrations against AWS RDS is still pending.**

## AWS infrastructure details

### VPC and networking

VPC CIDR: `10.0.0.0/16` in `us-east-1`.

| Tier | Availability Zone A | Availability Zone B | Purpose |
| --- | --- | --- | --- |
| Public | `10.0.1.0/24` | `10.0.2.0/24` | Internet-facing ALB; NAT Gateway |
| Private application | `10.0.11.0/24` | `10.0.12.0/24` | ECS/Fargate tasks, no public IPs |
| Private database | `10.0.21.0/24` | `10.0.22.0/24` | RDS, no general internet default route |

Public subnet routes use an Internet Gateway. The intended private application route uses a **single NAT Gateway** for outbound internet access; this is a development cost tradeoff, not a highly available production configuration. The NAT Gateway and its route were removed during shutdown and must be recreated before deploying private ECS tasks that need outbound access.

Security-group boundaries:

```text
Internet --TCP 80--> ALB SG --TCP 8000--> ECS SG
                                             |
                                             +--TCP 8000--> ECS SG (service-to-service)
                                             |
                                             +--TCP 5432--> RDS SG
```

Security-group references are used instead of broad CIDR access where practical. Service Connect provides discovery; security groups separately control whether traffic is allowed.

### ECR and container images

Two repositories exist:

- `cloudcart-product-service`
- `cloudcart-order-service`

Both images have been built and pushed to ECR. Image scanning on push is enabled. Current ECS task definitions reference `latest` during development; immutable/versioned tags are a future CI/CD improvement. The Docker images include Alembic configuration and migration files so migration tasks can use the same packaged application artifacts.

### ECS/Fargate and Service Connect

The Terraform design includes:

- ECS cluster `cloudcart-cluster`.
- Product and Order task definitions using **0.25 vCPU / 512 MiB**, `awsvpc` networking, private application subnets, and CloudWatch logging.
- ECS execution role permissions for ECR image pulls, CloudWatch Logs, and retrieval of the RDS-managed database secret.
- Product Service Connect alias `product-service:8000`; Order uses `PRODUCT_SERVICE_URL=http://product-service:8000`.
- ECS services initially configured with `desired_count = 0` until database migrations are completed, after which running tasks can be enabled.

**Deployment status:** The ECS cluster exists, but the task definitions and ECS application services were not created successfully in the initial deployment sequence. The latest verification returned an empty ECS service list. ECS task startup, image pull, secret injection, Service Connect, and application traffic remain untested on AWS.

### Application Load Balancer

Terraform defines an internet-facing ALB in the two public subnets, separate IP target groups for Product and Order, `/health` target health checks, and path-based routing:

| Request path | Destination |
| --- | --- |
| `/products` and `/products/*` | Product target group, port 8000 |
| `/orders` and `/orders/*` | Order target group, port 8000 |
| Other paths | Default 404 response |

The ALB and its listener/rules were created during the first deployment and later deleted to stop hourly charges. **AWS routing has not yet been validated with healthy ECS targets.** HTTP is used for the development environment; HTTPS/TLS is planned.

### RDS PostgreSQL and Secrets Manager

The intended RDS configuration includes PostgreSQL 17, database `cloudcart`, 20 GiB initial storage (up to 50 GiB), private DB subnet group, no public access, single-AZ deployment, and one-day backup retention. RDS is configured to manage its master password through Secrets Manager.

**Provisioning blocker:** AWS rejected `db.t4g.micro` capacity in the selected VPC/AZ configuration using both `gp3` and `gp2` storage. `db.t4g.small` was identified as a possible next class, but successful creation and live capacity have **not** been verified. Consult the current `terraform/rds.tf` for the precise committed instance class and storage settings before retrying.

The intended ECS execution role can retrieve the RDS-managed secret at task startup. Actual secret retrieval and application connectivity cannot be validated until RDS and the ECS services are deployed.

### IAM and observability

The ECS **execution role** is for platform startup operations such as ECR pulls, log delivery, and secret retrieval. An ECS **task role** would provide AWS API permissions to application code, especially when the future Worker Service consumes SQS messages.

CloudWatch log groups:

- `/ecs/cloudcart-product-service`
- `/ecs/cloudcart-order-service`

Both are configured for **seven-day retention**. Logs and metrics from a live AWS deployment remain a future validation milestone.

## Deployment history and troubleshooting

### 1. Local validation

Validated local Compose networking, both APIs, PostgreSQL persistence, health checks, dependency-failure behavior, and independent Alembic migrations against a fresh database.

### 2. ECR bootstrap

Provisioned Product and Order ECR repositories, built both container images, and pushed the images before attempting ECS startup. This avoids task image-pull failures caused by nonexistent repositories/images.

### 3. First Terraform deployment

The initial deployment plan included networking, load balancing, IAM, ECS, RDS, and supporting resources. Many foundational resources were created successfully, including the VPC/subnets, NAT Gateway, ALB, ECS cluster, CloudWatch log groups, security groups, IAM execution role, and service discovery namespace.

**Failure:** RDS returned `InsufficientDBInstanceCapacity` when creating `db.t4g.micro` with `gp3`. A retry using `gp2` also failed with the same capacity error. Because dependent resources require RDS outputs/secrets, the application task definitions and services were not created.

This is an AWS capacity/provisioning issue, **not proof of an application bug**. The next attempt should review available instance classes, current configuration, and a fresh Terraform plan; AWS orderability does not guarantee real-time capacity.

### 4. Cost-controlled shutdown

To avoid leaving development infrastructure accruing hourly charges overnight, targeted Terraform destroys removed:

- The NAT Gateway and associated private-app routing resources.
- The Application Load Balancer, listener, and listener rules.
- The NAT Gateway Elastic IP allocation.

The ECR repositories/images, ECS cluster, VPC/subnets, IAM, CloudWatch log groups, security groups, and other supporting resources were preserved. AWS CLI verification returned:

```json
{
  "serviceArns": []
}
```

**Operational caution:** Targeted destroys were an exceptional cost-control action. A future normal `terraform plan` will propose recreating the missing resources. Review that plan and its cost before applying. Terraform state is local and must be preserved; it is **not** committed to Git. Budget alerts are notifications, not spending caps.

## Infrastructure as Code

Terraform defines the VPC, subnets, routes, security groups, NAT/IGW, ECR, ECS, ALB, RDS, IAM, Service Connect, CloudWatch, and shared tagging. Provider versions are recorded in `terraform/.terraform.lock.hcl`.

Useful review commands (run from `terraform/`):

```bash
terraform fmt -check
terraform validate
terraform plan
terraform state list
```

> **Do not apply a plan casually:** With the current partial shutdown, a normal `terraform plan` is expected to recreate billable resources. Review the plan, database settings, deployment order, and expected spend first. Never commit `.tfstate`, saved `.tfplan` files, credentials, or local `.env` files.

## Troubleshooting approach

CloudCart deliberately exposes multiple operational failure layers. Examples:

| Symptom | What to investigate |
| --- | --- |
| ECS task fails to start | ECR image/tag, execution-role permissions, secret injection, log configuration |
| Service starts but fails database operations | RDS availability, DNS, security groups, credentials, Alembic schema |
| Order cannot reach Product | Product health, `PRODUCT_SERVICE_URL`, Service Connect, ECS-to-ECS security group rules, port 8000 |
| ALB returns errors/unhealthy targets | Listener rules, target registration, security groups, `/health`, application logs |
| Unexpected AWS costs | NAT Gateway, ALB, public IPv4 allocations, RDS, Fargate tasks, ECR/CloudWatch storage |

The goal is to isolate infrastructure, network, IAM, database, and application failures rather than assuming every failure originates in application code.

## Local-to-AWS concept mapping

| Local | AWS |
| --- | --- |
| Docker image | ECR image |
| Docker container | ECS task |
| Docker Compose service | ECS service |
| Docker internal DNS | ECS Service Connect |
| Local port publishing | ALB listener and routing |
| PostgreSQL container | Amazon RDS PostgreSQL |
| Docker volume | RDS-managed storage |
| Alembic migrations | Alembic migrations run against RDS |
| Environment variables / `.env` | ECS runtime configuration and Secrets Manager |
| Docker health checks | ECS/ALB health checks |
| `docker compose logs` | CloudWatch Logs |

## Repository structure

```text
cloudcart-microservices/
├── README.md
├── compose.yaml
├── .gitignore
├── terraform/
│   ├── .terraform.lock.hcl
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
    │   ├── app/                 # main.py, database.py, models.py
    │   └── migrations/          # env.py, versions/, Alembic templates
    └── order-service/
        ├── Dockerfile
        ├── .dockerignore
        ├── requirements.txt
        ├── alembic.ini
        ├── app/                 # main.py, database.py, models.py
        └── migrations/          # env.py, versions/, Alembic templates
```

## Next milestones

1. **Resolve RDS provisioning:** Review the committed RDS instance class/storage settings, AWS availability, and a fresh Terraform plan.
2. **Restore required networking:** Recreate NAT Gateway, ALB, listener/rules, and private-app routing when ready to incur deployment costs.
3. **Initialize RDS schema:** Run Product and Order Alembic migrations against the newly provisioned database using an appropriate controlled task/deployment sequence.
4. **Deploy ECS services:** Start Product and Order tasks, confirm ECR pulls, IAM secret access, CloudWatch logs, and application health.
5. **Validate end-to-end behavior:** Test ALB `/products` and `/orders` routing, Service Connect, ECS-to-RDS access, and dependency-failure handling.
6. **Extend the architecture:** Add SQS and a Worker Service, application task roles, Auto Scaling, improved monitoring, CI/CD with GitHub Actions, and HTTPS/security hardening.
