#!/usr/bin/env bash

function dump_kv_file(){
cat > /tmp/KVbmk.xml << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE unifiedTestConfiguration SYSTEM "http://www.hep.ucl.ac.uk/atlas/AtlasTesting/DTD/unifiedTestConfiguration.dtd">

<unifiedTestConfiguration>

<kv>
    <kvtest name='AtlasG4SPG' enabled='true'>
      <release>ALL</release>
      <priority>20</priority>
      <kvsuite>KV2012</kvsuite>
      <trf>AtlasG4_trf.py</trf>
      <desc>Single Muon Simulation</desc>
      <author>Alessandro De Salvo [Alessandro.DeSalvo@roma1.infn.it]</author>
      <outpath>${T_DATAPATH}/SimulHITS-${T_RELEASE}</outpath>
      <outfile>${T_PREFIX}-SimulHITS-${T_RELEASE}.pool.root</outfile>
      <logfile>${T_PREFIX}-SimulHITS-${T_RELEASE}.log</logfile>
      <kvprestage>http://kv.roma1.infn.it/KV/input_files/simul/preInclude.SingleMuonGenerator.py</kvprestage>
      <signature>
        outputHitsFile="${T_OUTFILE}" maxEvents=100 skipEvents=0 preInclude=KitValidation/kv_reflex.py,preInclude.SingleMuonGenerator.py geometryVersion=ATLAS-GEO-16-00-00 conditionsTag=OFLCOND-SDR-BS7T-04-03
      </signature>
      <copyfiles>
        ${T_OUTFILE} ${T_LOGFILE} PoolFileCatalog.xml metadata.xml jobInfo.xml
      </copyfiles>
      <checkfiles>${T_OUTPATH}/${T_OUTFILE}</checkfiles>
    </kvtest>
</kv>
</unifiedTestConfiguration>
EOF
}

function kv(){
KVBMK="file:///tmp/KVbmk.xml"
KVTAG="KV-Bmk-$CLOUD"
KVTHR=`grep -c processor /proc/cpuinfo`

rm -rf /scratch/KV/
mkdir -p /scratch/KV ; cd /scratch/KV
wget https://kv.roma1.infn.it/KV/sw-mgr --no-check-certificate -O sw-mgr
chmod u+x sw-mgr

export VO_ATLAS_SW_DIR=/cvmfs/atlas.cern.ch/repo/sw
echo 'source /cvmfs/atlas.cern.ch/repo/sw/software/x86_64-slc6-gcc46-opt/17.8.0/cmtsite/asetup.sh --dbrelease=current AtlasProduction 17.8.0.9 opt gcc46 slc6 64'
source /cvmfs/atlas.cern.ch/repo/sw/software/x86_64-slc6-gcc46-opt/17.8.0/cmtsite/asetup.sh --dbrelease=current AtlasProduction 17.8.0.9 opt gcc46 slc6 64


SW_MGR_START=`date +"%y-%m-%d %H:%M:%S"`
echo "start sw-mgr ${SW_MGR_START}"

KVSUITE=`grep -i "<kvsuite>" /tmp/KVbmk.xml | head -1 | sed -E "s@.*>(.*)<.*@\1@"`
echo KVBMK $KVBMK
echo KVSUITE $KVSUITE

echo "./sw-mgr -a 17.8.0.9-x86_64 --test 17.8.0.9 --no-tag -p /cvmfs/atlas.cern.ch/repo/sw/software/x86_64-slc6-gcc46-opt/17.8.0 --kv-disable ALL --kv-enable $KVSUITE --kv-conf $KVBMK --kv-keep --kvpost --kvpost-tag $KVTAG --tthreads $KVTHR "

REFDATE=`date +\%y-\%m-\%d_\%H-\%M-\%S`
KVLOG=kv_$REFDATE.out
./sw-mgr -a 17.8.0.9-x86_64 --test 17.8.0.9 --no-tag -p /cvmfs/atlas.cern.ch/repo/sw/software/x86_64-slc6-gcc46-opt/17.8.0 --kv-disable ALL --kv-enable $KVSUITE --kv-conf $KVBMK --kv-keep --kvpost --kvpost-tag $KVTAG --tthreads $KVTHR > $KVLOG

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


while [ "$1" != "" ]; do
    case $1 in
        --id=*    )             ID=${1#*=};
                                ;;
        --cloud=* )             CLOUD=${1#*=};
                                ;;
        --vo=* )                VO=${1#*=};
                                ;;
        --queue_port=* )        QUEUE_PORT=${1#*=};
                                ;;
        --queue_host=* )        QUEUE_HOST=${1#*=};
                                ;;
        --username=* )          QUEUE_USERNAME=${1#*=};
                                ;;
        --password=* )          QUEUE_PASSWORD=${1#*=};
                                ;;
        --topic=* )             QUEUE_NAME=${1#*=};
                                ;;
        * )         echo -e "${usage}" >&3
                    exit 1
    esac
    shift
