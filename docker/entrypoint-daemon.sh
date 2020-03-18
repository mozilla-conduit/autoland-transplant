#!/bin/sh
set -e

if [[ ! -d /repos/first-repo ]]; then
    for REPO_NAME in first-repo second-repo third-repo; do
        REPO_URL=http://${HG_WEB_HOSTNAME}/${REPO_NAME}
        echo Cloning $REPO_NAME from ${REPO_URL}
        hg clone ${REPO_URL} /repos/${REPO_NAME}
        export REPO_NAME
        envsubst < /home/autoland/docker/hgrc.template > /repos/${REPO_NAME}/.hg/hgrc
    done
fi

. /home/autoland/venv/bin/activate
cd ${SRC_PATH}
exec python autoland.py
