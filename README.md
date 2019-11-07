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

You'll want to set up your networking and locale information now, as `locale.conf` is required
for the Grub terminal to run, and a properly configured hosts file is used as part of power
management.

Create your hostname file.
```bash
echo "my-hostname" >> /etc/hostname
```

Create your `/etc/hosts` file.
```bash
127.0.0.1               localhost
::1                     localhost
hostname.localadmin     hostname
```

Uncomment your preferred locale in `/etc/locale.gen`, then run:
```bash
locale-gen
```

Finally, set your locale in `/etc/locale.conf`.
```bash
LANG=en_US.UTF-8
```

Install the GRUB bootloader, the nouveau video drivers, and some packages we will use later.
```bash
pacman -S grub efibootmgr netctl dialog vi vim sudo dhcpcd pulseaudio alsa linux-headers linux-firmware
pacman -S xf86-video-intel xf86-video-nouveau mesa mesa-demos acpi acpid
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
systemctl enable gdm
```

You'll also want to enable the `NetworkManager` and `acpid` daemons.
```bash
systemctl enable --now NetworkManager
systemctl enable --now acpid
```

You should now set your locale information, or the default Gnome
terminal will fail to load. Once you have set your locale information, you should confirm
the `i915` driver for the Intel GPU is loaded and in use. You should also see the `nouveau`
driver has been loaded, but is not in use:
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
    Kernel modules: nouveau
```

**Ensure the NVIDIA lines do not have a Kernel driver in use. If they do, something went
wrong, and you probably have to start again from step 1.**

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
gpasswd -a myname wheel
```

