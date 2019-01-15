#!/usr/bin/env python

import argparse
import base64
import json
import os
import subprocess
import time

import requests.adapters
from urllib3.util.retry import Retry

DEBUG = bool(os.getenv("DEBUG"))
ROOT = os.path.abspath(os.path.dirname(__file__))
RUN_TESTS = os.path.join(ROOT, "..", "..", "run-tests")
AUTOLAND_URL = "http://localhost:%s/autoland" % os.getenv("HOST_AUTOLAND")

POLL_TIMEOUT = 10  # seconds

# autoland_rest throws BadStatusLine errors while it's starting up - retry
requests_session = requests.Session()
Retry.BACKOFF_MAX = 0.25
retry = Retry(total=10, method_whitelist=False, backoff_factor=0.1)
requests_session.mount("http://", requests.adapters.HTTPAdapter(max_retries=retry))


def post_job(args):
    """Post a job to autoland.api container."""
    data = {
        "tree": args.tree,
        "rev": args.rev,
        "destination": args.destination,
        "pingback_url": args.pingback_url,
        "ldap_username": "autolanduser@example.com",
    }
    if args.trysyntax:
        data["trysyntax"] = args.trysyntax
    if args.push_bookmark:
        data["push_bookmark"] = args.push_bookmark
    if args.commit_descriptions:
        data["commit_descriptions"] = json.loads(args.commit_descriptions)
    if args.patch_url:
        data["patch_urls"] = [args.patch_url]
    if args.patch_file:
        with open(args.patch_file) as f:
            data["patch"] = base64.b64encode(f.read())

    r = requests_session.post(
        AUTOLAND_URL,
        data=json.dumps(data, sort_keys=True),
        headers={"Content-Type": "application/json"},
        auth=(args.username, args.password),
    )
    print(r.status_code, r.text)


def job_status(args):
    """Check job status.  If --poll is provided, block until job is complete."""
    url = "%s/status/%s" % (AUTOLAND_URL, args.request_id)

    if not args.poll:
        r = requests_session.get(url)
        print(r.status_code, r.text)
        return

    start_time = time.time()
    while time.time() - start_time < POLL_TIMEOUT:
        r = requests_session.get(url)
        if r.status_code != 200 or json.loads(r.text)["landed"] is not None:
            print(r.status_code, r.text)
            return
        time.sleep(0.1)

    print("timed out")


def execute(args):
    """Execute command on container."""
    cmd = ["docker", "exec"]

    # pick a default user based on the container
    if not args.user:
        default_users = dict(daemon="autoland", api="apache", hg="apache")
        args.user = default_users.get(args.container, None)

    # allow the caller to override default user
    if args.user:
        cmd += ["--user", args.user]
    cmd += ["-i", "autoland_test.%s" % args.container]

    # run using bash if required
    if args.shell:
        cmd += ["bash", "-c", " ".join(args.command)]
    else:
        cmd += args.command

    subprocess.check_call(cmd)


def treestatus(args):
    # The treestatus container isn't exposed externally; set the status from
    # within the transplant container.
    subprocess.check_call(
        ["docker", "exec", "autoland_test.daemon"]
        + ["curl", "-s", "-X", "PUT", "http://treestatus:8000/%s" % args.status]
    )


def main():
    try:
        parser = argparse.ArgumentParser()
        subparsers = parser.add_subparsers(help="command")
        subparsers.required = True
        subparsers.dest = "command"

        # post-job
        cmd = subparsers.add_parser("post-job", help="Post job to autoland")
        cmd.add_argument("tree", help="Source tree of the revision")
        cmd.add_argument("rev", help="Revision to land")
        cmd.add_argument("destination", help="Destination tree for the revision")
        cmd.add_argument(
            "--pingback-url",
            default="http://localhost:9898/",
            help="URL to which Autoland should post result",
        )
        cmd.add_argument("--trysyntax", help="Try syntax to use")
        cmd.add_argument("--push-bookmark", help="Bookmark name to use when pushing")
        cmd.add_argument(
            "--commit-descriptions", help="Commit descriptions to use when rewriting"
        )
        cmd.add_argument("--username", default="autoland", help="autoland api username")
        cmd.add_argument("--password", default="autoland", help="autoland api password")
        cmd.add_argument("--patch-url", help="URL of patch")
        cmd.add_argument("--patch-file", help="Patch file to inline into request")
        cmd.set_defaults(func=post_job)

        # job-status
        cmd = subparsers.add_parser("job-status", help="Get an autoland job status")
        cmd.add_argument("request_id", help="ID of the job for which to get status")
        cmd.add_argument(
            "--poll",
            action="store_true",
            help="Poll the status until the job is serviced or %s has elapsed"
            % POLL_TIMEOUT,
        )
        cmd.set_defaults(func=job_status)

        # exec
        cmd = subparsers.add_parser("exec", help="Execute command within a container")
        cmd.add_argument(
            "--container",
            "-c",
            default="daemon",
            help="Container name (will be prefixed with 'autoland_test'.)",
        )
        cmd.add_argument("--user", help="User to execute commands as")
        cmd.add_argument(
            "--shell",
            "-s",
            action="store_true",
            default=False,
            help="Execute commands with shell",
        )
        cmd.add_argument("command", nargs=argparse.REMAINDER, help="Command to execute")
        cmd.set_defaults(func=execute)

        # treestatus
        cmd = subparsers.add_parser("treestatus", help="Set the treestatus response")
        cmd.add_argument("status", choices=["open", "closed"], help="Status")
        cmd.set_defaults(func=treestatus)

        args = parser.parse_args()
        args.func(args)
    except KeyboardInterrupt:
        pass
    except Exception as e:
        if DEBUG:
            raise
        print(e)


main()
