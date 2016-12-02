#!/bin/bash
#================================================================
# HEADER
#================================================================
#%title           :HAE.sh
#%description     :This script will install and configure OCFS2, GFS2 and NFS on SLES HAE.
#%author		 : He YI
#%date            :2016-11-12
#%version         :2.0    
#%usage		 : ./HAE.sh OPTION
#% OPTIONS
#%    install,                     install the HAE and configure stonith and base group(DLM+CLVMD)
#%    addOCFS2,                     add OCFS2 as cluster resource
#%    removeOCFS2,                  remove OCFS2 resource
#%    addGFS2,                     add GFS2 as cluster resource(not ready yet)
#%    removeGFS2,                   remove GFS2 as cluster resource(not ready yet)
#%    addNFS,                      add NFS as cluster resource
#%    removeNFS,                   remove NFS as cluster resource
#%    changeStonith,               change stonith sbd device from one to another
#%    -h                            Print this help
#%    -v                            Print script information
#================================================================
#  HISTORY
#     2016/11/11 : Script creation, including install and ocfs2 config
#     2016/11/15 : add NFS, OCFS2 choice
# 
#================================================================
#  DEBUG OPTION
#    set -n  # Uncomment to check your syntax, without execution.
#    set -x  # Uncomment to debug this shell script
#
#================================================================
#================================================================
# END_OF_HEADER
#================================================================






usage()
{
echo  "Usage: ./HAE.sh option"
echo "OPTION could be:"
echo "install,                     install the HAE and configure stonith and base group(DLM+CLVMD)"
echo "addOCFS2,                    add OCFS2 as cluster resource"
echo "removeOCFS2,                 remove OCFS2 resource"
#echo "addGFS2,                     add GFS2 as cluster resource"
#echo "removeGFS2,                  remove GFS2 as cluster resource"
echo "addNFS,                      add NFS as cluster resource"
echo "removeNFS,                   remove NFS as cluster resource"
echo "changeStonith,               change stonith sbd device from one to another"
echo "help                         Print this help"
echo "version                      Print script version"
}




#======================define below parameters before running script========================

NodeA_IP="10.108.108.112"
NodeB_IP="10.108.108.122"
NFS_IP="10.108.108.123"
NodeA_HostName="sles1"
NodeB_HostName="sles2"
INTERFACE="eth0"
SBD_DEVICE="/dev/sdb"
DEV1="/dev/sdc"
DEV2="/dev/sdd"
MajorV=12
MinorV=SP1

MountPoint="10.108.104.80:/home/wide_open/temp/sles-iso"
NTPServer="10.106.16.22"
#=============================================================================================

LocalNode=`hostname`
LocalIP=`ifconfig $INTERFACE | grep "inet addr" | awk '{print $2}'| awk -F : '{print $2}'`
if [ $NodeA_HostName == $LocalNode ]
then
     RemoteNode="$NodeB_HostName"
else
     RemoteNode="$NodeA_HostName"
fi

#RemoteIP=`cat /etc/hosts | grep "10." | grep -v $LocalNode | awk '{print $1}'`
#echo "Please input your SLES Major version"
#echo "Example: 12"
#read MajorV


#echo "Please input your SLES Minor version"
#echo "Example: SP1"
#read MinorV

#==========================================================================


