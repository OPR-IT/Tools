#!/bin/bash

# Derive variables from the URL
read -p "Enter the website URL (e.g., yourdomain.com): " DOMAIN_NAME
WP_URL="http://$DOMAIN_NAME"
SUB_DIR="${DOMAIN_NAME//./_}"_$(date +%s) # Use the domain name with a timestamp as the subdirectory name
WP_DIR="/var/www/$SUB_DIR"
DB_NAME="${SUB_DIR}_db"
DB_USER="${SUB_DIR}_user"
DB_PASSWORD=$(openssl rand -base64 12) # Generating a random password

# Create WordPress installation directory
mkdir -p $WP_DIR
chown -R $SUDO_USER:$SUDO_USER $WP_DIR
cd $WP_DIR || exit

# Download WordPress
sudo -u $SUDO_USER wget https://wordpress.org/latest.tar.gz
sudo -u $SUDO_USER tar -xzvf latest.tar.gz
sudo -u $SUDO_USER rm latest.tar.gz

# Move WordPress files to the correct directory
mv wordpress/* $WP_DIR
rmdir wordpress

# Create the WordPress configuration file
sudo -u $SUDO_USER cp $WP_DIR/wp-config-sample.php $WP_DIR/wp-config.php
sudo -u $SUDO_USER sed -i "s/database_name_here/$DB_NAME/" $WP_DIR/wp-config.php
sudo -u $SUDO_USER sed -i "s/username_here/$DB_USER/" $WP_DIR/wp-config.php
sudo -u $SUDO_USER sed -i "s/password_here/$DB_PASSWORD/" $WP_DIR/wp-config.php

# Set up the database
mysql -u root -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
mysql -u root -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

# Set proper permissions
chown -R www-data:www-data $WP_DIR
chmod -R 755 $WP_DIR

# Update site URL in WordPress database
mysql -u $DB_USER -p$DB_PASSWORD -e "USE $DB_NAME; UPDATE wp_options SET option_value='$WP_URL' WHERE option_name='siteurl';"
mysql -u $DB_USER -p$DB_PASSWORD -e "USE $DB_NAME; UPDATE wp_options SET option_value='$WP_URL' WHERE option_name='home';"

# Generate CSR with Certbot
certbot certonly --webroot -w $WP_DIR -d $DOMAIN_NAME

# Create Apache Virtual Host Configuration File
tee /etc/apache2/sites-available/$SUB_DIR.conf > /dev/null << EOF
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
a2ensite $SUB_DIR.conf
a2enmod ssl
systemctl restart apache2

# Clean up WordPress temporary files
sudo rm -rf /var/www/latest.tar.gz

# Print installation summary
echo "WordPress installed successfully in a new subdirectory: $WP_DIR"
echo "Database Name: $DB_NAME"
echo "Database User: $DB_USER"
echo "Database Password: $DB_PASSWORD"
echo "Website URL: $WP_URL"
