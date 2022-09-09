#!/bin/sh

mount -t sysfs sysfs /sys
mount -t proc proc /proc
sysctl -w kernel.printk="2 4 1 7"
/bin/sh
poweroff -f
