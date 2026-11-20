# AC7: GitHub evidence and AWS-free reproduction

**Classification: VERIFY ONLY.** The runner may request a **real GitHub-issued OIDC token**, but this Python script only decodes selected claims and runs a **simulated AWS trust comparison**. It does not verify the JWT signature, assume an AWS role or call AWS.

The historical procedure and prior observations are retained in [HISTORICAL.md](HISTORICAL.md). Its older push/PR-trigger steps describe the original experiment: the current workflow has been changed to **manual-only**, so those steps are no longer an active CI contract.

## Current usage

- Local model checks: `python3 -m unittest discover -s verification/ac7 -v`
- GitHub Actions: manually run `VERIFY ONLY - AC7 OIDC simulation` on a chosen ref.
- Output: `ac7-evidence/trust.json` (uploaded as an artifact, untracked by Git). It identifies `simulation: true`, `signature_verified_by_this_script: false`, `aws_called: false`.
- GitHub PR/ruleset/approval records are real GitHub evidence, but not proof of a real AWS IAM decision.

The former post-merge mock-apply demonstration is intentionally **not** automatically triggered on pushes to `main`. To validate production control, use separately authorized real AWS STS/IAM and CloudTrail evidence; this repo's simulator is insufficient.
