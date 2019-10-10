#!/usr/bin/bash

if [[ $EUID -ne 0 ]]
then
  echo "This script must be run as root." 1>&2
  exit 1;
fi

echo "Switching to hybrid graphics mode...";

# Install and enable bumblebee if not present
echo "Enabling bumblebee...";
if ! test -f /usr/lib/bumblebeed
then
	pacman -S --noconfirm --quiet bumblebee
	systemctl enable bumblebeed
elif test -f /usr/lib/bumblebeed
then
  systemctl enable bumblebeed;
fi

# Ensure the proprietary nvidia driver is present on the system
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

echo "NOTICE: Please ensure your user has been added to group bumblebee. optirun will not function otherwise."
echo "Done. Reboot to apply changes."