if [ $# == '0' ] ; then
    usage;
    exit 1;
fi


if [ $# -gt 1 ];
then
    usage;
    exit 1;
fi


   if [ ! -b $SBD_DEVICE ]
  then 
       echo "block device $SBD_DEVICE doesn't exist"
	   exit 1
  fi
  
    if [ ! -b $DEV1 ]
  then 
       echo "block device $DEV1 doesn't exist"
	   exit 1
  fi
  
    if [ ! -b $DEV2 ]
  then 
       echo "block device $DEV2 doesn't exist"
	   exit 1
  fi

OPT="$1"
main()
{
case "$OPT" in
      "v")
        echo "Version $VERSION"
        exit 0;
        ;;
      "h")
        usage;
        exit 0;
        ;;
      "install")
        ParamCheck;
		getISO;
		copyISO;
		SetRepo;
		SetNTP;
		SetWatchDog;
		verifyLVM;
		initCluster;		
		exit 0;
        ;;
      "addOCFS2")
	    addcLVMD;
        addOCFS2;
		exit 0;
        ;;
      "removeOCFS2")
	    removeOCFS2;
		sleep 5s
		removecLVMD;
		exit 0;
        ;;
      "addGFS2")
	    #addcLVMD;
        #addGFS2;
		sleep 5s
		exit 0;
        ;;
      "removeGFS2")
        #removeGFS2;
		sleep 5s
		#removecLVMD;
		exit 0;
        ;;
      "addNFS")
        addNFS;
		exit 0;
        ;;
      "removeNFS")
        removeNFS;
		exit 0;
        ;;
      "changeStonith")
        changeStonith;
		exit 0;
        ;;
      *)
        echo "Wrong Option"
		usage;
        exit 0;
        ;;
esac

}


function ParamCheck()
{

grep "#" /etc/hosts > /etc/hosts_backup
echo "127.0.0.1       localhost" >> /etc/hosts_backup
echo "$NodeA_IP      $NodeA_HostName" >> /etc/hosts_backup
echo "$NodeB_IP      $NodeB_HostName" >> /etc/hosts_backup
mv /etc/hosts_backup /etc/hosts



if [ $LocalIP == "" ]
then
   echo "the interface "$INTERFACE" IP is not configured or doesn't exist"
   exit 2
fi

if [ $NodeA_HostName != $LocalNode ]
then
   if [ $NodeB_HostName != $LocalNode ] 
   then
   echo "local host name is $LocalNode, not the value in NodeA_HostName or NodeB_HostName"
   exit 2
   fi	
fi	


if [  $NodeA_IP != $LocalIP ]
then
   if [ $NodeB_IP != $LocalIP ] 
   then
   echo "local IP address is $LocalIP, not the value in NodeA_IP or NodeB_IP"
   exit 2
   fi	
fi	


if [ $NodeA_HostName == $LocalNode ]
then
IsNode1=1
else
IsNode1=0
fi

echo "Parameter Check passed"


}


function getISO()
{
if [ ! -d "ISO" ]; then
mkdir ISO
fi
MntMount=`df -k | grep mnt`
if [ "$MntMount" == ""  ]; then
mount $MountPoint  /mnt
fi

cd /mnt/sles$MajorV
if [ "$MinorV" != "" ];then

SLESISO=`ls -ltr | grep $MajorV | grep $MinorV | grep "x86_64" | grep Server | awk '{print $9}'`
SLESHAISO=`ls -ltr | grep $MajorV | grep $MinorV | grep "x86_64" | grep HA | grep -v GEO | awk '{print $9}'`


else

SLESISO=`ls -ltr | grep $MajorV | grep -v SP | grep "x86_64" | grep Server | awk '{print $9}'`
SLESHAISO=`ls -ltr | grep $MajorV | grep -v SP | grep "x86_64" | grep HA | grep -v GEO | awk '{print $9}'`

fi
if [ $SLESISO == "" ]
then 
   echo 'No sles$MajorV $MinorV ISO under 10.108.104.80:/home/wide_open/temp/sles-iso'
   exit 2
fi
if [ $SLESHAISO == "" ]
then 
   echo 'No sles$MajorV $MinorV HA ISO under 10.108.104.80:/home/wide_open/temp/sles-iso'
   exit 2
fi
}

######################copy the Server and HA ISO from NFS server##############################################

function copyISO()
{
echo "copying $SLESISO......"
cp /mnt/sles$MajorV/$SLESISO /root/ISO/
echo "copying $SLESHAISO......"
cp /mnt/sles$MajorV/$SLESHAISO /root/ISO/
}


