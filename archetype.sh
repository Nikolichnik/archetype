#!/bin/sh
# Luke's Auto Rice Boostrapping Script (LARBS)
# by Luke Smith <luke@lukesmith.xyz>
# License: GNU GPLv3

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

title="Archetype"

### FUNCTIONS ###

installpkg() {
    pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
}

error() {
    clear
    printf "ERROR:\\n%s\\n" "$1" >&2; exit 1
}

welcomemsg() {
    dialog --title "Welcome to Archetype!" --msgbox "\\nThis script will automatically install a fully-featured Linux desktop, including all the dependencies and programs specified in the programs.csv file and accompanying dotfiles.\\n" 10 60
    dialog --colors --title "Important Note!" --yes-label "All ready!" --no-label "Return..." --yesno "\\nBe sure the computer you are using has current pacman updates and refreshed Arch keyrings.\\n\\nIf it does not, the installation of some programs might fail." 8 70
}

# Prompts user for new username an password.
getuserandpass() {
    name=$(dialog --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1

    while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
        name=$(dialog --no-cancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
    done

    pass1=$(dialog --no-cancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
    pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)

    while ! [ "$pass1" = "$pass2" ]; do
        unset pass2
        pass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
        pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
    done
}

usercheck() {
    ! { id -u "$name" >/dev/null 2>&1; } ||
    dialog --colors --title "WARNING!" --yes-label "CONTINUE" --no-label "No wait..." --yesno "\\nThe user \"$name\" already exists on this system. Archetype can install for a user already existing, but it will \\Zboverwrite\\Zn any conflicting settings/dotfiles on the user account.\\n\\nArchetype will \\Zbnot\\Zn overwrite your user files, documents, videos, etc., so don't worry about that, but only click <CONTINUE> if you don't mind your settings being overwritten.\\n\\nNote also that Archetype will change $name's password to the one you just gave." 14 70
}

preinstallmsg() {
    dialog --title "Let's get this party started!" --yes-label "Let's go!" --no-label "No, nevermind!" --yesno "\\nThe rest of the installation will now be totally automated, so you can sit back and relax.\\n\\nIt will take some time, but when done, you can relax even more with your complete system.\\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 || { clear; exit 1; }
}

# Adds user "$name" with password $pass1.
adduserandpass() {
    dialog --infobox "\\nAdding user \"$name\"..." 5 50
    useradd -m -g wheel -s /bin/zsh "$name" >/dev/null 2>&1 ||
    usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
    repodir="/home/$name/.local/src"; mkdir -p "$repodir"; chown -R "$name":wheel "$(dirname "$repodir")"
    echo "$name:$pass1" | chpasswd
    unset pass1 pass2
}

refreshkeys() {
    dialog --infobox "\\nRefreshing Arch Keyring..." 5 40
    pacman --noconfirm -S archlinux-keyring >/dev/null 2>&1
}

# Set special sudoers settings for install (or after).
newperms() {
    sed -i "/#ARCHETYPE/d" /etc/sudoers
    echo "$* #ARCHETYPE" >> /etc/sudoers
}

# Installs $1 manually if not installed. Used only for AUR helper here.
manualinstall() {
    [ -f "/usr/bin/$1" ] || (
    dialog --infobox "\\nInstalling \"$1\", an AUR helper..." 5 50
    cd /tmp || exit 1
    rm -rf /tmp/"$1"*
    curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/"$1".tar.gz &&
    sudo -u "$name" tar -xvf "$1".tar.gz >/dev/null 2>&1 &&
    cd "$1" &&
    sudo -u "$name" makepkg --noconfirm -si >/dev/null 2>&1
    cd /tmp || return 1)
}

# Installs all needed programs from main repo.
maininstall() {
    echo calculatepercentage $n $total | dialog --title "$title" --gauge "\\nInstalling \"$1\". $1 $2" 10 70
    installpkg "$1"
}

gitmakeinstall() {
    progname="$(basename "$1" .git)"
    dir="$repodir/$progname"
    branch="${2:-master}"
    echo calculatepercentage $n $total | dialog --title "$title" --gauge "\\nInstalling \"$progname\", branch \"$branch\", via \"git\" and \"make\". $(basename "$1") $3" 10 70
    sudo -u "$name" git clone -b "$branch" --depth 1 "$1" "$dir" >/dev/null 2>&1 || { cd "$dir" || return 1 ; sudo -u "$name" git pull --force origin "$branch";}
    cd "$dir" || exit 1
    make >/dev/null 2>&1
    make install >/dev/null 2>&1
    cd /tmp || return 1
}

aurinstall() {
    echo calculatepercentage $n $total | dialog --title "$title" --gauge "\\nInstalling \"$1\" from the AUR. $1 $2" 10 70
    echo "$aurinstalled" | grep -q "^$1$" && return 1
    sudo -u "$name" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1
}

pipinstall() {
    echo calculatepercentage $n $total | dialog --title "$title" --gauge "\\nInstalling the Python package \"$1\". $1 $2" 10 70
    [ -x "$(command -v "pip")" ] || installpkg python-pip >/dev/null 2>&1
    yes | pip install "$1"
}

# Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
putgitrepo() {
    [ -z "$3" ] && branch="master" || branch="$repobranch"
    dir=$(mktemp -d)
    [ ! -d "$2" ] && mkdir -p "$2"
    chown -R "$name":wheel "$dir" "$2"
    sudo -u "$name" git clone --recursive -b "$branch" --depth 1 "$1" "$dir" >/dev/null 2>&1
    sudo -u "$name" cp -rfT "$dir" "$2"
}

# Clones the Archetype repository.
clonearchetype() {
    dialog --infobox "\\nCloning the Archetype..." 5 60
    putgitrepo "$archetyperepo" "/home/$name/.archetype" "$repobranch"
}

installationloop() {
    progsfile=/home/"$name"/.archetype/programs/programs.csv

    ([ -f "$progsfile" ] && cp "$progsfile" /tmp/programs.csv) || error "Missing programs.csv file..."

    total=$(wc -l < /tmp/programs.csv)
    aurinstalled=$(pacman -Qqm)

    while IFS=, read -r tag program branch comment; do
        n=$((n+1))
        echo "$comment" | grep -q "^\".*\"$" && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
        case "$tag" in
            "A") aurinstall "$program" "$comment" ;;
            "G") gitmakeinstall "$program" "$branch" "$comment" ;;
            "P") pipinstall "$program" "$comment" ;;
            *) maininstall "$program" "$comment" ;;
        esac
    done < /tmp/programs.csv
}

