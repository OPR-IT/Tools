if [ -z $1 ]; then
	_1='8080'
else
	_1="$1"
fi
if [ -z $2 ]; then
	if [ -d 'trilium-data' ]; then
		_2='trilium-data1'
	else
		_2='trilium-data'
	fi
else
	_2="$2"
fi
sudo docker pull zadam/trilium && \
sudo docker run --rm -dtip 0.0.0.0:"$_1":"$_1" -v "$_2":/home/node/trilium-data zadam/trilium
sed -i'.old' -r "s/port=(\d+)/port=$_1/;s/https=false/https=true/" "$_2"/config.ini
