#!/bin/bash
#set -e
#sudo su

#echo "copy *.ko to lib/~"
#./copy_script.sh
rmmod intel-ipu6

echo "modprobe intel-ipu6"
modprobe intel-ipu6
echo "modprobe intel-ipu6-isys"
modprobe intel-ipu6-isys
echo "modprobe intel-ipu6-psys"
modprobe intel-ipu6-psys
echo "modprobe otocam271isp"
modprobe otocam271isp
echo "source env.sh"
source env.sh
echo "run_1cam_display_mmap_otocam271isp"
./run_2cam_display_fps_otocam271isp-1-3.sh
#./run_1cam_display_mmap_otocam271isp.sh


