#!/usr/bin/env python

import json
import os
import sys

if len(sys.argv) != 2:
    print('syntax: create-config.py <config file>')
    sys.exit(1)
config_file = sys.argv[1]

config = {
    'testing': True,
    'database': "host='autolanddb' dbname='autoland' "
                "user='autoland' password='autoland'",
    'auth': {
        'autoland': os.getenv('AUTOLAND_KEY', 'autoland'),
    },
    'repos': {
        os.getenv('REPO_NAME', 'land-repo'): {
            'tree': os.getenv('REPO_NAME', 'land-repo'),
        },
        'try': {
            'tree': 'try',
        },
    },
    'pingback': {
        'example.com': {
            'typo': 'lando',
            'api-key': 'secret',
        },
        os.getenv('LANDO_HOST', 'lando.example.com'): {
            'type': 'lando',
            'api-key': os.getenv('LANDO_API_KEY', 'secret'),
        },
    },
    'patch_url_buckets': {
        os.getenv('LANDO_BUCKET', 'lando-dev'): {
            'aws_access_key_id': os.getenv('LANDO_AWS_KEY', 'key'),
            'aws_secret_access_key': os.getenv('LANDO_AWS_SECRET', 'secret'),
        },
    },
}

print('creating %s' % config_file)
with open(config_file, mode='w') as f:
    json.dump(config, f, indent=4, sort_keys=True)
