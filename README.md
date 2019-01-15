Dockerised `autoland transplant` for development.


OVERVIEW

Autoland is a tool that automatically lands patches from one Mercurial tree
to another. It is used at Mozilla to land requests from MozReview
(Review Board) and Lando (Phabricator).


QUICK START

`./create-virtualenv` to create the venv required for testing (and useful
for IDE integration).  Requires PostgreSQL 9.5 client libraries.

If installing psycopg2 fails on OSX with "ld: library not found for -lssl",
install openssl with homebrew then tell pip to use the openssl libraries
when building the PostgreSQL libraries:

    $ brew install openssl
    $ LDFLAGS="-I/usr/local/opt/openssl/include -L/usr/local/opt/openssl/lib" ./create-virtualenv

`docker-compose up --build --detach` to start the environment.

`clone-repo` to clone the Mercurial repository from your development
environment locally (into the `dev-repo` directory).  Commit changes to this
repository and use `../post-to-autoland` to submit commits.

Use http://localhost:8100/ to access autoland-transplant and
http://localhost:8101/ to access the Mercurial repositories.


    $ ./clone-repo
    cloning into dev-repo
    requesting all changes
    adding changesets
    adding manifests
    adding file changes
    added 1 changesets with 1 changes to 1 files
    new changesets 9fb7afc7a593
    updating to branch default
    1 files updated, 0 files merged, 0 files removed, 0 files unresolved
    $ cd dev-repo/
    $ echo testing >> readme
    $ hg commit -Am 'test commit'
    $ ../post-to-autoland
    Posting e9a97bd49986100e6de657df32471367b1460684
    Submission success: request_id 2
    $ curl -s http://localhost:8100/autoland/status/2
    {
      "destination": "land-repo",
      "error_msg": "",
      "landed": true,
      "ldap_username": "autoland@example.com",
      "patch": "...",
      "result": "34e4e39bb9f8418e0aa7852493033670c8206bc6",
      "rev": "1",
      "tree": "land-repo"
    }

Edit files in `autoland/` and run `docker-compose up --build --detach` again
to deploy your changes into the development environment.

Run tests with `./run-tests`.
