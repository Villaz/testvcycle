#! /bin/bash

#Install the packages needed to execute phoronix
#If OS is CernVM the php is not compatible, it should be removed and installed again
yum -y install epel-release
yum -y install lapack fio gcc-c++ yasm

kernel=`uname -r`
if [[ $kernel == *"cernvm"* ]]; then
  yum -y remove php
fi
yum -y install php
yum -y install php-domxml

rpm --nodeps -e ganglia ganglia-gmond
rpm -i https://github.com/Villaz/testvcycle/blob/master/ganglia/libganglia-3.4.0-1.x86_64.rpm?raw=true
rpm -i https://github.com/Villaz/testvcycle/blob/master/ganglia/ganglia-gmond-3.4.0-1.x86_64.rpm?raw=true
service gmond restart


if ! hash phoronix-test-suite 2>/dev/null; then
  #Downloads and install phoronix
  cd /root
  wget http://www.phoronix-test-suite.com/download.php?file=phoronix-test-suite-5.8.1 -O phoronix-test-suite-5.8.1.tar.gz
  tar -zxf phoronix-test-suite-5.8.1.tar.gz
  cd /root/phoronix-test-suite ; ./install-sh
fi


#Creates a new user to execute the tests
#If the tests are executed as root, the user-config and the result tests sometimes are not well defined.
/usr/sbin/useradd -b /home phoronix
echo phoronix | passwd phoronix --stdin

sed -e 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config > /etc/ssh/sshd_config_b
mv -f /etc/ssh/sshd_config_b /etc/ssh/sshd_config
service sshd restart

#Configure phoronix
yum -y install sshpass


#download phoronix data
sshpass -p "phoronix" ssh -o StrictHostKeyChecking=no phoronix@127.0.0.1 'wget http://vcycle-manager-lv.cern.ch/scripts/phoronix.tar.gz /home/phoronix/; cd home/phoronix/; tar -zxvf /home/phoronix/phoronix.tar.gz'
sshpass -p "phoronix" ssh -o StrictHostKeyChecking=no phoronix@127.0.0.1 'phoronix-test-suite batch-run pts/compress-7zip'
#sshpass -p "phoronix" ssh -o StrictHostKeyChecking=no phoronix@127.0.0.1 'phoronix-test-suite batch-run pts/encode-mp3'
#sshpass -p "phoronix" ssh -o StrictHostKeyChecking=no phoronix@127.0.0.1 'phoronix-test-suite batch-run pts/x264'
#sshpass -p "phoronix" ssh -o StrictHostKeyChecking=no phoronix@127.0.0.1 'phoronix-test-suite batch-run pts/build-linux-kernel'

#execute KV Benchmark
chmod u+x /var/spool/checkout/testvcycle/profile/kv.sh
/var/spool/checkout/testvcycle/profile/kv.sh

tar -zcvf /home/phoronix/phoronix.tar.gz /home/phoronix/.phoronix-test-suite/test-results
rm -rf /scratch/KV/pacman*
rm -rf /scratch/KV/*.bz2
rm -rf /scratch/KV/sw-mgr
tar -zcvf /home/phoronix/kv.tar.gz /scratch/KV
#Parse the tets and send the information to DB or Message Broker
sshpass -p "phoronix" ssh -o StrictHostKeyChecking=no phoronix@127.0.0.1 "source /usr/share/sources; source /usr/python-env/bin/activate; cd /var/spool/checkout/testvcycle/profile/;python profile.py -i `hostname` -c $SITE -v $EXPERIMENT"
