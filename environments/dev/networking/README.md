# Phase 1 — Networking (dev)

Foundation network for the future EKS cluster: one VPC, public + private
subnets across 2 AZs, IGW, NAT Gateway(s), and route tables. No IAM, ECR,
EKS, ALB, DNS, or monitoring resources are created here.

## Architecture

```
                    ┌────────────────── smart-finance-calculator-dev-vpc (10.0.0.0/16) ──────────────────┐
                    │                                                                                     │
  users/internet ──▶│ Internet Gateway                                                                    │
                    │        │                                                                            │
                    │        ▼                                                                            │
                    │  public route table (0.0.0.0/0 → IGW)                                               │
                    │   ┌──────────────┐        ┌──────────────┐                                           │
                    │   │ public AZ-a  │        │ public AZ-b  │  map_public_ip_on_launch = true            │
                    │   │ 10.0.0.0/24  │        │ 10.0.1.0/24  │  tag kubernetes.io/role/elb = 1            │
                    │   │  ★ NAT GW¹   │        │              │  (future ALB lives here)                   │
                    │   └──────────────┘        └──────────────┘                                           │
                    │                                                                                     │
                    │  private route table(s) (0.0.0.0/0 → NAT GW)                                         │
                    │   ┌──────────────┐        ┌──────────────┐                                           │
                    │   │ private AZ-a │        │ private AZ-b │  map_public_ip_on_launch = false           │
                    │   │ 10.0.10.0/24 │        │ 10.0.11.0/24 │  tag kubernetes.io/role/internal-elb = 1   │
                    │   │ (EKS nodes)  │        │ (EKS nodes)  │  (future EKS workers live here)            │
                    │   └──────────────┘        └──────────────┘                                           │
                    └─────────────────────────────────────────────────────────────────────────────────────┘
  ¹ single-NAT dev default: one NAT GW in the first public subnet, shared by all private subnets.
    multi_az mode: one NAT GW per AZ, each private subnet uses its AZ-local NAT GW.
```

## Design choices

- **Reusable module** (`modules/networking`): all network logic lives in the
  module; the dev stack is a thin wrapper (provider + module call + outputs).
  New environments reuse the module with different tfvars.
- **`count` (not `for_each`)** for every AZ-indexed resource (subnets, EIPs,
  NAT GWs, route tables, associations): these are positional lists tied to the
  ordered `local.azs` list, so index arithmetic (`private subnet i → NAT GW i`
  in `multi_az` mode) is trivially readable. `for_each` keyed by AZ name would
  be better if AZ membership churned often, but AZ sets are stable per
  environment and `count` gives cleaner diffs here. The choice is applied
  consistently — no mixing.
- **Auto-derived subnets**: empty `*_subnet_cidrs` derives `/24`s via
  `cidrsubnet(vpc_cidr, 8, …)` (public net numbers `0..N-1`, private
  `10..10+N-1`, never overlapping for ≤ 4 AZs). Explicit CIDRs are accepted
  when you need to fit an existing address plan; count mismatches are rejected
  by a `terraform_data` precondition (variable `validation` blocks cannot
  reference other variables).
- **Sorted AZs**: `slice(sort(data.aws_availability_zones…))` selects only
  AZs available in the configured region, deterministically.
- **Single NAT default**: cheapest dev option (see trade-off below).
- **No custom SGs / NACLs**: the VPC default SG (deny-by-default posture is
  enforced by creating nothing with open ingress) and default NACL are
  sufficient; EKS/ALB create their own SGs later.
- **DNS on**: `enable_dns_support` + `enable_dns_hostnames` are required for
  EKS control-plane ↔ node communication and private AWS API endpoints.
- **Explicit `depends_on` only on EIP/NAT → IGW**: Terraform infers every
  other edge (subnet→VPC, route→IGW/NAT, association→subnet/table). The IGW
  edge is the one exception the AWS API needs (a NAT GW in a VPC without an
  attached IGW cannot serve traffic), so it is declared explicitly.
