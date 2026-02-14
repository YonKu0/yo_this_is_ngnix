#!/usr/bin/env sh
set -eu

usage() {
  cat <<'EOF'
Usage:
  sh docs/github-actions/set_oidc_policy.sh [options]

Options:
  --plan-role NAME      Plan/build IAM role name (default: yo-this-is-ngnix-gha-plan)
  --apply-role NAME     Apply IAM role name (default: yo-this-is-ngnix-gha-apply)
  --region REGION       AWS region for GitHub variable setup (default: us-east-1)
  --repo OWNER/REPO     GitHub repo for variable setup (example: your-org/your-repo)
  --set-gh-vars         Also set GitHub repo variables via gh CLI
  --dry-run             Print all actions without making changes
  -h, --help            Show help

Notes:
  - Policy files are resolved relative to this script, not current working directory.
  - Requires AWS credentials with IAM permissions to create/update roles and policies.
EOF
}

require_arg() {
  option_name="$1"
  shift
  [ "$#" -gt 0 ] || {
    echo "missing value for ${option_name}" >&2
    exit 1
  }
}

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

PLAN_TRUST="${SCRIPT_DIR}/trust-policy-plan.json"
APPLY_TRUST="${SCRIPT_DIR}/trust-policy.json"
PLAN_PERMS="${SCRIPT_DIR}/permissions-policy-plan.json"
APPLY_PERMS="${SCRIPT_DIR}/permissions-policy.json"

PLAN_ROLE_NAME="${PLAN_ROLE_NAME:-yo-this-is-ngnix-gha-plan}"
APPLY_ROLE_NAME="${APPLY_ROLE_NAME:-yo-this-is-ngnix-gha-apply}"
REGION="${REGION:-us-east-1}"
GITHUB_REPO="${GITHUB_REPO:-}"
SET_GH_VARS=0
DRY_RUN=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --plan-role)
      shift
      require_arg "--plan-role" "$@"
      PLAN_ROLE_NAME="$1"
      ;;
    --apply-role)
      shift
      require_arg "--apply-role" "$@"
      APPLY_ROLE_NAME="$1"
      ;;
    --region)
      shift
      require_arg "--region" "$@"
      REGION="$1"
      ;;
    --repo)
      shift
      require_arg "--repo" "$@"
      GITHUB_REPO="$1"
      ;;
    --set-gh-vars)
      SET_GH_VARS=1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

for f in "$PLAN_TRUST" "$APPLY_TRUST" "$PLAN_PERMS" "$APPLY_PERMS"; do
  [ -f "$f" ] || {
    echo "Required file not found: $f" >&2
    exit 1
  }
done

if [ "$DRY_RUN" -eq 0 ]; then
  command -v aws >/dev/null 2>&1 || {
    echo "aws CLI is required." >&2
    exit 1
  }

  OIDC_PROVIDER="$(aws iam list-open-id-connect-providers \
    --query 'OpenIDConnectProviderList[?contains(Arn, `token.actions.githubusercontent.com`)].Arn | [0]' \
    --output text)"

  if [ -z "$OIDC_PROVIDER" ] || [ "$OIDC_PROVIDER" = "None" ]; then
    cat <<'EOF' >&2
GitHub OIDC provider was not found in this AWS account.
Create it first in IAM:
  URL: https://token.actions.githubusercontent.com
  Audience: sts.amazonaws.com
EOF
    exit 1
  fi
else
  OIDC_PROVIDER="(dry-run: not validated)"
fi

upsert_role() {
  role_name="$1"
  trust_file="$2"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] aws iam get-role --role-name ${role_name}"
    echo "[dry-run] aws iam update-assume-role-policy --role-name ${role_name} --policy-document file://${trust_file}"
    echo "[dry-run] aws iam create-role --role-name ${role_name} --assume-role-policy-document file://${trust_file}"
    return 0
  fi
  if aws iam get-role --role-name "$role_name" >/dev/null 2>&1; then
    aws iam update-assume-role-policy \
      --role-name "$role_name" \
      --policy-document "file://${trust_file}" >/dev/null
    echo "Updated trust policy: ${role_name}"
  else
    aws iam create-role \
      --role-name "$role_name" \
      --assume-role-policy-document "file://${trust_file}" >/dev/null
    echo "Created role: ${role_name}"
  fi
}

echo "Using policy directory: ${SCRIPT_DIR}"
echo "Found OIDC provider: ${OIDC_PROVIDER}"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "Mode: DRY RUN (no changes will be made)"
fi

upsert_role "$PLAN_ROLE_NAME" "$PLAN_TRUST"
upsert_role "$APPLY_ROLE_NAME" "$APPLY_TRUST"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] aws iam put-role-policy --role-name ${PLAN_ROLE_NAME} --policy-name yo-this-is-ngnix-plan-inline --policy-document file://${PLAN_PERMS}"
  echo "[dry-run] aws iam put-role-policy --role-name ${APPLY_ROLE_NAME} --policy-name yo-this-is-ngnix-apply-inline --policy-document file://${APPLY_PERMS}"
else
  aws iam put-role-policy \
    --role-name "$PLAN_ROLE_NAME" \
    --policy-name "yo-this-is-ngnix-plan-inline" \
    --policy-document "file://${PLAN_PERMS}" >/dev/null
  echo "Attached/updated inline policy: yo-this-is-ngnix-plan-inline"

  aws iam put-role-policy \
    --role-name "$APPLY_ROLE_NAME" \
    --policy-name "yo-this-is-ngnix-apply-inline" \
    --policy-document "file://${APPLY_PERMS}" >/dev/null
  echo "Attached/updated inline policy: yo-this-is-ngnix-apply-inline"
fi

ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"
if [ -z "$ACCOUNT_ID" ] && command -v aws >/dev/null 2>&1; then
  ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)"
fi
if [ -z "$ACCOUNT_ID" ]; then
  ACCOUNT_ID="000000000000"
fi

PLAN_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${PLAN_ROLE_NAME}"
APPLY_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${APPLY_ROLE_NAME}"

echo ""
echo "Plan role ARN : ${PLAN_ARN}"
echo "Apply role ARN: ${APPLY_ARN}"

if [ "$SET_GH_VARS" -eq 1 ]; then
  [ -n "$GITHUB_REPO" ] || {
    echo "--repo is required when using --set-gh-vars" >&2
    exit 1
  }
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] gh variable set AWS_REGION --body ${REGION} --repo ${GITHUB_REPO}"
    echo "[dry-run] gh variable set AWS_PLAN_ROLE_ARN --body ${PLAN_ARN} --repo ${GITHUB_REPO}"
    echo "[dry-run] gh variable set AWS_APPLY_ROLE_ARN --body ${APPLY_ARN} --repo ${GITHUB_REPO}"
  else
    command -v gh >/dev/null 2>&1 || {
      echo "gh CLI is required for --set-gh-vars." >&2
      exit 1
    }
    gh variable set AWS_REGION --body "$REGION" --repo "$GITHUB_REPO"
    gh variable set AWS_PLAN_ROLE_ARN --body "$PLAN_ARN" --repo "$GITHUB_REPO"
    gh variable set AWS_APPLY_ROLE_ARN --body "$APPLY_ARN" --repo "$GITHUB_REPO"
    echo "Updated GitHub repo variables for ${GITHUB_REPO}"
  fi
fi

echo ""
echo "Next:"
echo "1) Ensure GitHub environment 'production' has required reviewers."
echo "2) Trigger workflow and verify plan/apply use the correct role per job."
