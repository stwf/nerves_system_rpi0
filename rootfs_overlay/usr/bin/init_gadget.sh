#!/bin/sh

set -e
nerves_fw_active=a

ACTIVE_PART=$(fw_printenv -n nerves_fw_active)
APP_PARTITION=$(fw_printenv -n $ACTIVE_PART.nerves_fw_application_part0_devpath)

CONFIGFS="/sys/kernel/config"
GADGET="$CONFIGFS/usb_gadget"
VID="0x0525"
PID="0xa4a2"
SERIAL="0123456789"
MANUF="Nerves"
PRODUCT="$(fw_printenv -n $ACTIVE_PART.nerves_fw_platform) Gadget"

echo "Creating gadget directory g1"
mount none /sys/kernel/config -t configfs
mkdir -p $GADGET/g1

cd $GADGET/g1
if [ $? -ne 0 ]; then
    echo "Error creating usb gadget in configfs"
    exit 1;
else
    echo "OK"
fi

echo "\tCreating gadget functionality"
mkdir functions/mass_storage.0 # Storage
mkdir -p functions/acm.usb0    # Serial
mkdir -p functions/rndis.usb0  # Network
echo 1 > functions/mass_storage.0/stall

echo $APP_PARTITION > functions/mass_storage.0/lun.0/file
echo 1 > functions/mass_storage.0/lun.0/removable
echo 0 > functions/mass_storage.0/lun.0/cdrom
mkdir configs/c.1
echo 250 > configs/c.1/MaxPower
mkdir configs/c.1/strings/0x409
ln -s functions/mass_storage.0 configs/c.1
ln -s functions/rndis.usb0 configs/c.1/
ln -s functions/acm.usb0   configs/c.1/
echo "\tOK"
echo "OK"

echo "Setting Vendor and Product ID's"
echo $VID > idVendor
echo $PID > idProduct
echo "OK"

echo "Setting English strings"
mkdir -p strings/0x409
echo $SERIAL > strings/0x409/serialnumber
echo $MANUF > strings/0x409/manufacturer
echo $PRODUCT > strings/0x409/product
echo "OK"

echo "Binding USB Device Controller"
echo `ls /sys/class/udc` > UDC
echo "OK"
