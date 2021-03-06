output "rds_endpoint" {
  value       = coalesce(aws_rds_cluster.kong.*.endpoint)
  description = "The endpoint for the Kong database"
}

output "rds_password" {
  sensitive   = true
  value       = random_string.db_password.result
  description = "The database password for Kong"
}

output "master_password" {
  sensitive   = true
  value       = random_string.master_password.result
  description = "The master password for Kong"
}

output "admin_token" {
  sensitive   = true
  value       = random_string.admin_token.result
  description = "The admin token for Kong"
}

output "lb_endpoint_external" {
  value       = coalesce(aws_lb.external.*.dns_name)
  description = "The external load balancer endpoint"
}
output "lb_external_arn" {
  value       = coalesce(aws_lb.external.*.arn)[0]
  description = "The external load balancer endpoint"
}

output "lb_endpoint_internal" {
  value       = coalesce(aws_lb.internal.*.dns_name)
  description = "The internal load balancer endpoint"
}

output "lb_endpoint_internal-admin" {
  value       = coalesce(aws_lb.internal-admin.*.dns_name)
  description = "The internal load balancer endpoint only for admin access to kong - DO NOT use this output if using Enterprise Edition"
}

output "admin_service_lb_sg" {
  value       = coalesce(aws_security_group.admin_service_lb_access.id) 
  description = "The internal load balancer security group any AWS resource that wants access to the admin load balancer will need this sg"
}
output "direct_admin_access_sg" {
  value       = coalesce(aws_security_group.direct_admin_access.id) 
  description = "The security group any AWS resource that wants access directly to kong"
}

