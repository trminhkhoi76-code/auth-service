# AC7 control: unowned change still cannot assume production identity

This branch changes only this documentation file, outside every current CODEOWNERS pattern.
The existing AC7 workflow runs on push, requests a real GitHub OIDC token, and compares its claims with simulated production trust.
Expected: feature-branch subject is DENIED, regardless of the changed file having no code owner.
No workflow or policy change is needed to exercise this case. No real AWS STS call or IAM write occurs.

Evidence: Actions > AC7 AWS-free reproduction > Real OIDC claims, simulated AWS trust.
Look for MOCK Configure AWS credentials: DENY and the feature-branch sub.
The green job means the negative test passed, not that credentials were issued.

This demonstrates branch identity separation, not path-based AWS authorization.
On main, the same docs-only change could satisfy branch trust; sub does not encode changed paths or approvals.
