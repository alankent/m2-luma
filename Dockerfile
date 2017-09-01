FROM alankent/magento2devbox-web
MAINTAINER Alan Kent <alan.james.kent@gmail.com>

########### MySQL Setup ###########

ENV MYSQL_ROOT_PASSWORD=root
ENV MYSQL_DATABASE=magento2
ENV MYSQL_USER=magento2
ENV MYSQL_PASSWORD=magento2
ENV MYSQL_ALLOW_EMPTY_PASSWORD=yes

# Install the MySQL server
ADD mysql-install.sh /usr/local/bin
RUN chmod +x /usr/local/bin/mysql-install.sh
RUN /usr/local/bin/mysql-install.sh

ADD mysqld.cnf /etc/mysql/mysql.conf.d

# Initialize server and create the 'magento2' database
ADD mysql-init.sh /usr/local/bin
RUN chmod +x /usr/local/bin/mysql-init.sh
RUN /usr/local/bin/mysql-init.sh mysqld


########### Magento Setup ########### 

# Install the source code.
RUN rm -rf /var/www/magento2
ADD Magento-CE-2.1.8_sample_data-2017-08-09-08-33-36.tar.gz /var/www/magento2

# Add readme files so the directories are not empty (making PHP Storm remote
# file syncing able to pick up the empty directories.)
ADD README-code.txt /var/www/magento2/app/code/README.txt
ADD README-i18n.txt /var/www/magento2/app/i18n/README.txt
ADD README-frontend.txt /var/www/magento2/app/design/frontend/README.txt
ADD README-adminhtml.txt /var/www/magento2/app/design/adminhtml/README.txt

# Load the sample database
ADD magento2-install.sh /usr/local/bin

# Fix up file permissions.
RUN mkdir -p /var/www/magento2/var/log
RUN cd /var/www/magento2 && chown -R magento2:magento2 .
RUN chmod ug+x /var/www/magento2/bin/magento
RUN chmod +x /usr/local/bin/magento2-install.sh

# Load the database with Luma.
# Let cron jobs to update indexes etc.
RUN cd /var/www/magento2 \
 && chown -R mysql:mysql /var/lib/mysql \
 && service mysql start \
 && sleep 5 \
 && sudo -u magento2 /usr/local/bin/magento2-install.sh \
 && sleep 5 \
 && service mysql stop

# Hostname is not 'db', its now 'localhost'
ADD my.cnf /home/magento2/.my.cnf

# Turn on cron after Magento is installed.
RUN sudo -u magento2 mkdir -p /var/www/magento2/var/log/ \
 && chown -R magento2:magento2 /home/magento2 \
 && chmod +x /home/magento2/bin/* \
 && sudo -u magento2 bash /home/magento2/bin/cron-install

# Add mysqld to boot up sequence
#RUN TODO

# Entrypoint
#ADD entrypoint.sh /
#RUN chmod +x /entrypoint.sh
#ENTRYPOINT ["/entrypoint.sh"]
