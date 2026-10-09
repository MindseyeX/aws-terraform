# AWS Terraform Lab

Modular Terraform that builds a highly available AWS environment from scratch: a multi-AZ VPC, an Auto Scaling Linux web tier behind a load balancer, and supporting services. Built to be destroyed and rebuilt on demand.

## Architecture (Phase 1)

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
  (EC2/ASG, RDS)               (EC2/ASG, RDS)
```

## Layout

```
bootstrap/          S3 bucket for remote state (local state, run once per sandbox)
modules/network/    VPC, subnets, IGW, NAT, routing
envs/dev/           Root module for the dev environment
.github/workflows/  CI: fmt, validate, tflint, checkov
```

## Deploy

Requirements: Terraform >= 1.11 and AWS credentials for your sandbox (`aws sts get-caller-identity` should work).

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

## Tear down

Destroy in reverse order: the environment first, then the bucket that holds its state.

```bash
cd envs/dev  && terraform destroy
cd ../../bootstrap && terraform destroy
```

## Design decisions

- **`for_each` keyed by AZ name, not `count`.** Removing an AZ deletes only that AZ's subnets. With `count`, removing an item in the middle shifts indexes and recreates everything after it.
- **Subnet CIDRs calculated with `cidrsubnet()`.** Changing `vpc_cidr` re-derives every subnet; there are no hardcoded ranges to keep in sync.
- **No public IPs by default.** `map_public_ip_on_launch = false`; only the ALB and NAT face the internet. Instances live in private subnets and are reached through SSM Session Manager (phase 2), not SSH.
- **Default security group locked down.** The VPC's default SG has all rules removed, so nothing can be launched into it by accident (CIS AWS benchmark).
- **Single vs per-AZ NAT is one variable.** `single_nat_gateway = true` keeps dev cheap. Setting it to `false` gives each AZ its own NAT so an AZ outage doesn't cut egress for the others. The private route tables are already per-AZ, so the switch changes routes only.
- **Remote state in S3 with native locking.** `use_lockfile = true` uses S3 conditional writes for locking (Terraform 1.11+), so no DynamoDB table is needed. The bucket is versioned, encrypted, private, and TLS-only.
- **Partial backend config.** Sandbox account IDs change between sessions, so the bucket name lives in a generated `backend.hcl` rather than in code.

## Roadmap

- [x] Phase 1: networking (VPC, subnets, NAT, routing) and remote state
- [ ] Phase 2: compute module (launch template, ASG, AL2023/RHEL, cloud-init, SSM instance profile)
- [ ] Phase 3: ALB, S3, RDS, CloudWatch alarms + SNS
- [ ] Phase 4: prod environment, VPC flow logs, Ansible configuration
