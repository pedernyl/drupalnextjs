#!/bin/bash
set -e

echo "Väntar på databasen..."
sleep 10

cd /var/www/html

# Kontrollera om Composer finns
if ! command -v composer &> /dev/null; then
    echo "Installerar Composer..."
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
fi

# Installera Drush globalt om det inte redan finns
if ! command -v drush &> /dev/null; then
    echo "Installerar Drush..."
    composer global require drush/drush
    export PATH="$HOME/.composer/vendor/bin:$PATH"
    ln -s ~/.composer/vendor/bin/drush /usr/local/bin/drush
fi

# Se till att Drupal är installerat via Composer
if [ ! -d "web/core" ]; then
    echo "Drupal saknas! Installerar via Composer..."
    composer create-project drupal/recommended-project .
else
    echo "Drupal finns redan, hoppar över installation."
fi


# Installera beroenden om de saknas
echo "Uppdaterar Composer-paket..."
composer install

# Om Drupal inte redan är installerat, kör installationen
if [ ! -f web/sites/default/settings.php ]; then
    echo "Installerar Drupal..."
    vendor/bin/drush site:install standard \
        --db-url=mysql://drupal:drupal@db/drupal \
        --site-name="Min Drupal-sajt" \
        --account-name=admin \
        --account-pass=admin \
        --yes

    echo "Sätter rättigheter för settings.php..."
    chmod 644 web/sites/default/settings.php
fi

# Installera och aktivera GraphQL-modulen
echo "Installerar GraphQL-modulen..."
composer require drupal/graphql:^4
vendor/bin/drush en graphql -y

echo "Drupal är installerat med GraphQL!"
apache2-foreground
