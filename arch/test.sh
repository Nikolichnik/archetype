#!/bin/bash

install() {
    calculatepercentage $1 $2 | dialog --title "$title" --gauge "\\nInstalling \"$1\" from the AUR." 10 70
}

calculatepercentage() { 
    echo $(( 100 * $1 / $2 ))
}

install 34 100
