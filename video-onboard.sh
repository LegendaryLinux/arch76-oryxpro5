#!/usr/bin/bash

if [[ $EUID -ne 0 ]]
then
  echo "This script must be run as root." 1>&2
  exit 1;
fi

echo "Switching to onboard graphics mode...";

# Remove bumblebee if present
echo "Removing bumblebee if present..."
if test -f /usr/lib/bumblebeed
then
	systemctl disable bumblebeed
	pacman -R --noconfirm bumblebee
fi

# Ensure the proprietary nvidia driver is not present on the system
echo "Remove nvidia module if present..."
if test -f "/lib/modules/$(uname -r)/extramodules/nvidia.ko.gz"
then
	pacman -R --noconfirm nvidia nvidia-utils
fi

# Append nouveau.modeset=0 to the kernel parameters
echo "Making backup of default grub file at /etc/default/grub.backup..."
cp /etc/default/grub /etc/default/grub.backup
echo "Updating kernel parameters..."
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT.*/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet nouveau.modeset=0\"/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "Done. Reboot to apply changes."
