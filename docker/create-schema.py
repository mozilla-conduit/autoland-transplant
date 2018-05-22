#!/usr/bin/env python

import json
import sys
import time

import psycopg2


def db_conn(dsn):
    # Wait for the postgres server to startup.
    start_time = time.time()
    last_error = None
    while time.time() - start_time < 30:
        try:
            return psycopg2.connect(dsn)
        except psycopg2.OperationalError as e:
            last_error = e
            time.sleep(0.1)
    raise Exception('failed to connect to postgres: %s' % last_error)


if len(sys.argv) != 3:
    print('syntax: create-schema.py <config.json file> <schema.sql file>')
    sys.exit(1)

config_file = sys.argv[1]
sql_file = sys.argv[2]

with open(config_file) as f:
    config = json.load(f)

print('connecting to %s' % config['database'])
with db_conn(config['database']) as conn:
    conn.autocommit = True
    with conn.cursor() as curs:
        curs.execute("SELECT current_database()")
        db_name = curs.fetchone()[0]
        curs.execute(
            "SELECT EXISTS ("
            "   SELECT 1"
            "     FROM information_schema.tables"
            "    WHERE table_catalog='%s' AND table_name='%s'"
            ")" % (db_name, 'transplant'))

        if not curs.fetchone()[0]:
            print('initialising schema from %s' % sql_file)
            curs.execute(open(sql_file).read())
