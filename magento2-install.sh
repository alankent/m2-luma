#!/bin/bash

set -x

cd /var/www/magento2

# Install Magento and load sample data.
bin/magento setup:install --backend-frontname=admin \
	--cleanup-database --db-host=127.0.0.1 \
	--db-name=magento2 --db-user=magento2 --db-password=magento2 \
	--admin-firstname=Magento --admin-lastname=User \
	--admin-email=user@example.com \
	--admin-user=admin --admin-password=admin123 --language=en_US \
	--currency=USD --timezone=America/Chicago --use-rewrites=1 \
	--use-sample-data

# Trigger index rebuilds to make sure everything is ready before
# web server starts (reduces warnings in admin UI about indexes not
# being up to date)
bin/magento cron:run
bin/magento cron:run

# Deploy static view assets to make the start up phase faster.
bin/magento setup:static-content:deploy

# Set developer mode
bin/magento deploy:mode:set developer
