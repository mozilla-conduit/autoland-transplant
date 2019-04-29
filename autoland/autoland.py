#!/usr/bin/env python
import argparse
import base64
import datetime
import json
import logging
import os
import signal
import sys
import time
import traceback
import urlparse

import config
import lando
import mozreview
import psycopg2
import treestatus
from transplant import PatchTransplant, RepoTransplant


# max attempts to transplant before bailing
MAX_TRANSPLANT_ATTEMPTS = 50

# max updates to post to reviewboard / iteration
MOZREVIEW_COMMENT_LIMIT = 10

# time to wait before attempting to update MozReview after a failure to post
MOZREVIEW_RETRY_DELAY = datetime.timedelta(minutes=5)

# time to wait before retrying a transplant
TRANSPLANT_RETRY_DELAY = datetime.timedelta(minutes=5)

logger = logging.getLogger("autoland")


def handle_pending_transplants(dbconn):
    cursor = dbconn.cursor()
    now = datetime.datetime.now()
    query = """
        SELECT id, destination, request
        FROM Transplant
        WHERE landed IS NULL
              AND (last_updated IS NULL OR last_updated<=%(time)s)
        ORDER BY created
    """
    transplant_retry_delay = TRANSPLANT_RETRY_DELAY
    if config.testing():
        transplant_retry_delay = datetime.timedelta(seconds=1)

    cursor.execute(query, ({"time": now - transplant_retry_delay}))

    current_treestatus = {}
    finished_revisions = []
    mozreview_updates = []
    retry_revisions = []

    def handle_tree_retry(reason, transplant_id, tree, rev, destination, trysyntax):
        retry_revisions.append((now, transplant_id))
        data = {
            "request_id": transplant_id,
            "tree": tree,
            "rev": rev,
            "destination": destination,
            "trysyntax": trysyntax,
            "landed": False,
            "error_msg": "",
            "result": reason,
        }
        mozreview_updates.append([transplant_id, json.dumps(data)])

    # This code is a bit messy because we have to deal with the fact that the
    # the tree could close between the call to tree_is_open and when we
    # actually attempt the revision.
    #
    # We keep a list of revisions to retry called retry_revisions which we
    # append to whenever we detect a closed tree. These revisions have their
    # last_updated field updated so we will retry them after a suitable delay.
    #
    # The other list we keep is for transplant attempts that either succeeded
    # or failed due to a reason other than a closed tree, which is called
    # finished_revisions. Successful or not, we're finished with them, they
    # will not be retried.
    for row in cursor.fetchall():
        transplant_id, destination, request = row

        # Many of these values are used as command arguments. So convert
        # to binary because command arguments aren't unicode.
        destination = destination.encode("ascii")
        requester = request["ldap_username"]
        tree = request["tree"].encode("ascii")
        rev = request["rev"].encode("ascii")
        trysyntax = request.get("trysyntax", "")
        push_bookmark = request.get("push_bookmark", "").encode("ascii")
        commit_descriptions = request.get("commit_descriptions")
        patch_urls = [u.encode("ascii") for u in request.get("patch_urls", [])]

        repo_config = config.get_repo(tree)

        if trysyntax:
            # When pushing to try we need to check if try is open, not the
            # tree for the source repo.
            tree_name = "try"
        else:
            tree_name = repo_config.get("tree")

        if not tree_name:
            # Trees not present on treestatus cannot be closed.
            tree_open = True
        else:
            tree_open = current_treestatus.setdefault(
                destination, treestatus.tree_is_open(tree_name)
            )

        if not tree_open:
            handle_tree_retry(
                "Tree %s is closed - retrying later." % tree,
                transplant_id,
                tree,
                rev,
                destination,
                trysyntax,
            )
            continue

        attempts = 0
        started = datetime.datetime.now()
        landed = False
        while attempts < MAX_TRANSPLANT_ATTEMPTS:
            logger.info(
                "initiating transplant from tree: %s rev: %s "
                "to destination: %s, attempt %s"
                % (tree, rev, destination, attempts + 1)
            )

            os.environ["AUTOLAND_REQUEST_USER"] = requester
            try:
                if config.testing() and request.get("patch"):
                    tp = PatchTransplant(
                        tree,
                        destination,
                        rev,
                        None,
                        base64.b64decode(request.get("patch")),
                    )

                elif patch_urls:
                    tp = PatchTransplant(tree, destination, rev, patch_urls)

                else:
                    tp = RepoTransplant(tree, destination, rev, commit_descriptions)

                with tp:
                    if trysyntax:
                        result = tp.push_try(str(trysyntax))
                    elif push_bookmark:
                        result = tp.push_bookmark(push_bookmark)
                    else:
                        result = tp.push()
                landed = True
            except Exception as e:
                logger.exception(e)
                result = str(e)
                landed = False
            finally:
                del os.environ["AUTOLAND_REQUEST_USER"]

            logger.info(
                "transplant from tree: %s rev: %s attempt: %s: %s"
                % (tree, rev, attempts + 1, result)
            )

            if landed or "abort: push creates new remote head" not in result:
                break

            attempts += 1

        if landed:
            logger.info("transplant successful - new revision: %s" % result)

        else:
            if "is CLOSED!" in result:
                reason = "Tree %s is closed - retrying later." % tree
                logger.info("transplant failed: %s" % reason)
                current_treestatus[destination] = False
                handle_tree_retry(
                    reason, transplant_id, tree, rev, destination, trysyntax
                )
                continue

            elif "APPROVAL REQUIRED" in result:
                reason = (
                    'Tree %s is set to "approval required" - retrying ' "later." % tree
                )
                logger.info("transplant failed: %s" % reason)
                current_treestatus[destination] = False
                handle_tree_retry(
                    reason, transplant_id, tree, rev, destination, trysyntax
                )
                continue

            elif (
                "abort: push creates new remote head" in result
                or "repository changed while pushing" in result
            ):
                logger.info("transplant failed: we lost a push race")
                logger.info(result)
                retry_revisions.append((now, transplant_id))
                continue

            elif (
                "unresolved conflicts (see hg resolve" in result
                or "hunk FAILED -- saving rejects to file" in result
                or "hunks FAILED -- saving rejects to file" in result
            ):
                logger.info(
                    "transplant failed - manual rebase required: "
                    "tree: %s rev: %s destination: %s error: %s"
                    % (tree, rev, destination, result)
                )
                # This is the only autoland error for which we expect the
                # user to take action. We should make things nicer than the
                # raw mercurial error.
                header = (
                    "We're sorry, Autoland could not rebase your "
                    "commits for you automatically. Please manually "
                    "rebase your commits and try again.\n\n"
                )
                result = header + result

            else:
                logger.info(
                    "transplant failed: tree: %s rev: %s "
                    "destination: %s error: %s" % (tree, rev, destination, result)
                )

        completed = datetime.datetime.now()
        logger.info("elapsed transplant time: %s" % (completed - started))

        # set up data to be posted back to mozreview
        data = {
            "request_id": transplant_id,
            "tree": tree,
            "rev": rev,
            "destination": destination,
            "trysyntax": trysyntax,
            "landed": landed,
            "error_msg": "",
            "result": "",
        }

        if landed:
            data["result"] = result
        else:
            data["error_msg"] = result

        mozreview_updates.append([transplant_id, json.dumps(data)])

        finished_revisions.append([landed, result, transplant_id])

    if retry_revisions:
        query = """
            update Transplant set last_updated=%s
            where id=%s
        """
        cursor.executemany(query, retry_revisions)
        dbconn.commit()

    if finished_revisions:
        query = """
            update Transplant set landed=%s,result=%s
            where id=%s
        """
        cursor.executemany(query, finished_revisions)
        dbconn.commit()

    if mozreview_updates:
        query = """
            insert into MozreviewUpdate(transplant_id,data)
            values(%s,%s)
        """
        cursor.executemany(query, mozreview_updates)
        dbconn.commit()


