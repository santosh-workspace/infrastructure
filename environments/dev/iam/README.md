# Phase 2 — IAM (dev)

Identity foundation for the pipeline: EKS service roles, GitHub Actions OIDC
deploy role with a push-only ECR policy, and the official AWS Load Balancer
Controller policy (+ IRSA role once the cluster exists). No users, no access
keys, no `AdministratorAccess` anywhere.

## Architecture

```text
GitHub Actions (OIDC token, aud=sts.amazonaws.com, sub=repo:<owner>/<repo>:ref|environment:...)
  │  sts:AssumeRoleWithWebIdentity (no stored credentials)
  ▼
smart-finance-calculator-dev-github-actions-ecr-push  ──(attached)──▶  *-github-ecr-push policy
  │                                                                     (GetAuthorizationToken + push actions
  ▼                                                                      scoped to ONE ECR repository)
Amazon ECR (Phase 3) — image push only, zero EKS admin rights

EKS control plane (Phase 4) ◀── *-eks-cluster-role (AmazonEKSClusterPolicy)
EKS worker nodes  (Phase 4) ◀── *-eks-node-role    (WorkerNode + CNI + ECR-read-only)

AWS Load Balancer Controller (Phase 4+)
  ServiceAccount kube-system/aws-load-balancer-controller
  │  IRSA: eks.amazonaws.com/role-arn = *-aws-lb-controller
  ▼
*-aws-lb-controller role ◀── official iam_policy.json @ pinned release (always created)
                           (role created once cluster OIDC inputs are known)
```

## Design choices

- **OIDC everywhere, zero long-lived credentials.** GitHub authenticates with
  short-lived JWTs; nodes use instance roles; humans keep using SSO (passed
  through as `administrator_role_arn`, bound in Phase 4).
- **One IAM role per consumer** (cluster, nodes, CI push, controller) instead
  of a shared role, so each trust policy and permission set stays minimal and
  independently revocable.
- **IRSA for the controller, not EKS Pod Identity.** IRSA needs no
  agent, works on every cluster version Phase 4 may create, and the Helm
  chart consumes it via a ServiceAccount annotation. Migration to Pod
  Identity later changes only the association, not the policy.
- **Official controller policy, pinned.** `policies.tf` fetches
  `iam_policy.json` verbatim from the release tag in
  `aws_load_balancer_controller_version` (default `v3.5.0`, requires
  Kubernetes ≥ 1.22). Nothing is approximated — but note `plan/apply`
  needs HTTPS access to `raw.githubusercontent.com`.
- **No duplicate OIDC provider.** AWS allows one provider per issuer URL per
  account. `create_github_oidc_provider = false` +
  `existing_github_oidc_provider_arn` reuses it (with `terraform import`,
  see below) instead of erroring on a duplicate.
