# IAM policy approval demonstration

**Classification: DEMO / NO AWS ACCESS.** `demo-observe.json` is a harmless teaching fixture permitting only `sts:GetCallerIdentity`. It is **not** an application deploy policy and is never passed to `iam:PutRolePolicy`.

The original trial steps and limitations are preserved in [HISTORICAL.md](HISTORICAL.md), but GitHub Actions now runs this demo **only by manual dispatch**. No simulation workflow is allowed to create a required production check.

Use `VERIFY ONLY - Policy gate simulation` in Actions, or run:

```bash
python3 -m json.tool verification/policy-gate/demo-observe.json >/dev/null
```

Review approval on a PR is a real GitHub control when the branch ruleset is enforced; approval of a fixture does **not** establish permissions applied in AWS. The separate required `Policy validation` job now checks the real Terraform repository configuration.
