  $ . $TESTDIR/testing/harness/helpers.sh
  $ setup_test_env
  Restarting Test Environment
  $ cd client

Create a commit to test

  $ echo initial > foo
  $ hg commit -Am 'Bug 1 - some stuff'
  adding foo
  $ hg push
  pushing to $HGWEB_URL/test-repo
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  $ REV=`hg log -r . --template "{node|short}"`

Close the tree

  $ autolandctl treestatus closed
  treestatus set to: closed

Post a job to land-repo

  $ autolandctl post-job test-repo $REV land-repo --commit-descriptions "{\"$REV\": \"Bug 1 - some stuff; r=cthulhu\"}"
  (200, u'{"request_id":1}\n')
  $ autolandctl job-status 1 --poll
  timed out

Open the tree

  $ autolandctl treestatus open
  treestatus set to: open
  $ autolandctl job-status 1 --poll
  (200, u'{"commit_descriptions":{"bdf30e77471a":"Bug 1 - some stuff; r=cthulhu"},"destination":"land-repo","error_msg":"","landed":true,"ldap_username":"autolanduser@example.com","result":"2d8e774dca588a8e0578f9b450c734b120a978a1","rev":"bdf30e77471a","tree":"test-repo"}\n')

Close the tree

  $ autolandctl treestatus closed
  treestatus set to: closed

Post a job to try

  $ autolandctl post-job test-repo $REV try --trysyntax "stuff"
  (200, u'{"request_id":2}\n')
  $ autolandctl job-status 2 --poll
  timed out

Open the tree

  $ autolandctl treestatus open
  treestatus set to: open
  $ autolandctl job-status 2 --poll
  (200, u'{"destination":"try","error_msg":"","landed":true,"ldap_username":"autolanduser@example.com","result":"74c00ccf0884f03e12e29db95e5b8f708044e8f0","rev":"bdf30e77471a","tree":"test-repo","trysyntax":"stuff"}\n')
