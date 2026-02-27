FROM php:8.2-apache-bullseye

# Install dependencies for Mautic, Composer, Node, and Cron
RUN apt-get update && apt-get install -y \
    cron \
    supervisor \
    unzip \
    libzip-dev \
    libicu-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libonig-dev \
    libxml2-dev \
    libc-client-dev \
    libkrb5-dev \
    git \
    curl \
    mariadb-client \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Configure and install PHP extensions required by Mautic
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-install -j$(nproc) gd intl pdo_mysql mysqli zip opcache bcmath exif imap soap

# Enable Apache modules required by Mautic
RUN a2enmod rewrite ssl headers

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Install Node.js (for asset compilation)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Configure PHP for Mautic
RUN echo "memory_limit = 512M" > /usr/local/etc/php/conf.d/mautic.ini \
    && echo "upload_max_filesize = 128M" >> /usr/local/etc/php/conf.d/mautic.ini \
    && echo "post_max_size = 128M" >> /usr/local/etc/php/conf.d/mautic.ini \
    && echo "max_execution_time = 300" >> /usr/local/etc/php/conf.d/mautic.ini \
    && echo "date.timezone = UTC" >> /usr/local/etc/php/conf.d/mautic.ini

# Set working directory
WORKDIR /var/www/html

# Ensure www-data can write to its home directory for npm cache
RUN mkdir -p /var/www/.npm && chown -R www-data:www-data /var/www/.npm

# Copy the repository code into the container
COPY --chown=www-data:www-data . /var/www/html

# Setup cron configuration
COPY crontab /etc/cron.d/mautic
RUN chmod 0644 /etc/cron.d/mautic

# Setup Supervisor configuration
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Setup Entrypoint
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Let Apache know the document root (Mautic 5 uses the root)
ENV APACHE_DOCUMENT_ROOT /var/www/html
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

ENTRYPOINT ["docker-entrypoint.sh"]

# Command starts supervisor which runs both apache and cron
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