- **Pre-cluster safe.** The controller *policy* is always created; the
  controller *role* is created only when `eks_cluster_oidc_issuer_url` and
  `eks_oidc_provider_arn` are both set (Phase 4 outputs). Same idea for ECR:
  the push policy scopes to an explicit ARN when known, otherwise builds it
  from `ecr_repository_name` + account/region (a `data.aws_ecr_repository`
  lookup would fail because Phase 3 hasn't created the repo yet).
- **Explicit `depends_on`: none.** All edges are references Terraform infers
  (role → policy ARN, trust → provider ARN).

## Permission reference

### EKS cluster role (`*-eks-cluster-role`)

| Item | Detail |
|---|---|
| Trust | `eks.amazonaws.com` via `sts:AssumeRole` (control plane only) |
| `AmazonEKSClusterPolicy` (AWS-managed) | Create/describe ENIs, SGs, CloudWatch log groups for the control plane |
| NOT attached | `AmazonEKSVPCResourceController` — add in Phase 4 **only** if you enable security-groups-for-pods |

### EKS node role (`*-eks-node-role`, EC2 trust, no admin)

| Policy (all AWS-managed) | Grants |
|---|---|
| `AmazonEKSWorkerNodePolicy` | `ec2:Describe*` + autoscaling calls nodes need to join/scale |
| `AmazonEKS_CNI_Policy` | ENI/IP management for the VPC CNI (`aws-node`) incl. `ec2:AssignPrivateIpAddresses`, `ec2:CreateNetworkInterface` (ships with `Resource: "*"` — constrained by EC2 condition keys inside the AWS-managed text) |
| `AmazonEC2ContainerRegistryReadOnly` | `ecr:GetAuthorizationToken` (`*`, account-scoped by AWS design) + `ecr:BatchGetImage`, `ecr:GetDownloadUrlForLayer`, `ecr:BatchCheckLayerAvailability` on `*` (ECR read actions don't support tighter scoping for pulls across repos) — lets nodes **pull** images |

**CNI note:** keeping `AmazonEKS_CNI_Policy` on the node role is the default
working setup. The least-privilege upgrade (Phase 4) is a dedicated IRSA role
for ServiceAccount `kube-system:aws-node` carrying that one policy, then
detaching it here — required anyway if you use Pod Identity or prefix
delegation with custom networking.

### GitHub Actions role (`*-github-actions-ecr-push`)

Trust (both conditions required):

- `StringEquals token.actions.githubusercontent.com:aud = sts.amazonaws.com`
- `StringLike  token.actions.githubusercontent.com:sub ∈ {repo:<owner>/<repo>:ref:<ref> | repo:<owner>/<repo>:environment:<name>, + extras}`

No wildcard repo trust: exactly one repo, one ref or environment, plus only
the subjects you list in `github_additional_subjects`.

Attached push-only policy (`*-github-ecr-push`, customer-managed):

| Action | Resource | Why |
|---|---|---|
| `ecr:GetAuthorizationToken` | `*` | **Must be `*`**: account-scoped login, AWS offers no resource constraint |
| `ecr:BatchCheckLayerAvailability` | repo ARN | Skip layers already present ("checking the target repository") |
| `ecr:InitiateLayerUpload` | repo ARN | Start layer uploads |
| `ecr:UploadLayerPart` | repo ARN | Upload layer chunks |
| `ecr:CompleteLayerUpload` | repo ARN | Finish layer uploads |
| `ecr:PutImage` | repo ARN | Push the manifest |

Nothing else: no `ecr:CreateRepository` (Phase 3 owns repos), no EKS/EC2/ALB
rights, so a compromised workflow can at worst push to **one** repo.

### Controller policy + role (`*-aws-lb-controller`)

- Policy = official `iam_policy.json` @ pinned release (ELB/ACM/WAF/Shields
  describe+modify calls the controller needs; several are `Resource: "*"`
  because ELB tag-based scoping isn't expressive enough for discovery calls —
  that breadth comes from AWS's document, not from us).
- Role trust (created post-cluster): federated to the cluster OIDC provider,
  `aud = sts.amazonaws.com`, `sub = system:serviceaccount:kube-system:aws-load-balancer-controller`
  (both namespace and name pinned via variables).

### Human administration

`administrator_role_arn` creates **nothing** in this phase — it is echoed to
outputs for Phase 4, which will create `aws_eks_access_entry` +
`aws_eks_access_policy_association` (`AmazonEKSClusterAdminPolicy`, cluster
scope). Supply your SSO admin role ARN; never invent users (none are created).

## GitHub workflow (OIDC token)

```yaml
permissions:
  id-token: write   # required: mints the OIDC JWT
  contents: read    # required: actions/checkout

- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}  # = github_actions_role_arn output
    aws-region: eu-central-1
```

`configure-aws-credentials` calls `sts:AssumeRoleWithWebIdentity` with the
JWT; the `sub` claim is `repo:<owner>/<repo>:ref:refs/heads/<branch>` for
branch runs (or `…:environment:<name>` when the job sets `environment:` —
then set `github_environment` to match). Tags/pushes to other branches are
rejected by the `StringLike` condition.

## Usage

```bash
cd environments/dev/iam
# edit ../global.tfvars: fill github_owner/github_repository at minimum
terraform init
terraform fmt -check
terraform validate
terraform plan -var-file=../global.tfvars -out=tfplan
terraform apply tfplan
```

After Phase 4 exists, re-run with `eks_cluster_oidc_issuer_url` /
`eks_oidc_provider_arn` (and optionally `ecr_repository_arn`,
`administrator_role_arn`) set to create the controller IRSA role.

## Verification (AWS CLI)

```bash
PREFIX=smart-finance-calculator-dev
OIDC=$(terraform output -raw github_oidc_provider_arn)

# Roles exist with Phase tags, no AdministratorAccess attached
for R in $PREFIX-eks-cluster-role $PREFIX-eks-node-role $PREFIX-github-actions-ecr-push; do
  aws iam get-role --role-name $R --query 'Role.{Name:RoleName,Arn:Arn}'
  aws iam list-attached-role-policies --role-name $R --query 'AttachedPolicies[*].PolicyArn'
done

# Trust policies: EKS/EC2 services only; GitHub role federated to one repo
aws iam get-role --role-name $PREFIX-eks-cluster-role --query 'Role.AssumeRolePolicyDocument'
aws iam get-role --role-name $PREFIX-github-actions-ecr-push --query 'Role.AssumeRolePolicyDocument'

# OIDC provider (exactly one per account for this issuer)
aws iam list-open-id-connect-providers
aws iam get-open-id-connect-provider --open-id-connect-provider-arn $OIDC

# ECR push policy is scoped to one repo (+ unavoidable GetAuthorizationToken on *)
aws iam get-policy --policy-arn $(terraform output -raw ecr_publish_policy_arn)
aws iam get-policy-version \
  --policy-arn $(terraform output -raw ecr_publish_policy_arn) \
  --version-id $(aws iam get-policy --policy-arn $(terraform output -raw ecr_publish_policy_arn) --query 'Policy.DefaultVersionId' --output text)

# Controller policy version pin
terraform output lb_controller_policy_version
```

## Importing / reusing existing resources

Terraform never adopts existing IAM silently. If the account already has any
of these, import instead of letting apply fail on `EntityAlreadyExists`:

```bash
# OIDC provider (import ID = ARN), then set create_github_oidc_provider=false
# and existing_github_oidc_provider_arn to the same ARN
terraform import 'module.iam.aws_iam_openid_connect_provider.github[0]' \
  'arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com'

terraform import 'module.iam.aws_iam_role.eks_cluster' \
  'smart-finance-calculator-dev-eks-cluster-role'
terraform import 'module.iam.aws_iam_role.eks_node' \
  'smart-finance-calculator-dev-eks-node-role'
terraform import 'module.iam.aws_iam_role.github_actions' \
  'smart-finance-calculator-dev-github-actions-ecr-push'
terraform import 'module.iam.aws_iam_policy.github_ecr_push' \
  'arn:aws:iam::123456789012:policy/smart-finance-calculator-dev-github-ecr-push'
```

Check first with `aws iam get-role --role-name <name>` /
`aws iam list-open-id-connect-providers` to see what exists.

## Cleanup

```bash
cd environments/dev/iam
terraform destroy -var-file=../global.tfvars
```

IAM has no hourly cost; destroy order matters only in that Phase 4 must be
deleted first (cluster/node groups reference these role ARNs — deleting roles
first strands the cluster). Detach-before-delete is handled by Terraform.

## Outputs for later phases

- **Phase 3 (ECR)**: `github_actions_role_arn` (workflow identity),
  `ecr_repository_arn` / `ecr_repository_name` (must match the repo Phase 3
  creates, then feed the real ARN back here), `account_id`.
- **Phase 4 (EKS)**: `eks_cluster_role_arn`, `eks_node_role_name`/`_arn`,
  `lb_controller_policy_arn`; feed the cluster's OIDC issuer URL and IAM
  OIDC provider ARN back into `eks_cluster_oidc_issuer_url` /
  `eks_oidc_provider_arn` to materialize `lb_controller_role_arn`;
  `administrator_role_arn` → access entries; `github_oidc_provider_arn`
  if Phase 4 needs federated-trust references.

## Cost and security notes

- **Cost: IAM is free** (roles, policies, OIDC providers, STS calls). No
  hourly or per-GB charges in this phase — unlike Phase 1 NAT Gateways.
- Least privilege throughout: push-only CI policy, separate cluster/node
  roles, no users/keys/`AdministratorAccess`.
- `Resource: "*"` appears only where AWS makes it mandatory
  (`GetAuthorizationToken`, ECR pull reads, CNI ENI calls, controller
  discovery calls) — each case is called out above.
- Never commit `terraform.tfvars` (gitignored); role ARNs in outputs are
  identifiers, not secrets, and are safe to share with Phase 3/4.
