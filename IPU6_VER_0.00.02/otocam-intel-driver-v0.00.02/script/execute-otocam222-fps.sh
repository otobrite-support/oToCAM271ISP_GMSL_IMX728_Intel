#!/bin/bash
#set -e
#sudo su

#echo "copy *.ko to lib/~"
#./install_script.sh
echo "modprobe intel-ipu6"
modprobe intel-ipu6
echo "modprobe intel-ipu6-isys"
modprobe intel-ipu6-isys
echo "modprobe intel-ipu6-psys"
modprobe intel-ipu6-psys
echo "modprobe otocam222"
modprobe otocam222
echo "source env.sh"
source env.sh
echo "run_4cam_display_fps_otocam222"
./run_4cam_display_fps_otocam222.sh