def handle_pending_mozreview_updates(dbconn):
    """Attempt to post updates to mozreview"""

    cursor = dbconn.cursor()
    query = """
        select MozreviewUpdate.id,transplant_id,request,data
        from MozreviewUpdate inner join Transplant
        on (Transplant.id = MozreviewUpdate.transplant_id)
        limit %(limit)s
    """
    cursor.execute(query, {"limit": MOZREVIEW_COMMENT_LIMIT})

    mozreview_pingback = mozreview.MozReviewPingback()
    lando_pingback = lando.LandoPingback()

    completed = []
    failed = False
    for row in cursor.fetchall():
        update_id, transplant_id, request, data = row

        # Validate the pingback hostname is still present in config.json.
        pingback_url = request.get("pingback_url")
        hostname = urlparse.urlparse(pingback_url).hostname

        if hostname == "localhost":
            # localhost pingbacks are always a NO-OP; used during development
            # and testing.
            pingback_url = None

        else:
            if hostname not in config.get("pingback", {}):
                logger.error("ignoring pingback to %s: unconfigured" % hostname)
                pingback_url = None

        # Use the appropriate handler for this pingback.
        if pingback_url:
            pingback_config = config.get("pingback").get(hostname)

            if pingback_config["type"] == "mozreview":
                pingback = mozreview_pingback

            elif pingback_config["type"] == "lando":
                pingback = lando_pingback

            else:
                logger.warning("ignoring pinback to %s: not supported" % hostname)
                pingback_url = None

        # Update the requester if required.
        if pingback_url:
            logger.info(
                "trying to post %s update to: %s for request: %s"
                % (pingback.name, pingback_url, transplant_id)
            )

            status_code, text = pingback.update(pingback_url, data)

            if status_code == 200:
                # Success.
                completed.append([update_id])

            elif status_code == 404:
                # Submitting system "forgot" about this request; delete it
                # so we can continuing processing pending updates.
                logger.info("failed: %s - %s" % (status_code, text))
                completed.append([update_id])

            else:
                # Treat anything else as a transient failure.
                logger.info("failed: %s - %s" % (status_code, text))
                failed = True
                break

        else:
            completed.append([update_id])

    if completed:
        query = """
            delete from MozreviewUpdate
            where id=%s
        """
        cursor.executemany(query, completed)
        dbconn.commit()

    return not failed


