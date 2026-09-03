# terraform-aws-wordpress-ha

Terraform configuration for a highly available WordPress deployment on AWS.

```
CloudFront (+ WAF)  →  ALB  →  ECS Fargate (WordPress)  →  RDS MariaDB (+ read replica)
       │                                  │                 ElastiCache
       └── S3 (static / media, OAC)       └── EFS (wp-content)
```

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
| `efs` | Shared `wp-content` across tasks |
| `s3` | Static and media bucket with versioning and lifecycle rules |
| `cdn` | CloudFront distribution, S3 origin via OAC, WAF |
| `backup` | AWS Backup plan and vault |
| `vpn` | Pritunl VPN server for admin access to private subnets |
| `cicd` | CodePipeline and CodeBuild for image build and ECS deploy |

## Usage

```bash
cd env
terraform init
terraform plan
terraform apply
```

`env/test_prod.tf` is an example environment: provider setup, inputs for the `../main` module, and outputs. Copy and edit it for your own environment. If CI/CD is enabled, replace the `codestar_connection_arn` and `repository_id` placeholders.

All input variables are documented in `main/variables.tf`.

## Notes

- `vpn_admin_cidrs` is required when `enable_vpn = true`; `0.0.0.0/0` is rejected.
- The database password is generated with `random_password` and stored in SSM Parameter Store. It is also written to state in plain text, so encrypt your remote state.
- `static_bucket_force_destroy` defaults to `true`; set it to `false` in production.
- Enable `offload_uploads_to_s3` only if the container image has a plugin that writes media to S3.

## Requirements

- Terraform >= 1.5
- AWS provider >= 5.79, < 6.0
- Configured AWS credentials
