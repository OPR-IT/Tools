#!/bin/bash

# Derive variables from a domain
read -p "Enter your new domain (e.g., yourdomain.com): " DOMAIN_NAME
WP_URL="https://${DOMAIN_NAME}"
SUB_DIR="${DOMAIN_NAME//./_}"
WP_DIR="/var/www/$SUB_DIR"
DB_NAME="${SUB_DIR}_db"
DB_USER="${SUB_DIR}_user"
DB_PASSWORD="${SUB_DIR}_pass"

# Create WordPress directory
mkdir -p $WP_DIR
chown -R www-data:www-data $WP_DIR
chmod -R 755 $WP_DIR
cd $WP_DIR

# Download WordPress
wget https://wordpress.org/latest.tar.gz
tar -xzvf latest.tar.gz
rm latest.tar.gz

# Extract contents here
mv wordpress/* ./
rm -r wordpress

# Configure
cp $WP_DIR/wp-config-sample.php $WP_DIR/wp-config.php
sed -i "s/database_name_here/$DB_NAME/" $WP_DIR/wp-config.php
sed -i "s/username_here/$DB_USER/" $WP_DIR/wp-config.php
sed -i "s/password_here/$DB_PASSWORD/" $WP_DIR/wp-config.php

# Set up the database
mysql -u root -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
mysql -u root -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

# Update site URL in WordPress database
# mysql -u $DB_USER -p$DB_PASSWORD -e "USE $DB_NAME; UPDATE wp_options SET option_value='$WP_URL' # WHERE option_name='siteurl';"
# mysql -u $DB_USER -p$DB_PASSWORD -e "USE $DB_NAME; UPDATE wp_options SET option_value='$WP_URL' # WHERE option_name='home';"

# Generate CSR with Certbot
certbot certonly --webroot -w $WP_DIR -d $DOMAIN_NAME

# Create Apache Virtual Host Configuration File
tee /etc/apache2/sites-available/$SUB_DIR.conf > /dev/null << EOF
<VirtualHost *:80>
	ServerAdmin webmaster@${DOMAIN_NAME}
	ServerName ${DOMAIN_NAME}
	DocumentRoot ${WP_DIR}
	ErrorLog \${APACHE_LOG_DIR}/error.log
	CustomLog \${APACHE_LOG_DIR}/access.log combined
	RewriteEngine On
	RewriteCond %{HTTPS} off
	RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
</VirtualHost>

<VirtualHost *:443>
	ServerAdmin webmaster@${DOMAIN_NAME}
	ServerName ${DOMAIN_NAME}
	DocumentRoot ${WP_DIR}
	ErrorLog \${APACHE_LOG_DIR}/error.log
	CustomLog \${APACHE_LOG_DIR}/access.log combined
	<Directory ${WP_DIR}>
		Options FollowSymLinks
		AllowOverride All
		Require all granted
	</Directory>
	SSLEngine on
	SSLCertificateFile /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem
	SSLCertificateKeyFile /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem
	Include /etc/letsencrypt/options-ssl-apache.conf
</VirtualHost>
EOF

# Enable Apache Virtual Host and SSL
sudo a2ensite $SUB_DIR.conf
sudo a2enmod ssl
sudo systemctl restart apache2

# Print installation summary
echo -e "\n  ${WP_URL}\n"
echo "  Web Directory: ${WP_DIR}"
echo "  Database Name: ${DB_NAME}"
echo "  Database User: ${DB_USER}"
echo -e "  Database Pass: ${DB_PASSWORD}\n"
