#!/bin/sh

if [ -f /var/www/magento2/composer.json ]; then
    grep magento/product /var/www/magento2/composer.json | sed -e 's/^[ ]*//'
fi