##################zypper repository setting#####################################################################
function SetRepo()
{
echo "Setting zypper Repository ..."
zypper removerepo 1
zypper ar -c -t yast2 "iso:/?iso=/root/ISO/$SLESISO" "SLES$MajorV"
zypper ar -c -t yast2 "iso:/?iso=/root/ISO/$SLESHAISO" "SLES$MajorV HA"
zypper mr -r "SLES$MajorV"
zypper mr -r "SLES$MajorV HA"
echo "Set zypper repository as below"
zypper lr
echo "install HA add-on.."
zypper --non-interactive  install --auto-agree-with-licenses -t pattern ha_sles
}



##################Set NTP#############################################
function SetNTP()
{
echo "Set NTP......."
echo "server $NTPServer" >> /etc/ntp.conf
systemctl restart ntpd.service
systemctl status ntpd.service
chkconfig ntpd on
echo "NTP configured as below"
ntpq -p
}





function SetWatchDog()
{
echo "Setting watchdog.........."
modprobe softdog
grep softdog /etc/init.d/boot.local
if [  $? ]
then
   echo "modprobe softdog" >> /etc/init.d/boot.local
fi
}



function verifyLVM()
{
#  Lock_type=`grep "locking_type = " /etc/lvm/lvm.conf  | grep -v '#' | awk '{print $3}'`
#  use_lvmtad=`grep "use_lvmetad = " /etc/lvm/lvm.conf  | grep -v '#' | awk '{print $3}'`
#  if [  $Lock_type != 3 ]
#  then

#  sed -i -e 's/locking_type = 1/locking_type = 3/g' /etc/lvm/lvm.conf
#  fi
#    if [  $use_lvmtad != 0 ]
#  then

#  sed -i -e 's/use_lvmetad = 1/ use_lvmetad = 0/g' /etc/lvm/lvm.conf
lvmconf --enable-cluster
systemctl stop lvm2-lvmetad
systemctl disable lvm2-lvmetad
    
#  fi
  
}


function initCluster()
{

if [ $IsNode1 == "1" ]
then
ha-cluster-init -y -i $INTERFACE -s $SBD_DEVICE
else
ha-cluster-join -y -c $NodeA_IP
sleep 10s
fi

}



function addcLVMD()
{

if [ -f "/root/ISO/ServiceExist" ]
then 
    echo "please remove previous OCFS2/GFS2/NFS service first"
	exit 1
fi
lvmconf --enable-cluster
ssh $RemoteNode "lvmconf --enable-cluster"
crm configure primitive dlm ocf:pacemaker:controld op start interval=0 timeout=90 op stop interval=0 timeout=100 op monitor interval=60 timeout=60
crm configure primitive clvmd ocf:lvm2:clvmd op stop interval=0 timeout=100 op start interval=0 timeout=90 op monitor interval=20 timeout=20
crm configure  group base-group dlm clvmd
crm configure  clone base-clone base-group meta interleave=true target-role=Started
sleep 5s


}

function removecLVMD()
{

echo "stopping clvmd"
crm configure modgroup base-group remove clvmd
crm resource stop clvmd

sleep 5s
ResourceFlag=`crm status | grep 'clvmd' | grep -v '_0' |grep -v 'status'| grep -v '(target-role:Stopped) Stopped'`

while [ "$ResourceFlag" != "" ]
do
echo "wait clvmd to stop...."
sleep 5s
ResourceFlag=`crm status | grep 'clvmd' | grep -v '_0' |grep -v 'status'| grep -v '(target-role:Stopped) Stopped'`
done



echo "deleting clvmd"
crm configure delete clvmd



echo "stopping dlm"


crm resource stop dlm
ResourceFlag=`crm status | grep 'dlm' | grep -v '_0' |grep -v 'status'| grep -v '(target-role:Stopped) Stopped'`

while [ "$ResourceFlag" != "" ]
do
echo "wait dlm to stop...."
sleep 5s
ResourceFlag=`crm status | grep 'dlm' | grep -v '_0' |grep -v 'status'| grep -v '(target-role:Stopped) Stopped'`
done
sleep 5s
echo "deleting dlm"
crm configure delete dlm

}




