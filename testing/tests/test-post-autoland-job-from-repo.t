  $ . $TESTDIR/testing/harness/helpers.sh
  $ setup_test_env
  Restarting Test Environment
  $ cd client

Create a commit to test

  $ echo initial > foo
  $ hg commit -A -m 'Bug 1 - some stuff; r?cthulhu'
  adding foo
  $ hg push
  pushing to $HGWEB_URL/test-repo
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  $ REV=`hg log -r . --template "{node|short}"`

Posting a job with bad credentials should fail

  $ autolandctl post-job test-repo $REV land-reop --username blah --password blah
  (401, u'Login required')
  $ autolandctl post-job test-repo $REV land-repo --username blah --password ''
  (401, u'Login required')

Posting a job with without both trysyntax and commit_descriptions should fail

  $ autolandctl post-job test-repo 42 land-repo
  (400, u'{"error":"Bad request: one of trysyntax or commit_descriptions must be specified"}\n')

Posting a job with an unknown revision should fail

  $ autolandctl post-job test-repo 42 land-repo --commit-descriptions '{"42": "bad revision"}'
  (200, u'{"request_id":1}\n')
  $ autolandctl job-status 1 --poll
  (200, u'{"commit_descriptions":{"42":"bad revision"},"destination":"land-repo","error_msg":"hg error in cmd: hg pull test-repo -r 42: pulling from http://hgweb/test-repo\\nabort: unknown revision \'42\'!\\n","landed":false,"ldap_username":"autolanduser@example.com","result":"","rev":"42","tree":"test-repo"}\n')

Post a job

  $ autolandctl post-job test-repo $REV land-repo --commit-descriptions "{\"$REV\": \"Bug 1 - some stuff; r=cthulhu\"}"
  (200, u'{"request_id":2}\n')
  $ autolandctl job-status 2 --poll
  (200, u'{"commit_descriptions":{"3db0055aa281":"Bug 1 - some stuff; r=cthulhu"},"destination":"land-repo","error_msg":"","landed":true,"ldap_username":"autolanduser@example.com","result":"2d8e774dca588a8e0578f9b450c734b120a978a1","rev":"3db0055aa281","tree":"test-repo"}\n')
  $ autolandctl exec --container=hg hg log /repos/land-repo/ --template '{rev}:{desc|firstline}:{phase}:{join(extras, ":")}\n'
  1:Bug 1 - some stuff; r=cthulhu:public:branch=default
  0:initial commit:public:branch=default

Post a job with try syntax

  $ autolandctl post-job test-repo $REV try --trysyntax "stuff"
  (200, u'{"request_id":3}\n')
  $ autolandctl job-status 3 --poll
  (200, u'{"destination":"try","error_msg":"","landed":true,"ldap_username":"autolanduser@example.com","result":"2ea2487c0c0d82d5f753d21ebf41442dd8667645","rev":"3db0055aa281","tree":"test-repo","trysyntax":"stuff"}\n')
  $ autolandctl exec --container=hg hg log /repos/try --template '{rev}:{desc|firstline}:{phase}\n'
  2:try: stuff:public
  1:Bug 1 - some stuff; r?cthulhu:public
  0:initial commit:public

Post a job using a bookmark

  $ echo foo2 > foo
  $ hg commit -m 'Bug 1 - more goodness; r?cthulhu'
  $ hg push
  pushing to $HGWEB_URL/test-repo
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  $ REV=`hg log -r . --template "{node|short}"`

  $ autolandctl post-job test-repo $REV land-repo --push-bookmark "bookmark" --commit-descriptions "{\"$REV\": \"Bug 1 - more goodness; r=cthulhu\"}"
  (200, u'{"request_id":4}\n')
  $ autolandctl job-status 4 --poll
  (200, u'{"commit_descriptions":{"abb89d77a62a":"Bug 1 - more goodness; r=cthulhu"},"destination":"land-repo","error_msg":"","landed":true,"ldap_username":"autolanduser@example.com","push_bookmark":"bookmark","result":"1de97acfb23e3585b40a9cfc6608533596144627","rev":"abb89d77a62a","tree":"test-repo"}\n')
  $ autolandctl exec --container=hg hg log /repos/land-repo/ --template '{rev}:{desc|firstline}:{phase}\n'
  2:Bug 1 - more goodness; r=cthulhu:public
  1:Bug 1 - some stuff; r=cthulhu:public
  0:initial commit:public

