#Potential variables: timezone, lang and locale

passwd

TZuser=$(cat tzfinal.tmp)

ln -sf /usr/share/zoneinfo/$TZuser /etc/localtime

hwclock --systohc

echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "en_US ISO-8859-1" >> /etc/locale.gen
locale-gen

pacman --noconfirm --needed -S networkmanager
systemctl enable NetworkManager
systemctl start NetworkManager

pacman --noconfirm --needed -S grub && grub-install --target=i386-pc /dev/sda && grub-mkconfig -o /boot/grub/grub.cfg
pacman --noconfirm --needed -S dialog

archetype() {
    curl -O https://raw.githubusercontent.com/nikolichnik/archetype/master/archetype.sh && bash archetype.sh -r "$1" -b "$2" -a "$3" 
}

dialog --title "Archetype setup" --yesno "\\nArchetype install script will automatically install a full Arch Linux based desktop environment.\n\nIf you'd like to install this, select yes, otherwise select no." 13 70 && archetype $1 $2 $3
