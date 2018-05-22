#!/bin/sh
set -e

if [[ ! -d /repos/${REPO_NAME} ]]; then
    echo Cloning ${REPO_NAME} from ${REPO_URL}
    hg clone ${REPO_URL} /repos/${REPO_NAME}
    envsubst < /home/autoland/docker/hgrc.template > /repos/${REPO_NAME}/.hg/hgrc
    if [[ -n "${IS_TESTING}" ]]; then
        # the test environment has three repos (test-repo, land-repo, and try)
        echo upstream = http://hgweb/land-repo >> /repos/${REPO_NAME}/.hg/hgrc
        echo land-repo = http://hgweb/land-repo >> /repos/${REPO_NAME}/.hg/hgrc
        echo try = http://hgweb/try >> /repos/${REPO_NAME}/.hg/hgrc
    else
        # while the normal environment only has one (test-repo)
        echo upstream = ${REPO_URL} >> /repos/${REPO_NAME}/.hg/hgrc
    fi
fi

. /home/autoland/venv/bin/activate
cd ${SRC_PATH}
exec python autoland.py > /home/autoland/autoland.log
