#!/usr/bin/bash

if [[ $EUID -ne 0 ]]
then
  echo "This script must be run as root." 1>&2
  exit 1;
fi

echo "Switching to discrete graphics mode...";

# Remove bumblebee if present
echo "Removing bumblebee if present..."
if test -f /usr/lib/bumblebeed
then
	systemctl disable bumblebeed
	pacman -R --noconfirm --quiet bumblebee
fi

# Ensure the proprietary nvidia driver is installed
echo "Ensuring nvidia module is present..."
if ! test -f "/lib/modules/$(uname -r)/extramodules/nvidia.ko.gz"
then
	pacman -S --noconfirm --quiet nvidia nvidia-utils
fi

# Remove nouveau.modeset=0 from the kernel parameters if present
echo "Making backup of default grub file at /etc/default/grub.backup..."
cp /etc/default/grub /etc/default/grub.backup
echo "Updating kernel parameters..."
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT.*/GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

echo "Done. Reboot to apply changes."
