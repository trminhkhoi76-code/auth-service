import unittest
from reproduce import approved_reviews, trust_matches


class AC7Tests(unittest.TestCase):
    def test_subject_matrix(self):
        for suffix, expected in [('ref:refs/heads/main', True), ('pull_request', False),
                                 ('ref:refs/heads/feature', False), ('environment:prod', False)]:
            with self.subTest(suffix=suffix):
                self.assertEqual(trust_matches({'iss': 'https://token.actions.githubusercontent.com',
                    'aud': 'sts.amazonaws.com', 'sub': 'repo:owner/repo:' + suffix}, 'owner/repo'), expected)
        self.assertFalse(trust_matches({'iss': 'untrusted', 'aud': 'sts.amazonaws.com',
            'sub': 'repo:owner/repo:ref:refs/heads/main'}, 'owner/repo'))

    def test_id_bound_subject(self):
        claims = {'iss': 'https://token.actions.githubusercontent.com', 'aud': 'sts.amazonaws.com',
                  'sub': 'repo:owner@10/repo@20:ref:refs/heads/main'}
        self.assertTrue(trust_matches(claims, 'owner/repo', '10', '20'))
        self.assertFalse(trust_matches(claims, 'owner/repo', '10', '21'))
        claims['sub'] = 'repo:owner@10/repo@20:ref:refs/heads/feature'
        self.assertFalse(trust_matches(claims, 'owner/repo', '10', '20'))

    def test_approval_matrix(self):
        pr = {'user': {'login': 'author'}, 'head': {'sha': 'latest'}}
        def review(user='owner', state='APPROVED', sha='latest'):
            return {'user': {'login': user}, 'state': state, 'commit_id': sha}
        for reviews, expected in [([], False), ([review('member')], False),
                ([review('author')], False), ([review(sha='old')], False),
                ([review()], True), ([review(), review(state='DISMISSED')], False),
                ([review(), review(state='CHANGES_REQUESTED')], False)]:
            with self.subTest(reviews=reviews):
                self.assertEqual(bool(approved_reviews(pr, reviews, {'owner', 'author'})), expected)


if __name__ == '__main__':
    unittest.main()
