# Probes CPU & GPU (Nvidia-only) temps every two seconds and appends to "benchpress.txt"
# Run "./benchpress.sh &"

if [ -f benchpress.txt ]; then
	mv benchpress.txt benchpress${RANDOM}.txt
fi

while :
do
 cat <<<$(date +%y/%m/%d\ %H:%M:%S ; sensors | head -3 | tail -1 | awk '{print $2}' | sed -r 's/(\+)//;s/°//;s/C//' ; nvidia-smi -q -d temperature | head -11 | tail -1 | awk '{print $5}') | xargs >> benchpress.txt

	sleep 2

done
