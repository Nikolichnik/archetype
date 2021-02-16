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

echo "archetyperepo: $archetyperepo"
echo "repobranch: $repobranch"
echo "aurhelper: $aurhelper"

# clear

