#!/bin/sh
#################################################
#  EPJ -  Archlinux DialogBox Installer         #
#      -  RTFM   Archlinux Handbook Scripted    #
#      -  last version :         07-Nov-2021    #
#      -     update    :    adding dialogbox    #
#      -     version   :    RC-2                #
#################################################
### https://github.com/eugenepauljean/EPJADI   ##
#################################################
prepare_setup () {
    pacman -Sy --noconfirm --needed dialog
}
welcome_msg () {
    dialog --ok-label "--- OK 5 Minutes INSTALL ---" --title "EPJ-Archlinux-Installer" --msgbox "This script aims to minimize Archlinux installation steps, while respecting the handbook :\n\nDISK TARGET - WIPE - AUTOPARTITION\nENCRYPTION LUKS - CREATE USERNAME - REGION AND CITY\nLOCALES - KEYBOARD - DESKTOP ENV\nVIDEO DRIVER - AUDIO-PRO REALTIME" 10 100
}
select_mirrors () {
    if (dialog --title "EUROPE REPOSITORY - optional" --yesno "\n\nEnable fastest EUROPE Mirrors ? " 30 80)
    then
        # Edit manually the best server you will use
        echo "Server = http://ftp-stud.hs-esslingen.de/pub/Mirrors/archlinux/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist
    else
        exit 0
    fi
}
check_bootmode () {
    clear
    if [[ -d "/sys/firmware/efi/efivars" ]]
    then
        bootvar=gpt
    else
        bootvar=msdos
    fi
}
update_systemclock () {
    clear
    timedatectl set-ntp true
    hwclock --systohc
}
check_diskname () {
        let i=0
        diskselection=()
        while read -r line; do
            let i=$i+1
            diskselection+=($line)
        done < <( lsblk -n --output TYPE,KNAME,SIZE | grep "disk" |  awk '{print $2} {print $3}' )
        disknametarget=$(dialog --stdout --title "SELECT DISK TARGET" --menu "Diskname - Size : " 30 80 0 ${diskselection[@]})
}
erase_disk () {
    if (dialog --title "WIPE AND PREPARE AUTO PARTITION" --yesno "\nWARNING\n\n\nDO YOU ACCEPT TO WIPE, AUTOPARTITION, FORMAT\n\n\nDISKNAME : $disknametarget\nBOOTMODE : $bootvar\n" 20 60)
    then
        wipefs -a /dev/$disknametarget
    else
        exit 0
    fi
}
encrypted_choice () {
    if (dialog --title "LUKS ENCRYPTION" --yesno "\n\nENABLE DISK ENCRYPTION ?" 30 80)
    then
        encrypteddisk=yes
        create_partition_encrypted
    else
        encrypteddisk=no
        create_partition
    fi
}
create_partition_encrypted () {
    if [[ $bootvar == "gpt" ]] ; then
        parted -s /dev/$disknametarget mklabel gpt
        echo -e "${BLU}New partition table signature created : $bootvar ${NC}"
        parted -s /dev/$disknametarget mkpart fat32 1MiB 150MiB
        parted -s /dev/$disknametarget set 1 esp
        parted -s /dev/$disknametarget mkpart ext4 150MiB 300MiB
        parted -s /dev/$disknametarget mkpart ext4 300MiB 100%
        cryptsetup luksFormat /dev/${disknametarget}${part3}
        echo -e "${GRE}Mounting the encrypted partition${NC}"
        cryptsetup open /dev/${disknametarget}${part3} cryptroot
        mkfs.vfat /dev/${disknametarget}${part1}
        mkfs.ext4 /dev/${disknametarget}${part2}
        mkfs.ext4 -L root /dev/mapper/cryptroot
        mount /dev/mapper/cryptroot /mnt
        mkdir -p /mnt/boot
        mount /dev/${disknametarget}${part2} /mnt/boot
        mkdir /mnt/boot/efi
        mount /dev/${disknametarget}${part1} /mnt/boot/efi
    elif [[ $bootvar == "msdos" ]] ; then
        parted -s /dev/$disknametarget mklabel msdos
        echo -e "${BLU}New partition table signature created : $bootvar ${NC}"
        parted -s /dev/$disknametarget mkpart primary ext4 1MiB 150MiB
        parted -s /dev/$disknametarget set 1 boot on
        parted -s /dev/$disknametarget mkpart primary ext4 150Mib 100%
        cryptsetup luksFormat /dev/${disknametarget}${part2}
        echo -e "${GRE}Mounting the encrypted partition${NC}"
        cryptsetup open /dev/${disknametarget}${part2} cryptroot
        mkfs.vfat /dev/${disknametarget}${part1}
        mkfs.ext4 -L root /dev/mapper/cryptroot
        mount /dev/mapper/cryptroot /mnt
        mkdir -p /mnt/boot
        mount /dev/${disknametarget}${part1} /mnt/boot
    fi
}
create_partition () {
    if [[ $bootvar == "gpt" ]] ; then
        parted -s /dev/$disknametarget mklabel gpt
        echo -e "${BLU}New partition table signature created : $bootvar ${NC}"
        parted -s /dev/$disknametarget mkpart primary fat32 1MiB 150MiB
        parted -s /dev/$disknametarget mkpart primary ext4 150MiB 100%
        mkfs.vfat /dev/${disknametarget}${part1}
        mkfs.ext4 /dev/${disknametarget}${part2}
        mount /dev/${disknametarget}${part2} /mnt
        mkdir -p /mnt/boot/efi
        mount /dev/${disknametarget}${part1} /mnt/boot/efi
    elif [[ $bootvar == "msdos" ]] ; then
        parted -s /dev/$disknametarget mklabel msdos
        echo -e "${BLU}New partition table signature created : $bootvar ${NC}"
        parted -s /dev/$disknametarget mkpart primary ext4 1MiB 150MiB
        parted -s /dev/$disknametarget set 1 boot on
        parted -s /dev/$disknametarget mkpart primary 150MiB 100%
        mkfs.ext4 /dev/${disknametarget}${part1}
        mkfs.ext4 /dev/${disknametarget}${part2}
        mount /dev/${disknametarget}${part2} /mnt
        mkdir -p /mnt/boot
        mount /dev/${disknametarget}${part1} /mnt/boot
    fi
}
essential_packages () {
        pacstrap /mnt base linux linux-firmware grub
}
enter_username () {
        username=$(dialog --clear --title "USERNAME" --inputbox "Enter your Username" 30 80 3>&1 1>&2 2>&3 3>&-)
}
define_userpwd () {
        arch-chroot /mnt bash -c "useradd -m $username"
        usernamepwd=$(dialog --clear --title "USER PASSWORD" --insecure --passwordbox "Enter $username Password" 30 80 3>&1 1>&2 2>&3 3>&-)
        arch-chroot /mnt bash -c "echo -e \"$usernamepwd\\n$usernamepwd\\n\" | passwd $username"
}
define_rootpwd () {
        rootpwd=$(dialog --clear --title "SUPERUSER ROOT PASSWORD" --insecure --passwordbox "Enter the Root PWD" 30 80 3>&1 1>&2 2>&3 3>&-)
        arch-chroot /mnt bash -c "echo -e \"$rootpwd\\n$rootpwd\\n\" | passwd"
}
detect_cpu () {
        varcpu="`grep -m 1 'model name' /proc/cpuinfo | grep -oh "Intel"`"
    if [[ $varcpu == "Intel" ]] ; then
        pacstrap /mnt intel-ucode
    else
        pacstrap /mnt amd-ucode
    fi
}
generate_fstab () {
        genfstab -U /mnt >> /mnt/etc/fstab
}
set_timezone_region () {
        let i=0
        selectedtzr=()
        while read -r line; do
            let i=$i+1
            selectedtzr+=($line $i)
        done < <( ls -1 /usr/share/zoneinfo/ )
        tzregion=$(dialog --stdout --title "SET TIMEZONE - REGION" --menu "Select REGION" 30 80 0 ${selectedtzr[@]})
}
set_timezone_city () {
    # Select City
        let j=0
        selectedtzc=()
        while read -r line; do
            let j=$j+1
            selectedtzc+=($line $i)
        done < <( ls -1 /usr/share/zoneinfo/$tzregion )
        tzcity=$(dialog --stdout --title "SET TIMEZONE - CITY" --menu "Select CITY" 30 80 0 ${selectedtzc[@]})
        arch-chroot /mnt bash -c "ln -sf /usr/share/zoneinfo/$tzregion/$tzcity /etc/localtime"
}
set_localization () {
        let j=0
        looplistelement=()
        while read -r line; do
            let j=$j+1
            looplistelement+=($line)
        done < <( cat /mnt/etc/locale.gen | awk '{if (NR>=23) print}' | grep UTF-8 )

        definedlocales=$(dialog --stdout --title "LOCALES" --menu "Select LOCALES" 30 80 0 ${looplistelement[@]})
        varutf8="`echo $definedlocales | cut -c2-`"
        sed -i "s|$definedlocales UTF-8|$varutf8 UTF-8|g" /mnt/etc/locale.gen
        arch-chroot /mnt bash -c "locale-gen"
}
set_localeconf () {
        setlocaleconf="`echo $definedlocales | awk '{print $1}' | cut -c2-`"
        arch-chroot /mnt bash -c "echo 'LANG=$setlocaleconf' >> /etc/locale.conf"
}
set_keyboardlayoutmap () {
        setkeyboardtype=$(dialog --title "SET KEYBOARD LAYOUT" --radiolist "Select Layout" 30 80 2 \
        "1" "AZERTY" "on" \
        "2" "QWERTY" "off" \
        "3" "QWERTZ" "off" \
        2>&1 1>/dev/tty);
        if [[ $setkeyboardtype == "1" ]] ; then
                let i=0
                looplistelement=()
                while read -r line; do
                    let i=$i+1
                    looplistelement+=($line $i)
                done < <( ls -1 /usr/share/kbd/keymaps/i386/azerty | sed -n 's/\.map.gz$//p')
                setvconsole=$(dialog --stdout --title "SET KEYBMAP" --menu "Select MAP" 30 80 0 ${looplistelement[@]})
                arch-chroot /mnt bash -c "echo 'KEYMAP=$setvconsole' >> /etc/vconsole.conf"
        elif [[ $setkeyboardtype == "2" ]] ; then
                let i=0
                looplistelement=()
                while read -r line; do
                    let i=$i+1
                    looplistelement+=($line $i)
                done < <( ls -1 /usr/share/kbd/keymaps/i386/qwerty | sed -n 's/\.map.gz$//p')
                setvconsole=$(dialog --stdout --title "SET KEYMAP MAP" --menu "Select MAP" 30 80 0 ${looplistelement[@]})
                arch-chroot /mnt bash -c "echo 'KEYMAP=$setvconsole' >> /etc/vconsole.conf"
        elif [[ $setkeyboardtype == "3" ]] ; then
                let i=0
                looplistelement=()
                while read -r line; do
                    let i=$i+1
                    looplistelement+=("$line $i")
                done < <( ls -1 /usr/share/kbd/keymaps/i386/qwertz | sed -n 's/\.map.gz$//p')
                setvconsole=$(dialog --stdout --title "SET KEYMAP MAP" --menu "Select MAP" 30 80 0 ${looplistelement[@]})
                arch-chroot /mnt bash -c "echo 'KEYMAP=$setvconsole' >> /etc/vconsole.conf"
        fi
}
set_hostname () {
        arch-chroot /mnt bash -c "echo $username >> /etc/hostname"
        arch-chroot /mnt bash -c "echo '127.0.0.1     localhost $username' >> /etc/hosts"
        arch-chroot /mnt bash -c "echo '::1           localhost $username' >> /etc/hosts"
}
part1=1
part2=2
part3=3
# INSTALL BOOTLOADER GRUB
install_grub () {
    if [[ $bootvar == "gpt" ]] && [[ $encrypteddisk == "yes" ]] ; then
        pacstrap /mnt efibootmgr
        uuidblk="`blkid -o value -s UUID /dev/${disknametarget}${part3}`"
        echo $uuidblk
        sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"|GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=$uuidblk:cryptroot root=\/dev\/mapper\/cryptroot\"|g" /mnt/etc/default/grub
        sed -i "s|#GRUB_ENABLE_CRYPTODISK=y|GRUB_ENABLE_CRYPTODISK=y|g" /mnt/etc/default/grub
        hookold="HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)"
        hooknew="HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt filesystems fsck)"
        sed -i "s|$hookold|$hooknew|g" /mnt/etc/mkinitcpio.conf
        arch-chroot /mnt bash -c "mkinitcpio -P linux"
        arch-chroot /mnt bash -c "grub-install --target=x86_64-efi --bootloader-id=ArchDev --efi-directory=/boot/efi"
        arch-chroot /mnt bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
    elif [[ $bootvar == "gpt" ]] && [[ $encrypteddisk == "no" ]] ; then
        pacstrap /mnt efibootmgr
        arch-chroot /mnt bash -c "grub-install --target=x86_64-efi --bootloader-id=ArchDev --efi-directory=/boot/efi"
    elif [[ $bootvar == "msdos" ]] && [[ $encrypteddisk == "yes" ]] ; then
        uuidblk="`blkid -o value -s UUID /dev/${disknametarget}${part2}`"
        echo $uuidblk
        sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"|GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=UUID=$uuidblk:cryptroot root=\/dev\/mapper\/cryptroot\"|g" /mnt/etc/default/grub
        sed -i "s|#GRUB_ENABLE_CRYPTODISK=y|GRUB_ENABLE_CRYPTODISK=y|g" /mnt/etc/default/grub
        hookold="HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)"
        hooknew="HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt filesystems fsck)"
        sed -i "s|$hookold|$hooknew|g" /mnt/etc/mkinitcpio.conf
        arch-chroot /mnt bash -c "mkinitcpio -P linux"
        arch-chroot /mnt bash -c "grub-install --target=i386-pc /dev/$disknametarget"
        arch-chroot /mnt bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
    elif [[ $bootvar == "msdos" ]] && [[ $encrypteddisk == "no" ]] ; then
        arch-chroot /mnt bash -c "grub-install --target=i386-pc /dev/$disknametarget"
        arch-chroot /mnt bash -c "grub-mkconfig -o /boot/grub/grub.cfg"
    fi
}
install_packages () {
        arch-chroot /mnt bash -c "pacman -S --noconfirm --needed base-devel \
                                                                ark \
                                                                nano \
                                                                netctl \
                                                                networkmanager \
                                                                htop \
                                                                iftop \
                                                                mlocate \
                                                                flameshot \
                                                                bashtop \
                                                                gtop \
                                                                wget \
                                                                dialog"
        arch-chroot /mnt bash -c "systemctl enable NetworkManager.service"
}
optional_setup_audio_pro () {
    audio=$(dialog --title "SELECT AUDIO (PRO)" --radiolist "Spacebar for selection" 30 80 2 \
    "1" "AUDIO     : ALSA,PULSEAUDIO               (standard)" "on" \
    "2" "AUDIO-PRO : JACK,BRIDGE,ALSA,PULSEAUDIO   (recommanded + presets)" "off" \
    "3" "AUDIO     : PIPEWIRE,JACK,ALSA,PULSE      (expert)" "off" \
    2>&1 1>/dev/tty);
        if [[ $audio == "1" ]]; then
            arch-chroot /mnt bash -c "pacman -S --noconfirm --needed pulseaudio pulseaudio-bluetooth"
        elif [[ $audio == "2" ]]; then
            arch-chroot /mnt bash -c "pacman -S --noconfirm --needed realtime-privileges pulseaudio pulseaudio-bluetooth qjackctl pulseaudio-jack jack2 ardour mda.lv2 calf helm-synth lsp-plugins noise-repellent x42-plugins zam-plugins"
            arch-chroot /mnt bash -c "mkdir -p /etc/skel/audio-pro && cd /etc/skel/audio-pro && curl -LJO https://raw.githubusercontent.com/eugenepauljean/bridge-pulseaudio-jack/main/qjackctl-bridge-pulseaudio.sh"
            arch-chroot /mnt bash -c "mkdir -p /etc/skel/audio-pro && cd /etc/skel/audio-pro && curl -LJO https://raw.githubusercontent.com/eugenepauljean/bridge-pulseaudio-jack/main/ardour-preset.tar.gz && tar -xf ardour-preset.tar.gz"
            arch-chroot /mnt bash -c "chmod +x /etc/skel/audio-pro/qjackctl-bridge-pulseaudio.sh"
        elif [[ $audio == "3" ]]; then
            arch-chroot /mnt bash -c "pacman -S --noconfirm --needed realtime-privileges pipewire pipewire-alsa pipewire-jack pipewire-docs helvum ardour mda.lv2 calf helm-synth lsp-plugins noise-repellent x42-plugins zam-plugins"
            arch-chroot /mnt bash -c "ln -sf /usr/lib/pipewire-0.3/jack/libjackserver.so.0 /usr/lib/libjackserver.so.0"
            arch-chroot /mnt bash -c "ln -sf /usr/lib/pipewire-0.3/jack/libjacknet.so.0 /usr/lib/libjacknet.so.0"
            arch-chroot /mnt bash -c "ln -sf /usr/lib/pipewire-0.3/jack/libjack.so.0 /usr/lib/libjack.so.0"
            arch-chroot /mnt bash -c "mkdir -p /etc/skel/audio-pro && cd /etc/skel/audio-pro && curl -LJO https://raw.githubusercontent.com/eugenepauljean/bridge-pulseaudio-jack/main/qjackctl-bridge-pulseaudio.sh"
            arch-chroot /mnt bash -c "mkdir -p /etc/skel/audio-pro && cd /etc/skel/audio-pro && curl -LJO https://raw.githubusercontent.com/eugenepauljean/bridge-pulseaudio-jack/main/ardour-preset.tar.gz && tar -xf ardour-preset.tar.gz"
        fi
}
install_desktop () {
    installdesktop=$(dialog --title "SELECT DESKTOP" --radiolist "Spacebar for selection" 30 80 2 \
    "1" "PLASMA-DESKTOP" "on" \
    "2" "XFCE" "off" \
    "3" "GNOME" "off" \
    2>&1 1>/dev/tty);
        if [[ $installdesktop == "1" ]] ; then
        arch-chroot /mnt bash -c "pacman -S --noconfirm --needed xorg-server plasma-desktop plasma-nm plasma-pa powerdevil bluedevil dolphin konsole kate kscreen sddm sddm-kcm"
        arch-chroot /mnt bash -c "systemctl enable sddm.service"
        elif [[ $installdesktop == "2" ]] ; then
        arch-chroot /mnt bash -c "pacman -S --noconfirm --needed xorg-server pavucontrol xfce4 xfce4-goodies lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings xfce4-pulseaudio-plugin"
        arch-chroot /mnt bash -c "systemctl enable lightdm.service"
        elif [[ $installdesktop == "3" ]] ; then
        arch-chroot /mnt bash -c "pacman -S --noconfirm --needed xorg-server gnome gnome-extra lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings"
        arch-chroot /mnt bash -c "systemctl enable lightdm.service"
        fi
}
install_driver_video () {
    vgacard=$(dialog --title "SELECT VIDEO CARDS" --radiolist "Spacebar for selection" 30 80 2 \
    "1" "AMD" "off" \
    "2" "ATI" "off" \
    "3" "INTEL" "off" \
    "4" "NVIDIA - proprietary" "off" \
    "5" "NVIDIA - opensource" "off" \
    "6" "VIRTUAL MACHINE" "off" \
    "7" "VESA" "on" \
    2>&1 1>/dev/tty);
        if [[ $vgacard == "1" ]]; then
            arch-chroot /mnt bash -c "pacman -S --noconfirm --needed xf86-video-amdgpu"
        elif [[ $vgacard == "2" ]]; then
            arch-chroot /mnt bash -c "pacman -S --noconfirm --needed xf86-video-ati"
        elif [[ $vgacard == "3" ]]; then
            arch-chroot /mnt bash -c "pacman -S --noconfirm --needed xf86-video-intel"
        elif [[ $vgacard == "4" ]]; then
            arch-chroot /mnt bash -c "pacman -S --noconfirm --needed nvidia nvidia-dkms linux-headers nvidia-settings nvtop"
        elif [[ $vgacard == "5" ]]; then
            arch-chroot /mnt bash -c "pacman -S --noconfirm --needed xf86-video-nouveau"
        elif [[ $vgacard == "6" ]]; then
            arch-chroot /mnt bash -c "pacman -S --noconfirm --needed xf86-video-qxl virglrenderer spice-vdagent celt0.5.1 virtualbox-guest-utils xf86-video-vmware"
        elif [[ $vgacard == "7" ]]; then
            arch-chroot /mnt bash -c "pacman -S --noconfirm --needed xf86-video-vesa"
        fi
}
set_xkeyboard () {
        arch-chroot /mnt bash -c "mkdir --parent /etc/X11/xorg.conf.d"
        arch-chroot /mnt bash -c "echo 'Section \"InputClass\"' > /etc/X11/xorg.conf.d/00-keyboard.conf"
        arch-chroot /mnt bash -c "echo '    Identifier \"system-keyboard\"' >> /etc/X11/xorg.conf.d/00-keyboard.conf"
        arch-chroot /mnt bash -c "echo '    MatchIsKeyboard \"on\"' >> /etc/X11/xorg.conf.d/00-keyboard.conf"
        arch-chroot /mnt bash -c "echo '    Option \"XkbLayout\" \"$setvconsole\"' >> /etc/X11/xorg.conf.d/00-keyboard.conf"
        arch-chroot /mnt bash -c "echo 'EndSection' >> /etc/X11/xorg.conf.d/00-keyboard.conf"
}
user_add_group_audio () {
        if [[ $audio == "1" ]]; then
            echo "nothing special to do"
        elif [[ $audio == "2" ]]; then
            arch-chroot /mnt bash -c "usermod -aG realtime audio $username"
        elif [[ $audio == "3" ]]; then
            arch-chroot /mnt bash -c "usermod -aG realtime audio $username"
        fi
}
clean_restart () {
        umount -R /mnt/boot/efi
        umount -R /mnt/boot
        umount -R /mnt
        reboot
}
prepare_setup
select_mirrors
welcome_msg
check_bootmode
update_systemclock
check_diskname
erase_disk
encrypted_choice
essential_packages
enter_username
detect_cpu
generate_fstab
set_timezone_region
set_timezone_city
set_localization
set_localeconf
set_keyboardlayoutmap
set_hostname
install_grub
install_packages
optional_setup_audio_pro
install_desktop
install_driver_video
set_xkeyboard
define_userpwd
define_rootpwd
user_add_group_audio
clean_restart
