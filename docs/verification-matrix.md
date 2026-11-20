# Evidence levels and execution boundaries

| Area | Mode | Source of truth | Meaning of a green check |
| --- | --- | --- | --- |
| Authentication API | **Application code** | `src/main/` | Code exists; not a guarantee of deployment |
| Auth integration tests | **Automated test** | `src/test/` + Testcontainers | Auth scenarios passed on a disposable MySQL instance |
| Terraform fmt / validate | **Static validation** | `infra/` | Configuration parses and validates; no AWS apply |
| Required `Policy validation` | **Repository-side guardrail** | `.github/workflows/policy-validation.yml` | Terraform/ownership/simulation separation checks passed |
| CODEOWNERS + ruleset | **Real GitHub enforcement** | Repository settings, PR merge UI, reviews | GitHub approval constraints, subject to actual settings and permissions |
| AC7 OIDC probe | **Real GitHub token, simulated AWS decision** | `verification/ac7/` and Actions artifact | Claims observed; no JWT signature verification or AWS STS test |
| Policy gate demo | **Simulation** | `verification/policy-gate/` | Example policy fixture parsed; zero AWS writes |
| Main branch CI/CD | **Actual AWS-capable deployment path** | `.github/workflows/ci-cd.yml` | May build/push ECR image and apply Terraform to **dev** after merge |
| Production environment | **Not defined by this repository** | No `prod.tfvars` or prod deploy job found | Do not claim production is running |

## Deployment warning

A merge to `main` runs the existing CI/CD workflow, which **may apply Terraform to AWS dev**. This cleanup PR does not alter that deploy pipeline, IAM trust, AWS credentials, or runtime source.

**Unresolved role mismatch:** `infra/bootstrap/main.tf` defines `auth-service-github-plan` and `auth-service-github-deploy`; `.github/workflows/ci-cd.yml` currently references `auth-service-github-action` for both PR plan and deploy. Before relying on read-only PR plans or deployment security, inspect the existing AWS roles and reconcile this difference in a dedicated, reviewed infrastructure change.

**Unresolved bootstrap placeholder:** `infra/bootstrap/terraform.tfvars` still contains `github_repository = "<owner>/auth-service"`. Do not apply bootstrap without setting the intended repository and verifying the impact on existing state.

No AWS state, deploy, STS, IAM, or CloudTrail observation was made while preparing this repository cleanup.
