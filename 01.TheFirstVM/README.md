# Chapter 1 : The First VM

For this first chapter, we will focus on doing the minimum required amounts of steps to be able to run a linux VM under QEMU.

For our VM, we will need exactly 3 things : the linux kernel itself [^1], a special executable called busybox [^2], and a single script to be used as our PID 1 program.
As alluded to in the prelude, this chapter is really but a text recreation of a tutorial by Victor Engelmann [^3] with slight adaptations. The most notable difference is that his tutorial is a big shell script, and this is a big Makefile.

## A word about how we're going to use GNU make
For the work that we're doing, it would be rather inconvenient to use a big shell script.
Suppose for instance that your compilation step didn't work because you were lacking a dependency on your machine. If you make a single shell script that does everything, either A) your shell script will probably re-download source code archives needlessly, or B) you need to explicitly think about the re-entrancy of you shell script, and add guards such as this : ``` if ! test -e myarchive.tgz; then  wget https://my/url.tgz; fi```. This is going to be unreadable very quickly.
I think it's a better idea to use a program that has that kind of task ordering semantics. One like **make(1)**.

## A 101-lvl introduction to GNU make (you can skip this section if you know make already)
If you have never heard of **make(1)** before, it's a scripting language that is often used in order to specify the build tasks for programming with compiled languages. You can tell it that, in order to make a specific file (some say "artefact" in that context), a certain number of tasks are required. I can tell **make(1)** that in order to make a file named foo it needs to execute the touch command, by making a file named Makefile, and putting this in it
```makefile

foo:
	touch foo
#note that the indentation for the steps HAS to start with a TAB character
#If you do anything else, make doesn't understand the specification
```
If I then invoke **make foo**, it's going to create the file. But if I type this again, make is going to tell me that there is nothing to do, as the file already exists. So far that's not much more practical than shell scripting.
Where the language really shines, is when you have the ability to specify dependencies recursively.

```makefile

bar:
	touch bar

foo: bar
	touch foo
```
Now if you invoke **make foo**, make is going to realize that the bar file doesn't exist, but is a prerequisite to foo. So it's going to make it, and THEN run the steps to make foo

There is a final capability that we are particularly interrested in : make inspects the date of last modification, and runs the appropriate tasks to ensure that any given dependency is always NEWER than every single of its own dependencies

This is useful eg, when you want to make compilation steps. Suppose I make a "Hello, World!" program in C whose source file is hello.c
```makefile

hello: hello.c
	gcc hello.c -o hello
```
After any modification to the file hello.c, I can simple run **make hello** to re-create the executable. Thanks to this final capability, it is quite easy to test changes incrementally: change one file, run make, observe the results. So long as make has a complete enough picture of what depends upon what, you never need to care about the exact list of commands you need to run to get a working result anymore.

Make has variables, and variable expansion. Because of this, the $ symbol has special semantics. If you want to use this symbol in your shell commands, you must escape $ with another $. This is the reason you'll see double-dollars later in the code

#### The .ONESHELL fake make target
Under its normal mode of operation, GNU make runs a separate shell for each line of instruction that are required to make a single target

Say I make this following Makefile
```makefile

src/A.txt:
	mkdir -p src
	cd src
	touch A.txt
```
Where is A.txt going to end up ? In the current directory, not under src/. Because the **cd** step is run independently from the **touch** step.
Specifying an empty pseudo-target called .ONESHELL: disables this.
It's not clear what default shell make uses, so it's probably best to specify it via the SHELL make variable.

However, we are now faced with a new problem : by default, bash doesn't stop at the first error. So having those multiple lines run under a single shell doesn't catch errors as soon as they occur. For this, we turn to the so-called unofficial bash "strict mode" [^4]

