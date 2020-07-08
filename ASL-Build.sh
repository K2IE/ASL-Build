#!/bin/bash
#
# Script to build ASL on Debian Buster (x86_64)
#
# Author: Scott Weis <KB2EAR>
# Based upon a build procedure documented by Dan Srebnick <K2IE> for the 020 Digital Multiprotocol Network (http://k2ie.net)
# Released July 8, 2020
#
# Please report any issues at https://github.com/K2IE/ASL-BUILD.sh
#
# Fetch the needed system pieces to compile, including an ancient gcc
export DEBIAN_FRONTEND=noninteractive
apt-get install -y dahdi dahdi-dkms ssh dahdi-source
echo "deb http://ftp.us.debian.org/debian/ jessie main contrib non-free" >> /etc/apt/sources.list.d/jessie.list
echo "deb-src http://ftp.us.debian.org/debian/ jessie main contrib non-free" >> /etc/apt/sources.list.d/jessie.list
apt-get update
apt-get install gcc-4.9 g++-4.9 -y
rm -f /etc/apt/sources.list.d/jessie.list
apt-get update
apt-get install -y git libss7-dev aptitude tcsh libusb-dev libblkid-dev autoconf libasound2-dev libncurses-dev gtk++-dev
apt-get build-dep asterisk -y
apt-get purge -y libopenr2-3 libopenr2-dev
dpkg --configure -a
apt-get install -f

if ! grep -q snd_pcm_oss /etc/modules
then echo snd_pcm_oss >> /etc/modules
fi

modprobe snd_pcm_oss

# Create asterisk user so that we can run as non-root
groupadd --gid 501 --system asterisk
useradd -r -g asterisk -d /var/lib/asterisk -s /usr/sbin/nologin asterisk

# Handle the creation of dahdi_pseudo and the zap symlink
cd /etc/udev/rules.d
rm -rf dahdi.rules
wget https://raw.githubusercontent.com/asterisk/dahdi-tools/master/dahdi.rules
if [ -f dahdi.rules ]
then
cat dahdi.rules | sed 's/LABEL="dahdi_add_end"/KERNEL=="dahdi\/pseudo", SUBSYSTEM=="dahdi",    SYMLINK+="zap\/pseudo", TAG+="systemd"\nLABEL="dahdi_add_end"/' > dahdi.tmp
mv dahdi.tmp dahdi.rules
else
exit 9
fi

udevadm control --reload-rules
modprobe dahdi

#Follow https://wiki.allstarlink.org/wiki/Compiling#Install_requirements_for_building
#  Start at Install GCC 4.9 to compile ASL 1.01+

# Compile and install the very old asterisk used by ASL
cd ~
rm -rf git
mkdir git
cd git
git clone https://github.com/AllStarLink/Asterisk
cd Asterisk/asterisk
./bootstrap.sh
make distclean
./configure CXX=g++-4.9 CC=gcc-4.9 LDFLAGS="-zmuldefs -lasound" CFLAGS="-Wno-unused -Wno-all -Wno-int-conversion"
make menuselect.makeopts
#menuselect/menuselect --enable app_rpt --enable chan_beagle --enable chan_tlb --enable chan_usrp --enable chan_rtpdir --enable chan_usbradio --enable chan_simpleusb --enable chan_echolink --enable app_gps --enable chan_voter --enable radio-tune-menu --enable simpleusb-tune-menu menuselect.makeopts
sed 's/^MENUSELECT_EXTRA_SOUNDS=/MENUSELECT_EXTRA_SOUNDS=EXTRA-SOUNDS-EN-ULAW EXTRA-SOUNDS-EN-G729/;s/MENUSELECT_CORE_SOUNDS=CORE-SOUNDS-EN-GSM/MENUSELECT_CORE_SOUNDS=CORE-SOUNDS-EN-ULAW CORE-SOUNDS-EN-GSM CORE-SOUNDS-EN-G722/;s/^MENUSELECT_ASL_SOUNDS=/MENUSELECT_ASL_SOUNDS=ASL-SOUNDS-EN-ULAW/' menuselect.makeopts > menuselect.makeopts.new
mv menuselect.makeopts.new menuselect.makeopts
make
make install
make samples

# Copy scripts and systemd units
cp ~/git/Asterisk/allstar/updatenodelist/rc.updatenodelist /usr/local/bin
cp ~/git/Asterisk/asterisk/contrib/systemd/asterisk.service /lib/systemd/system
cp ~/git/Asterisk/asterisk/contrib/systemd/updatenodelist.service /lib/systemd/system

# Fix for announcement server change
sed -i 's/rsync:\/\/allstarlink.org\/connect-messages/rsync:\/\/rsync.allstarlink.org\/connect-messages/g' /usr/local/bin/rc.updatenodelist

# Make sure all directories and files are owned by asterisk:asterisk
chown -R asterisk.asterisk /etc/asterisk
chown -R asterisk.asterisk /var/lib/asterisk
chown -R asterisk.asterisk /usr/lib/asterisk
chown -R asterisk.asterisk /var/spool/asterisk

# Deal with permissions for /run/asterisk
echo "d /run/asterisk 0755 asterisk asterisk" > /etc/tmpfiles.d/asterisk.conf
mkdir /run/asterisk
chown -R asterisk.asterisk /run/asterisk
chmod 0755 /run/asterisk

sed -e 's/astrundir => \/var\/run/astrundir => \/run\/asterisk/' /etc/asterisk/asterisk.conf > /etc/asterisk/asterisk.conf.new
mv /etc/asterisk/asterisk.conf.new /etc/asterisk/asterisk.conf
sed 's/^load => codec_ilbc.so/noload => codec_ilbc.so/' /etc/asterisk/modules.conf > /etc/asterisk/modules.conf.new
mv /etc/asterisk/modules.conf.new /etc/asterisk/modules.conf
cp -r ~/git/Asterisk/allstar/sounds /var/lib/asterisk/
systemctl enable --now asterisk.service
systemctl enable --now updatenodelist.service

