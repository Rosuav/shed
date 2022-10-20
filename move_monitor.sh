#!/bin/bash
if [[ $# -gt 2 ]]; then
	echo Parent
	$0 $1 &
	echo Main
	shift
	echo "$@"
	exit
fi
echo Child: $1
until wmctrl -xr $1 -e 0,1920,0,1920,1080; do
	echo Sleep...
	((tries++ == 30)) && exit 1
	sleep 2
done
# For some reason, the window doesn't move the first time it's visible in the list.
# So we wait a bit, and try again.
sleep 5
echo Doing it again!
wmctrl -xr $1 -e 0,1920,0,1920,1080
