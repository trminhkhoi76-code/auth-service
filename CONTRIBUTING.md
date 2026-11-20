# Contributing

## Change categories

| Prefix | Scope | Expected behavior |
| --- | --- | --- |
| `feat/`, `fix/` | Application source `src/main/` | Reviewed code + integration tests |
| `infra/` | Terraform or AWS deployment CI | Explicit deployment impact and IAM review |
| `test/` | Repeatable tests in `src/test/` | No deployment resources required by the test itself |
| `verify/` | `verification/` experiments | Simulation labelled, manually triggered |
| `docs/`, `refactor/` | Documentation/structure | No behavior change unless declared |

## Before requesting review

1. State the intent and classify each changed behavior as **LIVE**, **TEST**, **VERIFY**, or **DEMO**.
2. Run `./mvnw verify` (Docker required for Testcontainers) when Java code changes.
3. Run `terraform fmt -check -recursive infra` and Terraform validation for infrastructure changes.
4. Describe AWS execution, credentials, IAM and deployment impacts, even for documentation-only merges: this repository runs deploy CI on `main`.
5. Ensure the required `Policy validation` check passes, all relevant CODEOWNERS have reviewed and the branch ruleset is satisfied.
6. Provide links to real evidence for real claims; never present simulation output as AWS evidence.

Do not commit secrets, Terraform state, local evidence artifacts, or example production credentials. Do not bypass protections to land a test-only change.
