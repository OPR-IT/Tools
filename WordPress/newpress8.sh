#!/bin/bash

# Derive Variables from Domain
read -p "Enter your new domain (e.g., yourdomain.com): " DOMAIN_NAME
WP_URL="https://${DOMAIN_NAME}"
SUB_DIR="${DOMAIN_NAME//./}"
WP_DIR="/var/www/${DOMAIN_NAME}"
DB_NAME="${SUB_DIR}_db"
DB_USER="${SUB_DIR}_user"
DB_PASSWORD="${SUB_DIR}_pass"

# Create WordPress Directory
mkdir -p $WP_DIR
chown -R www-data:www-data $WP_DIR
chmod -R 755 $WP_DIR
cd $WP_DIR

# Download WordPress
wget https://wordpress.org/latest.tar.gz
tar -xzvf latest.tar.gz
rm latest.tar.gz

# Extract Contents Here
mv wordpress/* ./
rm -r wordpress

# Configure
cp $WP_DIR/wp-config-sample.php $WP_DIR/wp-config.php
sed -i "s/database_name_here/$DB_NAME/" $WP_DIR/wp-config.php
sed -i "s/username_here/$DB_USER/" $WP_DIR/wp-config.php
sed -i "s/password_here/$DB_PASSWORD/" $WP_DIR/wp-config.php

# Make Database
mysql -u root -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
mysql -u root -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
mysql -u root -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -u root -e "FLUSH PRIVILEGES;"

# Update Database
# mysql -u $DB_USER -p$DB_PASSWORD -e "USE $DB_NAME; UPDATE wp_options SET option_value='$WP_URL' # WHERE option_name='siteurl';"
# mysql -u $DB_USER -p$DB_PASSWORD -e "USE $DB_NAME; UPDATE wp_options SET option_value='$WP_URL' # WHERE option_name='home';"

# Make CSR to Let's Encrypt
certbot certonly --webroot -w $WP_DIR -d $DOMAIN_NAME

# Make Apache Config
tee /etc/apache2/sites-available/$SUB_DIR.conf > /dev/null << EOF
<VirtualHost *:80>

	ServerName ${DOMAIN_NAME}
	Redirect / "https://${DOMAIN_NAME}"

</VirtualHost>

<IfModule mod_ssl.c>
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

	</VirtualHost>
</IfModule>
EOF

# Enable Site & SSL
sudo a2ensite $SUB_DIR.conf
sudo a2enmod ssl
sudo systemctl reload apache2

# Print Summary
echo -e "\n  ${WP_URL}\n"
echo "  Web Directory: ${WP_DIR}"
echo "  Database Name: ${DB_NAME}"
echo "  Database User: ${DB_USER}"
echo -e "  Database Pass: ${DB_PASSWORD}\n"