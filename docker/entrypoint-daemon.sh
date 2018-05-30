#!/bin/sh
set -e

if [[ ! -d /repos/land-repo ]]; then
    for REPO_NAME in land-repo test-repo try; do
        REPO_URL=http://hgweb/${REPO_NAME}
        echo Cloning $REPO from ${REPO_URL}
        hg clone ${REPO_URL} /repos/${REPO_NAME}
        envsubst < /home/autoland/docker/hgrc.template > /repos/${REPO_NAME}/.hg/hgrc
    done
fi

. /home/autoland/venv/bin/activate
cd ${SRC_PATH}
exec python autoland.py
