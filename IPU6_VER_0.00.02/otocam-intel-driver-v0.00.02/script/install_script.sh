sudo cp ../xml/ipu6epmtl/libcamhal_profile.xml /etc/camera/ipu6epmtl/
sudo cp ../xml/ipu6epmtl/sensors/* /etc/camera/ipu6epmtl/sensors/
sudo cp ../bin/otocam*.ko /lib/modules/6.12.36-lts-250711t071314z/kernel/drivers/media/i2c/
sudo cp ../bin/serdes.ko /lib/modules/6.12.36-lts-250711t071314z/kernel/drivers/media/i2c/max9x/serdes.ko
sudo cp ../bin/intel-ipu6-psys.ko /lib/modules/6.12.36-lts-250711t071314z/kernel/drivers/media/pci/intel/ipu6/psys/intel-ipu6-psys.ko
sudo cp ../bin/intel-ipu6-isys.ko /lib/modules/6.12.36-lts-250711t071314z/kernel/drivers/media/pci/intel/ipu6/intel-ipu6-isys.ko
sudo cp ../bin/intel-ipu6.ko /lib/modules/6.12.36-lts-250711t071314z/kernel/drivers/media/pci/intel/ipu6/intel-ipu6.ko
sudo cp ../bin/max9295.ko /lib/modules/6.12.36-lts-250711t071314z/kernel/drivers/media/i2c/max9x/max9295.ko
sudo cp ../bin/max9296.ko /lib/modules/6.12.36-lts-250711t071314z/kernel/drivers/media/i2c/max9x/max9296.ko
sudo cp ../bin/ipu6-acpi.ko /lib/modules/6.12.36-lts-250711t071314z/kernel/drivers/media/platform/intel/ipu6-acpi.ko
sudo cp ../bin/ipu6-acpi-common.ko /lib/modules/6.12.36-lts-250711t071314z/kernel/drivers/media/platform/intel/ipu6-acpi-common.ko
sudo cp ../bin/ipu6-acpi-pdata.ko /lib/modules/6.12.36-lts-250711t071314z/kernel/drivers/media/platform/intel/ipu6-acpi-pdata.ko
sudo depmod -a
