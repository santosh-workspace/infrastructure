# Phase 3 — Amazon ECR (dev)

One private ECR repository as the single source of truth for Smart Finance
Calculator images: GitHub Actions (Phase 2 OIDC role) pushes, future EKS
nodes pull. No EKS, IAM, networking, DNS, or monitoring changes here.

## Architecture

```text
Developer push to GitHub
  │  tests + docker build
  ▼
GitHub Actions ──(OIDC: sts:AssumeRoleWithWebIdentity, NO keys)──▶ Phase 2 role
  │  ecr:GetAuthorizationToken + push actions scoped to ONE repo ARN
  ▼
ECR private repo smart-finance-calculator  (scan-on-push, MUTABLE in dev)
  │  tags: <commit-SHA> (deploy ref) + latest (convenience) [+ release-*]
  │  lifecycle: keep 10 recent release-*, expire untagged > 7d
  ▼
EKS nodes (Phase 4, ContainerRegistryReadOnly) pull <repo-url>:<SHA>
```

## Design choices

- **Private repository, default AES-256 encryption.** No custom KMS key:
  an extra key adds cost, rotation, and key-policy failure modes with no
  threat-model benefit for dev images. Revisit only for compliance mandates.
- **MUTABLE in dev.** Allows re-pushing `latest` while keeping the commit SHA
  as the real deployment reference. Switch to `IMMUTABLE` for prod so a tag
  can never be silently reused (deployments then pin SHAs/digests).
- **Scan on push (basic scanning).** Currently supported repository-level
  setting; surfaces OS CVEs per image. (Registry-wide *enhanced* scanning via
  Inspector is account-wide config — deliberately out of scope.)
- **`force_delete = false`.** `terraform destroy` refuses while images exist
  instead of wiping them. Set true only for throwaway environments.
- **Same-account = identity policies only.** No `aws_ecr_repository_policy`
  by default: Phase 2 already grants push to the GitHub role and pull to the
  node role. Repository policies are for cross-account sharing — enabled only
  via `cross_account_access_enabled`, pull-only, listed accounts only, never
  public.
- **No registry policy / replication.** Account-wide settings stay untouched.

## Tag strategy (recommended CI/CD)

| Tag | Purpose | Mutability |
|---|---|---|
| `<commit-SHA>` (e.g. `a1b2c3d…`) | **Deployment reference.** Unique, traceable GitHub → image → rollout. GitOps updates the manifest to this tag. | Never overwrite (works on MUTABLE repos by convention, enforced on IMMUTABLE) |
| `latest` | Human convenience (`docker pull` without a tag, local testing) | Overwritten every push — **never deploy from it** |
| `release-<n>` / `v*` | Promotion milestones kept for rollback | Retained by lifecycle rule (last 10) |

Terraform never hardcodes image tags — tags are created by the CI workflow.

## Lifecycle policy (how rules interact with tags)

ECR evaluates rules lowest `rulePriority` first; a matched image is protected
from later rules. Our two rules match **disjoint** sets, so nothing serving
traffic can expire:

1. **Priority 1 — cap `release-*`:** `tagged` + `tagPrefixList = ["release-"]`
   + `imageCountMoreThan: 10` → expire all but the 10 newest. SHA tags,
   `latest`, and `v*` tags are **not matched** and therefore never expired.
2. **Priority 2 — drop dangling manifests:** `untagged` +
   `sinceImagePushed > 7d` → expire. Untagged images arise when a tag moves
   (e.g. `latest` re-pushed); nothing can pull an untagged image by
   reference, so rollback is unaffected.

Rendered JSON is visible via `terraform plan` (`policy` attribute) and
verifiable with the CLI below. Disable entirely with
`lifecycle_policy_enabled = false` (not recommended).

## Existing repository: detect, reuse, or import

**1. Detect** (before anything else):

```bash
aws ecr describe-repositories --repository-names smart-finance-calculator --region <region>
# RepositoryNotFoundException => does not exist, use mode "create".
# Returns details            => it exists, choose 2a or 2b.
```

**2a. Reference without managing (`existing` mode).** Set
`repository_management_mode = "existing"`. Terraform reads the repo via
`data.aws_ecr_repository` (plan fails clearly if the name is wrong) and
manages **only** the lifecycle policy (+ optional cross-account policy) —
never the repository's own settings or images. Safest when another team or a
click-ops setup owns the repo. Note: applying will attach/replace the
*lifecycle policy* on that repo unless `lifecycle_policy_enabled = false`.

**2b. Take over management (`create` mode + import).** Keep
`repository_management_mode = "create"`, then import once:

```bash
cd environments/dev/ecr
terraform init
terraform import 'module.ecr.aws_ecr_repository.this[0]' 'smart-finance-calculator'
```

