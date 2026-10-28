# Observe CODEOWNERS → ruleset → policy workflow

This is a dry-run demonstration. It never assumes an AWS role or calls IAM.
The existing CI/CD workflow is unchanged and still runs its existing PR checks.
Merging any PR into main still triggers the existing application deployment.

## Setup
1. Merge the setup PR only when ready for the existing main deployment.
2. Open Settings → Rules → Rulesets → New branch ruleset.
3. Name: policy-owner-gate; Enforcement: Active; target: main; bypass list: empty.
4. Require a pull request before merging; require 1 approval; enable Require review from Code Owners and Dismiss stale pull request approvals when new commits are pushed.
5. Require status checks: Policy validation. Select the check from this PR after its first run.
6. Block force pushes and branch deletion.

CODEOWNERS must already exist on the PR base branch to request its owner.
The setup PR itself cannot demonstrate ownership from a CODEOWNERS file it introduces.
The owner is @trminhkhoi76-code. A PR authored by that same user cannot be self-approved.
Use another collaborator with write access to author the demonstration PR, or choose an independent owner with write access.

## Observe
1. Open a second PR changing only whitespace in policies/demo-observe.json.
2. In Checks, observe Detect policy changes, validation, policy hash, and the printed put-role-policy command.
3. Apply preview after merge is skipped on PRs, even if validation succeeds.
4. In the merge box, observe the required code-owner review while approval is missing.
5. Have the code owner approve. Then add a whitespace commit: approval should become stale.
6. Reapprove and merge: observe Apply preview after merge in Actions (simulation only).

CODEOWNERS is a merge review gate, not an IAM content validator and not a workflow-start gate.
PR validation can run before owner approval. Only a push-to-main apply workflow is gated indirectly by protected merging.
An administrator bypass, direct push exemption, or unrelated privileged workflow would invalidate this boundary.

## Real put-role-policy
The example command targets a dedicated demo role, not the application's ECS roles.
It is printed only. There is no demo role provisioned and no live apply implementation.
For a live implementation: provision that isolated role, grant an OIDC executor only iam:PutRolePolicy on its exact ARN,
restrict trust to the protected deployment context, validate the reviewed policy, then apply the exact reviewed commit.
Do not grant the executor permission to modify its own policy. Do not mix direct policy writes with Terraform-managed policies.
The current CI/CD uses auth-service-github-action for both plan and deploy despite the bootstrap defining separate roles; verify its actual AWS permissions before relying on read-only PR execution.