function addOCFS2()
{

if [ -f "/root/ISO/ServiceExist" ]
then 
    echo "please remove previous OCFS2/NFS service first"
	exit 1
fi

#lvmconf --disable-cluster
#ssh $RemoteNode "lvmconf --disable-cluster"
#systemctl stop lvm2-lvmetad
#ssh $RemoteNode "systemctl stop lvm2-lvmetad"

pvcreate $DEV1 $DEV2
vgcreate -cy cluster_vg $DEV1 $DEV2
#lvcreate -ncluster_lv -l90%VG cluster_vg --config 'global {locking_type = 0}'
lvcreate -ncluster_lv -l90%VG cluster_vg
mkfs.ocfs2 -N 2 /dev/cluster_vg/cluster_lv 

crm configure  primitive cluster_vg LVM params volgrpname=cluster_vg op monitor interval=60 timeout=60
crm configure primitive ocfs2-1 Filesystem params device="/dev/cluster_vg/cluster_lv" directory="/ocfs2/clusterfs1" fstype=ocfs2 options=acl op monitor interval=20 timeout=40
crm configure modgroup base-group add cluster_vg
crm configure modgroup base-group add ocfs2-1
crm resource cleanup ocfs2-1
sleep 5s
crm status

touch /root/ISO/ServiceExist
scp /root/ISO/ServiceExist $RemoteNode:/root/ISO/

}


function removeOCFS2()
{
echo "removing OCFS2"
crm resource stop cluster_vg
ResourceFlag=`crm status | grep 'cluster_vg'`
StopFlag=`crm status | grep 'cluster_vg' | grep ') Stopped'`
while [[ $ResourceFlag != "" && $StopFlag == "" ]]
do
echo "wait cluster_vg to stop...."
sleep 5s
StopFlag=`crm status | grep 'cluster_vg'  | grep ') Stopped'`
done

crm resource stop ocfs2-1
StopFlag=`crm status | grep 'ocfs2-1' | grep ') Stopped' `
ResourceFlag=`crm status | grep 'ocfs2-1'`
while  [[ $ResourceFlag != "" && $StopFlag == "" ]]
do
echo "wait ocfs2-1 to stop"
sleep 5s
StopFlag=`crm status | grep 'ocfs2-1' | grep ') Stopped'`
done

crm configure modgroup base-group remove ocfs2-1
crm configure modgroup base-group remove cluster_vg

crm configure delete ocfs2-1
crm configure delete cluster_vg
vgchange -cn  cluster_vg

#vgchange -cn  cluster_vg --config 'global {locking_type = 0}'
lvremove cluster_vg/cluster_lv
vgremove cluster_vg
pvremove $DEV1 $DEV2

rm -rf /root/ISO/ServiceExist
ssh $RemoteNode "rm -rf  /root/ISO/ServiceExist"


}







function addGFS2()
{

if [ -f "/root/ISO/ServiceExist" ]
then 
    echo "please remove previous OCFS2/GFS2/NFS service first"
	exit 1
fi

echo "addGFS2"
pvcreate $DEV1 $DEV2
vgcreate -cy cluster_vg $DEV1 $DEV2
lvcreate -ncluster_lv -l100%VG cluster_vg
mkfs.gfs2 -t hacluster:mygfs2 -p lock_dlm -j 32 /dev/cluster_vg/cluster_lv

crm configure  primitive cluster_vg LVM params volgrpname=cluster_vg op monitor interval=60 timeout=60
crm configure  primitive gfs2-1 ocf:heartbeat:Filesystem params device=="/dev/cluster_vg/cluster_lv"  directory=""/ocfs2/clusterfs1" " fstype="gfs2" op monitor interval="20" timeout="40"
crm configure modgroup base-group add cluster_vg
crm configure modgroup base-group add gfs2-1
crm resource cleanup gfs2-1
sleep 5s
crm status

touch /root/ISO/ServiceExist
scp /root/ISO/ServiceExist $RemoteNode:/root/ISO/
}

