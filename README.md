# ASL-Build
Script to build ASL (AllStarLink) on Debian Buster (x86 only)

Caveat:  The build is working fine for hub/bridge situations but the resultant build is not working with radio interface hardware
such as the URI.  Booting a system which starts Asterisk with hardware making use of simpleusb or usbradio can cause the system to
loose network connectivity.  Proceed with caution if you need to use with radio interface hardware.
