# -----------------------------------------------------------------------------
# Compute module: Auto Scaling Group of Amazon Linux 2023 web servers
#
#   private subnet AZ-a        private subnet AZ-b
#   +-----------------+        +-----------------+
#   | EC2 (nginx)     |        | EC2 (nginx)     |   <- launched from one
#   +-----------------+        +-----------------+      launch template
#            \                        /
#             +---- Auto Scaling ----+   keeps desired_capacity running,
#                                        replaces unhealthy instances
#
# Access is through SSM Session Manager - no SSH keys, no port 22, no bastion.
# Outbound traffic (package installs, SSM) leaves through the NAT gateway.
# -----------------------------------------------------------------------------

# Latest Amazon Linux 2023 AMI, published by AWS as a public SSM parameter.
# New launches always get a patched image without hardcoding an AMI ID.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Provider default_tags don't reach instances/volumes launched by an ASG,
# so read them here and copy them into the launch template's tag_specifications.
data "aws_default_tags" "current" {}

locals {
  instance_tags = merge(data.aws_default_tags.current.tags, var.tags, {
    Name = "${var.name}-web"
  })
}

# --- IAM: let instances talk to SSM ------------------------------------------

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "web" {
  name               = "${var.name}-web-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = var.tags
}

# AWS-managed policy with exactly what the SSM agent needs: register the
# instance, open Session Manager shells, and receive Run Command jobs.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "web" {
  name = "${var.name}-web-profile"
  role = aws_iam_role.web.name

  tags = var.tags
}

# --- Security group -----------------------------------------------------------
# No inbound rules at all. SSM works over an OUTBOUND connection from the
# agent, so the instances need nothing open. Phase 3 adds a single rule:
# port 80, from the load balancer's security group only.

resource "aws_security_group" "web" {
  name        = "${var.name}-web-sg"
  description = "Web instances: no inbound by default; outbound for updates and SSM"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-web-sg" })
}

resource "aws_vpc_security_group_egress_rule" "web_all" {
  security_group_id = aws_security_group.web.id
  description       = "Outbound to anywhere (via NAT): dnf repos, SSM endpoints"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- Launch template ------------------------------------------------------------

resource "aws_launch_template" "web" {
  name_prefix   = "${var.name}-web-"
  description   = "Amazon Linux 2023 + nginx, configured by cloud-init"
  image_id      = data.aws_ssm_parameter.al2023.insecure_value # an AMI ID isn't secret; this keeps it visible in plans
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.web.arn
  }

  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = base64encode(templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
    name        = var.name
    environment = var.environment
  }))

  # IMDSv2 only: the instance metadata service requires a session token,
  # which blocks the SSRF-style credential theft IMDSv1 allowed.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = local.instance_tags
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.instance_tags
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# --- Auto Scaling Group ---------------------------------------------------------

resource "aws_autoscaling_group" "web" {
  name                = "${var.name}-web-asg"
  vpc_zone_identifier = var.subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity

  # EC2 = replace instances that fail EC2 status checks.
  # Phase 3 switches this to "ELB" so the load balancer's HTTP health check
  # decides, which also catches a crashed nginx on a running instance.
  health_check_type         = "EC2"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  # When the launch template changes (new AMI, edited cloud-init, bigger
  # instance type), replace instances gradually instead of all at once.
  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-web"
    propagate_at_launch = false # instances get Name from the launch template
  }

  dynamic "tag" {
    for_each = var.tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = false
    }
  }
}