#### The .PHONY targets
The .PHONY target tells GNU make (and I believe this is a GNU extension not necessarily otherwise found in other make implementations ? Don't quote me on that) that the task is not here to make a file, but is just a way to logically group some actions. If you invoke make with the associated target, the steps will always run, even if there is a file with that name that actually exists.

More so than guarding about someone who makes a file by the name of the task, marking a task a .PHONY tells the reader of the Makefile that this task produces no artefacts, and that's the intended behaviour.

## Compiling the kernel

Since we're not interested in doing kernel developpment, it is largely enough to download the source code of the kernel we want to run, and to compile it. Cloning the kernel git tree is a time-consuming process, as the linux kernel codebase is one of the largest bodies of git commits in existence.


```makefile
.ONESHELL:
SHELL=/bin/bash

KERNEL_VERSION=5.15.6
KERNEL_MAJOR=5

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
```
If available, **nproc(1)** is a command that prints to standard out the number of threads available to the OS. In my case, 12.
If the command is not available, consider making just a shell script that prints a number under your PATH, or just replacing the invocation by a sane value like 8 or 12.
  
## Compiling busybox

Once again, a pretty self-explanatory Makefile

```Makefile
BUSYBOX_VERSION=1.34.1
.ONESHELL:
SHELL=/bin/bash

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
```
The only notable thing is that, by default, busybox is not going to be compiled statically.
We'd rather have it be a statically-linked file for our use case.
So the file produced by asking for the default configuration (make defconfig) is ammended to have the line CONFIG\_STATIC=y

## Busybox and Toybox, and argc[0] in C programming

We are almost ready to make our filesystem. But first we need to explain a few things about busybox. We won't cover anything about toybox until a later chapter, but the following remarks apply to toybox as well.

Busybox is a program that "contains" a multitude of programs/commands within it. Its website call it a "multi-call binaries".

If you go under the build/ directory, and invoke **busybox echo hello**, the busybox program will behave like the echo program for which you gave the argument "hello". Likewise, if you were to invoke **busybox yes** (then press ctrl-C after a while to stop its execution), busybox will behave like the yes program. In other words, busybox can support a multitude of programs.
It goes further : if you rename busybox, or make a symbolic link to busybox, busybox will behave under the program with that name.

This is an example script demonstrating the use of a symbolic link as the name for busybox.
```bash
#!/bin/bash

cd build
ln -sf ./ busybox echo
./busybox echo "Hello from busybox executable"
./echo "Hello from busybox run under the echo name"
```

Under Linux, any program is passed an array of command-line arguments when it is created. The first of these arguments is always the name of the program itself.
To demonstrate, let's write a small C program that prints how many arguments it has, and prints the arguments one-by-one.
```C
//////////save under main.c
#include <stdio.h>

int main(int argc, char** argv){
	int i;
	printf("This program is invoked with %d command-line arguments\n", argc);
	for (i=0;i<argc;i++){
		printf("arg #%d : %s\n", i, argv[i]);
	}
	return 0;
}
```
If you compile and run ``` gcc main.c -o main && ./main foo bar && echo ===== && ln -sf main newname && ./newname foo bar```, you get the following output :
```bash
This program is invoked with 3 command-line arguments
arg #0 : ./main
arg #1 : foo
arg #2 : bar
=====
This program is invoked with 3 command-line arguments
arg #0 : ./newname
arg #1 : foo
arg #2 : bar
```

So, as a program writer, the name of your program is dynamically bound to argc[0]. You can write code that works differently based upon the name. That's exactly what busybox (and as we will see later, toybox) do.

In busybox, you can get the exact list of supported command by invoking **busybox --list**.

In toybox you get the same (although the exact format of the output differs a bit), by invoking **toybox --long**.

So when we compiled busybox, we actually compiled a rather exhaustive set of command-line tools. It notably includes a shell called **sh**, which purports to be a posix-compliant shell.
```bash
# # Let's see how many commands are within
# cd build && ./busybox --list | wc -l
399
# #Do we have a sh shell ?
# ./busybox --list | grep ^sh$
sh
```
What we will do in just a few minutes, is that we will query busybox for the different commands that it supports, and make one symlink per supported command under the /bin directory.
This way we will have created a lot of "binaries", even though everything under the hood is just busybox itself.
If you compare this to, say, Linux From Scratch, we have side-stepped the entirety of its Chapter 2, as well as the need to compile bash, binutils, bison, bzip2, coreutils, diffutils, e2fsprog, elfutils, file, findutils, flex, gawk, glibc, grep, gzip, intltool, kdb, less, ninja, perl, python, readline, shadow, vim, util-linux, xz utils, and zlib.

We might be tempted to still compile some of those packages later, because the commands provided by busybox may not be to our liking (grep won't have any option to have color, vi can feel underwhelming to ardent vim users, etc.).

## Making an init script

Our init script is going to be rather terse.

```bash
#!/bin/sh

##Found under own_src/init.sh

mount -t sysfs sysfs /sys
mount -t proc proc /proc
sysctl -w kernel.printk="2 4 1 7"
/bin/sh
poweroff -f
```

In this script, we : 
- Mount a sysfs pseudo-filesystem under /sys (this step is technically optionnal, but some userland utilities rely on this).
- Mount a proc pseudo-filesystem under /proc (this step is technically optionnal, but some userland utilities rely on this).
- Make a request to the kernel that reduces a bit the kernel message verbosity, otherwise you might end up with live kernel messages clobbering your running terminal -- not fun.
- We invoke a shell that we will be able to interact on.
- Finally, we call a program to shut down cleanly

The last point warrants a longer explanation. The Linux kernel does not expect PID 1 to ever exit on its own, whatever its exit code may be. This is not the API provided by the kernel to stop a machine.
So if you leave off the ``` poweroff -f``` command, the kernel will panic after the shell has closed. It's fun to try once, but otherwise not really a good idea.

Should you need it, the **pkill qemu** command can probably help you stop a qemu instance that runs haywire.

## Making an initrd image

One of the simplest processes that allows us to boot a linux VM is the use of a so-called "initial ramdisk" [^5] [^6]

The concept is that you give to the kernel the location of a (possibly gzip-compressed) filesystem archive in a format called cpio, and the kernel will boot to it.
You can later have this minimal system mount its own filesystems, and even perform a complete switch that tells the kernel that the new root is located a given place.
A special executable called init, that can only be placed at a few specific locations, will take on the task of being the process that has PID 1.
All other processes are children of this process.
It's not very clear that all shells are able to properly perform the task of "reaping their children" for long-lived processes [^7].

Even if it were an officially supported feature, we are not free from implementation bugs.
We will switch the init program to a dedicated init daemon in later chapters.
Probably sinit [^8].


So let's make our initrd image. Our initrd image will consist of a root directory with some common folders like etc/ or bin/, we will populate bin/ with a few command line utilities including a shell, and we will make a script that works as a PID 1 script.


```makefile
build/initrd.img: build/busybox
	cd build
	#
	#Create the initrd folder that will be the root of our VM
	mkdir -p initrd
	cd initrd
	#
	#Populate folders like bin/, or etc/
	mkdir -p bin dev proc sys etc home
	cp ../busybox ./bin/
	cd bin
	#
	#Populate /bin with multiple binaries, including a shell
	for prog in $$(./busybox --list); do ln -sf ./busybox ./$$prog ; done
	cd ../..
	#
	#Copy the init script
	install -m 500 ../own_src/init.sh ./initrd/init
	cd initrd
	#
	#Finally, we make a cpio archive that can be fed to the kernel
	find . | cpio -R +0:+0 -o -H newc > ../initrd.img
```

As we wrote earlier a gzip-compressed version of the same archive is also supported.
So you can replace as such:
```diff
- 	find . | cpio -R +0:+0 -o -H newc > ../initrd.img
+	find . | cpio -R +0:+0 -o -H newc | gzip -9 -n  > ../initrd.img
```
At this stage we get a compression ratio of ~1.9. The uncompressed image is around 2.7 MB.
While this may not matter as of writing, this step would have been the difference between fitting our system in a 1.7 MB floppy drive or not.

## Running our first VM

So we have everything required : a kernel to run, a filesystem to boot on, and in the filesystem there is an init script. We don't need a bootloader _yet_ (see Annex, QEMU has one already)
There are two modes to run the VM : one where you have a graphical interface, and one where you tell the kernel to use the serial port (that QEMU will emulate for us) and you tell QEMU to redirect its stdin and stdout to the serial port.

You should try both. Invoke them via **make graphical** and **make run**.

```make
.PHONY: graphical
graphical: build/initrd.img build/kernel
	qemu-system-x86_64 -kernel build/kernel -initrd build/initrd.img
	
.PHONY: run
run:  build/initrd.img build/kernel
	qemu-system-x86_64 -kernel build/kernel -initrd build/initrd.img -nographic -append 'console=ttyS0'
```

If all goes well, you will see a lot of boot messages, and you will enter a shell prompt. If you made it this far, congratulations !


[^1]: https://mirrors.edge.kernel.org/pub/linux/kernel/ is one the official mirrors of all the linux kernels, by release number. You can browse to it via https://kernel.org

[^2]: https://busybox.net/downloads/ official mirror for busybox, by release number

[^3]: https://www.youtube.com/watch?v=asnXWOUKhTA

[^4]: http://redsymbol.net/articles/unofficial-bash-strict-mode/

[^5]: https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/Documentation/admin-guide/initrd.rst?h=v5.19.8

[^6]: https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/Documentation/admin-guide/init.rst?h=v5.19.8

[^7]: The Linux Programming Interface (published in October 2010, No Starch Press, ISBN 978-1-59327-220-3) is a detailed guide and reference for Linux and UNIX system programming. 
See in particular Chapter 26 Section 3 "The SIGCHLD Signal", that details portability issues and the complexity of handling zombie children properly.
The rationale of making sure that utltimately all children are reaped by a dedicated init process, rather than a possibly flaky shell, becomes quite apparent upon reading.

[^8]: https://core.suckless.org/sinit/

## Annex : Don't we need a bootloader ?

TL,DR : QEMU has a bootloader, so we don't _need_ an additional bootloader. Yet.

You might be surprised by the fact that nowhere up until this point, this chapter has mentionned the issue of bootloading.
There is a missing step between the moment that your hardware decides to read the first few sectors of a storage media and the moment that the CPU is properly configured to even boot the linux kernel.
Under physical hardware, this step would be undertaken by a program called a bootloader.
Examples of famous bootloaders include GRUB, LILO, and U-BOOT.
QEMU has its own bootloader, and you can read a bit in the man page for  **qemu-system-x86_64(1)** under the section for the -kernel flag.
So long as your kernel is a Linux kernel or is in a specific format, QEMU can pick up on it just like a bootloader would do.
There is a way to emulate a machine with a bootloader entirely, and we might cover this in a later chapter.
After all, a bootloader is a required component if we are ever to boot under physical hardware. This chapter's aim was not booting under physical hardware, so we skip this for now.
We might revisit this in a later chapter.

## Annex : Links

