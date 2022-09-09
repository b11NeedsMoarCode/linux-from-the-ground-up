# Linux-From-ThreGroundUp

This project aims to build a Linux VM that can run under the QEMU hypervisor, entirely from source components. It documents my personnal journey to make a distribution from the ground up. Views in the document are entirely my own, and I make no claims that everything stated in prose is 100% factual.

Much credit goes to Viktor Engelmann <https://github.com/AlgorithMan-de> for this amazing video tutorial in which he makes a qemu-runnable VM in 45 minutes. Really, the first chapter is a rewording of this tutorial : https://www.youtube.com/watch?v=asnXWOUKhTA

As you would have guessed, the name is a tongue-in-cheek reference to Linux From Scratch, which you can find here : https://www.linuxfromscratch.org/lfs/downloads/stable/ . While inspiration will be taken from it, this is a different project entirely, built around busybox (in chapter 1) or toybox (chapter 2 an later). By doing so, we can make a VM that can run quickly and easily, even though it starts off very bare-bones indeed. LFS takes many hours before you can run anything under qemu.

## PROJECT LAYOUT

The project will be divided into chapters.
Each chapter will be a directory following this structure

```
XX.Chapter\_Name/
|-- build/        #Place to store build artefacts
|-- src/          #Source folder for the code compiled from source
|-- own\_src/     #Source folder for our own scripts and configuration files
|-- Makefile      #Makefile for the chapter
`-- README.md     #Chapter prose
```
