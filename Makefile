SERIAL_DEVICE = /dev/ttyUSB0
PYTHON = python2
WGET = wget


all: prepare


#
# ext2sim
#
android-core:
	git clone https://android.googlesource.com/platform/system/core $@

e2fsprogs:
	git clone git://git.kernel.org/pub/scm/fs/ext2/e2fsprogs.git $@

LIBSPARSE_DIR = android-core/libsparse
EXT2SIMG_DIR = e2fsprogs/contrib/android
EXT2SIMG_OBJS = $(LIBSPARSE_DIR)/backed_block.o           \
                $(LIBSPARSE_DIR)/output_file.o            \
                $(LIBSPARSE_DIR)/sparse.o                 \
                $(LIBSPARSE_DIR)/sparse_crc32.o           \
                $(EXT2SIMG_DIR)/ext2simg.o

ext2simg: CFLAGS = -Wall -O2 -I$(LIBSPARSE_DIR)/include
ext2simg: LDLIBS = -lz -lext2fs -lcom_err
ext2simg: android-core e2fsprogs $(EXT2SIMG_OBJS)
	$(CC) $(LDFLAGS) $(EXT2SIMG_OBJS) $(LDLIBS) -o $@


#
# Arch Linux generic
#

ARCH_TARBALL = ArchLinuxARM-aarch64-latest.tar.gz
$(ARCH_TARBALL):
	$(WGET) http://archlinuxarm.org/os/$@


#
# Hikey boot tools and blobs
#

PTABLE = ptable-linux-8g.img
LOADER = l-loader.bin
HISI_IDT = hisi-idt.py
BOOTLOADER_BINS = $(HISI_IDT) $(LOADER) $(PTABLE)
$(BOOTLOADER_BINS):
	$(WGET) http://builds.96boards.org/releases/reference-platform/debian/hikey/16.06/bootloader/$@

BOOT_IMG = hikey-boot-linux-20160629-120.uefi.img
$(BOOT_IMG): $(BOOT_IMG).gz
	gunzip -k $@.gz
$(BOOT_IMG).gz:
	$(WGET) http://builds.96boards.org/releases/reference-platform/debian/hikey/16.06/$@


#
# Root FS building
#

ROOTFS_BUILD_REQUIREMENTS = ext2simg $(ARCH_TARBALL)
ROOTFS_RAW = rootfs.raw
ROOTFS_IMG = rootfs.img
IMG_SIZE = 7199505920 # 14061535 sectors of 512B (~6.7G)
MOUNT_POINT = rootfs_mnt
$(ROOTFS_IMG): $(ROOTFS_BUILD_REQUIREMENTS)
	fallocate -l $(IMG_SIZE) $(ROOTFS_RAW)
	mkfs.ext4 -L rootfs $(ROOTFS_RAW)
	mkdir -p $(MOUNT_POINT)
	umount $(MOUNT_POINT) || true
	mount $(ROOTFS_RAW) $(MOUNT_POINT)
	bsdtar -xpf $(ARCH_TARBALL) -C $(MOUNT_POINT)
	mkdir -p $(MOUNT_POINT)/boot/grub
	cp grub.cfg $(MOUNT_POINT)/boot/grub
	umount $(MOUNT_POINT) || true
	rmdir $(MOUNT_POINT) || true
	./ext2simg $(ROOTFS_RAW) $(ROOTFS_IMG)

rootfs: $(ROOTFS_IMG)


#
# Flashing on the emmc
#

FLASH_REQUIREMENTS_DOWNLOADS = $(HISI_IDT) $(LOADER) $(PTABLE) $(BOOT_IMG) 
flash: $(FLASH_REQUIREMENTS_DOWNLOADS) $(ROOTFS_IMG)
	$(PYTHON) $(HISI_IDT) --img1=$(LOADER) -d $(SERIAL_DEVICE)
	sleep 3
	fastboot flash ptable $(PTABLE)
	fastboot flash boot $(BOOT_IMG)
	fastboot flash system $(ROOTFS_IMG)

prepare: $(ROOTFS_BUILD_REQUIREMENTS) $(FLASH_REQUIREMENTS_DOWNLOADS)

serial:
	miniterm.py --raw --eol=lf $(SERIAL_DEVICE) 115200

.PHONY: all rootfs flash prepare serial