installdotfiles() {
    dialog --infobox "\\nInstalling dotfiles..." 5 60
    sudo -u "$name" cp -af /home/"$name"/.archetype/dotfiles/. /home/"$name"
}

systembeepoff() { 
    dialog --infobox "\\nGetting rid of the error beep sound..." 5 50
    rmmod pcspkr
    echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf
}

calculatepercentage() { 
    echo $(( 100 * $1 / $2 ))
}

finalize() {
    dialog --infobox "\\nPreparing welcome message..." 5 50
    dialog --title "All done!" --msgbox "\\nCongrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\\n\\nTo run the new graphical environment, log out and log back in as your new user, then run the command \"startx\" to start the graphical environment (it will start automatically in tty1).\\n" 13 80
    dialog --title "$title" --yesno "\\nWould you like to keep local Archetype repository? This will allow you to update and syncronize dotfiles and programs to install with remote Archetype repository." 10 70 || yes | rm -r /home/"$name"/.archetype
}

### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

# Check if user is root on Arch distro. Install dialog.
pacman --noconfirm --needed -Sy dialog || error "Are you sure you're running this as the root user, are on an Arch-based distribution and have an internet connection?"

# Welcome user and pick dotfiles.
welcomemsg || error "User exited."

# Get and verify username and password.
getuserandpass || error "User exited."

# Give warning if user already exists.
usercheck || error "User exited."

# Last chance for user to back out before install.
preinstallmsg || error "User exited."

### The rest of the script requires no user input.

# Refresh Arch keyrings.
refreshkeys || error "Error automatically refreshing Arch keyring. Consider doing so manually."

for x in curl base-devel git ntp zsh; do
    dialog --title "$title" --infobox "\\nInstalling \"$x\" which is required to install and configure other programs." 5 70
    installpkg "$x"
done

dialog --title "$title" --infobox "\\nSynchronizing system time to ensure successful and secure installation of software..." 6 70
ntpdate 0.us.pool.ntp.org >/dev/null 2>&1

adduserandpass || error "Error adding username and/or password."

# Just in case
[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers

# Allow user to run sudo without password. Since AUR programs must be installed in a
# fakeroot environment, this is required for all builds with AUR.
newperms "%wheel ALL=(ALL) NOPASSWD: ALL"

# Make pacman and yay colorful and adds eye candy on the progress bar because why not.
grep -q "^Color" /etc/pacman.conf || sed -i "s/^#Color$/Color/" /etc/pacman.conf
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf

# Use all cores for compilation.
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf

manualinstall $aurhelper || error "Failed to install AUR helper."

# Clone the Archetype repository.
clonearchetype

# The command that does all the installing. Reads the ~/.archetype/programs/programs.csv
# file and installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a passworprogs.csvd
# and all build dependencies are installed.
installationloop

dialog --title "$title" --infobox "\\nFinally, installing \"libxft-bgra-git\" to enable color emoji in suckless software without crashes." 5 70
yes | sudo -u "$name" $aurhelper -S libxft-bgra-git >/dev/null 2>&1

# Install the dotfiles in the user's home directory
installdotfiles

# Create default urls file if none exists.
[ ! -f "/home/$name/.config/newsboat/urls" ] && echo "https://www.archlinux.org/feeds/news/" > "/home/$name/.config/newsboat/urls"

# Most important command! Get rid of the beep!
systembeepoff

# Make zsh the default shell for the user.
chsh -s /bin/zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"

# dbus UUID must be generated for Artix runit.
dbus-uuidgen > /var/lib/dbus/machine-id

# Tap to click
[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && printf 'Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
    # Enable left mouse button by tapping
    Option "Tapping" "on"
EndSection' > /etc/X11/xorg.conf.d/40-libinput.conf

# Fix fluidsynth/pulseaudio issue.
grep -q "OTHER_OPTS='-a pulseaudio -m alsa_seq -r 48000'" /etc/conf.d/fluidsynth ||
    echo "OTHER_OPTS='-a pulseaudio -m alsa_seq -r 48000'" >> /etc/conf.d/fluidsynth

# Start/restart PulseAudio.
killall pulseaudio; sudo -u "$name" pulseaudio --start

# This line, overwriting the "newperms" command above will allow the user to run
# serveral important commands, "shutdown", "reboot", updating, etc. without a password.
newperms "%wheel ALL=(ALL) ALL #ARCHETYPE
%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/packer -Syu,/usr/bin/packer -Syyu,/usr/bin/systemctl restart NetworkManager,/usr/bin/rc-service NetworkManager restart,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/yay,/usr/bin/pacman -Syyuw --noconfirm"

# Last message! Install complete!
finalize
clear
