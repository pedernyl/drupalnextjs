FROM drupal:latest

# Install Composer
RUN apt-get update && apt-get install -y curl unzip && rm -rf /var/lib/apt/lists/*
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

COPY composer.json composer.lock ./

# Install project files from composer.json and composer.lock
RUN composer install

COPY config/php/custom-php.ini /usr/local/etc/php/conf.d/
