if [ $1 -z ]; then
  echo 'SAFETY CHECK: Run this script with an argument to proceed...';
else
  sudo rm -r /var/www/html/wordpress
  sudo mv -f wordpress/ /var/www/html/
  sudo chown www-data:www-data -R /var/www/html/wordpress/
  sudo chmod -R 755 /var/www/html/wordpress/
  rm latest.zip wordpress/
fi