done


#Install pip and python enviroment
wget https://bootstrap.pypa.io/get-pip.py
python get-pip.py

#create python enviroment
pip install virtualenv
mkdir -p /usr/python-env
virtualenv /usr/python-env/
source /usr/python-env/bin/activate
pip install wheel
pip install requests
pip install python-geoip
pip install python-geoip-geolite2
pip install ipgetter
pip install pymongo
pip install stomp.py
deactivate

#Install the packages needed to execute phoronix
#If OS is CernVM, php is not compatible, it should be removed and installed again
yum -y install epel-release
yum -y install lapack fio gcc-c++ yasm
yum -y install ruby

kernel=`uname -r`
if [[ $kernel == *"cernvm"* ]]; then
  yum -y remove php
fi
yum -y install php
yum -y install php-domxml


if ! hash phoronix-test-suite 2>/dev/null; then
  #Downloads and install phoronix
  cd /root
  wget http://www.phoronix-test-suite.com/download.php?file=phoronix-test-suite-5.8.1 -O phoronix-test-suite-5.8.1.tar.gz
  tar -zxf phoronix-test-suite-5.8.1.tar.gz
  cd /root/phoronix-test-suite ; ./install-sh
fi


#Creates a new user to execute the tests
#If the tests are executed as root, the user-config and the result tests won't be well defined.
/usr/sbin/useradd -b /home phoronix
echo phoronix | passwd phoronix --stdin

sed -e 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config > /etc/ssh/sshd_config_b
mv -f /etc/ssh/sshd_config_b /etc/ssh/sshd_config
service sshd restart

#Configure phoronix
yum -y install sshpass

cat > /tmp/download.py << 'EOF'
import requests
from requests.adapters import HTTPAdapter

s = requests.Session()
s.mount('http://vcycle-manager-lv.cern.ch', HTTPAdapter(max_retries=5))
r = s.get('http://vcycle-manager-lv.cern.ch/scripts/phoronix.tar.gz', stream=True)
with open('/home/phoronix/phoronix.tar.gz', 'wb') as f:
    for chunk in r.iter_content(chunk_size=1024):
        if chunk: # filter out keep-alive new chunks
            f.write(chunk)
            f.flush()
EOF
chmod ugo+rx /tmp/download.py

if [ ! -f /home/phoronix/phoronix.tar.gz ]; then
#download phoronix data and execute the tests
sshpass -p "phoronix" ssh -o StrictHostKeyChecking=no phoronix@127.0.0.1 'source /usr/python-env/bin/activate; python /tmp/download.py; deactivate; cd /home/phoronix/; tar -zxvf /home/phoronix/phoronix.tar.gz'
fi

echo "export init_tests=`date +%s`" > /tmp/times.source
echo "export init_phoronix_test=`date +%s`" >> /tmp/times.source
sshpass -p "phoronix" ssh -o StrictHostKeyChecking=no phoronix@127.0.0.1 'phoronix-test-suite batch-run pts/compress-7zip'
sshpass -p "phoronix" ssh -o StrictHostKeyChecking=no phoronix@127.0.0.1 'phoronix-test-suite batch-run pts/encode-mp3'
sshpass -p "phoronix" ssh -o StrictHostKeyChecking=no phoronix@127.0.0.1 'phoronix-test-suite batch-run pts/x264'
sshpass -p "phoronix" ssh -o StrictHostKeyChecking=no phoronix@127.0.0.1 'phoronix-test-suite batch-run pts/build-linux-kernel'
echo "export end_phoronix_test=`date +%s`" >> /tmp/times.source


#execute KV Benchmark
dump_kv_file
echo "export init_kv_test=`date +%s`" >> /tmp/times.source
kv
echo "export end_kv_test=`date +%s`" >> /tmp/times.source


#Parse the tests
cat <<X5_EOF >/tmp/parser
source /usr/python-env/bin/activate
source /tmp/times.source
source /usr/share/sources
export HWINFO=`ruby /var/spool/checkout/testvcycle/benchmark/hwinfo.rb`
python /var/spool/checkout/testvcycle/benchmark/parser.py -i $ID -c $CLOUD -v $VO
python /var/spool/checkout/testvcycle/benchmark/send_queue.py --port=$QUEUE_PORT --server=$QUEUE_HOST --username=$QUEUE_USERNAME --password=$QUEUE_PASSWORD --name=$QUEUE_NAME --file=/tmp/result_profile.json
deactivate
X5_EOF
chmod ugo+rx /tmp/parser

sshpass -p "phoronix" ssh -o StrictHostKeyChecking=no phoronix@127.0.0.1 "/tmp/parser"
#Clean the folder
rm -rf /home/phoronix/.phoronix-test-suite/test-results/*
