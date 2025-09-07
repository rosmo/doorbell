#!/bin/bash

set -e

USER=doorbell
CURDIR=$(pwd)
GROUP=users

if ! id -u $USER 2>/dev/null >/dev/null ; then
  echo "Adding user $USER..."
  useradd -G $GROUP,sudo,dialout $USER
else
  usermod -s /bin/bash -G $GROUP,sudo,dialout $USER
fi
if [ ! -d /home/$USER ] ; then
  mkdir -p /home/$USER
  chown -R $USER:$GROUP /home/$USER
  chmod 0700 /home/$USER
fi

tee /etc/sudoers.d/doorbell <<EOF
doorbell ALL=(ALL:ALL) NOPASSWD: ALL
EOF

echo "Installing curl, git and python3-pip..."
apt-get install -y curl git python3-pip pkg-config

if [ ! -f /etc/sysctl.d/50-unprivileged-ports.conf ] ; then
  echo 'net.ipv4.ip_unprivileged_port_start=0' > /etc/sysctl.d/50-unprivileged-ports.conf
  sysctl --system
fi

echo "Disabling Debian madness for Python..."
if [ -f /usr/lib/python3.*/EXTERNALLY-MANAGED ] ; then
  rm -f /usr/lib/python3.*/EXTERNALLY-MANAGED
fi

apt-get install -y gpiod \
	git tmux \
	xinput x11-dbus notification-daemon \
	tigervnc-scraping-server tigervnc-tools

tee /lib/udev/rules.d/99-gpiochip.rules <<EOF
# Enable dialout group to write to GPIOs
SUBSYSTEM=="gpio*", PROGRAM="/bin/sh -c 'chgrp -R dialout /dev/gpiochip* && chmod 0660 /dev/gpiochip*'"
EOF

curl -so /usr/local/bin/startvnc https://raw.githubusercontent.com/sebestyenistvan/runvncserver/refs/heads/master/startvnc
chmod a+rx /usr/local/bin/startvnc

tee /etc/tigervnc/vncserver-config-defaults <<EOF
\$localhost = "no";
1;
EOF

tee /home/doorbell/.xsessionrc <<EOF
# Rotate display to left
xrandr --output HDMI-1 --rotate left

# Enable blanking, disable screensaver
xset dpms 60
xset s off

# Fix touchscreen
DISPLAY_ID=\$(xinput list | grep 'USB2IIC' | awk -F 'id=|\[' '{ print \$2; }')
xinput set-prop \$DISPLAY_ID 'Coordinate Transformation Matrix' 0 -1 1 1 0 0 0 0 1

# Start notification daemon
/usr/lib/notification-daemon/notification-daemon &

# Start scraping VNC server
/usr/local/bin/startvnc start >/dev/null 2>&1
EOF
chown doorbell:doorbell /home/doorbell/.xsessionrc

tee /home/doorbell/.Xresources <<EOF
Xft.dpi: 200
EOF
chown doorbell:doorbell /home/doorbell/.Xresources

rm -f /etc/X11/xorg.conf.d/98-dietpi-disable_dpms.conf
tee /etc/X11/xorg.conf.d/98-enable_dpms.conf <<EOF
Section "Extensions"
        Option "DPMS" "Enable"
EndSection
Section "ServerFlags"
        Option "BlankTime" "60"
EndSection
EOF

