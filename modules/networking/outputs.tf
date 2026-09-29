output "vpc_id" {
  description = "ID of the created VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the created VPC."
  value       = aws_vpc.main.cidr_block
}

output "availability_zones" {
  description = "Availability Zones used for subnet placement."
  value       = local.azs
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (one per AZ, in AZ order)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (one per AZ, in AZ order)."
  value       = aws_subnet.private[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets."
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets."
  value       = aws_subnet.private[*].cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway attached to the VPC."
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateway(s). Single element in \"single\" mode, one per AZ in \"multi_az\" mode."
  value       = aws_nat_gateway.main[*].id
}

output "nat_eip_allocation_ids" {
  description = "Allocation IDs of the Elastic IP(s) backing the NAT Gateway(s)."
  value       = aws_eip.nat[*].id
}

output "public_route_table_id" {
  description = "ID of the shared public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs of the private route table(s). Single element in \"single\" mode, one per AZ in \"multi_az\" mode."
  value       = aws_route_table.private[*].id
}

output "name_prefix" {
  description = "Name prefix applied to resources (<project>-<environment>)."
  value       = local.name_prefix
}
