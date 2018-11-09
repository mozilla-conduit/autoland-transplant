  $ . $TESTDIR/testing/harness/helpers.sh
  $ setup_test_env
  Restarting Test Environment
  $ cd client

Create a commit to test

  $ echo initial > foo
  $ hg commit -Am 'Bug 1 - some stuff; r?cthulhu'
  adding foo
  $ hg push
  pushing to $HGWEB_URL/test-repo
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  $ REV=`hg log -r . --template "{node|short}"`

Post a job

  $ autolandctl post-job test-repo $REV land-repo --commit-descriptions "{\"$REV\": \"Bug 1 - some stuff; r=cthulhu\"}"
  (200, u'{"request_id":1}\n')
  $ autolandctl job-status 1 --poll
  (200, u'{"commit_descriptions":{"3db0055aa281":"Bug 1 - some stuff; r=cthulhu"},"destination":"land-repo","error_msg":"","landed":true,"ldap_username":"autolanduser@example.com","result":"2d8e774dca588a8e0578f9b450c734b120a978a1","rev":"3db0055aa281","tree":"test-repo"}\n')
  $ autolandctl exec --container=hg hg log /repos/land-repo/ --template '{rev}:{desc|firstline}:{phase}\n'
  1:Bug 1 - some stuff; r=cthulhu:public
  0:initial commit:public

Post a job with a bad merge

  $ autolandctl exec --container=hg --user=apache --shell 'cd /repos/land-repo/ && hg update tip && echo foo2 > foo && hg commit -m trouble'
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo foo3 > foo
  $ hg commit -m 'Bug 1 - more stuff; r?cthulhu'
  $ hg push
  pushing to $HGWEB_URL/test-repo
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  $ REV=`hg log -r . --template "{node|short}"`
  $ autolandctl post-job test-repo $REV land-repo --commit-descriptions "{\"$REV\": \"Bug 1 - more stuff; r=cthulhu\"}"
  (200, u'{"request_id":2}\n')
  $ autolandctl job-status 2 --poll
  (200, u'{"commit_descriptions":{"fc889022e642":"Bug 1 - more stuff; r=cthulhu"},"destination":"land-repo","error_msg":"We\'re sorry, Autoland could not rebase your commits for you automatically. Please manually rebase your commits and try again.\\n\\nhg error in cmd: hg rebase -s 45db4f6d62468c05c88203f93ff73f9dfc9afc4f -d bff1a2e236a2: rebasing 4:45db4f6d6246 \\"Bug 1 - more stuff; r=cthulhu\\" (tip)\\nmerging foo\\nwarning: conflicts while merging foo! (edit, then use \'hg resolve --mark\')\\nunresolved conflicts (see hg resolve, then hg rebase --continue)\\n","landed":false,"ldap_username":"autolanduser@example.com","result":"","rev":"fc889022e642","tree":"test-repo"}\n')
  $ autolandctl exec --container=hg hg log /repos/land-repo/ --template '{rev}:{desc|firstline}:{phase}\n'
  2:trouble:draft
  1:Bug 1 - some stuff; r=cthulhu:public
  0:initial commit:public

