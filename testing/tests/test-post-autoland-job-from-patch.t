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

  $ autolandctl post-job test-repo p0 land-repo --username blah --password blah --patch-url http://hgweb/test-repo/raw-rev/$REV
  (401, u'Login required')
  $ autolandctl post-job test-repo p0 land-repo --username blah --password '' --patch-url http://hgweb/test-repo/raw-rev/$REV
  (401, u'Login required')

Post a job from http url should fail

  $ autolandctl post-job test-repo p0 land-repo --patch-url http://example.com/p2.patch
  (400, u'{"error":"Bad request: bad patch_url"}\n')

Post a job from s3 url.  This should fail because we don't have a mock
environment for S3.

  $ autolandctl post-job test-repo p1 land-repo --patch-url s3://lando-dev/p1.patch
  (200, u'{"request_id":1}\n')
  $ autolandctl job-status 1 --poll
  200
  {
    "destination": "land-repo",
    "error_msg": "unable to download s3://lando-dev/p1.patch: permission denied",
    "landed": false,
    "ldap_username": "autolanduser@example.com",
    "patch_urls": [
      "s3://lando-dev/p1.patch"
    ],
    "result": "",
    "rev": "p1",
    "tree": "test-repo"
  }

Post a job from private ip

  $ autolandctl post-job test-repo p2 land-repo --patch-url http://hgweb/test-repo/raw-rev/$REV
  (200, u'{"request_id":2}\n')
  $ autolandctl job-status 2 --poll
  200
  {
    "destination": "land-repo",
    "error_msg": "",
    "landed": true,
    "ldap_username": "autolanduser@example.com",
    "patch_urls": [
      "http://hgweb/test-repo/raw-rev/3db0055aa281"
    ],
    "result": "6a1a92b3919045841a41fb370ed7c6a633f82657",
    "rev": "p2",
    "tree": "test-repo"
  }
  $ autolandctl exec --container=hg hg log /repos/land-repo/ --template '{rev}:{desc|firstline}:{phase}:{join(extras, ":")}\n'
  1:Bug 1 - some stuff; r?cthulhu:public:branch=default:moz-landing-system=lando
  0:initial commit:public:branch=default

Post a job using an inline patch

  $ echo foo2 > foo
  $ hg commit -m 'Bug 1 - some more stuff; r?cthulhu'
  $ hg export > $TESTTMP/patch
  $ hg push
  pushing to $HGWEB_URL/test-repo
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files

  $ autolandctl post-job test-repo p3 land-repo --push-bookmark "bookmark" --patch-file $TESTTMP/patch
  (200, u'{"request_id":3}\n')
  $ autolandctl job-status 3 --poll
  200
  {
    "destination": "land-repo",
    "error_msg": "",
    "landed": true,
    "ldap_username": "autolanduser@example.com",
    "patch": "*", (glob)
    "push_bookmark": "bookmark",
    "result": "91bf2a9abc542b18810989b5eeff70debe462f11",
    "rev": "p3",
    "tree": "test-repo"
  }
  $ autolandctl exec --container=hg hg log /repos/land-repo/ --template '{rev}:{desc|firstline}:{phase}:{join(extras, ":")}\n'
  2:Bug 1 - some more stuff; r?cthulhu:public:branch=default:moz-landing-system=lando
  1:Bug 1 - some stuff; r?cthulhu:public:branch=default:moz-landing-system=lando
  0:initial commit:public:branch=default

