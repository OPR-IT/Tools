#!/bin/bash

# Get user input for variables
read -p "Enter the WordPress installation directory (e.g., /var/www/html): " WP_DIR
read -p "Enter the desired domain name for the WordPress site (e.g., example.com): " DOMAIN_NAME
read -p "Enter the desired database name for WordPress: " DB_NAME
read -p "Enter the desired database username for WordPress: " DB_USER
read -s -p "Enter the password for the database user: " DB_PASSWORD
echo ""
read -p "Enter your website URL (e.g., http://yourdomain.com): " WP_URL

# Create WordPress installation directory
sudo mkdir -p $WP_DIR
sudo chown -R $USER:$USER $WP_DIR
cd $WP_DIR

# Download WordPress
wget https://wordpress.org/latest.tar.gz
tar -xzvf latest.tar.gz
rm latest.tar.gz

# Create the WordPress configuration file
cd wordpress
cp wp-config-sample.php wp-config.php
sed -i "s/database_name_here/$DB_NAME/" wp-config.php
sed -i "s/username_here/$DB_USER/" wp-config.php
sed -i "s/password_here/$DB_PASSWORD/" wp-config.php

# Set up the database
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS $DB_NAME"
mysql -u root -p -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD'"
mysql -u root -p -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost'"
mysql -u root -p -e "FLUSH PRIVILEGES"

# Set up WordPress site
mv * ../
cd ..
rmdir wordpress

# Set proper permissions
sudo chown -R www-data:www-data $WP_DIR
sudo chmod -R 755 $WP_DIR

# Update site URL in WordPress database
mysql -u $DB_USER -p $DB_NAME -e "UPDATE wp_options SET option_value='$WP_URL' WHERE option_name='siteurl'"
mysql -u $DB_USER -p $DB_NAME -e "UPDATE wp_options SET option_value='$WP_URL' WHERE option_name='home'"

# Generate CSR with Certbot
sudo certbot certonly --webroot -w $WP_DIR -d $DOMAIN_NAME

# Create Apache Virtual Host Configuration File
sudo tee /etc/apache2/sites-available/$DOMAIN_NAME.conf > /dev/null << EOF
<VirtualHost *:80>
    ServerAdmin webmaster@$DOMAIN_NAME
    ServerName $DOMAIN_NAME
    DocumentRoot $WP_DIR
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
</VirtualHost>

<VirtualHost *:443>
    ServerAdmin webmaster@$DOMAIN_NAME
    ServerName $DOMAIN_NAME
    DocumentRoot $WP_DIR
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
    <Directory $WP_DIR>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem
    Include /etc/letsencrypt/options-ssl-apache.conf
</VirtualHost>
EOF

# Enable Apache Virtual Host and SSL
sudo a2ensite $DOMAIN_NAME.conf
sudo a2enmod ssl
sudo systemctl restart apache2

echo "WordPress installed successfully with directories created, Apache virtual host, Certbot-generated SSL, and HTTP to HTTPS redirection!"
