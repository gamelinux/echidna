#!bin/bash

IAM=`whoami`;
if [ "$IAM" != "root" ]; then
    echo "[!] Must be root to run this script"
    exit 1
fi

mkdir /usr/local/lib/site_perl/NSMFcommon/ /usr/local/lib/site_perl/NSMFnode/
mkdir /usr/local/lib/site_perl/NSMFserver/ /usr/local/lib/site_perl/NSMFmodules/
# mkdir /usr/local/lib/site_perl/NSMFworkers/

cp -v common/NSMFcommon/* /usr/local/lib/site_perl/NSMFcommon/
cp -v server/NSMFserver/* /usr/local/lib/site_perl/NSMFserver/
cp -v nodes/NSMFnode/* /usr/local/lib/site_perl/NSMFnode/
#cp worker/NSMFworker/* /usr/local/lib/site_perl/NSMFworker/

cpm -v server/modules/NSMFmodules/* /usr/local/lib/site_perl/NSMFmodules/


