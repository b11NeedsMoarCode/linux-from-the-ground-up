#!/bin/bash

GREEN=$'\x1b[32m'
RED=$'\x1b[31m'
RESET=$'\x1b[00m'

for dependency in gcc make bash qemu-system-x86_64 cpio tar wget cp sed install find
do
	printf "${dependency}: " ;
	if which "${dependency}" >/dev/null; then
		echo "$GREEN"OK"$RESET"
	else
		echo "$RED"KO"$RESET"
	fi
done
