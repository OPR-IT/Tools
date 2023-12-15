#!/bin/bash
if [ $1 -z ]; then
	V='60.4'
else
	V=$1
fi
bigname="trilium-linux-x64-server-0.${V}.tar.xz"
url="https://github.com/zadam/trilium/releases/download/v0.${V}/${bigname}"
if [ -f $bigname ]; then
	rm -v $bigname
fi
wget $url -P ~/ && tar -xvf $bigname
rm -v $bigname
