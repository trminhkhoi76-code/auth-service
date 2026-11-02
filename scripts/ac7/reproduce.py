"""AWS-free AC7 demonstration. Claim comparison is NOT JWT signature verification."""
import base64
import hashlib
import json
import os
from pathlib import Path
import urllib.parse
import urllib.request


def trust_matches(claims, repo):
    return (claims.get('iss') == 'https://token.actions.githubusercontent.com'
            and claims.get('aud') == 'sts.amazonaws.com'
            and claims.get('sub') == f'repo:{repo}:ref:refs/heads/main')


def request_json(url, token):
    req = urllib.request.Request(url, headers={'Authorization': 'Bearer ' + token,
                                             'Accept': 'application/vnd.github+json'})
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)


def approved_reviews(pr, reviews, owners):
    latest = {}
    for review in reviews:
        if review['state'] in ('APPROVED', 'CHANGES_REQUESTED', 'DISMISSED'):
            latest[review['user']['login']] = review
    return [r for user, r in latest.items()
            if user in owners and user != pr['user']['login']
            and r['state'] == 'APPROVED' and r['commit_id'] == pr['head']['sha']]


def github(path):
    return request_json('https://api.github.com/repos/' + os.environ['GITHUB_REPOSITORY'] + path,
                        os.environ['GH_TOKEN'])


def main():
    repo = os.environ['GITHUB_REPOSITORY']
    url = os.environ['ACTIONS_ID_TOKEN_REQUEST_URL'] + '&audience=sts.amazonaws.com'
    jwt = request_json(url, os.environ['ACTIONS_ID_TOKEN_REQUEST_TOKEN'])['value']
    # Token never printed or persisted. Only selected claims are retained.
    payload = jwt.split('.')[1]
    claims = json.loads(base64.urlsafe_b64decode(payload + '=' * (-len(payload) % 4)))
    allowed = trust_matches(claims, repo)
    evidence = {'simulation': True, 'signature_verified_by_this_script': False,
                'aws_called': False, 'repository': repo, 'sha': os.environ['GITHUB_SHA'],
                'event': os.environ['GITHUB_EVENT_NAME'],
                'claims': {k: claims.get(k) for k in ('iss', 'aud', 'sub')},
                'trust_result': 'ALLOW' if allowed else 'DENY',
                'run_url': f'https://github.com/{repo}/actions/runs/' + os.environ['GITHUB_RUN_ID']}
    Path('ac7-evidence').mkdir(exist_ok=True)
    Path('ac7-evidence/trust.json').write_text(json.dumps(evidence, indent=2))
    print('MOCK Configure AWS credentials:', evidence['trust_result'])
    print('Observed sub:', claims.get('sub'))
    if not allowed:
        print('SIMULATED: Not authorized to perform sts:AssumeRoleWithWebIdentity')
        # Expected rejection is a successful test, not a failed workflow.
        assert not (os.environ['GITHUB_EVENT_NAME'] == 'push'
                    and os.environ['GITHUB_REF'] == 'refs/heads/main')
        return
    if os.environ['GITHUB_EVENT_NAME'] != 'push' or os.environ['GITHUB_REF'] != 'refs/heads/main':
        print('Trust allows main, but trigger gate prevents simulated apply.')
        return
    prs = github('/commits/' + os.environ['GITHUB_SHA'] + '/pulls')
    prs = [p for p in prs if p.get('merged_at') and p['base']['ref'] == 'main'
           and p.get('merge_commit_sha') == os.environ['GITHUB_SHA']]
    assert len(prs) == 1, 'Require exactly one merged PR associated with this push'
    pr = github('/pulls/' + str(prs[0]['number']))
    reviews = []
    for page in range(1, 101):
        batch = github(f'/pulls/{pr["number"]}/reviews?per_page=100&page={page}')
        reviews.extend(batch)
        if len(batch) < 100:
            break
    else:
        raise AssertionError('Review pagination limit reached')
    # This reproduction uses individual user owners; team membership requires separate verification.
    owners = set()
    for line in Path('.github/CODEOWNERS').read_text().splitlines():
        parts = line.split()
        if parts and parts[0] == '/policies/':
            owners = {x[1:] for x in parts[1:] if x.startswith('@') and '/' not in x}
    approvals = approved_reviews(pr, reviews, owners)
    assert approvals, 'No independent code-owner approval on the merged PR head commit'
    evidence['approval'] = [{'who': r['user']['login'], 'when': r['submitted_at'],
                             'commit_id': r['commit_id'], 'url': r['html_url']} for r in approvals]
    evidence['pr'] = pr['html_url']
    evidence['policy_sha256'] = hashlib.sha256(Path('policies/demo-observe.json').read_bytes()).hexdigest()
    evidence['simulated_command'] = 'aws iam put-role-policy --role-name AC7DemoTarget --policy-name observe-demo --policy-document file://policies/demo-observe.json'
    Path('ac7-evidence/mock-apply.json').write_text(json.dumps(evidence, indent=2))
    print('SIMULATED put-role-policy: recorded approval and policy hash; no AWS write.')


if __name__ == '__main__':
    main()