function removeGFS2()
{
   echo "removeGFS2"
   echo "stopping GFS2-1"
crm resource stop cluster_vg
ResourceFlag=`crm status | grep 'cluster_vg'`
StopFlag=`crm status | grep 'cluster_vg' | grep ') Stopped'`
while [[ $ResourceFlag != "" && $StopFlag == "" ]]
do
echo "wait cluster_vg to stop...."
sleep 5s
StopFlag=`crm status | grep 'cluster_vg'  | grep ') Stopped'`
done

crm resource stop gfs2-1
StopFlag=`crm status | grep 'gfs2-1' | grep ') Stopped' `
ResourceFlag=`crm status | grep 'gfs2-1'`
while  [[ $ResourceFlag != "" && $StopFlag == "" ]]
do
echo "wait gfs2-1 to stop"
sleep 5s
StopFlag=`crm status | grep 'gfs2-1' | grep ') Stopped'`
done

crm configure modgroup base-group remove gfs2-1
crm configure modgroup base-group remove cluster_vg

crm configure delete gfs2-1
crm configure delete cluster_vg
vgchange -cn  cluster_vg

#vgchange -cn  cluster_vg --config 'global {locking_type = 0}'
lvremove cluster_vg/cluster_lv
vgremove cluster_vg
pvremove $DEV1 $DEV2
rm -rf /root/ISO/ServiceExist



}




function addNFS()
{
   echo "addingNFS"
   if [ -f "/root/ISO/ServiceExist" ]
then 
    echo "please remove previous OCFS2/GFS2/NFS service first"
	exit 1
fi
   
   lvmconf --enable-halvm --services --startstopservices   
#   ssh $RemoteNode "lvmconf --enable-halvm --services --startstopservices"
   sed -i -e 's/^volume_list = \[ \]//g' /etc/lvm/lvm.conf
   scp /etc/lvm/lvm.conf $RemoteNode:/etc/lvm/
   pvcreate $DEV1 $DEV2
   vgcreate nfs_vg $DEV1 $DEV2
   vgchange -ay nfs_vg
   lvcreate -nnfs_lv -l100%VG nfs_vg
   result=`lvs | grep nfs_vg`
   if [ "$result" == "" ];
   then 
      echo "create nfs_vg or nfs_lv from $DEV1 and $DEV2 failed, please have a check"
	  exit 1
	fi

    mkfs.ext4 /dev/nfs_vg/nfs_lv -F
    mkdir -p /nfsshare
	ssh $RemoteNode "mkdir -p /nfsshare"
	chmod 777 /nfsshare
	ssh $RemoteNode "chmod 777 /nfsshare"
    mount /dev/nfs_vg/nfs_lv /nfsshare
	mkdir -p /nfsshare/exports
        chmod 777 /nfsshare/exports
	mkdir -p /nfsshare/exports/export1
         chmod 777 /nfsshare/exports/export1
	umount /dev/nfs_vg/nfs_lv
    vgchange -an nfs_vg
	sed '/# volume_list = /a volume_list = [ ]' /etc/lvm/lvm.conf > /etc/lvm/lvm.conf_bak
	cp /etc/lvm/lvm.conf_bak /etc/lvm/lvm.conf
	scp /etc/lvm/lvm.conf $RemoteNode:/etc/lvm/
	sed -i -e 's/NFSV4LEASETIME=""/NFSV4LEASETIME="15"/g' /etc/sysconfig/nfs
	scp /etc/sysconfig/nfs $RemoteNode:/etc/sysconfig/
	systemctl restart nfs
	ssh $RemoteNode "systemctl restart nfs"
	sleep 5
	
	
	
crm configure primitive nfs_vg ocf:heartbeat:LVM params volgrpname="nfs_vg" exclusive="yes" op monitor interval="60" timeout="60"
crm configure group g-nfs nfs_vg

crm configure primitive nfsshare ocf:heartbeat:Filesystem params device=/dev/nfs_vg/nfs_lv directory=/nfsshare fstype=ext4 op monitor interval="10s"
crm configure modgroup g-nfs add nfsshare

crm configure primitive nfsserver  systemd:nfs-server  op monitor interval="30s"
crm configure modgroup g-nfs add nfsserver

crm configure primitive nfs_exportfs-root ocf:heartbeat:exportfs params  fsid="0" directory="/nfsshare/exports"  options="rw,crossmnt" clientspec="*" wait_for_leasetime_on_stop=true op monitor interval="30s"
crm configure primitive nfs_exportfs ocf:heartbeat:exportfs params  fsid="1" directory="/nfsshare/exports/export1"  options="rw,mountpoint" clientspec="*" wait_for_leasetime_on_stop=true op monitor interval="30s"
crm configure modgroup g-nfs add nfs_exportfs-root
crm configure modgroup g-nfs add nfs_exportfs


crm configure primitive vip_nfs ocf:heartbeat:IPaddr2 params ip=$NFS_IP cidr_netmask=24 op monitor interval=10 timeout=20
crm configure modgroup g-nfs add vip_nfs

touch /root/ISO/ServiceExist
scp /root/ISO/ServiceExist $RemoteNode:/root/ISO/

}


