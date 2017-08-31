#!/bin/sh


# From https://github.com/docker-library/mysql

# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
groupadd -r mysql
useradd -r -g mysql mysql

# add gosu for easy step-down from root
GOSU_VERSION=1.7
set -x
apt-get update && apt-get install -y --no-install-recommends ca-certificates wget && rm -rf /var/lib/apt/lists/*
wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)"
wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc"
export GNUPGHOME="$(mktemp -d)"
gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4
gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu
rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc
chmod +x /usr/local/bin/gosu
gosu nobody true 

mkdir /docker-entrypoint-initdb.d

# FATAL ERROR: please install the following Perl modules before executing /usr/local/mysql/scripts/mysql_install_db:
# File::Basename
# File::Copy
# Sys::Hostname
# Data::Dumper
apt-get update
apt-get install -y perl pwgen --no-install-recommends
rm -rf /var/lib/apt/lists/*

# gpg: key 5072E1F5: public key "MySQL Release Engineering <mysql-build@oss.oracle.com>" imported
apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys A4A9406876FCBD3C456770C88C718D3B5072E1F5

# Warning: MYSQL_VERSION need updating frequently. Current number can be found
# in https://github.com/docker-library/mysql/blob/master/5.6/Dockerfile
export MYSQL_MAJOR=5.7
export MYSQL_VERSION=5.7.19-1debian8

echo "deb http://repo.mysql.com/apt/debian/ jessie mysql-${MYSQL_MAJOR}" > /etc/apt/sources.list.d/mysql.list

# the "/var/lib/mysql" stuff here is because the mysql-server postinst doesn't have an explicit way to disable the mysql_install_db codepath besides having a database already "configured" (ie, stuff in /var/lib/mysql/mysql)
# also, we set debconf keys to make APT a little quieter
{
    echo mysql-community-server mysql-community-server/data-dir select '';
    echo mysql-community-server mysql-community-server/root-pass password '';
    echo mysql-community-server mysql-community-server/re-root-pass password '';
    echo mysql-community-server mysql-community-server/remove-test-db select false;
    } | debconf-set-selections
apt-get update && apt-get install -y mysql-server="${MYSQL_VERSION}" && rm -rf /var/lib/apt/lists/*
rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /var/run/mysqld
chown -R mysql:mysql /var/lib/mysql /var/run/mysqld
# ensure that /var/run/mysqld (used for socket and lock files) is writable regardless of the UID our mysqld instance ends up having at runtime
chmod 777 /var/run/mysqld

# comment out a few problematic configuration values
# don't reverse lookup hostnames, they are usually another container
sed -Ei 's/^(bind-address|log)/#&/' /etc/mysql/mysql.conf.d/mysqld.cnf
echo '[mysqld]\nskip-host-cache\nskip-name-resolve' > /etc/mysql/conf.d/docker.cnf 

exit 0


# # add our user and group first to make sure their IDs get assigned
# # consistently, regardless of whatever dependencies get added
# groupadd -r mysql
# useradd -r -g mysql mysql
# mkdir /docker-entrypoint-initdb.d
# apt-get update
# apt-get install -y mysql-server-5.7
# sed -Ei 's/^(bind-address|log)/#&/' /etc/mysql/my.cnf
# mv /tmp/my.cnf /etc/mysql/my.cnf
# mysql_secure_installation