Post a job using an inline patch with 'Diff Start Line'

  $ echo foo3 > foo
  $ hg commit -m 'Bug 1 - even more stuff; r?cthulhu'
  $ hg export > $TESTTMP/patch2
  $ DSL=`cat -n $TESTTMP/patch2 | grep 'diff ' | head -n 1 | awk '{print $1+1}'`
  $ perl -pe 's/^(# User)/# Diff Start Line '$DSL'\n$1/' < $TESTTMP/patch2 > $TESTTMP/patch
  $ hg push
  pushing to $HGWEB_URL/test-repo
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files

  $ autolandctl post-job test-repo p4 land-repo --push-bookmark "bookmark" --patch-file $TESTTMP/patch
  (200, u'{"request_id":4}\n')
  $ autolandctl job-status 4 --poll
  200
  {
    "destination": "land-repo",
    "error_msg": "",
    "landed": true,
    "ldap_username": "autolanduser@example.com",
    "patch": "*", (glob)
    "push_bookmark": "bookmark",
    "result": "c1c0ffb7147ada279f474bd1ba164e0796ed5f07",
    "rev": "p4",
    "tree": "test-repo"
  }
  $ autolandctl exec --container=hg hg log /repos/land-repo/ --template '{rev}:{desc|firstline}:{phase}:{join(extras, ":")}\n'
  3:Bug 1 - even more stuff; r?cthulhu:public:branch=default:moz-landing-system=lando
  2:Bug 1 - some more stuff; r?cthulhu:public:branch=default:moz-landing-system=lando
  1:Bug 1 - some stuff; r?cthulhu:public:branch=default:moz-landing-system=lando
  0:initial commit:public:branch=default

Post a job using a bookmark

  $ echo foo4 > foo
  $ hg commit -m 'Bug 1 - more goodness; r?cthulhu'
  $ hg push
  pushing to $HGWEB_URL/test-repo
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  $ REV=`hg log -r . --template "{node|short}"`

  $ autolandctl post-job test-repo p5 land-repo --push-bookmark "bookmark" --patch-url http://hgweb/test-repo/raw-rev/$REV
  (200, u'{"request_id":5}\n')
  $ autolandctl job-status 5 --poll
  200
  {
    "destination": "land-repo",
    "error_msg": "",
    "landed": true,
    "ldap_username": "autolanduser@example.com",
    "patch_urls": [
      "http://hgweb/test-repo/raw-rev/85e19ca28526"
    ],
    "push_bookmark": "bookmark",
    "result": "125fb26594d32e024f056ca42da2d01598e662df",
    "rev": "p5",
    "tree": "test-repo"
  }
  $ autolandctl exec --container=hg hg log /repos/land-repo/ --template '{rev}:{desc|firstline}:{phase}:{join(extras, ":")}\n'
  4:Bug 1 - more goodness; r?cthulhu:public:branch=default:moz-landing-system=lando
  3:Bug 1 - even more stuff; r?cthulhu:public:branch=default:moz-landing-system=lando
  2:Bug 1 - some more stuff; r?cthulhu:public:branch=default:moz-landing-system=lando
  1:Bug 1 - some stuff; r?cthulhu:public:branch=default:moz-landing-system=lando
  0:initial commit:public:branch=default

Post a job with unicode

  $ echo foo5 > foo
  $ hg commit --encoding utf-8 -m 'Bug 1 - こんにちは; r?cthulhu'
  $ hg push
  pushing to $HGWEB_URL/test-repo
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  $ REV=`hg log -r . --template "{node|short}"`

  $ autolandctl post-job test-repo p6 land-repo --push-bookmark "bookmark" --patch-url http://hgweb/test-repo/raw-rev/$REV
  (200, u'{"request_id":6}\n')
  $ autolandctl job-status 6 --poll
  200
  {
    "destination": "land-repo",
    "error_msg": "",
    "landed": true,
    "ldap_username": "autolanduser@example.com",
    "patch_urls": [
      "http://hgweb/test-repo/raw-rev/d5b17bac3b15"
    ],
    "push_bookmark": "bookmark",
    "result": "8ec47f5278c79b0efed3742ecd77df69e57a752a",
    "rev": "p6",
    "tree": "test-repo"
  }
  $ autolandctl exec --container=hg hg log --encoding=utf-8 /repos/land-repo/ --template '{rev}:{desc|firstline}:{phase}:{join(extras, ":")}\n'
  5:Bug 1 - \xe3\x81\x93\xe3\x82\x93\xe3\x81\xab\xe3\x81\xa1\xe3\x81\xaf; r?cthulhu:public:branch=default:moz-landing-system=lando (esc)
  4:Bug 1 - more goodness; r?cthulhu:public:branch=default:moz-landing-system=lando
  3:Bug 1 - even more stuff; r?cthulhu:public:branch=default:moz-landing-system=lando
  2:Bug 1 - some more stuff; r?cthulhu:public:branch=default:moz-landing-system=lando
  1:Bug 1 - some stuff; r?cthulhu:public:branch=default:moz-landing-system=lando
  0:initial commit:public:branch=default

