#! /bin/bash

#Install the packages needed to execute phoronix
#Is OS is CernVM the php is not compatible, it should be removed and installed again
yum -y install epel-release
yum -y install lapack fio gcc-c++ yasm
yum -y remove php
yum -y install php-domxml

#Downloads and install phoronix
wget http://www.phoronix-test-suite.com/download.php?file=phoronix-test-suite-5.8.1 -O phoronix-test-suite-5.8.1.tar.gz
tar -zxf phoronix-test-suite-5.8.1.tar.gz
cd /root/phoronix-test-suite ; ./install-sh

#Creates a new user to execute the tests
#If the tests are executed as root, the user-config and the result tests sometime are not well defined.
/usr/sbin/useradd -b /home phoronix

#Configure phoronix
echo 'Y' | /usr/bin/sudo -n -u phoronix phoronix-test-suite
/usr/bin/sudo -n -u phoronix phoronix-test-suite batch-install pts/build-linux-kernel pts/compress-7zip pts/encode-mp3 pts/x264

#Copy the user-config file to use the batch mode
cp /root/profile/user-config.xml /home/phoronix/.phoronix-test-suite/user-config.xml
chown phoronix /home/phoronix/.phoronix-test-suite/user-config.xml
chgrp phoronix /home/phoronix/.phoronix-test-suite/user-config.xml
chmod u+w /home/phoronix/.phoronix-test-suite/user-config.xml

#execute the tests
/usr/bin/sudo -n -u phoronix phoronix-test-suite batch-run pts/compress-7zip

#Parse the tets and send the information to DB or Message Broker
pip install pymongo==3.0.3
cd /root/profile/; python profile.py
