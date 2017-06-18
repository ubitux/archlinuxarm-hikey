SERIAL_DEVICE = /dev/ttyUSB0
PYTHON = python2
WGET = wget


all: prepare


#
# ext2simg
#
android-core:
	git clone --depth 1 https://android.googlesource.com/platform/system/core $@

e2fsprogs:
	git clone --depth 1 git://git.kernel.org/pub/scm/fs/ext2/e2fsprogs.git $@

LIBSPARSE_DIR = android-core/libsparse
EXT2SIMG_DIR = e2fsprogs/contrib/android

EXT2SIMG_SRC = $(EXT2SIMG_DIR)/ext2simg.c
EXT2SIMG_SRC_SPARSE = $(LIBSPARSE_DIR)/backed_block.c           \
                      $(LIBSPARSE_DIR)/output_file.c            \
                      $(LIBSPARSE_DIR)/sparse.c                 \
                      $(LIBSPARSE_DIR)/sparse_crc32.c           \

EXT2SIMG_SRC_ALL = $(EXT2SIMG_SRC) $(EXT2SIMG_SRC_SPARSE)
EXT2SIMG_OBJS = $(EXT2SIMG_SRC_ALL:.c=.o)

$(EXT2SIMG_SRC_SPARSE): android-core
$(EXT2SIMG_SRC): e2fsprogs

ext2simg: CFLAGS = -Wall -O2 -I$(LIBSPARSE_DIR)/include
ext2simg: LDLIBS = -lz -lext2fs -lcom_err
ext2simg: $(EXT2SIMG_OBJS)
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@


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

ROOTFS_RAW = rootfs.raw
ROOTFS_IMG = rootfs.img
IMG_SIZE = 7199505920 # 14061535 sectors of 512B (~6.7G)
MOUNT_POINT = rootfs_mnt
$(ROOTFS_RAW): $(ARCH_TARBALL)
	fallocate -l $(IMG_SIZE) $(ROOTFS_RAW)
	mkfs.ext4 -L rootfs $(ROOTFS_RAW)
	mkdir -p $(MOUNT_POINT)
	sudo umount $(MOUNT_POINT) || true
	sudo mount $(ROOTFS_RAW) $(MOUNT_POINT)
	sudo bsdtar -xpf $(ARCH_TARBALL) -C $(MOUNT_POINT)
	sudo mkdir -p $(MOUNT_POINT)/boot/grub
	sudo cp grub.cfg $(MOUNT_POINT)/boot/grub
	sudo umount $(MOUNT_POINT) || true
	rmdir $(MOUNT_POINT) || true

$(ROOTFS_IMG): ext2simg $(ROOTFS_RAW)
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

prepare: $(ROOTFS_IMG) $(FLASH_REQUIREMENTS_DOWNLOADS)

serial:
	miniterm.py --raw --eol=lf $(SERIAL_DEVICE) 115200

.PHONY: all rootfs flash prepare serial
