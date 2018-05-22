#!/bin/sh
echo Starting autoland HTTPD on port ${PORT}
exec httpd -DFOREGROUND
