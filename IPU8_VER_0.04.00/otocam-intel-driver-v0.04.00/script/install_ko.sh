
KER_DIR="/lib/modules/7.0.0-mainline-preprod-v7.0-deb-overlay-260713t072449z"
#sudo cp -a ../ko/drivers ${KER_DIR}/
# Install to updates/ so these modules take priority over the kernel-shipped
# ones (intel-ipu7*, videodev, mc, ipu-acpi*) in kernel/.
cd "$(dirname "$0")"
sudo mkdir -p ${KER_DIR}/updates
sudo cp -a ../ko/drivers ${KER_DIR}/updates/
sudo depmod -a