- **`domain = "vpc"`** on EIPs (the old `vpc = true` argument is deprecated).
- **No hardcoded account/region/IDs**: region comes from `var.aws_region`;
  everything else is derived. Backend is local by default with a commented S3
  template — fill it from Phase 0 outputs, never hardcode.

## NAT trade-off (single vs multi_az)

| | `single` (dev default) | `multi_az` |
|---|---|---|
| NAT GWs / EIPs | 1 / 1 | one per AZ (2 / 2 with default AZ count) |
| Hourly + data-processing cost | ~1× | ~N× (one charge per GW plus per-GB processing on each) |
| Failure mode | AZ outage of the NAT's AZ **or** NAT failure removes outbound internet for **all** private subnets (no image pulls, no AWS API calls from nodes) | Only the affected AZ loses outbound; other AZs keep working |
| Route tables | 1 shared private RT | 1 private RT per AZ, each pointing at its AZ-local NAT |

Use `single` for dev cost savings; use `multi_az` for staging/prod or any
resilience testing. Switching modes replaces NAT/route-table resources and
briefly interrupts private-subnet egress — plan a maintenance window.

## Resources created

| Resource | Configuration |
|---|---|
| `aws_vpc.main` | `var.vpc_cidr`, DNS support + hostnames on, `Name=<project>-<env>-vpc` |
| `aws_internet_gateway.main` | Attached to VPC, target of public `0.0.0.0/0` |
| `aws_subnet.public[*]` | One/AZ, auto or explicit CIDR, public IP on launch **true** (NAT GWs and future public LBs need public addressing), tagged `kubernetes.io/role/elb=1` |
| `aws_subnet.private[*]` | One/AZ, auto or explicit CIDR, public IP on launch **false**, tagged `kubernetes.io/role/internal-elb=1` |
| `aws_eip.nat[*]` | 1 (single) or 1/AZ (multi_az), `domain="vpc"` |
| `aws_nat_gateway.main[*]` | In public subnet(s), `depends_on` IGW |
| `aws_route_table.public` + `aws_route.public_internet` | Single table, `0.0.0.0/0 → IGW`, all public subnets associated |
| `aws_route_table.private[*]` + `aws_route.private_nat[*]` | 1 shared (single) or 1/AZ (multi_az), `0.0.0.0/0 → NAT GW`, private subnets associated accordingly |

## Security groups — intentionally none

No `aws_security_group` is created. The VPC default security group (which
allows no inbound unless you add rules) plus the default NACL is the correct
starting posture: there is nothing listening yet, so any ingress rule would be
dead surface area, and both EKS and the AWS Load Balancer Controller create
and manage their own security groups in later phases:

- **Phase 4 (EKS)** will create: cluster SG (control-plane ↔ nodes, 443) and
  node SG (kubelet, pod-to-pod). Let the `aws_eks_cluster` / node-group
  resources manage these.
- **Phase 5 (load balancer)** will create: ALB SG (world-facing 80/443
  ingress, tightly scoped) managed by the AWS Load Balancer Controller, plus
  pod SGs if security-groups-for-pods is enabled.
- Never add `0.0.0.0/0` ingress in this phase; the only `0.0.0.0/0` entries
  here are **egress routes** (not firewall rules).

## Network ACLs — default is correct

The VPC default NACL (allow all in/out) is left in place. Reasons:

1. Subnet isolation is already enforced by route tables (private subnets have
   no direct internet ingress path) and the absence of public IPs.
2. NACLs are stateless — every allow needs a mirrored ephemeral-port return
   rule, which is error-prone and the #1 cause of "works in one direction"
   outages for newcomers.
3. Stateful filtering belongs in security groups at the workload layer
   (Phases 4–5), where rules track instances/pods instead of raw CIDRs.

Add custom NACLs only later if compliance mandates defense-in-depth, and do it
per-subnet-type with mirrored ephemeral rules (1024–65535).

## Cost notes (this setup is NOT free)

- **NAT Gateway**: billed per-hour per GW + per-GB data processing. It is the
  dominant Phase 1 cost — `single` ≈ 1×, `multi_az` ≈ N×.
