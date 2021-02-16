#!/bin/bash

### OPTIONS AND VARIABLES ###

while getopts ":r:b:a:h" o; do case "${o}" in
    r) archetyperepo=${OPTARG} && git ls-remote "$archetyperepo" || exit 1 ;;
    b) repobranch=${OPTARG} ;;
    a) aurhelper=${OPTARG} ;;
    h) printf "Optional arguments for custom use:\\n  -r: Archetype repository\\n  -b: Archetype repository branch\\n  -a: AUR helper (must have pacman-like syntax)\\n  -h: Show this message\\n" && exit 1 ;;
    *) printf "Invalid option: -%s\\n" "$OPTARG" && exit 1 ;;
esac done

[ -z "$archetyperepo" ] && archetyperepo="https://github.com/nikolichnik/archetype.git"
[ -z "$repobranch" ] && repobranch="master"
[ -z "$aurhelper" ] && aurhelper="yay"

pacman -Sy --noconfirm dialog || { echo "Error at script start: Are you sure you're running this as the root user? Are you sure you have an internet connection?"; exit; }

dialog --defaultno --title "WARNING!" --yesno "Running this script will delete your entire /dev/sda and reinstall Arch.\n\nTo stop this script, press no. To continue, press yes."  10 60 || exit

dialog --no-cancel --inputbox "Enter a name for your computer." 10 60 2> comp

dialog --defaultno --title "Time Zone select" --yesno "\\nDo you want use the default time zone (Europe/Belgrade)?.\n\nPress no for select your own time zone"  10 60 && echo "Europe/Belgrade" > tz.tmp || tzselect > tz.tmp

dialog --no-cancel --inputbox "Enter partitionsize in gb, separated by space (swap & root)." 10 60 2>psize

IFS=' ' read -ra SIZE <<< $(cat psize)

re='^[0-9]+$'
if ! [ ${#SIZE[@]} -eq 2 ] || ! [[ ${SIZE[0]} =~ $re ]] || ! [[ ${SIZE[1]} =~ $re ]] ; then
    SIZE=(12 25);
fi

timedatectl set-ntp true

cat <<EOF | fdisk /dev/sda
o
n
p


+200M
n
p


+${SIZE[0]}G
n
p


+${SIZE[1]}G
n
p


w
EOF
partprobe

yes | mkfs.ext4 /dev/sda4
yes | mkfs.ext4 /dev/sda3
yes | mkfs.ext4 /dev/sda1
mkswap /dev/sda2
swapon /dev/sda2
mount /dev/sda3 /mnt
mkdir -p /mnt/boot
mount /dev/sda1 /mnt/boot
mkdir -p /mnt/home
mount /dev/sda4 /mnt/home

pacman -Sy --noconfirm archlinux-keyring

pacstrap /mnt base base-devel linux linux-firmware

genfstab -U /mnt >> /mnt/etc/fstab
cat tz.tmp > /mnt/tzfinal.tmp
rm tz.tmp
mv comp /mnt/etc/hostname

curl https://raw.githubusercontent.com/nikolichnik/archetype/master/arch/chroot.sh > /mnt/chroot.sh && arch-chroot /mnt bash chroot.sh -r "$archetyperepo" -b "$repobranch" -a "$aurhelper" && rm /mnt/chroot.sh

dialog --defaultno --title "Final Qs" --yesno "\\nReboot computer?"  5 30 && reboot
dialog --defaultno --title "Final Qs" --yesno "\\nReturn to chroot environment?"  6 30 && arch-chroot /mnt

clear