function removeNFS()
{
 echo "removing NFS"
crm resource stop g-nfs
sleep 5s
ResourceFlag=`crm status | grep 'vip_nfs\|nfs_exportfs\|nfs_exportfs-root\|nfsshare\|nfsserver\|nfs_vg' | grep -v '_0' |grep -v 'status'| grep -v '(target-role:Stopped) Stopped'`

while [ "$ResourceFlag" != "" ]
do
echo "wait g-nfs to stop...."
sleep 5s
ResourceFlag=`crm status | grep 'vip_nfs\|nfs_exportfs\|nfs_exportfs-root\|nfsshare\|nfsserver\|nfs_vg' | grep -v '_0' |grep -v 'status'| grep -v '(target-role:Stopped) Stopped'`
done

crm configure delete vip_nfs
crm configure delete nfs_exportfs
crm configure delete nfs_exportfs-root
crm configure delete nfsserver
crm configure delete nfsshare
crm configure delete nfs_vg

vgchange -cn  nfs_vg
lvremove nfs_vg/nfs_lv
vgremove nfs_vg
pvremove $DEV1 $DEV2

sed -i -e 's/^volume_list = \[ \]//g' /etc/lvm/lvm.conf
scp /etc/lvm/lvm.conf $RemoteNode:/etc/lvm/
rm -rf /root/ISO/ServiceExist
ssh $RemoteNode "rm -rf  /root/ISO/ServiceExist"
   
}

function changeStonith()
{
  echo "please input the new stonith device path:"
  read newStonith
  if [ ! -b $newStonith ]
  then 
       echo "this block device doesn't exist"
	   exit 1
  fi
  echo "sbd -d $newStonith -4 20 -1 10 create..."
  sbd -d $newStonith -4 20 -1 10 create &> /dev/null
  
  #sbd -d $newStonith dump &>/dev/null
  #ssh $RemoteNode "sbd -d $newStonith dump" &>/dev/null
  
sed -n '/SBD_DEVICE=/!p' /etc/sysconfig/sbd > /etc/sysconfig/sbd_back 
mv /etc/sysconfig/sbd_back /etc/sysconfig/sbd
echo "SBD_DEVICE='$newStonith'" >> /etc/sysconfig/sbd
  scp /etc/sysconfig/sbd $RemoteNode:/etc/sysconfig/sbd &> /dev/null
  newDevice=`grep SBD_DEVICE /etc/sysconfig/sbd | grep -v '#' `
  echo "$newDevice\n\n"
  echo "restart pacemaker on local node"
  systemctl restart pacemaker
  echo "restart pacemaker on Remote node"
  ssh $RemoteNode "systemctl restart pacemaker"
  echo "####################Note###################################################"
  echo "#run \"systemctl status sbd\" to check if the change works                #"
  echo "#you may have to reboot each host to make the new stonith devcie work     #"
  echo "####################Note###################################################"
#echo 'SBD_OPTS="-W"   ' >> /etc/sysconfig/sbd

  
#systemctl restart pacemaker
#ssh  $RemoteNode "systemctl restart pacemaker"






}



main;








































