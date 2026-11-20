# Verification laboratory (not a deployment path)

This directory contains **manual demonstrations** and reusable evidence from earlier GitHub approval/OIDC experiments. Nothing here is consumed by the Java application or Terraform deployment. No script here proves live AWS STS or IAM behavior.

| Material | Status | What it can prove |
| --- | --- | --- |
| `ac7/` | **VERIFY / SIMULATED AWS** | GitHub-issued OIDC claim observations; simulated trust comparison and owner-approval model |
| `policy-gate/` | **DEMO / SIMULATED IAM** | A fixture can be validated; GitHub review gating can be observed separately |
| `src/test/` (outside this directory) | **AUTOMATED APPLICATION TEST** | Spring Boot auth API behavior with Testcontainers/MySQL |
| `infra/` | **REAL TERRAFORM CONFIGURATION** | Deployment definitions, not proof they were successfully applied |
| `.github/workflows/ci-cd.yml` | **LIVE DEV DEPLOYMENT PATH** | Can call AWS and deploy on pushes to `main` |

## Run manually

From the repository root:

```bash
python3 -m unittest discover -s verification/ac7 -v
python3 -m json.tool verification/policy-gate/demo-observe.json >/dev/null
```

In GitHub Actions, run only `VERIFY ONLY - AC7 OIDC simulation` or `VERIFY ONLY - Policy gate simulation` when intentionally collecting evidence. Both workflows are `workflow_dispatch`-only and issue no AWS write operations.

Do not treat a green simulation job as evidence of real AWS authorization, or the required `Policy validation` check as independent security approval. See [the verification matrix](../docs/verification-matrix.md).
