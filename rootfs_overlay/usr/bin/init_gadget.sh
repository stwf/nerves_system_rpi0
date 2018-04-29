#!/bin/sh
# Mostly stolen from: https://raw.githubusercontent.com/ev3dev/ev3-systemd/ev3dev-jessie/scripts/ev3-usb.sh

set -e
active_fw=$(fw_printenv -n nerves_fw_active)
app_partition=$(fw_printenv -n $active_fw.nerves_fw_application_part0_devpath)

configfs_home="/sys/kernel/config"
g="$configfs_home/usb_gadget/g"
usb_ver="0x0200" # USB 2.0
dev_class="2"
vid="0x1d6b" # Linux Foundation
pid="0x0104" # Multifunction Composite Gadget
device="0x3000" # this should be incremented any time there are breaking changes
                # to this script so that the host OS sees it as a new device and
                # re-enumerates everything rather than relying on cached values

mfg="Nerves Team"
prod="$(fw_printenv -n $active_fw.nerves_fw_platform) Gadget"

serial="deadbeef00115599"

attr="0xC0" # Self powered
pwr="1" # 2mA
cfg1="CDC"
cfg2="RNDIS"

mac="d6:1e:58:8a:8f:42"

# Change the first number for each MAC address - the second digit of 2 indicates
# that these are "locally assigned (b2=1), unicast (b1=0)" addresses. This is
# so that they don't conflict with any existing vendors. Care should be taken
# not to change these two bits.
dev_mac1="02:1e:58:8a:8f:42"
host_mac1="12:1e:58:8a:8f:42"
dev_mac2="22:1e:58:8a:8f:42"
host_mac2="32:1e:58:8a:8f:42"

# Windows hacks.
ms_vendor_code="0xcd" # Microsoft
ms_qw_sign="MSFT100" # also Microsoft (if you couldn't tell)
ms_compat_id="RNDIS" # matches Windows RNDIS Drivers
ms_subcompat_id="5162001" # matches Windows RNDIS 6.0 Driver

echo "Setting up gadget..."
# Mount configfs. TODO(Connor) - Try moving this to erlinit?
mount none $configfs_home -t configfs

# Create a new gadget

mkdir $g
echo "$usb_ver" > $g/bcdUSB
echo "$dev_class" > $g/bDeviceClass
echo "$vid" > $g/idVendor
echo "$pid" > $g/idProduct
echo "$device" > $g/bcdDevice
mkdir $g/strings/0x409
echo "$mfg" > $g/strings/0x409/manufacturer
echo "$prod" > $g/strings/0x409/product
echo "$serial" > $g/strings/0x409/serialnumber

# Create 2 configurations. The first will be CDC. The second will be RNDIS.
# Thanks to os_desc, Windows should use the second configuration.

# config 1 is for CDC

mkdir $g/configs/c.1
echo "$attr" > $g/configs/c.1/bmAttributes
echo "$pwr" > $g/configs/c.1/MaxPower
mkdir $g/configs/c.1/strings/0x409
echo "$cfg1" > $g/configs/c.1/strings/0x409/configuration

# Create the CDC function

mkdir $g/functions/ecm.usb0

echo "$dev_mac1" > $g/functions/ecm.usb0/dev_addr
echo "$host_mac1" > $g/functions/ecm.usb0/host_addr

# Create mass storage function
mkdir $g/functions/mass_storage.0
echo 1 > $g/functions/mass_storage.0/stall
echo $app_partition > $g/functions/mass_storage.0/lun.0/file
echo 1 > $g/functions/mass_storage.0/lun.0/removable
echo 0 > $g/functions/mass_storage.0/lun.0/cdrom

# Create serial function
mkdir $g/functions/acm.usb0

# config 2 is for RNDIS

mkdir $g/configs/c.2
echo "$attr" > $g/configs/c.2/bmAttributes
echo "$pwr" > $g/configs/c.2/MaxPower
mkdir $g/configs/c.2/strings/0x409
echo "$cfg2" > $g/configs/c.2/strings/0x409/configuration

# On Windows 7 and later, the RNDIS 5.1 driver would be used by default,
# but it does not work very well. The RNDIS 6.0 driver works better. In
# order to get this driver to load automatically, we have to use a
# Microsoft-specific extension of USB.

echo "1" > $g/os_desc/use
echo "$ms_vendor_code" > $g/os_desc/b_vendor_code
echo "$ms_qw_sign" > $g/os_desc/qw_sign

# Create the RNDIS function, including the Microsoft-specific bits

mkdir $g/functions/rndis.usb0
echo "$dev_mac2" > $g/functions/rndis.usb0/dev_addr
echo "$host_mac2" > $g/functions/rndis.usb0/host_addr
echo "$ms_compat_id" > $g/functions/rndis.usb0/os_desc/interface.rndis/compatible_id
echo "$ms_subcompat_id" > $g/functions/rndis.usb0/os_desc/interface.rndis/sub_compatible_id

# Link everything up and bind the USB device

ln -s $g/functions/acm.usb0 $g/configs/c.1/
ln -s $g/functions/ecm.usb0 $g/configs/c.1
ln -s $g/functions/mass_storage.0 $g/configs/c.1
ln -s $g/functions/rndis.usb0 $g/configs/c.2
ln -s $g/configs/c.2 $g/os_desc
ls /sys/class/udc/ > $g/UDC
echo "Done."
