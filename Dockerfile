FROM drupal:latest

# Installera Composer
RUN apt-get update && apt-get install -y curl unzip && rm -rf /var/lib/apt/lists/*
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

COPY composer.json composer.lock ./

RUN composer install

# Kopiera installationsskriptet och göra det körbart
COPY install-drupal.sh /install-drupal.sh
RUN chmod +x /install-drupal.sh

# Kör skriptet vid uppstart
#CMD ["/bin/bash", "/install-drupal.sh"]
#CMD ["/bin/bash"]
