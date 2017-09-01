#!/bin/bash

# HACK! Docker has a "union file system" with copy-on-write
# semantics. When it starts up and locks files, then you modify
# the file, it appears it copies the file causing problems for
# MySQL locking. This seems a problem for database contents in
# particular. This hack touches all the data files for databases
# forcing a local copy before mysqld starts up, avoiding this
# problem.
chown -R mysql:mysql /var/lib/mysql

service mysql start
