#!/bin/sh
set -e

export SRC_PATH=${SRC_PATH:-/home/autoland/autoland}
export PORT=${PORT:-8000}
export CONFIG_FILE=/home/autoland/config.json

cd ${SRC_PATH}
/home/autoland/docker/create-config.py ${CONFIG_FILE}
envsubst < /home/autoland/docker/autoland.conf.template > /etc/httpd/conf/autoland.conf

case "${1:-help}" in
    "help")
        exec echo "This image is designed to be run by docker-compose"
        ;;
    "init")
        exec su autoland -c /home/autoland/docker/entrypoint-init.sh
        ;;
    "api")
        # test environment doesn't have any persistent volumes; always init
        [[ -n "${IS_TESTING}" ]] && su autoland -c /home/autoland/docker/entrypoint-init.sh
        exec /home/autoland/docker/entrypoint-api.sh
        ;;
    "daemon")
        # test environment doesn't have any persistent volumes; always init
        [[ -n "${IS_TESTING}" ]] && su autoland -c /home/autoland/docker/entrypoint-init.sh
        exec su autoland -c /home/autoland/docker/entrypoint-daemon.sh
        ;;
    *)
        exec $*
        ;;
esac

