#!/bin/bash

# Start up MySQL
service mysql start

# Be friendly, give MySQL a nice head start.
sleep 2

exec bash /usr/local/bin/entrypoint.sh
