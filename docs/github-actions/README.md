# GitHub Actions → AWS OIDC

## Trust policies

- `trust-policy.json`: trust policy for the **apply role** (production environment only).
- `trust-policy-plan.json`: trust policy for the **plan/build role** (main + develop branch refs).

- **Audience:** We use `StringEquals` for the single-valued `token.actions.githubusercontent.com:aud` claim (no `ForAllValues`/`ForAnyValue`). That matches AWS guidance: do not use condition set operators (qualifiers) with single-valued context keys.
- If your IDE/linter shows **“Confirm Audience Claim Type”** or **“do not use a qualifier”**: the policy is already correct; you can safely ignore that warning. The condition uses plain `StringEquals` and the required key `token.actions.githubusercontent.com:aud`.

## Permissions policies

- `permissions-policy.json`: policy for the **apply role** (Terraform apply only; no ECR push).
- `permissions-policy-plan.json`: policy for the **plan/build role** (ECR build/push + Terraform plan + state-bucket bootstrap).

## Workflow variables

- `AWS_PLAN_ROLE_ARN`: role assumed by `build_image` and `plan` jobs.
- `AWS_APPLY_ROLE_ARN`: role assumed by the `apply` job.

## Setup Script

Run from repository root:

```bash
sh docs/github-actions/set_oidc_policy.sh --repo <OWNER>/<REPO> --set-gh-vars
```

Preview only (no changes):

```bash
sh docs/github-actions/set_oidc_policy.sh --repo <OWNER>/<REPO> --set-gh-vars --dry-run
```

Notes:
- The script resolves policy files relative to its own location (`docs/github-actions/`).
- It creates/updates both IAM roles and both inline policies idempotently.
- For different accounts/repos, update policy JSON literals before applying:
  - `689254730158` -> your AWS account ID
  - `YonKu0/yo_this_is_ngnix` -> your `OWNER/REPO`
