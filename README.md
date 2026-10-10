# AWS Terraform Lab

![terraform](https://github.com/MindseyeX/aws-terraform/actions/workflows/terraform.yml/badge.svg)

Modular Terraform that builds a highly available AWS environment from scratch: a multi-AZ VPC, an Auto Scaling Linux web tier, and (next) a load balancer and supporting services. Built to be destroyed and rebuilt on demand.

## Architecture (Phase 2)

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

## Design decisions

### Network
- **`for_each` keyed by AZ name, not `count`.** Removing an AZ deletes only that AZ's subnets. With `count`, removing an item in the middle shifts indexes and recreates everything after it.
- **Subnet CIDRs calculated with `cidrsubnet()`.** Changing `vpc_cidr` re-derives every subnet; there are no hardcoded ranges to keep in sync.
- **No public IPs by default.** `map_public_ip_on_launch = false`; only the ALB and NAT face the internet.
- **Default security group locked down.** The VPC's default SG has all rules removed, so nothing can be launched into it by accident (CIS AWS benchmark).
- **Single vs per-AZ NAT is one variable.** `single_nat_gateway = true` keeps dev cheap. Setting it to `false` gives each AZ its own NAT so an AZ outage doesn't cut egress for the others. The private route tables are already per-AZ, so the switch changes routes only.

### Compute
- **SSM Session Manager instead of SSH.** The web security group has *zero* inbound rules. The SSM agent makes an outbound connection, so there are no keys to manage, no port 22, no bastion host, and every session is logged by AWS.
- **AMI from AWS's public SSM parameter**, not a hardcoded ID. New launches always get the latest patched Amazon Linux 2023 image.
- **IMDSv2 required.** The instance metadata service only answers requests carrying a session token, which blocks the SSRF-style credential theft IMDSv1 allowed.
- **Encrypted gp3 root volumes**, defined in the launch template.
- **cloud-init via `templatefile()`.** Server configuration is code, versioned alongside the infrastructure. Changing it rolls out automatically (next point).
- **Rolling instance refresh.** When the launch template changes, the ASG replaces instances gradually while keeping at least 50% healthy, instead of all at once.
- **Default tags reach instances.** Provider `default_tags` don't propagate to ASG-launched instances, so the module reads them with `data.aws_default_tags` and copies them into the launch template's `tag_specifications`.
- **Least-privilege IAM.** Instances get exactly one AWS-managed policy, `AmazonSSMManagedInstanceCore`.

### State
- **Remote state in S3 with native locking.** `use_lockfile = true` uses S3 conditional writes for locking (Terraform 1.11+), so no DynamoDB table is needed. The bucket is versioned, encrypted, private, and TLS-only.
- **Partial backend config.** Sandbox account IDs change between sessions, so the bucket name lives in a generated `backend.hcl` rather than in code.

## Roadmap

- [x] Phase 1: networking (VPC, subnets, NAT, routing) and remote state
- [x] Phase 2: compute module (launch template, ASG, AL2023, cloud-init, SSM access)
- [ ] Phase 3: ALB, S3, RDS, CloudWatch alarms + SNS
- [ ] Phase 4: prod environment, VPC flow logs, Ansible configuration, CI plan via OIDC
