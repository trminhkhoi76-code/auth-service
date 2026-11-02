# Collaborator control: unowned file and OIDC subject

This is the only change on this branch relative to its main starting point.
This docs path is outside current CODEOWNERS patterns; workflows and policy files are unchanged.

## Open the PR
Use a collaborator account to open this branch against main in the same repository.
Expected: normal required approval, without code-owner approval wording for this file.
A different non-owner with write access should be able to supply the normal review, subject to last-push requirements and required checks.

## Observe identity denial
The existing AC7 workflow runs both on branch push and on pull_request.
Inspect Real OIDC claims, simulated AWS trust: branch subject and pull_request subject should both produce mock DENY.
The negative test job is green when the denial is expected. No AWS STS request is made.

## After merge
A push-main run has the main subject and can satisfy simulated branch trust.
The simulator separately requires an independent code-owner review before mock apply, even for this docs-only PR.
If the PR has only non-owner review, trust ALLOW followed by approval-check failure is expected in the simulator.
That extra check is custom simulator behavior, not CODEOWNERS or AWS STS behavior.
Existing CI/CD also runs on merge; inspect before merging.
