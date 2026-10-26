# terraform-aws-wordpress-ha

Terraform configuration for a highly available WordPress deployment on AWS.
It runs the [wordpress-shop-demo](https://github.com/egeeuzun/wordpress-shop-demo)
image (the *Yerel Market* WooCommerce store) and is the starting point of a
project that moves the store from Frankfurt to the AWS Istanbul Local Zone.

```
CloudFront (+ WAF)  →  ALB  →  ECS Fargate (WordPress)  →  RDS MariaDB (+ read replica)
       │                                  │                 ElastiCache
       └── S3 (static / media, OAC)       └── EFS (optional: uploads, plugins, themes)
```

## Layout

| Path | What it is |
| --- | --- |
| `bootstrap/` | Run once per account: S3 bucket for Terraform state and a monthly AWS Budgets alarm. Local state. |
| `envs/frankfurt-baseline/` | Phase 1 baseline: Frankfurt, Fargate, RDS. Stateless tasks (no EFS, media on S3). |
| `main/` | The root module every environment calls. |
| `modules/` | The building blocks below. |
| `docs/00-envanter.md` | Inventory of what this repo and the image deploy (in Turkish). |

## Modules

| Module | Purpose |
| --- | --- |
| `network` | VPC with public / app / data subnets across `az_count` AZs, NAT gateway per AZ |
| `security` | Security groups for each tier |
| `alb` | Application Load Balancer, target group, health checks |
| `ecs` | Fargate service, task definition, autoscaling, ECS Exec |
| `ecr` | Container registry for the WordPress image |
| `rds` | MariaDB with optional read replica and Multi-AZ standby |
| `elasticache` | Object cache |
| `efs` | Optional shared `wp-content/uploads` (and `plugins`/`themes`) across tasks |
| `s3` | Static and media bucket with versioning and lifecycle rules |
| `cdn` | CloudFront distribution, S3 origin via OAC, WAF |
| `backup` | AWS Backup plan and vault |
| `vpn` | Pritunl VPN server for admin access to private subnets |
| `cicd` | CodePipeline and CodeBuild for image build and ECS deploy |

## Usage

**1. Bootstrap (once per account)**

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars   # set budget_emails
terraform init && terraform apply
terraform output -raw backend_hcl > ../envs/frankfurt-baseline/backend.hcl
```

AWS sends a confirmation e-mail for the budget alarm; nothing arrives until you
accept it. The state bucket has `prevent_destroy`.

**2. An environment**

```bash
cd envs/frankfurt-baseline
cp terraform.tfvars.example terraform.tfvars   # admin IPs, CI/CD connection
terraform init -backend-config=backend.hcl
terraform apply
```

State is locked with S3's own lock file (`use_lockfile`), so there is no
DynamoDB table. Every resource gets the default tags `project=lz-woo`,
`phase`, `environment` and `managed-by`.

**3. Fill the store**

Push the image through the CI/CD pipeline (or set `container_image`), finish the
WordPress install, then run the seed kit in a task with ECS Exec:

```bash
aws ecs execute-command --cluster <ecs_cluster_name> --task <TASK_ID> --container wordpress \
  --interactive --command "su -s /bin/sh www-data -c 'wp eval-file /usr/src/shop-seed/seed.php'"
```

All input variables are documented in `main/variables.tf`.

### Moving from the old `env/` directory

`env/test_prod.tf` became `envs/frankfurt-baseline`. Its local state is not
moved automatically. To keep the existing resources, set `project = "wordpress HA"`
and `env = "Test"` in `terraform.tfvars` (resource names come from these), then:

```bash
terraform init -backend-config=backend.hcl
terraform state push ../../env/terraform.tfstate
terraform plan
```

The baseline turns EFS off. On an existing deployment that destroys the file
system and anything in it; set `enable_efs = true` in `envs/frankfurt-baseline/main.tf`
first if uploads are not yet on S3.

## Notes

- **WordPress salts** are generated with `random_password`, stored in SSM
  Parameter Store under `/<name>/wp-salts/` and passed to the task as
  `WORDPRESS_*` secrets. Without them the image falls back to fixed, public
  defaults. Recreating them logs everyone out.
- **Stateless mode (`enable_efs = false`)** needs `offload_uploads_to_s3 = true`
  and `enable_plugin_installs = false`; the plan stops otherwise. Code comes from
  the image, media from S3, and a task can be replaced without losing anything.
  Local Zones have no EFS, so this keeps the baseline comparable.
- **Task definition changes reach the service.** The ECS service follows the
  Terraform task definition. The CodePipeline deploy copies the service's current
  revision and only swaps the image, so the next `terraform apply` rolls the
  service back to the same image under `:latest`.
- **Data tags.** Resources that hold store data are tagged
  `data-residency=<data_residency>` (default `tr`) and `data-class`
  (`personal` for the database and its replica, snapshots and backups, EFS,
  ElastiCache and the ECS log groups; `non-personal` for the media bucket).
  The residency checks later in the project use these tags.
- The ALB health check uses the image's `/health.php`, which does not load
  WordPress (`health_check_path`).
- `MEMCACHED_HOST` lists every ElastiCache node; the image's client does not do
  auto-discovery.
- `vpn_admin_cidrs` is required when `enable_vpn = true`; `0.0.0.0/0` is rejected.
- The database password is generated with `random_password` and stored in SSM Parameter Store. It (and the salts) are also written to state in plain text; the bootstrap state bucket is encrypted and private.
- `static_bucket_force_destroy` defaults to `true`; set it to `false` in production.
- Enable `offload_uploads_to_s3` only if the container image has a plugin that writes media to S3.

## Requirements

- Terraform >= 1.11 for the `envs/` and `bootstrap/` roots (`main/` alone works with >= 1.5)
- AWS provider >= 5.79, < 6.0
- Configured AWS credentials
