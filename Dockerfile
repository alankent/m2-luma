FROM alankent/m2-apache
MAINTAINER Alan Kent <alan.james.kent@gmail.com>


########### Magento Setup ########### 

ENV MAGENTO_USER magento
ENV MAGENTO_GROUP magento

# Install the source code.
ADD Magento-CE-2.1.2_sample_data-2016-10-11-11-27-51.tar.gz /magento2

# Add readme files so the directories are not empty (making PHP Storm remote
# file syncing able to pick up the empty directories.)
ADD README-code.txt /magento2/app/code/README.txt
ADD README-i18n.txt /magento2/app/i18n/README.txt
ADD README-frontend.txt /magento2/app/design/frontend/README.txt
ADD README-adminhtml.txt /magento2/app/design/adminhtml/README.txt

# Load the sample database
ADD magento2-install.sh /usr/local/bin


# Fix up file permissions.
# Load the database with Luma.
# Run cron jobs to update indexes etc.
# Bashrc file.
RUN cd /magento2 \
 && chown -R ${MAGENTO_USER}:${MAGENTO_GROUP} . \
 && chmod ug+x bin/magento \
 && chmod +x /usr/local/bin/magento2-install.sh \
 && service mysql start \
 && sleep 5 \
 && sudo -u ${MAGENTO_USER} /usr/local/bin/magento2-install.sh \
 && sleep 5 \
 && service mysql stop \
 && service cron start \
 && ( \
    echo "*/1 * * * * /usr/local/bin/php -c /usr/local/etc/php/php.ini /magento2/bin/magento cron:run" ; \
    echo "*/1 * * * * /usr/local/bin/php -c /usr/local/etc/php/php.ini /magento2/update/cron.php" ; \
    echo "*/1 * * * * /usr/local/bin/php -c /usr/local/etc/php/php.ini /magento2/bin/magento setup:cron:run" \
    ) | crontab -u ${MAGENTO_USER} -

# Entrypoint
ADD entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
