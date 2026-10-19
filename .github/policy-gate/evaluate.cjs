// Pure ordering rule, shared with local regression tests.
module.exports = function evaluate({sha, author, comments, reviews, policyUsers, prUsers}) {
  const policy = comments.filter(c => c.user.type === 'User' && c.user.login !== author &&
    policyUsers.includes(c.user.login) && c.created_at === c.updated_at &&
    c.body.trim() === `/approve-policy ${sha}`).sort((a,b) => a.id-b.id)[0];
  if (!policy) return {state:'pending', description:'Waiting for policy approval for current SHA'};
  const latest = new Map();
  for (const r of [...reviews].sort((a,b) => a.id-b.id)) {
    if (r.state !== 'COMMENTED') latest.set(r.user.login,r);
  }
  if ([...latest.values()].some(r => r.state === 'CHANGES_REQUESTED'))
    return {state:'failure', description:'Unresolved changes requested'};
  const approved = [...latest.values()].some(r => r.state === 'APPROVED' && r.commit_id === sha &&
    r.user.type === 'User' && r.user.login !== author && r.user.login !== policy.user.login &&
    prUsers.includes(r.user.login) && Date.parse(r.submitted_at) > Date.parse(policy.created_at));
  return approved ? {state:'success', description:'Policy approved, then independently PR approved'} :
    {state:'pending', description:'Waiting for a different PR reviewer after policy approval'};
};