Bad Merge (using the now obsolete inline-patch created earlier)

  $ autolandctl post-job test-repo p7 land-repo --push-bookmark "bookmark" --patch-file $TESTTMP/patch
  (200, u'{"request_id":7}\n')
  $ autolandctl job-status 7 --poll
  200
  {
    "destination": "land-repo",
    "error_msg": "We're sorry, Autoland could not rebase your commits for you automatically. Please manually rebase your commits and try again.
  applying * (glob)
  foo
  Hunk #1 FAILED at 1.
  1 out of 1 hunk FAILED -- saving rejects to file foo.rej
  abort: patch command failed: exited with status 256
  ",
    "landed": false,
    "ldap_username": "autolanduser@example.com",
    "patch": "*", (glob)
    "push_bookmark": "bookmark",
    "result": "",
    "rev": "p7",
    "tree": "test-repo"
  }

Test falling back to patch

  $ echo foo4 > foo
  $ hg commit -m 'Bug 1 - too much stuff to hold; r?cthulhu'
  $ hg export > $TESTTMP/patch3
  $ perl -pe 's/^(# User)/# Fail HG Import True\n$1/' < $TESTTMP/patch3 > $TESTTMP/patch
  $ hg push
  pushing to $HGWEB_URL/test-repo
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files

  $ autolandctl post-job test-repo p8 land-repo --push-bookmark "bookmark" --patch-file $TESTTMP/patch
  (200, u'{"request_id":8}\n')
  $ autolandctl job-status 8 --poll
  200
  {
    "destination": "land-repo",
    "error_msg": "",
    "landed": true,
    "ldap_username": "autolanduser@example.com",
    "patch": "*", (glob)
    "push_bookmark": "bookmark",
    "result": "a1cce11f4932b53b2a12feb302203c42d53e9016",
    "rev": "p8",
    "tree": "test-repo"
  }
  $ autolandctl exec --container=hg hg log /repos/land-repo/ --template '{rev}:{desc|firstline}:{phase}:{join(extras, ":")}\n'
  6:Bug 1 - too much stuff to hold; r?cthulhu:public:branch=default:moz-landing-system=lando
  5:Bug 1 - \xe3\x81\x93\xe3\x82\x93\xe3\x81\xab\xe3\x81\xa1\xe3\x81\xaf; r?cthulhu:public:branch=default:moz-landing-system=lando (esc)
  4:Bug 1 - more goodness; r?cthulhu:public:branch=default:moz-landing-system=lando
  3:Bug 1 - even more stuff; r?cthulhu:public:branch=default:moz-landing-system=lando
  2:Bug 1 - some more stuff; r?cthulhu:public:branch=default:moz-landing-system=lando
  1:Bug 1 - some stuff; r?cthulhu:public:branch=default:moz-landing-system=lando
  0:initial commit:public:branch=default

Create a commit to test on Try

  $ echo try > foo
  $ hg commit -m 'Bug 1 - some stuff; r?cthulhu'
  $ hg push
  pushing to $HGWEB_URL/test-repo
  searching for changes
  remote: adding changesets
  remote: adding manifests
  remote: adding file changes
  remote: added 1 changesets with 1 changes to 1 files
  $ REV=`hg log -r . --template "{node|short}"`

