#!/bin/bash

die(){
	echo "Error: $1"
	echo "Exiting..."
	exit 1
}

if [ ! -d /usr/local/mfc ]; then
	die 'Directory /usr/local/mfc does not exist!'
fi

if [ ! -e /usr/local/bin/mfc ]; then
	die 'File /usr/local/bin/mfc does not exist!'
fi


rm -rf /usr/local/mfc
rm /usr/local/bin/mfc

echo "Uninstalled successfully!"