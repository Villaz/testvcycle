#! /bin/bash

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