#!/bin/bash
if [ $1 -z ]; then
        V=$(curl -I https://github.com/zadam/trilium/releases/latest | grep 'location: *' | cut -d\/ -f8 | cut -d\. -f2- | sed -r s/\\r//)
else
        V=$1
fi
name="trilium-linux-x64-server-0.${V}.tar.xz"
url="https://github.com/zadam/trilium/releases/download/v0.${V}/${name}"
if [ -f $name ]; then
        rm -v $name
fi
wget --show-progress -O $name $url && tar -xvf $name
rm -v $name*
if [ -d trilium-server ]; then
        rm -rv trilium-server
fi
mv -fv trilium-linux-x64-server trilium-server && \
        cd trilium-server