Installing AUR packages requires use of `makepkg`, which is provided as a part of the
`base-devel` package we installed earlier. For help using `makepkg`, please refer to
[the docs](https://wiki.archlinux.org/index.php/AUR#Installing_packages).

Once you have those packages installed, we need to enable the three services they provide:
```bash
systemctl enable --now system76-firmware-daemon
systemctl enable --now system76-backlight --user
systemctl enable --now system76
```

## Part 5: Choose and configure a graphics mode

You have three options to choose from in this section:
1. **onboard-graphics** - Use only the onboard Intel GPU, and keep the Nvidia GPU powered off.
This option consumes the least amount of power.

2. **discrete-graphics** - Use only the Nvidia GPU to render your display(s). Both the Intel and
the Nvidia GPUs will be powered on at all times. This gives the best graphical performance,
but consumes the most power.

3. **hybrid-graphics** - Use the Intel GPU to render everything by default, and selectively
render applications with the Nvidia GPU. Both GPUs remain powered on at all times, though
this consumes less power than discrete-graphics mode.

## Part 5a: onboard-graphics mode

To use only the Intel GPU, you need to ensure the Nvidia GPU does not remain powered on.
The `nouveau` driver supports and will try to use your Nvidia GPU to enable
[PRIME](https://wiki.archlinux.org/index.php/PRIME) technology. We can prevent this by
passing an argument to the kernel at boot. You'll need to edit `/boot/grub/grub.cfg` and
add `nouveau.modeset=0` to your kernel parameters. The line should look something like this:
```bash
linux	/vmlinuz-linux root=UUID=e2749517-4300-4735-a203-5ab47b3570d3 rw  loglevel=3 quiet nouveau.modeset=0
```

## Part 5b: discrete-graphics mode

If you want to use your Nvidia GPU to render everything, the only thing you need to do is
install the `nvidia` proprietary drivers. They automatically blacklist the `nouveau` module.
```bash
pacman -S nvidia nvidia-utils
```

## Part 5c: hybrid-graphics mode

For the moment, the only working solution for hybrid-graphics mode
uses `bumblebee`. Unfortunately, there are several problems with it.

1. Bumblebee suffers from very significant performance issues. In my benchmarks, the Intel
GPU outperforms the Nvidia card by well over 300%.

2. Bumblebee seems to be abandoned. Its last commit was in 2013.

3. Bumblebee has no support for Vulkan.

In hybrid-graphics mode, the Intel GPU will render everything by default and the
Nvidia GPU will render applications on demand. To accomplish this, you will install
`bumblebee`. This will allow us to pass command line arguments which will tell the
system to render the target application using the discrete GPU.

First, we need to install `bumblebee` and the `nvidia` drivers:
```bash
pacman -S bumblebee nvidia nvidia-utils
```

Once `bumblebee` is installed, enable the `bumblebeed` daemon.
```bash
systemctl enable --now bumblebeed
```

Add your user to the `bumblebee` group.
```bash
gpasswd -a myname bumblebee
```

## Part 6: Enabling onboard audio
The onboard audio does not work out of the box on ArchLinux. It is controlled by a kernel
module called `snd_hda_intel`. To enable audio and prevent `dmesg` from spitting out
endless error messages, you'll need to install the appropriate packages and set
some options to be applied at boot. First, you'll need to install `alsa` and `pulseaudio`.
```bash
pacman -S alsa alsa-firmware pulseaudio
```

You'll then need to apply an option to the kernel driver used to control the onboard
audio hardware. Create fhe file `/etc/modprobe.d/audio-patch.conf`. It should contain
the following:
```bash
options snd_hda_intel probe_mask=1
```

To apply this change, you either need to unload and reload the module with `rmmod` and
`modprobe` respectively, or reboot the system.

## Part 7: Testing

Once you have rebooted into your GUI of choice, you will want to install a GPU benchmark to
test 3D rendering. For the purposes of this guide, we are not interested in pushing the
GPU to the limit. We only care that it works properly. For this purpose, we will use
`glmark2`. It can be found in the AUR [here](https://aur.archlinux.org/packages/glmark2/).
You'll know the benchmark is working if a window appears with a spinning 3D rendered object.

### Testing onboard-graphics and discrete-graphics modes
In a terminal, run:
```bash
glmark2
```

If you are using onboard-graphics mode, your terminal should output the following:
```bash
    glmark2 2014.03
=======================================================
    OpenGL Information
    GL_VENDOR:     Intel Open Source Technology Center
    GL_RENDERER:   Mesa DRI Intel(R) UHD Graphics 630 (Coffeelake 3x8 GT2) 
    GL_VERSION:    3.0 Mesa 19.2.0
=======================================================
```

If you have chosen to run your system in discrete graphics mode, your output should be:
```bash
    glmark2 2014.03
=======================================================
    OpenGL Information
    GL_VENDOR:     NVIDIA Corporation
    GL_RENDERER:   GeForce RTX 2070 with Max-Q Design/PCIe/SSE2
    GL_VERSION:    4.6.0 NVIDIA 435.21
=======================================================
```

Where `435.21` should be replaced with the version of your Nvidia driver.

### Testing hybrid-graphics mode

If you have chosen to run your system in hybrid graphics mode, you need to perform two
tests. The first test should be the same as the onboard-graphics test above. Run `glmark2`
in a terminal, and expect the Intel graphics output.

Your second test will ensure the Nvidia GPU can be invoked on command. To test this
functionality, run the following in a terminal:
```bash
optirun glmark2
```

Your terminal should output the same result as the discrete-graphics test above.

## Part 8: Final considerations and known issues

**At this point, you're done. Arch is working properly on your laptop (hopefully).**

* Bluetooth does not seem to work. Toggling the status in the gnome control panel
will cause the switch to turn blue, but that does not seem to matter.

* Multiple displays function only in discrete graphics mode. The Nvidia GPU controls
all the external displays, and so is required for them to operate.

* For your convenience, three files have been included to assist you
in switching between graphics modes. Mark them as executable and run them as root.

* It does not seem possible to completely power off the Nvidia GPU. Doing so with
`acpi-call` will cause the system to become immediately unresponsive.

* After two months of usage, it seems like discrete-graphics mode offers the best
battery life when not performing GPU intensive tasks. As it is not possible to
power-off the discrete GPU, I suspect it remains in low power mode while the onboard
GPU handles rendering.

* I have been looking into PRIME rendering as a better implementation of hybrid-graphics
mode. At the moment, it doesn't work quite right. If the `nvidia` module is loaded, the
system behaves as though it is in discrete-graphics mode. If the `nouveau` module is
loaded, hybrid-graphics mode works until you invoke the Nvidia GPU, at which point
`dmesg` starts spitting out errors, and the system locks up shortly thereafter. I expect
this is a matter of waiting for the `nouveau` team to further reverse-engineer the `nvidia`
driver.