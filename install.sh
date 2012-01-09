#!/bin/bash

die(){
	echo "Error: $1"
	echo "Exiting..."
	exit 1
}

if [ -d /usr/local/mfc ]; then
	die 'Directory /usr/local/mfc already exists!'
fi

if [ -e /usr/local/bin/mfc ]; then
	die 'File /usr/local/bin/mfc already exists!'
fi


mkdir /usr/local/mfc

cp -r ./* /usr/local/mfc/

ln -s /usr/local/mfc/mfc /usr/local/bin/mfc

chmod +x /usr/local/bin/mfc

echo "Installed successfully!

MFC files are in /usr/local/mfc

If you can't run mfc directly in the terminal check if the directory /usr/local/bin is on your path
	
	1 - to check your path just run 
	
	  $ echo \$PATH.
			
	2 - if it's not there, you can run this command
	
	  $ touch ~/.bash_profile && echo 'export PATH=/usr/local/bin:\$PATH' >> ~/.bash_profile && source ~/.bash_profile

Now you can try:
	
	$ cd /usr/local/mfc/example
	$ mfc

	And just open your browser at http://localhost:4000/
"