Post a job with unicode commit descriptions to be rewritten

  $ echo foo3 > foo
  $ hg commit --encoding utf-8 -m 'Bug 1 - こんにちは; r?cthulhu'
  $ hg push
  pushing to $HGWEB_URL/test-repo
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  $ REV=`hg log -r . --template "{node|short}"`

  $ autolandctl post-job test-repo $REV land-repo --commit-descriptions "{\"$REV\": \"Bug 1 - \\u3053\\u3093\\u306b\\u3061\\u306f; r=cthulhu\"}"
  (200, u'{"request_id":5}\n')
  $ autolandctl job-status 5 --poll
  (200, u'{"commit_descriptions":{"9d071f68d358":"Bug 1 - \\u3053\\u3093\\u306b\\u3061\\u306f; r=cthulhu"},"destination":"land-repo","error_msg":"","landed":true,"ldap_username":"autolanduser@example.com","result":"9888509cd7a7356a0a2fe45d22423f06f239a666","rev":"9d071f68d358","tree":"test-repo"}\n')
  $ autolandctl exec --container=hg hg log --encoding=utf-8 /repos/land-repo/ --template '{rev}:{desc|firstline}:{phase}\n'
  3:Bug 1 - \xe3\x81\x93\xe3\x82\x93\xe3\x81\xab\xe3\x81\xa1\xe3\x81\xaf; r=cthulhu:public (esc)
  2:Bug 1 - more goodness; r=cthulhu:public
  1:Bug 1 - some stuff; r=cthulhu:public
  0:initial commit:public

Getting status for an unknown job should return a 404

  $ autolandctl job-status 42
  (404, u'{"error":"Not found"}\n')

Test pingback url whitelist.  localhost, private IPs, and example.com are in
the whitelist. example.org is not.

  $ autolandctl post-job test-repo $REV land-repo1 --pingback-url http://example.com:9898 --commit-descriptions "{\"$REV\": \"Bug 1 - some stuff; r=cthulhu\"}"
  (200, u'{"request_id":6}\n')
  $ autolandctl post-job test-repo $REV land-repo2 --pingback-url http://localhost --commit-descriptions "{\"$REV\": \"Bug 1 - some stuff; r=cthulhu\"}"
  (200, u'{"request_id":7}\n')
  $ autolandctl post-job test-repo $REV land-repo3 --pingback-url http://127.0.0.1 --commit-descriptions "{\"$REV\": \"Bug 1 - some stuff; r=cthulhu\"}"
  (200, u'{"request_id":8}\n')
  $ autolandctl post-job test-repo $REV land-repo4 --pingback-url http://192.168.0.1 --commit-descriptions "{\"$REV\": \"Bug 1 - some stuff; r=cthulhu\"}"
  (200, u'{"request_id":9}\n')
  $ autolandctl post-job test-repo $REV land-repo5 --pingback-url http://172.16.0.1 --commit-descriptions "{\"$REV\": \"Bug 1 - some stuff; r=cthulhu\"}"
  (200, u'{"request_id":10}\n')
  $ autolandctl post-job test-repo $REV land-repo6 --pingback-url http://10.0.0.1:443 --commit-descriptions "{\"$REV\": \"Bug 1 - some stuff; r=cthulhu\"}"
  (200, u'{"request_id":11}\n')
  $ autolandctl post-job test-repo $REV land-repo7 --pingback-url http://8.8.8.8:443 --commit-descriptions "{\"$REV\": \"Bug 1 - some stuff; r=cthulhu\"}"
  (400, u'{"error":"Bad request: bad pingback_url"}\n')
  $ autolandctl post-job test-repo $REV land-repo8 --pingback-url http://example.org:9898 --commit-descriptions "{\"$REV\": \"Bug 1 - some stuff; r=cthulhu\"}"
  (400, u'{"error":"Bad request: bad pingback_url"}\n')

Post the same job twice.  Start with stopping the autoland service to
guarentee the first request is still in the queue when the second is submitted.

  $ docker stop autoland_test.daemon
  autoland_test.daemon
  $ autolandctl post-job test-repo $REV try --trysyntax "stuff"
  (200, u'{"request_id":12}\n')
  $ autolandctl post-job test-repo $REV try --trysyntax "stuff"
  (400, u'{"error":"Bad Request: a request to land revision 9d071f68d358 to try is already in progress"}\n')
