# Arch Linux on System76 Oryx Pro 5

Step-by-step instructions for installing and configuring Arch Linux on a System76 Oryx
Pro 5.

## Part 1: Install Pop!_OS and configure EFI
The System76 dev team has written their own Linux distribution based on Ubuntu. It's
called Pop!_OS. According to their customer service team, Pop!_OS uses each video card
discretely. They have a function built into the system that alters the EFI settings
to toggle between GPU usage. Swapping between them requires a reboot.

In order to configure the EFI settings to properly use the RTX card, we need to install
Pop!_OS. The configuration doesn't matter, but at the time of writing there are two
versions of it available on [their website](https://system76.com/pop). Make sure you grab
the Nvidia version, which will install the proprietary driver.

Once you have it installed and are sitting on the Gnome desktop, follow this procedure:

1. Find and launch the `system76-driver` program. Ensure there are no firmware updates
waiting to be installed. The option will be greyed out if there are no updates available.
If there **are** updates available, install them and then reboot.

2. Click the interface in the upper-right corner of the screen. This opens the Gnome
profile display. Click on the battery line, and observe the default setting of
Pop!_OS is to use Intel graphics. This should already be selected. Click on it anyway.

3. The system will display a notification informing you it is preparing to use Intel
graphics, then it will prompt you to reboot. Do so.

4. Once the system is rebooted, click the upper-right corner of your display again, and
this time choose the Nvidia graphics option. The system will again display a notice, this
time informing you it is switching to the Nvidia GPU. Reboot when prompted.

5. Once the system is booted, verify it is using the Nvidia GPU by running the following
in a console window:
```bash
lspci -k | grep -A 3 VGA
```
If all is well, you should see the following output:
```bash
00:02.0 VGA compatible controller: Intel Corporation UHD Graphics 630 (Mobile)
    Subsystem: CLEVO/KAPOK Computer UHD Graphics 630 (Mobile)
    Kernel driver in use: i915
    Kernel modules: i915
--
01:00.0 VGA compatible controller: NVIDIA Corporation TU106M [GeForce RTX 2070 Mobile] (rev a1)
    Subsystem: CLEVO/KAPOK Computer TU106M [GeForce RTX 2070 Mobile]
    Kernel driver in use: nvidia
    Kernel modules: nouveau, nvidia_drm, nvidia
```

The important thing here is the `nvidia` driver is currently in use. This tells you
the system is rendering on that card, and outputting through the Intel GPU.

Shut down the computer.

## Part 2: Installing Arch Linux

At the time of this writing, the most recent version of the Arch ISO is `2019.10.01`.
Download the ISO and write it to a flash drive.
```bash
dd if=/path/to/arch.iso of=/dev/sdx
```

Once that's done, the Arch Installation is mostly standard procedure, but there are a
few specifics we need to get right. 

Set the system clock:
```bash
timedatectl set-ntp true
```

Partition your hard drive(s).
```bash
fdisk /dev/nvme0n1
```

You'll want three partitions. The first should be a 512 MB EFI partition. fdisk will
warn you that the partition signature is `vfat`. **Do not remove that signature.**
```bash
n, 1, enter, +512M
t, 1, 1
```

Create a swap partition. Any size you want really, but I like 8 GB.
```bash
n, 2, enter, +8G
t, 2, 19
```

Create your root partition.
```bash
n, 3, enter, enter
t, 3, 20
```

Save the partition table to disk.
```bash
w
```

Format the partitions and activate your swap.
```bash
mkfs.fat -F 32 /dev/nvme0n1p1
mkfs.ext4 /dev/nvme0n1p3
mkswap /dev/nvme0n1p2
swapon /dev/nvme0n1p2
```

Mount the partitions.
```bash
mount /dev/nvme0n1p3 /mnt
mkdir /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot
```

Install the essential packages.
```bash
pacstrap /mnt base base-devel linux
```

Generate and save a filesystem table. Double check it for errors.
```bash
genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
```

chroot into the new system.
```bash
arch-chroot /mnt
```

At this point, you could set up your locale information, but it varies from user to user
and isn't actually necessary to carry on. So we skip it for now.

Create your hostname file.
```bash
echo "my-hostname" >> /etc/hostname
```

Install the GRUB bootloader, the Nvidia proprietary drivers, and some packages we
will use later.
```bash
pacman -S grub efibootmgr netctl dialog nvidia vi vim sudo dhcpcd pulseaudio alsa linux-headers
```

Configure the GRUB bootloader.
```bash
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
```

Set your superuser password.
```bash
passwd
```

At this point, Arch Linux has been successfully installed. Unmount your partitions
and reboot the system.
```bash
exit
umount /dev/nvme0n1p1
umount /dev/nvme0n1p3
reboot
```

## Part 3: Configuration

From here, we need to install a DM and GUI of choice. I have confirmed `gdm` and `gnome`
to work, as well as `ldxm` and `xfce`. I have also found that for whatever reason,
`xfce` takes about fifteen seconds to render once the user logs in. `gnome` renders
immediately. For the purposes of this guide, I will be using `gdm` and `gnome`. 

Install and enable a DM and GUI.
```bash
pacman -S gdm gnome
systemctl enable --now gdm
```

This will launch GDM and present you with a login prompt. **Make sure you use an X session
to launch the GUI. The Nvidia proprietary driver does not support wayland, and using it
may cause your screen to turn black, followed shortly by your system locking up.** 

Once the GUI is loaded, you should set your locale information, or the default Gnome
terminal will fail to load. Once you have set your locale information, you should
confirm the Nvidia proprietary driver is present, **but not loaded**, and that the
intel driver is present and **is loaded**. In a terminal:
```bash
lspci -k | grep -A 3 VGA
```

With any luck, your output will look like:
```bash
00:02.0 VGA compatible controller: Intel Corporation UHD Graphics 630 (Mobile)
    Subsystem: CLEVO/KAPOK Computer UHD Graphics 630 (Mobile)
    Kernel driver in use: i915
    Kernel modules: i915
--
01:00.0 VGA compatible controller: NVIDIA Corporation TU106M [GeForce RTX 2070 Mobile] (rev a1)
    Subsystem: CLEVO/KAPOK Computer TU106M [GeForce RTX 2070 Mobile]
    Kernel modules: nouveau, nvidia_drm, nvidia
```

Ensure the NVIDIA lines do not have a Kernel driver in use. If they do, something went
wrong, and you probably have to start again from step 1.

You'll also want to enable the `NetworkManager` daemon.
```bash
systemctl enable --now NetworkManager
```

## Part 4: Installing the System76 proprietary drivers

The Arch Linux community is awesome, and has created several AUR packages which
need to be installed. They are:
- [system76-io-dkms](https://aur.archlinux.org/packages/system76-io-dkms/)
- [system76-dkms](https://aur.archlinux.org/packages/system76-dkms/)
- [system76-firmware-daemon](https://aur.archlinux.org/packages/system76-firmware-daemon/)
- [system76-driver](https://aur.archlinux.org/packages/system76-driver/)

Arch Linux does not allow the root user to install packages from the AUR, and for good
reason. You will therefore need to create your user and assign them a home directory.
Once you are logged in as your user, you can continue.
```bash
useradd myname
passwd myname
mkdir /home/myname
chown myname /home/myname
```

Installing AUR packages requires use of `makepkg`, which is provided as a part of the
`base-devel` package we installed earlier. For help using `makepkg`, please refer to
[the docs](https://wiki.archlinux.org/index.php/AUR#Installing_packages).

Once you have those packages installed, we need to enable three services they provide:
```bash
systemctl enable --now system76-firmware-daemon
systemctl enable --now system76-backlight --user
systemctl enable --now system76
```

## Part 5: Installing bumblebee and optirun

To allow usage of the Nvidia video card, we need to install `bumblebee` and a few other
helpful packages. These will allow us to pass command line arguments which will tell
the system to render the target application using the discrete GPU.

First, we need to install the required packages:
```bash
pacman -S bumblebee mesa xf86-video-intel mesa-demos 
```

I'm not convinced you need them, but if you would like to support 32-bit applications
through `optirun`, you'll need the 32-bit libraries. To make them available for install,
you'll need to enable the `multilib` repository in `/etc/pacman.conf`.
```bash
pacman -S lib32-virtualgl lib32-nvidia-utils
```

Once those packages are installed, enable the `bumblebeed` daemon.
```bash
systemctl enable --now bumblebeed
```

Add your user to the `bumblebee` group.
```bash
gpasswd -a myname bumblebee
```

From here, restart the system.
```bash
reboot
```

## Part 6: Testing

Once you have rebooted into your GUI of choice, you need to install a GPU benchmark to
use while testing. For the purposes of this guide, we are not interested in pushing the
GPU to the limit. We only care that it works properly with `optirun`. For this purpose,
we will use `glmark2`. It can be found in the AUR
[here](https://aur.archlinux.org/packages/glmark2/).

Once `glmark2` is installed, you need to test both the Intel and Nvidia GPUs. You'll
know the benchmark is working if a window appears with a spinning 3D rendered object.

To test the Intel card, run the following command in a terminal:
```bash
glmark2
```

If the following appears in your terminal, the Intel card is working properly:
```bash
    glmark2 2014.03
=======================================================
    OpenGL Information
    GL_VENDOR:     Intel Open Source Technology Center
    GL_RENDERER:   Mesa DRI Intel(R) UHD Graphics 630 (Coffeelake 3x8 GT2) 
    GL_VERSION:    3.0 Mesa 19.2.0
=======================================================
```

To test the Nvidia card, run the following in a terminal:
```bash
optirun glmark2
```

If the see the following output in your terminal, the Nvidia card is working properly:
```bash
    glmark2 2014.03
=======================================================
    OpenGL Information
    GL_VENDOR:     NVIDIA Corporation
    GL_RENDERER:   GeForce RTX 2070 with Max-Q Design/PCIe/SSE2
    GL_VERSION:    4.6.0 NVIDIA 435.21
=======================================================
```

`435.21` should be replaced with the version of your Nvidia driver.

## Part 7: Final considerations and known issues

**At this point, you're done. Arch is working properly on your laptop (hopefully).**

* I have not yet figured out how to get wireless working. The driver used (`iwlwifi`)
is well supported and is successfully loaded by `systemd`, but `NetworkManager`
does not hook it. Interestingly, `wifi-menu` works fine if you boot from the
installation media. Wired networking works without issue.

* Related to the wireless problem above, there is some weirdness with how Gnome handles
airplane mode and bluetooth. Bluetooth always appears in an "OFF" state, but attempting
to turn it on activates airplane mode. This has no effect on wired networking, which
works in either state. Turning airplane mode off also turns off bluetooth. In neither
case is bluetooth active.

* If you use `xfce`, you will notice a fifteen-ish second delay when the Intel GPU
attempts to render your DM or GUI. There are workarounds for this problem in the Arch
Wiki on the
[NVIDIA/Troubleshooting](https://wiki.archlinux.org/index.php/NVIDIA/Troubleshooting)
page, as well as on the [NVIDIA Optimus](https://wiki.archlinux.org/index.php/Optimus)
page. However, doing so may require blacklisting modules which are necessary for
`optirun` to function. In the future there may be a solution to this, but for now
I recommend against implementing a blacklist solution. If you really like `xfce`
(like me), fifteen seconds isn't all that bad considering the amount of trouble
necessary to get Arch working on this system.

* Most of the function toggles on the keyboard work properly, with airplane mode being
the biggest exception. `dmesg` lists a lot of unknown keys when they are pressed. I'm
not sure if this issue will ever be resolved, as it would require a port of
the software from System76.

* I have not yet tested an external display, but I presume it should work because the
Intel GPU driver is well supported, and Xorg is pretty good at handling multiple
displays these days. I don't expect the Nvidia card to interfere with this operation,
as it is powered off when not activated by `optirun`.