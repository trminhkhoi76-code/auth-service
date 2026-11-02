# AC7: GitHub evidence + AWS-free simulation

## Scope
Real: GitHub PRs, reviews, ruleset, merge state, Actions events, GitHub-issued OIDC claims.
Simulated: AWS trust evaluation, Configure AWS credentials denial, put-role-policy.
Not tested: AWS STS, IAM authorization, role existence, CloudTrail, private-repository plan eligibility.
This public repository does not prove private-plan enforcement.
The simulator decodes a token obtained directly from GitHub's runner endpoint; it does NOT verify JWT signatures.
It is not an authentication service or a production control. Never export the token.

## Before testing
1. Merge this setup through the current rules. It changes no AWS resource. Existing CI/CD still deploys on main.
2. Settings > Rules > policy-owner-gate: Active, main target, empty bypass list, 1 required approval,
   Require review from Code Owners, Dismiss stale approvals, Require approval of the most recent reviewable push.
   That last option was disabled at preparation time; enable it manually.
3. Keep Policy validation required. Optionally add AC7 model tests after its first run.
4. Use individual owners trminhkhoi76-code and lamduthach with write access. Member author: mktran76.
   This simulator's review check supports these user entries, not teams. Team rules need membership evidence.
5. Record effective rules and ownership errors using an authenticated CLI:

```bash
REPO=trminhkhoi76-code/auth-service
gh api "repos/$REPO/codeowners/errors?ref=main"
gh api "repos/$REPO/rules/branches/main"
```

Require empty ownership errors, require_code_owner_review=true, dismiss_stale_reviews_on_push=true,
require_last_push_approval=true. Snapshot the ruleset including bypass_actors=[].
Do not rely on requested_reviewers alone. The exact merge-box wording can differ by GitHub UI version.

## Reproduce in order
| AC | Action | Evidence / expected result |
|---|---|---|
| 1 | Inspect main CODEOWNERS and run CLI above | policies, all workflows, simulator scripts and CODEOWNERS owned; no errors |
| 2 | mktran76 opens same-repository PR changing policy JSON whitespace | screenshot: code owner review required; merge blocked |
| 3 | A different non-owner with write access approves | still blocked for code owner; author cannot supply this review |
| 4 | lamduthach or trminhkhoi76-code approves latest head | owner requirement satisfied, subject to other checks |
| 5 | Author pushes another policy whitespace commit | stale approval dismissed; blocked again |
| 6 | One owner pushes a new diff commit and approves | another person's approval still required by last-push rule |
| 7 | Separate PR changes docs only | normal 1-approval requirement, no owner requirement |
| 8 | Admin views unapproved owned PR | blocked; capture merge box and empty bypass list, do not force merge |
| 9 | Inspect trust_matches and trust artifact | exact main subject, issuer and audience comparison (SIMULATED trust) |
| 10a | Open same-repository PR | oidc-probe observes pull_request subject; mock DENY; expected-denial test passes |
| 10b | Push feature branch after setup exists on it | branch subject; mock DENY |
| 10c | Actions > AC7 AWS-free reproduction > Run workflow > choose feature branch | branch subject; mock DENY |
| 11 | Independently approved policy PR merged to main | push event, main subject, mock ALLOW; mock-apply.json records approval and policy hash |
| 12 | Collect PR reviews | code owner APPROVED on original merged PR head SHA, not merge commit SHA; not PR author |

For AC3 use a third non-owner if mktran76 is the author; do not substitute author self-approval.
Last-push approval requires a different approver; GitHub's owner requirement and last-pusher requirement are separate.
To demonstrate a distinct owner approval after an owner push, have the OTHER owner approve.
No automated script here certifies last-pusher identity or team membership; record these manually.
If there are other PRs on the same head commit with pending reviews, they can also affect merging; use distinct test commits.

## Artifacts and approval record
Each run uploads ac7-<run-id>-<attempt>. trust.json records selected claims, event, SHA and simulated result.
On push-main only, mock-apply.json is created AFTER the script finds a merged PR whose merge commit matches
the push SHA and an independent owner approval on its latest head. It records reviewer, timestamp, review URL,
policy SHA-256 and simulated command. No AWS credential is issued and no policy is written.
A setup PR lacking an independent owner approval intentionally fails the mock apply evidence check.
workflow_dispatch on main can satisfy trust but never applies: the separate event gate requires push.

```bash
REPO=trminhkhoi76-code/auth-service
PR=123 # replace with actual merged policy PR
gh api "repos/$REPO/pulls/$PR" --jq '{author:.user.login,head:.head.sha,merge:.merge_commit_sha,merged_at}'
gh api --paginate "repos/$REPO/pulls/$PR/reviews?per_page=100" \
  --jq '.[] | {who:.user.login,state,commit_id,submitted_at,html_url}'
```

## Boundaries that must not be overclaimed
Exact main sub does not identify an approved PR or a specific workflow. Any suitable main-context workflow
may request that identity; audit every privileged workflow and avoid executing unreviewed code through
pull_request_target or other main-context dispatch inputs. All workflows are owned here for that reason.
An empty bypass list prevents configured bypass; an administrator able to edit the ruleset can still weaken it.
The simulator adds an approval check before its mock write, after claim comparison; that is not AWS STS enforcement.
Native CODEOWNERS + branch-only trust cannot by themselves prove the absolute statement that every role session
has an independent code-owner approval. Include the observed owner-as-author exception from earlier tests.
Real AWS acceptance requires later repeating AC9-11 with a real role and STS/CloudTrail; simulated logs are not CloudTrail.

Fork PRs are out of scope. The workflow intentionally has id-token:write only in the probe job, no environment,
no AWS action, no AWS secret and no deployment command. Negative tests finish green when denial is expected;
read trust_result=DENY in the artifact, not just the workflow's success icon.
