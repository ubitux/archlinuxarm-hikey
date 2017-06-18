This repository is a helper to build an ArchLinuxARM image for the Hikey board.


Dependencies
============

- `make`
- `git`
- `sudo`
- `bsdtar` (`libarchive`)
- `python2`
- `fastboot` (`android-tools`)


Creating the flashable root FS image
====================================

Run `make`.

Note: running with jobs is supported.

Flashing the image on the emmc
==============================

- Make sure you created the root FS image with `make`
- Connect the pins 1-2 (auto power) and 3-4 (recovery) on the board
- Plug the micro USB cable
- Plug the DC cable
- Wait about 3 seconds and run `make flash`


Goodies
=======

If you have a serial cable and `miniterm.py` installed (`python-pyserial`),
`make serial` will open a session with the appropriate settings.


TODO
====

- Find a way to achieve the same but on the SD card
- Upstream on archlinuxarm.org
