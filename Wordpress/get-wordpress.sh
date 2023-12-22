if [ -f latest.zip ]; then
	rm latest.zip
fi
wget https://wordpress.org/latest.zip
unzip latest.zip
rm latest.zip
