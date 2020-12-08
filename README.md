# Key Info
- supports Kong 2.x (check tags) "kong-2.2.0"
- admin only exposed via an admin ELB for dns access and sg security, admin port used for internal and external for lb healthcheck, but not listened on.
- only Community Edition (CE) only
- Linux 2 ami's used instead of ubuntu
- prometheus plugin enabled by default (prometheus not required)

PR's welcomed.
## Example

main.tf:
```
module "kong" {
  source = "github.com/miketwenty1/kong-terraform-aws?ref=1.0.0"
  vpc                           = "${var.env}_vpc"
  environment                   = "dev"
  redis_subnets                 = aws_elasticache_subnet_group.elasti_sub.name
  db_subnets                    = aws_db_subnet_group.rds_sub.id
  default_security_group        = aws_security_group.kong_default.name
  ec2_key_name                  = data.terraform_remote_state.base.outputs.ssh_key_name
  ssl_cert_admin                = data.terraform_remote_state.base.outputs.acm_cert_domain_extended # if you want extended for "admin.*.domain.example" 
  ssl_cert_external             = data.terraform_remote_state.base.outputs.acm_cert_domain          # if you want "*.domain.example"
  ssl_cert_internal             = data.terraform_remote_state.base.outputs.acm_cert_domain
  ssl_cert_manager              = data.terraform_remote_state.base.outputs.acm_cert_domain
  ssl_cert_portal               = data.terraform_remote_state.base.outputs.acm_cert_domain
  enable_internal_admin_lb      = true
  enable_redis                  = true
  enable_deletion_protection    = false
  asg_health_check_grace_period = 1800
  ec2_instance_type             = "t3a.small"
  enable_external_lb            = true
  cloudwatch_actions            = [data.aws_sns_topic.ops.arn] # topic to publish cloudwatch alerts to

  tags = local.common_tags
  
  providers = {
    aws = aws.env
  }
}
```

## Important Outputs

- **admin_service_lb_sg** (for use to help lock down the admin ELB)
- **lb_endpoint_internal-admin** (for use with route53 / CNAMES / direct access)
- **lb_endpoint_internal** (for use with route53 / CNAMES / direct access)
- **lb_endpoint_external** (for use with route53 / CNAMES / direct access)


# Kong Cluster Terraform Module for AWS

[Kong API Gateway](https://konghq.com/) is an API gateway microservices
management layer. Both Kong and Enterprise Edition are supported.

By default, the following resources will be provisioned:

- RDS PostgreSQL database for Kong's configuration store
- An Auto Scaling Group (ASG) and EC2 instances running Kong (Kong nodes)
- An external load balancer (HTTPS only)
  - HTTPS:443 - Kong Proxy
- An internal load balancer (HTTP and HTTPS)
  - HTTP:80 - Kong Proxy
  - HTTPS:443 - Kong Proxy
- admin load balancer (HTTP and HTTPS)
  - HTTPS:443 - Kong Proxy
- Security groups granting least privilege access to resources
- An IAM instance profile for access to Kong specific SSM Parameter Store 
  metadata and secrets

Optionally, a redis cluster can be provisioned for rate-limiting counters and
caching, and most default resources can be disabled.  See variables.tf for a
complete list and description of tunables. 

The Kong nodes are based on [Minimal Ubuntu](https://wiki.ubuntu.com/Minimal).
Using cloud-init, the following is provisioned on top of the AMI:

- A kong service user
- Minimal set of dependencies and debugging tools
- decK for Kong declarative configuration management
- Kong, running under runit process supervision
- Log rotation of Kong log files

Prerequisites:

- An AWS VPC
- Private and public subnets tagged with a subnet_tag (default = 'Tier' tag) 
  - (Tags must be explict)! (Tier = "public") and (Tier "private")
- Database subnet group
- Cache subnet group (if enabling Redis)
- An SSH Key
- An SSL managed certificate to associate with HTTPS load balancers
