# Warm the cache a bit so demos start faster
RUN /usr/local/bin/mysql-start.sh \
 && sleep 1 \
 && (php-fpm -F &) \
 && sleep 1 \
 && apachectl start \
 && sleep 5 \
 && mkdir /wget.tmp \
 && cd /wget.tmp \
 && wget --recursive --reject-regex "(.*)\?(.*)" --level=1 http://localhost/ \
 && cd / \
 && rm -rf wget.tmp \
 && service mysql stop \
 && apachectl stop \
 && sleep 10
