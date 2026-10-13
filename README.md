# AWS Terraform Lab

![terraform](https://github.com/MindseyeX/aws-terraform/actions/workflows/terraform.yml/badge.svg)

Modular Terraform that builds a highly available AWS environment from scratch: a multi-AZ VPC, an Auto Scaling Linux web tier, and a load balancer and supporting services. Built to be destroyed and rebuilt on demand.

## Architecture

```
                    Internet
                       |
               [Internet Gateway]
                       |
        +--------------+--------------+
        |                             |
  public subnet AZ-a           public subnet AZ-b
  10.10.0.0/24                 10.10.1.0/24
  [NAT Gateway]                (ALB - phase 3)
        |                             |
  private subnet AZ-a          private subnet AZ-b
  10.10.10.0/24                10.10.11.0/24
  [EC2 AL2023 + nginx]         [EC2 AL2023 + nginx]
        \                             /
         +------ Auto Scaling Group -+
                 (SSM access, no SSH)
```

## Layout

```
bootstrap/          S3 bucket for remote state (local state, run once per sandbox)
modules/network/    VPC, subnets, IGW, NAT, routing
modules/compute/    Launch template, Auto Scaling Group, IAM role for SSM, cloud-init
envs/dev/           Root module for the dev environment
.github/workflows/  CI: fmt, validate, tflint, checkov
```

## Deploy

Requirements: Terraform >= 1.11 and AWS credentials(`aws sts get-caller-identity` should work).

```bash
# 1. Create the state bucket (also writes envs/dev/backend.hcl)
cd bootstrap
terraform init
terraform apply

# 2. Deploy the dev environment
cd ../envs/dev
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
```

## Connect to a server

No SSH keys or open ports: instances are reached through AWS Systems Manager Session Manager. Requires the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) for the AWS CLI.

```bash
cd envs/dev
eval "$(terraform output -raw list_instances)"   # list running web servers
aws ssm start-session --target <instance-id>      # shell on one of them
curl -s localhost | grep -E 'Instance|Zone'       # (inside) the page nginx serves
curl -s localhost/healthz                         # (inside) health endpoint -> ok
```

## Tear down

Destroy in reverse order: the environment first, then the bucket that holds its state.

```bash
cd envs/dev  && terraform destroy
cd ../../bootstrap && terraform destroy
```

## Roadmap

- [x] Phase 1: networking (VPC, subnets, NAT, routing) and remote state
- [x] Phase 2: compute module (launch template, ASG, AL2023, cloud-init, SSM access)
- [x] Phase 3: Application Load Balancer (target group, `/healthz` health checks, SG-to-SG rules) and CPU target-tracking auto scaling with rolling instance refresh
- [ ] Phase 4: Ansible over SSM (dynamic inventory, CIS-style hardening, compliance check)