State implications: import records the live repo (name, mutability,
scan/encryption settings) into state, so the next `plan` shows only drift
corrections (e.g. tags) instead of `EntityAlreadyExists`. The repo's
*images are never touched* by import. Afterwards, Terraform fully owns the
repository settings (deleting the stack could delete the repo — guarded by
`force_delete = false`), so prefer 2a unless you want that ownership.

**Reference vs import:** referencing (`existing`) = Terraform reads, never
deletes or reconfigures the repo; importing = Terraform adopts it and its
future `apply`/`destroy` acts on the repo itself.

## GitHub Actions integration (docs only — workflow lives in the app repo)

```yaml
permissions:
  id-token: write
  contents: read
```

```bash
# Authenticate with the Phase 2 OIDC role (no access keys)
ROLE=$(cd infrastructure/environments/dev/iam && terraform output -raw github_actions_role_arn)
CREDS=$(aws sts assume-role-with-web-identity \
  --role-arn "$ROLE" --role-session-name "gha-$GITHUB_SHA" \
  --web-identity-token "$ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output text)
# (In practice use aws-actions/configure-aws-credentials@v4 with role-to-assume.)

# Push (REPO = phase-3 output repository_url, e.g. 123456789012.dkr.ecr.eu-central-1.amazonaws.com/smart-finance-calculator)
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin "$REPO"
docker build -t "$REPO:$GITHUB_SHA" -t "$REPO:latest" .
docker push "$REPO:$GITHUB_SHA"
docker push "$REPO:latest"
```

Permission split: the **GitHub role** holds *push* rights (Phase 2 policy);
**EKS nodes** hold *pull* rights (`AmazonEC2ContainerRegistryReadOnly`,
Phase 2 node role). Neither side gets the other's rights, and the GitHub
role has zero EKS admin permissions.

## Usage

```bash
cd environments/dev/ecr
# edit ../global.tfvars (region, repository_name) as needed
terraform init
terraform fmt -check
terraform validate
terraform plan -var-file=../global.tfvars -out=tfplan
terraform apply tfplan
terraform output repository_url   # hand to CI + Phase 4
```

After apply, feed `repository_arn` back into Phase 2 `ecr_repository_arn`
for an exact (rather than constructed) push-policy scope.

## Verification (AWS CLI)

```bash
REGION=<your-region>; REPO=smart-finance-calculator

# Repository: private, mutable/immutable, scan-on-push, tags
aws ecr describe-repositories --repository-names $REPO --region $REGION \
  --query 'repositories[0].{Uri:repositoryUri,Arn:repositoryArn,Mutability:imageTagMutability,Scan:imageScanningConfiguration,Encryption:encryptionConfiguration}'

# Lifecycle policy (valid JSON, two rules)
aws ecr get-lifecycle-policy --repository-name $REPO --region $REGION --output text

# Scan findings for a pushed image
aws ecr describe-image-scan-findings --repository-name $REPO --image-id imageTag=<SHA> --region $REGION \
  --query '{Status:imageScanStatus,Findings:imageScanFindings.findingSeverityCounts}'

# Tags present (confirm SHA + latest after a CI run)
aws ecr list-images --repository-name $REPO --region $REGION
aws ecr describe-images --repository-name $REPO --region $REGION \
  --query 'sort_by(imageDetails,&imagePushedAt)[*].{Tags:imageTags,Pushed:imagePushedAt}' --output table
```

## Cleanup

```bash
cd environments/dev/ecr
terraform destroy -var-file=../global.tfvars   # refuses while images remain (force_delete=false) — intended
```

To empty first (destructive, breaks rollbacks): delete images in the console
or `aws ecr batch-delete-image`, then destroy. In `existing` mode, destroy
removes only the lifecycle/cross-account policies, never the repository.
Orphaned cost is small (storage per GB-month) but stale images accumulate —
the lifecycle policy exists precisely to prevent that.

## Outputs for Phase 4 (EKS)

`repository_url` (image reference `<url>:<SHA>` in manifests),
`repository_arn`, `repository_name`, `registry_id`, `registry_url` (docker
login), `aws_region`. Nodes need no new policy — Phase 2's
`AmazonEC2ContainerRegistryReadOnly` on the node role already covers pulls
(same account, private subnets reach ECR via the Phase 1 NAT Gateway).

## Cost, security, retention

- **Cost: storage-only** (~per GB-month; negligible for one app) — no hourly
  charges. Cross-region replication (not enabled) and enhanced scanning would
  add cost.
- **Security:** private only, no public/cross-account access by default;
  scan-on-push surfaces CVEs; SHA tags give traceable, non-reusable deploy
  references; no credentials in Terraform (OIDC only).
- **Retention:** 10 recent `release-*` + 7-day untagged expiry keeps rollback
  capacity bounded without unbounded growth. SHA/`latest` tags are never
  auto-expired — prune them manually if the repo grows.
