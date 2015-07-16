#! /bin/bash


#Install the packages needed to execute phoronix
#If OS is CernVM the php is not compatible, it should be removed and installed again
yum -y install epel-release
yum -y install lapack fio gcc-c++ yasm

kernel=`uname -r`
if [[ $kernel == *"cernvm"* ]]; then
  yum -y remove php
fi
yum -y install php-domxml

service gmond start

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
echo phoronix | passwd phoronix --stdin


sed -e 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config > /etc/ssh/sshd_config_b
cp /etc/ssh/sshd_config_b /etc/ssh/sshd_config
service sshd restart

#Configure phoronix
yum -y install sshpass
sshpass -p "phoronix" ssh -o StrictHostKeyChecking=no phoronix@127.0.0.1 'echo "Y"|phoronix-test-suite batch-install pts/build-linux-kernel pts/compress-7zip pts/encode-mp3 pts/x264'

#Copy the user-config file to use the batch mode
rm -f /home/phoronix/.phoronix-test-suite/user-config.xml
cp -f /var/spool/checkout/testvcycle/profile/user-config.xml /home/phoronix/.phoronix-test-suite/user-config.xml
chown phoronix /home/phoronix/.phoronix-test-suite/user-config.xml
chgrp phoronix /home/phoronix/.phoronix-test-suite/user-config.xml
chmod u+w /home/phoronix/.phoronix-test-suite/user-config.xml

#execute the tests
sshpass -p "phoronix" ssh -o StrictHostKeyChecking=no phoronix@127.0.0.1 'phoronix-test-suite batch-run pts/compress-7zip'



#Parse the tets and send the information to DB or Message Broker
pip install pymongo==3.0.3
cd /var/spool/checkout/testvcycle/profile/; python profile.py -i `hostname`
