#!/bin/bash

ping -c 3 www.google.com

if [ $? -ge 1 ]; then
	echo "Did not get a response from google, trying to ping yahoo"
	
	ping -c 3 www.yahoo.com
	
	if [ $? -ge 1 ]; then
		echo "Did not get a response from yahoo, trying to ping bing"

		ping -c www.bing.com

		if [ $? -ge 1 ]; then
			echo "Did not get a response from bing rebooting the machine"
			sudo reboot
		fi
	fi
fi

exit 0

