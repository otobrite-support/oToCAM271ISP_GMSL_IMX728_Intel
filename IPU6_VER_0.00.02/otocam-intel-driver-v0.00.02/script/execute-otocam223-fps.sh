#!/bin/bash
#set -e
#sudo su

#echo "copy *.ko to lib/~"
#./copy_script.sh
echo "modprobe intel-ipu6"
modprobe intel-ipu6
echo "modprobe intel-ipu6-isys"
modprobe intel-ipu6-isys
echo "modprobe intel-ipu6-psys"
modprobe intel-ipu6-psys
echo "modprobe otocam223"
modprobe otocam223
echo "source env.sh"
source env.sh
echo "run_4cam_display_fps_otocam223"
./run_4cam_display_fps_otocam223.sh

