#!/bin/bash
echo Initialising Database
/home/autoland/venv/bin/python /home/autoland/docker/create-schema.py \
    "${CONFIG_FILE}" "${SRC_PATH}/schema/schema.sql"