def get_dbconn(dsn):
    dbconn = None
    while not dbconn:
        try:
            dbconn = psycopg2.connect(dsn)
        except psycopg2.OperationalError:
            time.sleep(0.1)
    return dbconn


def main():
    parser = argparse.ArgumentParser()

    dsn = config.get("database")

    parser.add_argument("--dsn", default=dsn, help="Postgresql DSN connection string")
    args = parser.parse_args()

    # log to stdout
    stdout_handler = logging.StreamHandler(sys.stdout)
    stdout_handler.setFormatter(logging.Formatter("%(levelname)s %(message)s"))
    logger.addHandler(stdout_handler)
    logger.setLevel(logging.DEBUG)

    # boto's debug logging is rather verbose.
    logging.getLogger("botocore").setLevel(logging.INFO)

    logger.info("starting autoland")
    dbconn = get_dbconn(args.dsn)

    # Set up signal handling to ensure we aren't cancelled mid-transplant.
    global running
    running = True

    def handle_term(signal, frame):
        logger.info("stopping autoland")
        global running
        running = False

    signal.signal(signal.SIGTERM, handle_term)
    signal.signal(signal.SIGINT, handle_term)

    last_error_msg = None
    next_mozreview_update = datetime.datetime.now()
    while running:
        try:
            handle_pending_transplants(dbconn)

            # TODO: In normal configuration, all updates will be posted to the
            # same MozReview instance, so we don't bother tracking failure to
            # post for individual urls. In the future, we might need to
            # support this.
            if datetime.datetime.now() > next_mozreview_update:
                ok = handle_pending_mozreview_updates(dbconn)
                if ok:
                    next_mozreview_update += datetime.timedelta(seconds=1)
                else:
                    next_mozreview_update += MOZREVIEW_RETRY_DELAY

            time.sleep(0.1)
        except psycopg2.InterfaceError:
            dbconn = get_dbconn(args.dsn)
        except:
            # If things go really badly, we might see the same exception
            # thousands of times in a row. There's not really any point in
            # logging it more than once.
            error_msg = traceback.format_exc()
            if error_msg != last_error_msg:
                logger.error(error_msg)
                last_error_msg = error_msg


if __name__ == "__main__":
    main()
