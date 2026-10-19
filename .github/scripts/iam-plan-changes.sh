#!/usr/bin/env bash
# Usage: iam-plan-changes.sh <saved-plan>   (run from the Terraform root, e.g. infra/app)
#
# Finds the IAM changes (managed aws_iam_* resources that are not no-op) in a saved plan and writes
# to $GITHUB_OUTPUT:
#   changed=true|false
#   fingerprint=<sha256>  — identical planned IAM changes always give the same value, so the policy
#                           approved in one job can be compared with the plan applied in another
# The human-readable diff of those resources is appended to $GITHUB_STEP_SUMMARY for the approver.
set -euo pipefail

plan=$1

changes=$(terraform show -json "$plan" | jq -cS '
  [.resource_changes[]?
    | select(.mode == "managed" and (.type | startswith("aws_iam_")))
    | select(.change.actions != ["no-op"] and .change.actions != ["read"])
    | {address, actions: .change.actions, before: .change.before, after: .change.after,
       after_unknown: .change.after_unknown}]
  | sort_by(.address)')
count=$(jq 'length' <<<"$changes")
fingerprint=$(printf '%s' "$changes" | sha256sum | cut -d ' ' -f 1)

changed=false
if [[ "$count" -gt 0 ]]; then
  changed=true
fi

{
  echo "changed=${changed}"
  echo "fingerprint=${fingerprint}"
} >> "$GITHUB_OUTPUT"

{
  echo "## IAM policy changes"
  echo ""
  if [[ "$changed" == false ]]; then
    echo "None: this plan does not need \`production-policy\` approval."
  else
    echo "**${count}** IAM resource(s) change: \`terraform apply\` waits for \`production-policy\` approval."
    echo "The release PR review does not count as this approval."
    echo ""
    echo "Fingerprint: \`${fingerprint}\`"
    echo ""
    echo '```'
    # Each resource block starts with "  # <address> will be ..." and ends with a 4-space "}"
    terraform show -no-color "$plan" |
      awk '/^  # (module\.[^ ]+\.)?aws_iam_/ { p = 1 } p { print } p && /^    }$/ { p = 0; print "" }'
    echo '```'
  fi
} >> "$GITHUB_STEP_SUMMARY"