- **Elastic IP**: attached EIPs are free while attached to a running NAT GW;
  **unattached EIPs cost money** — a failed `destroy` that orphans an EIP will
  bill you. Verify release after destroy.
- **IGW, VPC, subnets, route tables**: no hourly charge.
- **Destroy carefully**: `terraform destroy` removes NAT GWs/EIPs/IGW/VPC.
  Destroying the VPC while EKS/ALB/RDS from later phases still reference it
  will fail or strand ENIs — always tear down higher phases first.

## Usage

```bash
cd environments/dev/networking

# edit ../global.tfvars (region, VPC settings) as needed

terraform init
terraform fmt -check -recursive   # from repo root, or -check in this dir
terraform validate
terraform plan -var-file=../global.tfvars -out=tfplan
terraform apply tfplan
```

Backend wiring (Phase 0): uncomment the `backend "s3"` block in `main.tf`
with your Phase 0 bucket/key/region (or use `-backend-config` flags), then
`terraform init -migrate-state`.

## Verification (AWS CLI)

```bash
REGION=<your-region>  # e.g. eu-central-1
VPC=$(terraform output -raw vpc_id)

# VPC + DNS settings
aws ec2 describe-vpcs --region $REGION --vpc-ids $VPC \
  --query 'Vpcs[0].{Id:VpcId,Cidr:CidrBlock,DnsSupport:EnableDnsSupport,DnsHostnames:EnableDnsHostnames}'

# Subnets + AZs + Kubernetes discovery tags
aws ec2 describe-subnets --region $REGION \
  --filters "Name=vpc-id,Values=$VPC" \
  --query 'Subnets[*].{Id:SubnetId,AZ:AvailabilityZone,Cidr:CidrBlock,PublicIp:MapPublicIpOnLaunch,ELB:Tags[?Key==`kubernetes.io/role/elb`].Value|[0],InternalELB:Tags[?Key==`kubernetes.io/role/internal-elb`].Value|[0]}' \
  --output table

# IGW attachment
aws ec2 describe-internet-gateways --region $REGION \
  --filters "Name=attachment.vpc-id,Values=$VPC" \
  --query 'InternetGateways[*].{Id:InternetGatewayId,State:Attachments[0].State}'

# NAT GWs + EIPs
aws ec2 describe-nat-gateways --region $REGION \
  --filter "Name=vpc-id,Values=$VPC" \
  --query 'NatGateways[*].{Id:NatGatewayId,State:State,Subnet:SubnetId,EIP:NatGatewayAddresses[0].PublicIp}'

# Routes: public → IGW, private → NAT
aws ec2 describe-route-tables --region $REGION \
  --filters "Name=vpc-id,Values=$VPC" \
  --query 'RouteTables[*].{Id:RouteTableId,Name:Tags[?Key==`Name`].Value|[0],Routes:Routes[*].{Dest:DestinationCidrBlock,Target:GatewayId,NAT:NatGatewayId}}'
```

## Cleanup

```bash
cd environments/dev/networking
terraform destroy -var-file=../global.tfvars
# Then confirm no orphaned EIPs/NAT GWs (unattached EIPs bill hourly):
aws ec2 describe-addresses --region $REGION --query 'Addresses[?AssociationId==null]'
aws ec2 describe-nat-gateways --region $REGION --filter "Name=vpc-id,Values=$VPC" --query 'NatGateways[*].State'
```

Warnings: never `destroy` while later phases (EKS/ALB) exist — delete those
first. `multi_az → single` switches and full destroys both interrupt
private-subnet egress during the operation.

## Outputs for later phases

- **Phase 2 (IAM)**: consumes nothing from Phase 1 outputs (IAM is global),
  but record `vpc_id`/`vpc_cidr` for trust-policy conditions if you scope
  roles by network later.
- **Phase 4 (EKS)** consumes: `vpc_id`, `private_subnet_ids` (node groups),
  `public_subnet_ids` (public load balancers), `availability_zones`,
  `vpc_cidr` (cluster SG rules), and indirectly the `kubernetes.io/role/*`
  subnet tags for load-balancer discovery.
