
KERNEL_VERSION=5.15.6
BUSYBOX_VERSION=1.34.1
KERNEL_MAJOR=5

.ONESHELL:
SHELL=/bin/bash


src/kernel.tgz:
	set -euo pipefail
	cd src
	wget https://mirrors.edge.kernel.org/pub/linux/kernel/v${KERNEL_MAJOR}.x/linux-${KERNEL_VERSION}.tar.gz
	cp linux-${KERNEL_VERSION}.tar.gz kernel.tgz

build/kernel: src/kernel.tgz
	set -euo pipefail
	cd src
	tar -xf kernel.tgz
	rm -r kernel || true
	mv linux-$(KERNEL_VERSION) kernel
	cd kernel
	make defconfig
	make -j$$(nproc)
	cd ../..
	cp src/kernel/arch/x86_64/boot/bzImage build/kernel
	
	
src/busybox.tar.bz2:
	set -euo pipefail
	cd src
	wget https://busybox.net/downloads/busybox-$(BUSYBOX_VERSION).tar.bz2
	cp busybox-$(BUSYBOX_VERSION).tar.bz2 busybox.tar.bz2


build/busybox: src/busybox.tar.bz2
	set -euo pipefail
	cd src
	tar -xf busybox.tar.bz2
	rm -r ./buysbox/ || true
	mv busybox-$(BUSYBOX_VERSION) busybox
	cd busybox
	make defconfig
	sed -i 's/^.*CONFIG_STATIC[^_].*$$/CONFIG_STATIC=y/' .config
	make -j$$(nproc) busybox
	cd ../..
	cp src/busybox/busybox build/busybox
	
build/initrd.img: build/busybox
	cd build
	mkdir -p initrd
	cd initrd
	mkdir -p bin dev proc sys etc home
	cp ../busybox ./bin/
	cd bin
	for prog in $$(./busybox --list); do ln -sf ./busybox ./$$prog ; done
	cd ../..
	install -m 500 ../own_src/init.sh ./initrd/init
	cd initrd
	find . | cpio -R +0:+0 -o -H newc  > ../initrd.img
	
.PHONY: graphical
graphical: build/initrd.img build/kernel
	qemu-system-x86_64 -kernel build/kernel -initrd build/initrd.img
	
.PHONY: run
run:  build/initrd.img build/kernel
	qemu-system-x86_64 -kernel build/kernel -initrd build/initrd.img -nographic -append 'console=ttyS0'
