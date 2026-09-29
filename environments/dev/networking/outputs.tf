output "vpc_id" {
  description = "ID of the dev VPC (consumed by Phase 4 EKS)."
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the dev VPC."
  value       = module.networking.vpc_cidr
}

output "availability_zones" {
  description = "AZs used for subnet placement."
  value       = module.networking.availability_zones
}

output "public_subnet_ids" {
  description = "Public subnet IDs (future ALB placement, Phase 4/5)."
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs (EKS nodes live here, Phase 4)."
  value       = module.networking.private_subnet_ids
}

output "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks."
  value       = module.networking.public_subnet_cidrs
}

output "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks."
  value       = module.networking.private_subnet_cidrs
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = module.networking.internet_gateway_id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateway(s)."
  value       = module.networking.nat_gateway_ids
}

output "public_route_table_id" {
  description = "ID of the shared public route table."
  value       = module.networking.public_route_table_id
}

output "private_route_table_ids" {
  description = "IDs of the private route table(s)."
  value       = module.networking.private_route_table_ids
}
