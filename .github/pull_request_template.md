## Intent and scope

**Category:** LIVE / TEST / VERIFY / DEMO / DOCS

**Summary:**

**Affected paths:**

## Deployment and security impact

- [ ] No runtime, AWS or IAM effect from the code change itself
- [ ] Potential AWS/dev deployment effect explained (merge to `main` invokes CI/CD)
- [ ] IAM roles, ruleset and CODEOWNERS impact reviewed, or marked not applicable

## Evidence

- [ ] Java integration tests (`./mvnw verify`) — result or reason not run
- [ ] Terraform format/validate — result or reason not run
- [ ] GitHub checks — links to runs
- [ ] Simulation evidence clearly labelled; real AWS evidence separated

## Review checklist

- [ ] No secrets or Terraform state
- [ ] No demo workflow running automatically on PR or push
- [ ] Required `Policy validation` and independent approval satisfied
- [ ] Rollback and deployment considerations documented where relevant
