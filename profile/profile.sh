#! /bin/bash

#Install the packages needed to execute phoronix
#Is OS is CernVM the php is not compatible, it should be removed and installed again
yum -y install epel-release
yum -y install lapack fio gcc-c++ yasm

kernel=`uname -r`
if [[ $kernel == *"cernvm"* ]]; then
  yum -y remove php
fi
yum -y install php-domxml

if ! hash phoronix-test-suite 2>/dev/null; then 
  #Downloads and install phoronix
  cd /root
  wget http://www.phoronix-test-suite.com/download.php?file=phoronix-test-suite-5.8.1 -O phoronix-test-suite-5.8.1.tar.gz
  tar -zxf phoronix-test-suite-5.8.1.tar.gz
  cd /root/phoronix-test-suite ; ./install-sh
fi

#Creates a new user to execute the tests
#If the tests are executed as root, the user-config and the result tests sometime are not well defined.
/usr/sbin/useradd -b /home phoronix

#Configure phoronix
echo 'Y' | /usr/bin/sudo -n -u phoronix phoronix-test-suite
/usr/bin/sudo -n -u phoronix phoronix-test-suite batch-install pts/build-linux-kernel pts/compress-7zip pts/encode-mp3 pts/x264

#Copy the user-config file to use the batch mode
cp /var/spool/checkout/testvcycle/profile/user-config.xml /home/phoronix/.phoronix-test-suite/user-config.xml
chown phoronix /home/phoronix/.phoronix-test-suite/user-config.xml
chgrp phoronix /home/phoronix/.phoronix-test-suite/user-config.xml
chmod u+w /home/phoronix/.phoronix-test-suite/user-config.xml

#execute the tests
/usr/bin/sudo -n -u phoronix phoronix-test-suite batch-run pts/compress-7zip

#Parse the tets and send the information to DB or Message Broker
pip install pymongo==3.0.3
cd /var/spool/checkout/testvcycle/profile/; python profile.py -i `hostname`