Post a job with try syntax

  $ autolandctl post-job test-repo p0 land-repo --trysyntax "stuff" --patch-url http://hgweb/test-repo/raw-rev/$REV
  (400, u'{"error":"Bad request: trysyntax is not supported with patch_urls"}\n')

Getting status for an unknown job should return a 404

  $ autolandctl job-status 42
  (404, u'{"error":"Not found"}\n')

Ensure unexpected files in the repo path are not landed.

  $ autolandctl exec touch /repos/test-repo/rogue
  $ autolandctl post-job test-repo p9 land-repo --patch-url http://hgweb/test-repo/raw-rev/$REV
  (200, u'{"request_id":9}\n')
  $ autolandctl job-status 9 --poll
  200
  {
    "destination": "land-repo",
    "error_msg": "",
    "landed": true,
    "ldap_username": "autolanduser@example.com",
    "patch_urls": [
      "http://hgweb/test-repo/raw-rev/ca6d3b938cfa"
    ],
    "result": "9f2de2f2c973baab51cdce274313cda926fb2208",
    "rev": "p9",
    "tree": "test-repo"
  }
  $ autolandctl exec --container=hg hg -q -R /repos/land-repo update tip
  $ autolandctl exec --container=hg hg files --cwd /repos/land-repo
  foo
  readme

Test pingback url whitelist.  localhost, private IPs, and example.com are in
the whitelist. example.org is not.

  $ autolandctl post-job test-repo p10 land-repo --pingback-url http://example.com:9898 --patch-url http://hgweb/test-repo/raw-rev/$REV
  (200, u'{"request_id":10}\n')
  $ autolandctl post-job test-repo p11 land-repo --pingback-url http://localhost --patch-url http://hgweb/test-repo/raw-rev/$REV
  (200, u'{"request_id":11}\n')
  $ autolandctl post-job test-repo p12 land-repo --pingback-url http://localhost --patch-url http://hgweb/test-repo/raw-rev/$REV
  (200, u'{"request_id":12}\n')
  $ autolandctl post-job test-repo p13 land-repo --pingback-url http://127.0.0.1 --patch-url http://hgweb/test-repo/raw-rev/$REV
  (200, u'{"request_id":13}\n')
  $ autolandctl post-job test-repo p14 land-repo --pingback-url http://192.168.0.1 --patch-url http://hgweb/test-repo/raw-rev/$REV
  (200, u'{"request_id":14}\n')
  $ autolandctl post-job test-repo p15 land-repo --pingback-url http://172.16.0.1 --patch-url http://hgweb/test-repo/raw-rev/$REV
  (200, u'{"request_id":15}\n')
  $ autolandctl post-job test-repo p16 land-repo --pingback-url http://10.0.0.1:443 --patch-url http://hgweb/test-repo/raw-rev/$REV
  (200, u'{"request_id":16}\n')
  $ autolandctl post-job test-repo p0 land-repo --pingback-url http://8.8.8.8:443 --patch-url http://hgweb/test-repo/raw-rev/$REV
  (400, u'{"error":"Bad request: bad pingback_url"}\n')
  $ autolandctl post-job test-repo p0 land-repo --pingback-url http://example.org:9898 --patch-url http://hgweb/test-repo/raw-rev/$REV
  (400, u'{"error":"Bad request: bad pingback_url"}\n')

Post the same job twice.  Start with stopping the autoland service to
guarentee the first request is still in the queue when the second is submitted.

  $ docker stop autoland_test.daemon
  autoland_test.daemon
  $ autolandctl post-job test-repo p17 land-repo --trysyntax "stuff"
  (200, u'{"request_id":17}\n')
  $ autolandctl post-job test-repo p17 land-repo --trysyntax "stuff"
  (400, u'{"error":"Bad Request: a request to land revision p17 to land-repo is already in progress"}\n')
