#!/bin/bash
# GL printer installation assistant for Linux by Ihor Bordun & Kyrylo Gerasymenko
# tested on Ubuntu 16.04 LTS, Manjaro Linux 17.0.2

# exit on first unhandled error
set -e
VERSION="v3.0"
main() {
  clear
  echo ""
  echo "         = GL printer installation assistant $VERSION ="
  echo ""
  echo "     This script will attempt to install all the required"
  echo "     packages and add selected printer to your system."
  echo ""
  echo "     Please report all issues here http://bit.ly/2vBscyq"
  echo "     To exit at any point - press Ctrl+C"
  echo ""
  echo "                   !! IMPORTANT NOTE !!"
  echo ""
  echo "     The script will ask you for the GL domain login and password"
  echo "     and store them as plain-text in /etc/cups/printers.conf"
  echo "     Remember - it's your responsibility to keep that information safe."
  echo ""
  echo "                 Press ENTER to continue ..."
  read PAUSE
  clear

  echo ""
  echo "         = GL printer installation assistant $VERSION ="
  echo ""
  echo " * Checking if required packages installed..."
  # ID=manjaro VS ID=ubuntu
  DISTRO=$(awk -F "=" '/^ID=/ {print $2}' /etc/*-release | tr -d ' ');
  case $DISTRO in
    "manjaro" ) sudo pacman -S smbclient gutenprint cups --needed && sudo systemctl restart org.cups.cupsd;;
    # if DPKG return non-zero code - request SUDO, install packages and restart CUPS
    "ubuntu"  ) dpkg -s smbclient printer-driver-gutenprint cups &> /dev/null || (sudo apt-get install smbclient printer-driver-gutenprint cups && sudo service cups restart);;
    *         ) dpkg -s smbclient printer-driver-gutenprint cups &> /dev/null || (sudo apt-get install smbclient printer-driver-gutenprint cups && sudo service cups restart);;
  esac
  echo "                            DONE"
  echo ""
  echo " * Setting workgroup in smb.conf (please enter sudo password)..."
  # if smb.conf isn't available, but template exists - copy template first
  [ ! -f /etc/samba/smb.conf ] && [ -f /etc/samba/smb.conf.default ] \
  && sudo cp /etc/samba/smb.conf.default /etc/samba/smb.conf
  # set workgroup to SYNAPSE in the samba config
  sudo sed -i -E 's/workgroup = (WORK|MY)GROUP/workgroup = SYNAPSE/g' /etc/samba/smb.conf
  #echo "                            DONE"
  #echo ""
  #echo "                 Press ENTER to continue ..."
  #read PAUSE
  clear

  echo ""
  echo "         = GL printer installation assistant $VERSION ="
  echo ""
  choose LOCATION "Please enter the number of your location: " "$LOCATIONS"
  case $LOCATION in
    "KBP") COMP="print-kbp.synapse.com";;
    "ODS") COMP="prn-ods1-1.synapse.com";;
    "LWO") COMP="prn-lwo1-1.synapse.com";;
    "HRK") COMP="prn-hrk1-1.synapse.com";;
  esac

  echo ""
  echo ""
  echo "Please enter GL domain credentials."
  echo ""
  read -p "login (e-mail part before '@'): " USER
  read -s -p "password: " PASSWD
  clear

  PRINTERS=`smbclient -U $USER%$PASSWD -L $COMP -g | grep 'Printer' | awk -F'|' ' !/^Disk/ { print $2, "=>", $2}'`
  clear

  echo "";echo "         = Network connectivity test ="
  echo "";echo "";echo ""
  echo "       Performing the test, please wait... "
  echo "";echo "";echo ""
  while ! ping -c4 -w 5 $COMP &>/dev/null
  do 
  echo "There is some problem with the network connection, please make sure that you are connected to GL-xxx-VLAN wireless or wired network and try again."
  echo "";echo ""
  echo "In case if you are connected to the proper network please create appropriate ticket in IT Service Desk and attach file 'errlog.txt' for faster processing."
  echo `date`>errlog.txt
  echo $HOSTNAME>>errlog.txt
  echo "*****************************************">>errlog.txt
  ifconfig -a>>errlog.txt
  echo "*****************************************">>errlog.txt
  netstat -rn>>errlog.txt
  echo "*****************************************">>errlog.txt
  nmcli device show>>errlog.txt
  echo "*****************************************">>errlog.txt
  nmcli connection show --active>>errlog.txt
  echo "*****************************************">>errlog.txt
  nslookup $COMP>>errlog.txt
  exit 0
  done 
  clear

  echo ""
  echo "         = GL printer installation assistant $VERSION ="
  echo ""
  echo "Your location is set to $LOCATION and print server to $COMP"
  echo ""
  choose PRINTER "Please enter the number of printer you want to install: " "$PRINTERS"
  clear

  echo ""
  echo "         = GL printer installation assistant $VERSION ="
  echo ""
  echo "               Please check the settings:"
  echo ""
  echo "             - Print-server: $COMP"
  echo "             - Printer: $PRINTER"
  echo "             - Login: $USER"
  echo ""
  echo "         If something is wrong, press Ctrl+C to exit,"
  echo "       otherwise press ENTER to add the selected printer."
  read PAUSE
  clear

  echo ""
  echo "         = GL printer installation assistant $VERSION ="
  echo ""
  echo "               Please, wait up to 20 seconds..."
  DRIVER=$(lpinfo -m | grep "pcl-g_5e_l" | awk '{print $1}')
  sudo /usr/sbin/lpadmin -p $PRINTER -v smb://$(urlencode "$USER"):$(urlencode "$PASSWD")@${COMP}/${PRINTER} -E -m ${DRIVER} -o PageSize=A4
  echo "               Printer should be added now."
  echo "       You'll need to run this script again after "
  echo "           your domain password is changed."
  echo ""
}

## helper which allows user to select one option among several
function choose {
  readarray -t lines <<< "$3"
  local i=0;
  local options=()
  for el in "${lines[@]}"
  do
    [[ $el =~ ^[[:space:]]*$ ]] && continue;
    ((++i));
    options[$i]="${el%%=>*}"
    printf "%3d ... %s\n" "$i" "${el#*=>}"
  done

  read -p "$2" UINPUT
  local res=$(echo "${options[$UINPUT]}" | tr -d ' ')
  eval "$1=$res"
}
# https://stackoverflow.com/questions/296536/how-to-urlencode-data-for-curl-command
urlencode() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o  

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  echo "${encoded}"    # You can either set a return variable (FASTER)
  REPLY="${encoded}"   #+or echo the result (EASIER)... or both... :p
}
# Returns a string in which the sequences with percent (%) signs followed by
# two hex digits have been replaced with literal characters.
urldecode() {
  printf -v REPLY '%b' "${1//%/\\x}" # You can either set a return variable (FASTER)
  echo "${REPLY}"  #+or echo the result (EASIER)... or both... :p
}

## known locations
LOCATIONS="
KBP => KBP (Kyiv)
ODS => ODS (Mykolaiv)
LWO => LWO (Lviv)
HRK => HRK (Kharkiv)
"
main "$@"
