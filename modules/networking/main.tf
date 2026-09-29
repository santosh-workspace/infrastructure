# ------------------------------------------------------------------------------
# Networking module: VPC, subnets, IGW, NAT, route tables.
# Phase 1 only — no IAM, EKS, ALB, DNS, or monitoring resources.
# ------------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Distinct, sorted AZs so subnet placement is deterministic.
  # slice() fails loudly if the region has fewer AZs than requested.
  azs      = slice(sort(data.aws_availability_zones.available.names), 0, var.availability_zone_count)
  az_count = var.availability_zone_count

  # Derive /24 subnets from the VPC CIDR when the caller passes empty lists.
  # Public subnets take net numbers  0..N-1, private subnets take 10..10+N-1,
  # so the two ranges can never overlap for az_count <= 4 with a /16 VPC
  # (and remain valid for /17-/20 VPCs; explicit CIDRs are required otherwise).
  effective_public_cidrs = length(var.public_subnet_cidrs) > 0 ? var.public_subnet_cidrs : [
    for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 8, i)
  ]
  effective_private_cidrs = length(var.private_subnet_cidrs) > 0 ? var.private_subnet_cidrs : [
    for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 10)
  ]

  nat_count = var.nat_gateway_mode == "single" ? 1 : local.az_count

  base_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Phase       = "phase-1-networking"
    },
    var.common_tags
  )
}

# Cross-variable guard: variable validation blocks can only reference their own
# variable, so subnet-count mismatches are caught here before any resource is
# created. terraform_data is a no-op resource used purely for preconditions.
resource "terraform_data" "input_validation" {
  input = {
    az_count      = var.availability_zone_count
    public_len    = length(var.public_subnet_cidrs)
    private_len   = length(var.private_subnet_cidrs)
    public_cidrs  = local.effective_public_cidrs
    private_cidrs = local.effective_private_cidrs
  }

  lifecycle {
    precondition {
      condition     = length(var.public_subnet_cidrs) == 0 || length(var.public_subnet_cidrs) == var.availability_zone_count
      error_message = "public_subnet_cidrs must be empty (auto-derive) or contain exactly availability_zone_count entries."
    }

    precondition {
      condition     = length(var.private_subnet_cidrs) == 0 || length(var.private_subnet_cidrs) == var.availability_zone_count
      error_message = "private_subnet_cidrs must be empty (auto-derive) or contain exactly availability_zone_count entries."
    }
  }
}

# --- VPC --------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# --- Internet Gateway --------------------------------------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# --- Subnets -----------------------------------------------------------------
# count (rather than for_each) is used consistently for every AZ-indexed
# resource because subnets/NATs/route tables are positional lists tied to the
# ordered local.azs list. count keeps the index arithmetic (e.g. "private
# subnet i uses NAT GW i in multi_az mode") trivially readable. for_each keyed
# by AZ name would be preferable if AZ membership churned frequently, but AZ
# sets are stable per environment and count produces cleaner diffs here.

resource "aws_subnet" "public" {
  count = local.az_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.effective_public_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.base_tags, {
    Name                     = "${local.name_prefix}-public-${local.azs[count.index]}"
    Type                     = "public"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "private" {
  count = local.az_count

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.effective_private_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.base_tags, {
    Name                              = "${local.name_prefix}-private-${local.azs[count.index]}"
    Type                              = "private"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# --- NAT Gateways ------------------------------------------------------------

resource "aws_eip" "nat" {
  count = local.nat_count

  domain = "vpc"

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-nat-eip-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count = local.nat_count

  allocation_id = aws_eip.nat[count.index].id
  # single mode: NAT lives in the first public subnet; multi_az: NAT i in public subnet i.
  subnet_id = aws_subnet.public[var.nat_gateway_mode == "single" ? 0 : count.index].id

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# --- Route tables ------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.base_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count = local.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count = local.nat_count

  vpc_id = aws_vpc.main.id

  tags = merge(local.base_tags, {
    Name = var.nat_gateway_mode == "single" ? "${local.name_prefix}-private-rt" : "${local.name_prefix}-private-rt-${local.azs[count.index]}"
  })
}

resource "aws_route" "private_nat" {
  count = local.nat_count

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id
}

resource "aws_route_table_association" "private" {
  count = local.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.nat_gateway_mode == "single" ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}
