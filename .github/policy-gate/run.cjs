const evaluate = require('./evaluate.cjs');
module.exports = async ({github, context, core}) => {
  const repo = context.repo;
  const number = context.payload.pull_request?.number || context.payload.issue?.number;
  if (!number || (context.payload.issue && !context.payload.issue.pull_request)) return;
  const {data: pr} = await github.rest.pulls.get({...repo, pull_number:number});
  if (pr.state !== 'open' || pr.base.ref !== 'main') return;
  const sha = pr.head.sha;
  const status = async result => github.rest.repos.createCommitStatus({...repo,sha,
    context:'policy/approval-order', ...result,
    target_url:`https://github.com/${repo.owner}/${repo.repo}/actions/runs/${context.runId}`});
  await status({state:'pending',description:'Checking policy and approval order'});
  try {
    const files = await github.paginate(github.rest.pulls.listFiles,{...repo,pull_number:number,per_page:100});
    if (pr.changed_files > files.length) throw new Error('Incomplete changed-file list');
    const changed = files.filter(f => f.filename.startsWith('examples/iam/') || f.previous_filename?.startsWith('examples/iam/'));
    if (!changed.length) return await status({state:'success',description:'No example IAM policy changes'});
    if (changed.some(f => f.filename !== 'examples/iam/policy.json' || !['added','modified'].includes(f.status)))
      throw new Error('Only add/modify of examples/iam/policy.json is supported');
    // Retrieve JSON as data only. Never checkout or execute PR code with this token.
    const {data:file} = await github.rest.repos.getContent({...repo,path:'examples/iam/policy.json',ref:sha});
    const policy = JSON.parse(Buffer.from(file.content,'base64').toString('utf8'));
    if (policy.Version !== '2012-10-17' || !Array.isArray(policy.Statement) || !policy.Statement.length ||
        policy.Statement.some(s => !['Allow','Deny'].includes(s.Effect) || !s.Action || !s.Resource))
      throw new Error('Invalid example policy structure (not a full IAM semantic validator)');
    core.info(`Policy SHA256: ${require('crypto').createHash('sha256').update(Buffer.from(file.content,'base64')).digest('hex')}`);
    const users = value => (value || '').split(',').map(s=>s.trim()).filter(Boolean);
    const policyUsers = users(process.env.POLICY_APPROVERS);
    const prUsers = users(process.env.POLICY_PR_APPROVERS);
    if (!policyUsers.length || !prUsers.length) throw new Error('Configure POLICY_APPROVERS and POLICY_PR_APPROVERS');
    // Recheck current repository write permission, not comment author_association.
    const permitted = async names => {
      const result = [];
      for (const username of names) {
        const {data} = await github.rest.repos.getCollaboratorPermissionLevel({...repo,username});
        if (['write','maintain','admin'].includes(data.permission)) result.push(username);
      }
      return result;
    };
    const comments = await github.paginate(github.rest.issues.listComments,{...repo,issue_number:number,per_page:100});
    const reviews = await github.paginate(github.rest.pulls.listReviews,{...repo,pull_number:number,per_page:100});
    const result = evaluate({sha,author:pr.user.login,comments,reviews,
      policyUsers:await permitted(policyUsers),prUsers:await permitted(prUsers)});
    const {data:latest} = await github.rest.pulls.get({...repo,pull_number:number});
    if (latest.head.sha !== sha) return; // A synchronize event evaluates the new SHA.
    await status(result);
    await core.summary.addHeading('Policy approval gate').addRaw(`${result.description}\n\nCommit: ${sha}`).write();
  } catch (e) {
    await status({state:'failure',description:'Policy gate failed; inspect workflow logs'});
    throw e;
  }
};
