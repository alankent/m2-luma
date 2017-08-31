#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
set -x

# From https://github.com/docker-library/mysql/ 5.7/docker-entrypoint.sh

set -eo pipefail
shopt -s nullglob

# Fetch value from server config
# We use mysqld --verbose --help instead of my_print_defaults because the
# latter only show values present in config files, and not server defaults
_get_config() {
	local conf="$1"; shift
	"$@" --verbose --help --log-bin-index="$(mktemp -u)" 2>/dev/null | awk '$1 == "'"$conf"'" { print $2; exit }'
}

DATADIR=/var/lib/mysql

# allow the container to be started with `--user`
if [ "$(id -u)" = '0' ]; then
	mkdir -p "$DATADIR"
	chown -R mysql:mysql "$DATADIR"
	exec gosu mysql "$BASH_SOURCE" "$@"
fi

mkdir -p "$DATADIR"

echo 'Initializing database'
mysqld --initialize-insecure
echo 'Database initialized'

if command -v mysql_ssl_rsa_setup > /dev/null && [ ! -e "$DATADIR/server-key.pem" ]; then
	# https://github.com/mysql/mysql-server/blob/23032807537d8dd8ee4ec1c4d40f0633cd4e12f9/packaging/deb-in/extra/mysql-systemd-start#L81-L84
	echo 'Initializing certificates'
	mysql_ssl_rsa_setup --datadir="$DATADIR"
	echo 'Certificates initialized'
fi

SOCKET="$(_get_config 'socket' "$@")"
"$@" --skip-networking --socket="${SOCKET}" &
pid="$!"

echo ============= $pid ================

mysql=( mysql --protocol=socket -uroot -hlocalhost --socket="${SOCKET}" )

for i in {30..0}; do
	if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
		break
	fi
	echo 'MySQL init process in progress...'
echo ============= $pid ================
	tail -100 /var/log/mysql/error.log
	sleep 1
done
if [ "$i" = 0 ]; then
	echo >&2 'MySQL init process failed.'
	exit 1
fi

if [ -z "$MYSQL_INITDB_SKIP_TZINFO" ]; then
	# sed is for https://bugs.mysql.com/bug.php?id=20545
	mysql_tzinfo_to_sql /usr/share/zoneinfo | sed 's/Local time zone must be set--see zic manual page/FCTY/' | "${mysql[@]}" mysql
fi

# default root to listen for connections from anywhere
MYSQL_ROOT_HOST=%

echo ======= "${mysql[@]}" =======
ps -ef

"${mysql[@]}" <<-EOSQL
-- What's done in this file shouldn't be replicated
--  or products like mysql-fabric won't work
SET @@SESSION.SQL_LOG_BIN=0;

DELETE FROM mysql.user WHERE user NOT IN ('mysql.sys', 'mysqlxsys', 'root') OR host NOT IN ('localhost');
SET PASSWORD FOR 'root'@'localhost'=PASSWORD('${MYSQL_ROOT_PASSWORD}');
GRANT ALL ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
CREATE USER 'root'@'${MYSQL_ROOT_HOST}' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
GRANT ALL ON *.* TO 'root'@'${MYSQL_ROOT_HOST}' WITH GRANT OPTION ;
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOSQL

if [ ! -z "$MYSQL_ROOT_PASSWORD" ]; then
	mysql+=( -p"${MYSQL_ROOT_PASSWORD}" )
fi

if [ "$MYSQL_DATABASE" ]; then
	echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\`;" | "${mysql[@]}"
	mysql+=( "$MYSQL_DATABASE" )
fi

if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
	echo "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;" | "${mysql[@]}"

	if [ "$MYSQL_DATABASE" ]; then
		echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%' ;" | "${mysql[@]}"
	fi

	echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"
fi

if ! kill -s TERM "$pid" || ! wait "$pid"; then
	echo >&2 'MySQL init process failed.'
	exit 1
fi

sleep 2

echo
echo 'MySQL init process done. Ready for start up.'
echo

echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo +++ Starting mysqld server #1
"$@" &
pid="$!"
sleep 3
echo ========================= "${mysql[@]}"
echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"
if ! kill -s TERM "$pid" || ! wait "$pid"; then
	echo >&2 'MySQL init process failed.'
	exit 1
fi
sleep 2
	tail -100 /var/log/mysql/error.log

echo +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
echo +++ Starting mysqld server #2
"$@" &
pid="$!"
sleep 3
echo ========================= "${mysql[@]}"
echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"
if ! kill -s TERM "$pid" || ! wait "$pid"; then
	echo >&2 'MySQL init process failed.'
	exit 1
fi
sleep 2
	tail -100 /var/log/mysql/error.log
