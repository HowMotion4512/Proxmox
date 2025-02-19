#!/usr/bin/env bash

set -o errexit  
set -o errtrace 
set -o nounset  
set -o pipefail 
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR
trap 'die "Script interrupted."' INT

function error_exit() {
  trap - ERR
  local DEFAULT='Unknown failure occured.'
  local REASON="\e[97m${1:-$DEFAULT}\e[39m"
  local FLAG="\e[91m[ERROR:LXC] \e[93m$EXIT@$LINE"
  msg "$FLAG $REASON"
  exit $EXIT
}
function msg() {
  local TEXT="$1"
  echo -e "$TEXT"
}

msg "Setting up LXC OS..."
sed -i "/$LANG/ s/\(^# \)//" /etc/locale.gen
locale-gen >/dev/null

# Update container OS
msg "Updating container OS..."
apt update &>/dev/null
apt-get -qqy upgrade &>/dev/null

msg "Installing Prerequisites..."
apt-get update &>/dev/null
apt-get -qqy install \
    curl \
    sudo &>/dev/null

msg "Installing Pi-hole.."
curl -sSL https://install.pi-hole.net | bash

msg "Customizing LXC..."
rm /etc/motd 
rm /etc/update-motd.d/10-uname 
touch ~/.hushlogin 
GETTY_OVERRIDE="/etc/systemd/system/container-getty@1.service.d/override.conf"
mkdir -p $(dirname $GETTY_OVERRIDE)
cat << EOF > $GETTY_OVERRIDE
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear --keep-baud tty%I 115200,38400,9600 \$TERM
EOF
systemctl daemon-reload
systemctl restart $(basename $(dirname $GETTY_OVERRIDE) | sed 's/\.d//')

msg "Cleanup..."
rm -rf /pihole_setup.sh /var/{cache,log}/* /var/lib/apt/lists/*
