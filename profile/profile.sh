#! /bin/bash


function exec_kv {
  KVBMK="https://raw.githubusercontent.com/Villaz/testvcycle/master/profile/KVbmk.xml"
  KVTAG=$SITE
  KVTHR=1

  mkdir -p /scratch/KV ; cd /scratch/KV
  wget https://kv.roma1.infn.it/KV/sw-mgr --no-check-certificate -O sw-mgr
  chmod u+x sw-mgr

  export VO_ATLAS_SW_DIR=/cvmfs/atlas.cern.ch/repo/sw
  echo 'source /cvmfs/atlas.cern.ch/repo/sw/software/x86_64-slc6-gcc46-opt/17.8.0/cmtsite/asetup.sh --dbrelease=current AtlasProduction 17.8.0.9 opt gcc46 slc6 64'
  source /cvmfs/atlas.cern.ch/repo/sw/software/x86_64-slc6-gcc46-opt/17.8.0/cmtsite/asetup.sh --dbrelease=current AtlasProduction 17.8.0.9 opt gcc46 slc6 64


  SW_MGR_START=`date +"%y-%m-%d %H:%M:%S"`
  echo "start sw-mgr ${SW_MGR_START}"

  wget $KVBMK -O /tmp/KVbmk.xml

  KVSUITE=`grep -i "<kvsuite>" /tmp/KVbmk.xml | head -1 | sed -E "s@.*>(.*)<.*@\1@"`
  echo KVBMK $KVBMK
  echo KVSUITE $KVSUITE

  echo "./sw-mgr -a 17.8.0.9-x86_64 --test 17.8.0.9 --no-tag -p /cvmfs/atlas.cern.ch/repo/sw/software/x86_64-slc6-gcc46-opt/17.8.0 --kv-disable ALL --kv-enable $KVSUITE --kv-conf $KVBMK --kv-keep --kvpost --kvpost-tag $KVTAG --tthreads $KVTHR "

  REFDATE=`date +\%y-\%m-\%d_\%H-\%M-\%S`
  KVLOG=kv_$REFDATE.out
  ./sw-mgr -a 17.8.0.9-x86_64 --test 17.8.0.9 --no-tag -p /cvmfs/atlas.cern.ch/repo/sw/software/x86_64-slc6-gcc46-opt/17.8.0 --kv-disable ALL --kv-enable $KVSUITE --kv-conf $KVBMK --kv-keep --kvpost --kvpost-tag $KVTAG --tthreads $KVTHR #> $KVLOG
  [ $? -ne 0 ] && exit 1

  TESTDIR=`ls -tr | grep kvtest_ | tail -1`
  df -h > space_available.log
  tar -cvjf ${TESTDIR}_${REFDATE}.tar.bz2 ${TESTDIR}/KV.thr.*/data/*/*log $KVLOG space_available.log
  SW_MGR_STOP=`date +"%y-%m-%d %H:%M:%S"`
  echo "end sw-mgr ${SW_MGR_STOP}"

  PERFMONLOG=PerfMon_summary_`date +\%y-\%m-\%d_\%H:\%M:\%S`.out
  echo "host_ip: `hostname`" >> $PERFMONLOG
  echo "start sw-mgr ${SW_MGR_START}">> $PERFMONLOG
  echo "end sw-mgr ${SW_MGR_STOP}" >> $PERFMONLOG
  grep -H PerfMon $TESTDIR/KV.thr.*/data/*/*log >> $PERFMONLOG
}


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
#If the tests are executed as root, the user-config and the result tests sometime are not well defined.
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
sshpass -p "phoronix" ssh -o StrictHostKeyChecking=no phoronix@127.0.0.1 'phoronix-test-suite batch-run pts/encode-mp3'
sshpass -p "phoronix" ssh -o StrictHostKeyChecking=no phoronix@127.0.0.1 'phoronix-test-suite batch-run pts/x264'
sshpass -p "phoronix" ssh -o StrictHostKeyChecking=no phoronix@127.0.0.1 'phoronix-test-suite batch-run pts/build-linux-kernel'

#execute KV Benchmark
exec_kv

tar -zcvf /home/phoronix/phoronix.tar.gz /home/phoronix/.phoronix-test-suite/test-results
rm -rf /scratch/KV/pacman*
rm -rf /scratch/KV/*.bz2
rm -rf /scratch/KV/sw-mgr
tar -zcvf /home/phoronix/kv.tar.gz /scratch/KV
#Parse the tets and send the information to DB or Message Broker
source /usr/python-env/bin/activate
cd /var/spool/checkout/testvcycle/profile/
python profile.py -i `hostname` -c $SITE -v $EXPERIMENT
deactivate