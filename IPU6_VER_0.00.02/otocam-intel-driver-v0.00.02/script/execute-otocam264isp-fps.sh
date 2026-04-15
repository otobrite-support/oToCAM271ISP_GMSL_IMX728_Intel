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
echo "modprobe otocam264isp"
modprobe otocam264isp
echo "source env.sh"
source env.sh
echo "run_1cam_display_mmap_otocam264isp.sh"
#./run_4cam_display_mmap_otocam271isp.sh
./run_4cam_display_fps_otocam264isp.sh


