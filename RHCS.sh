#!/bin/bash
#================================================================
# HEADER
#================================================================
#%title           :RHCS.sh
#%description     :This script will install and configure GFS2 and NFS on RHCS.
#%author                 : He YI
#%date            :2016-11-15
#%version         :3.0
#%usage          : ./RHCS.sh OPTION
#% OPTIONS
#%    install,                     install the RHCS
#%    addGFS2,                     add GFS2 as cluster resource
#%    removeGFS2,                  remove GFS2 resource
#%    addNFS,                      add NFS as cluster resource
#%    removeNFS,                   remove NFS as cluster resource
#%    changeStonith,               change stonith sbd device from one to another
#%    help                           Print this help
#%    version                          Print script information
#================================================================
#  HISTORY
#     2016/11/18 : Script creation, including install and gfs2 config
#     2016/11/22 : add NFS choice
#     2017/7/22 adding 2 more GFS2 services
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
echo  "Usage: ./RHCS.sh option"
echo "OPTION could be:"
echo "install,                     install the RHCS "
echo "addGFS2,                     add GFS2 as cluster resource"
echo "removeGFS2,                  remove GFS2 as cluster resource"
echo "addNFS,                      add NFS as cluster resource"
echo "removeNFS,                   remove NFS as cluster resource"
#echo "changeStonith,               change stonith sbd device from one to another"
echo "help                         Print this help"
echo "version                      Print script version"
}




#======================define below parameters before running script========================

NodeA_IP="10.228.100.40"
NodeB_IP="10.228.100.42"
NodeA_HostName="e2e-4-10040"
NodeB_HostName="e2e-4-10042"
INTERFACE="em3"

DEV1="/dev/mapper/mpatha"
DEV2="/dev/mapper/mpathb"
DEV3="/dev/mapper/mpathm"
DEV4="/dev/mapper/mpathn"
DEV5="/dev/mapper/mpatho"
DEV6="/dev/mapper/mpathp"
FENCE_DEV1="$DEV1,$DEV2,$DEV3,$DEV4,$DEV5,$DEV6"
echo "$DEV1,$DEV2,$DEV3,$DEV4,$DEV5,$DEV6" > device_list

MajorV=7
MinorV=4



NFS_IP="10.228.100.103"
YumSever="10.228.104.189"
NTPServer="10.106.16.22"
#=============================================================================================

LocalNode=`hostname`
LocalIP=` ip addr show dev $INTERFACE  |grep inet | grep -v "inet6" |awk '{print $2}' | awk -F / '{print $1}'`
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


GFS2_2=1
GFS2_3=1


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

      if [ ! -b $DEV3 ]
  then
       echo "block device $DEV3 doesn't exist, the second GFS2 won't be generated"
       GFS2_2=0
  fi

    if [ ! -b $DEV4 ]
  then
       echo "block device $DEV4 doesn't exist, the second GFS2 won't be generated"
       GFS2_2=0
  fi

      if [ ! -b $DEV5 ]
  then
       echo "block device $DEV5 doesn't exist, the third GFS2 won't be generated"
       GFS2_3=0
  fi

    if [ ! -b $DEV6 ]
  then
       echo "block device $DEV6 doesn't exist, the third GFS2 won't be generated"
       GFS2_3=0
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
                hostsUpdate;
                SetRepo1;
                sshSharekeyG;
                ParamCheck2;
                SetRepo2;
                SetNTP;
                passwdHA;
                startPM;
                authCluster;
                initCluster;
        addcLVMD;
                addGFS2;
                exit 0;
        ;;
      "addGFS2")
            addcLVMD;
        addGFS2;
                exit 0;
        ;;
      "removeGFS2")
            removeGFS2;
                sleep 5s
                removecLVMD;
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


function hostsUpdate()
{

grep "#" /etc/hosts > /etc/hosts_backup
echo "127.0.0.1       localhost" >> /etc/hosts_backup
echo "$NodeA_IP      $NodeA_HostName" >> /etc/hosts_backup
echo "$NodeB_IP      $NodeB_HostName" >> /etc/hosts_backup
mv /etc/hosts_backup /etc/hosts


}


function ParamCheck()
{

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

ping $NodeB_IP -c 1
if [ "$?" != "0" ]
then
   echo "$NodeB_IP is not pingable, please check your IP address"
   exit 1
fi

echo "Parameter Check passed"


}




##################zypper repository setting#####################################################################
function SetRepo1()
{
echo "Setting yum Repository ..."

echo "[rhel$MajorV$MinorV-Base]" >> /etc/yum.conf
echo "name=rhel$MajorV$MinorV-Base" >> /etc/yum.conf
echo "baseurl=http://$YumSever/OS/RHEL$MajorV$MinorV/" >> /etc/yum.conf
echo "enabled=1" >> /etc/yum.conf
echo "gpgcheck=0" >> /etc/yum.conf

echo "[rhel$MajorV$MinorV-HA]" >> /etc/yum.conf
echo "name=rhel$MajorV$MinorV-HA" >> /etc/yum.conf
echo "baseurl=http://$YumSever/OS/RHEL$MajorV$MinorV/addons/HighAvailability" >> /etc/yum.conf
echo "enabled=1">> /etc/yum.conf
echo "gpgcheck=0" >> /etc/yum.conf

echo "[rhel$MajorV$MinorV-ReS]" >> /etc/yum.conf
echo "name=rhel$MajorV$Minor-VRes" >> /etc/yum.conf
echo "baseurl=http://$YumSever/OS/RHEL$MajorV$MinorV/addons/ResilientStorage" >> /etc/yum.conf
echo "enabled=1" >> /etc/yum.conf
echo "gpgcheck=0" >> /etc/yum.conf

yum clean all

echo "Set yum repository as below"
yum repolist



echo "install HA add-on.."
yum install -y expect
yum install -y ntp
yum install -y nfs-utils
yum install -y pcs fence-agents-all fence-virt
yum install -y lvm2-cluster  gfs2-utils

}



function sshSharekeyG()
{
cd /root/
echo '#!/usr/bin/expect' > sshSharekey.sh
if [ ! -f /root/.ssh/id_rsa ];
then
{
echo 'spawn ssh-keygen -t rsa' >> sshSharekey.sh
echo 'expect "Enter file in which to save the key (/root/.ssh/id_rsa):"' >> sshSharekey.sh
echo "send \"\r\"" >> sshSharekey.sh
echo 'expect "Enter passphrase (empty for no passphrase):"' >> sshSharekey.sh
echo "send \"\r\"" >> sshSharekey.sh
echo "expect \"Enter same passphrase again:\"" >> sshSharekey.sh
echo "send \"\r\"" >> sshSharekey.sh
echo "expect \"randomart image\"" >> sshSharekey.sh
echo "send \"\r\"" >> sshSharekey.sh
echo "expect eof" >> sshSharekey.sh
}
fi

echo "spawn ssh-copy-id -i /root/.ssh/id_rsa.pub $RemoteNode" >> sshSharekey.sh
echo "expect \"assword:\"" >> sshSharekey.sh
echo 'send "#1Danger0us\r"' >> sshSharekey.sh
echo "expect eof" >> sshSharekey.sh

grep "StrictHostKeyChecking no" /etc/ssh/ssh_config &>/dev/null
if [ ! -z $? ];
then
{
echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config
}
fi
chmod 755 /root/sshSharekey.sh
#cat sshSharekey.sh
expect /root/sshSharekey.sh

}


function ParamCheck2()
{

scp /etc/hosts $RemoteNode:/etc/


}
function SetRepo2()
{
echo "Setting yum Repository on $RemoteNode"
scp /etc/yum.conf $RemoteNode:/etc/yum.conf

ssh $RemoteNode "yum clean all"

echo "Set yum repository as below"
ssh $RemoteNode "yum repolist"



echo "install HA add-on on $RemoteNode"
ssh $RemoteNode "yum install -y expect"
ssh $RemoteNode "yum install -y ntp"
ssh $RemoteNode "yum install -y nfs-utilss"
ssh $RemoteNode "yum install -y pcs fence-agents-all fence-virt"
ssh $RemoteNode "yum install -y lvm2-cluster  gfs2-utils"

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

scp /etc/ntp.conf $RemoteNode:/etc/
echo "Set NTP on $RemoteNode"
ssh $RemoteNode "systemctl restart ntpd.service"
ssh $RemoteNode "systemctl status ntpd.service"
ssh $RemoteNode "chkconfig ntpd on"
echo "NTP configured as below"
ssh $RemoteNode "ntpq -p"

}


function passwdHA()
{
echo '#!/usr/bin/expect' > passwd.sh

echo 'spawn passwd hacluster' >> passwd.sh
echo 'expect "New password:"' >> passwd.sh
echo 'send "#1Danger0us\r"' >> passwd.sh
echo 'expect "Retype new password:"' >> passwd.sh
echo 'send "#1Danger0us\r"' >> passwd.sh
echo 'expect "all authentication tokens updated successfully"' >> passwd.sh


chmod 755 passwd.sh
expect passwd.sh

scp passwd.sh $RemoteNode:/root/
ssh $RemoteNode "expect passwd.sh"

}


function startPM()
{
   systemctl  stop firewalld.service
   systemctl disable firewalld.service
   ssh $RemoteNode "systemctl  stop firewalld.service"
   ssh $RemoteNode "systemctl disable firewalld.service"
   systemctl  start pcsd.service
   systemctl enable pcsd.service
   ssh $RemoteNode " systemctl  start pcsd.service"
   ssh $RemoteNode "systemctl enable pcsd.service"



}


function authCluster()

{
echo '#!/usr/bin/expect' > authCluster.sh

echo "spawn pcs cluster auth $NodeA_HostName $NodeB_HostName" >> authCluster.sh
echo 'expect "Username:"' >> authCluster.sh
echo 'send "hacluster\r"' >> authCluster.sh
echo 'expect "Password:"' >> authCluster.sh
echo 'send "#1Danger0us\r"' >> authCluster.sh
echo 'expect "Authorized"' >> authCluster.sh

chmod 755 authCluster.sh
expect authCluster.sh


}



function initCluster()
{

   pcs cluster setup --start  --name RHCS  $NodeA_HostName $NodeB_HostName --force
   pcs cluster enable --all
   ssh $RemoteNode "pcs cluster enable --all"
   pcs cluster status
   sleep 20
   pcs stonith  create  emc_fence  fence_scsi  devices="$FENCE_DEV1"   pcmk_host_list="$NodeA_HostName,$NodeB_HostName" pcmk_monitor_action="metadata" pcmk_host_check="static-list"  meta provides="unfencing"
   pcs cluster status


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






function addcLVMD()
{

if [ -f "/root/ServiceExist" ]
then
    echo "please remove previous OCFS2/GFS2/NFS service first"
        exit 1
fi
lvmconf --enable-cluster
ssh $RemoteNode "lvmconf --enable-cluster"
systemctl stop lvm2-lvmetad
ssh $RemoteNode "systemctl stop lvm2-lvmetad"

sleep 2s

pcs property set no-quorum-policy=freeze
pcs resource create dlm ocf:pacemaker:controld op monitor interval=30s on-fail=fence clone interleave=true ordered=true
pcs resource create clvmd ocf:heartbeat:clvm op monitor interval=30s on-fail=fence clone interleave=true ordered=true
pcs constraint order start dlm-clone then clvmd-clone
pcs constraint colocation add clvmd-clone with dlm-clone

sleep 5s
ResourceFlag=`pcs status | grep -A 1 clvmd | tail -1| awk -F : '{print $1}' | grep Started`

while [ "$ResourceFlag" == "" ]
do
echo "wait clvmd to start...."
sleep 5s
ResourceFlag=`pcs status | grep -A 1 clvmd | tail -1| awk -F : '{print $1}' | grep Started`

done


}

function removecLVMD()
{



echo "deleting clvmd"
pcs resource delete clvmd
echo "delete dlm"
pcs resource delete dlm





}




function addGFS2()
{

if [ -f "/root/ServiceExist" ]
then
    echo "please remove previous GFS2/NFS service first"
        exit 1
fi

#lvmconf --disable-cluster
#ssh $RemoteNode "lvmconf --disable-cluster"
#systemctl stop lvm2-lvmetad
#ssh $RemoteNode "systemctl stop lvm2-lvmetad"

pcs status
pvcreate $DEV1 $DEV2
vgcreate -cy -Ay cluster_vg_1 $DEV1 $DEV2
sleep 5
#lvcreate -ncluster_lv -l90%VG cluster_vg --config 'global {locking_type = 0}'
lvcreate -W n -ncluster_lv -l100%VG cluster_vg_1
echo "mkfs.gfs2 /dev/cluster_vg_1/cluster_lv_1..."
mkfs.gfs2  -j2 -p lock_dlm -t RHCS:gfs2_1 /dev/cluster_vg_1/cluster_lv -o align=0

echo "creating gfs resource..."
pcs resource create clusterfs1 Filesystem device="/dev/cluster_vg_1/cluster_lv" directory="/GFS2_1" fstype="gfs2" "options=noatime" op monitor interval=10s on-fail=fence clone interleave=true
pcs constraint colocation add clusterfs1-clone with clvmd-clone
pcs constraint order start clvmd-clone then clusterfs1-clone

if [ $GFS2_2 == 1 ]
then

pvcreate $DEV3 $DEV4
vgcreate -cy -Ay cluster_vg_2 $DEV3 $DEV4
#lvcreate -ncluster_lv -l90%VG cluster_vg --config 'global {locking_type = 0}'
lvcreate -W n -ncluster_lv -l100%VG cluster_vg_2
sleep 5
echo "mkfs.gfs2 /dev/cluster_vg_2/cluster_lv..."
mkfs.gfs2  -j2 -p lock_dlm -t RHCS:gfs2_2 /dev/cluster_vg_2/cluster_lv -o align=0

echo "creating the second gfs2 resource..."
pcs resource create clusterfs2 Filesystem device="/dev/cluster_vg_2/cluster_lv" directory="/GFS2_2" fstype="gfs2" "options=noatime" op monitor interval=10s on-fail=fence clone interleave=true
pcs constraint colocation add clusterfs2-clone with clvmd-clone
pcs constraint order start clvmd-clone then clusterfs2-clone
touch /root/GFS2Exist
scp /root/GFS2Exist $RemoteNode:/root/

fi


if [ $GFS2_3 == 1 ]
then

pvcreate $DEV5 $DEV6
vgcreate -cy -Ay cluster_vg_3 $DEV5 $DEV6
#lvcreate -ncluster_lv -l90%VG cluster_vg --config 'global {locking_type = 0}'
lvcreate -W n -ncluster_lv -l100%VG cluster_vg_3
sleep 5
echo "mkfs.gfs2 /dev/cluster_vg_3/cluster_lv..."
mkfs.gfs2  -j2 -p lock_dlm -t RHCS:gfs2_3 /dev/cluster_vg_3/cluster_lv -o align=0

echo "creating the third gfs resource..."
pcs resource create clusterfs3 Filesystem device="/dev/cluster_vg_3/cluster_lv" directory="/GFS2_3" fstype="gfs2" "options=noatime" op monitor interval=10s on-fail=fence clone interleave=true

pcs constraint colocation add clusterfs3-clone with clvmd-clone
pcs constraint order start clvmd-clone then clusterfs3-clone
touch /root/GFS3Exist
scp /root/GFS3Exist $RemoteNode:/root/

fi




sleep 5s
pcs status

touch /root/ServiceExist
scp /root/ServiceExist $RemoteNode:/root/

}


function removeGFS2()
{
echo "removing GFS2"
pcs resource delete clusterfs1

vgchange -cn  cluster_vg_1 --config 'global {locking_type = 0}'
lvremove /dev/cluster_vg_1/cluster_lv -f
vgremove cluster_vg_1
pvremove $DEV1 $DEV2

if [ -f /root/GFS2Exist ];
then
pcs resource delete clusterfs2
vgchange -cn  cluster_vg_2 --config 'global {locking_type = 0}'
lvremove /dev/cluster_vg_2/cluster_lv -f
vgremove cluster_vg_2
pvremove $DEV3 $DEV4
rm -rf /root/GFS2Exist
ssh $RemoteNode "rm -rf  /root/GFS2Exist"

fi


if [ -f /root/GFS3Exist ];
then
pcs resource delete clusterfs3
vgchange -cn  cluster_vg_3 --config 'global {locking_type = 0}'
lvremove /dev/cluster_vg_3/cluster_lv -f
vgremove cluster_vg_3
pvremove $DEV5 $DEV6
rm -rf /root/GFS3Exist
ssh $RemoteNode "rm -rf  /root/GFS3Exist"

fi

rm -rf /root/ServiceExist
ssh $RemoteNode "rm -rf  /root/ServiceExist"


}






function addNFSnoLVM()
{
   echo "addingNFS"
   if [ -f "/root/ServiceExist" ]
then
    echo "please remove previous OCFS2/GFS2/NFS service first"
        exit 1
fi



    mkfs.ext4 $DEV7 -F
    mkdir -p /nfsshare
        ssh $RemoteNode "mkdir -p /nfsshare"
        chmod 777 /nfsshare
        ssh $RemoteNode "chmod 777 /nfsshare"
    mount $DEV7 /nfsshare
        mkdir -p /nfsshare/exports
    chmod 777 /nfsshare/exports
        mkdir -p /nfsshare/exports/export1
    chmod 777 /nfsshare/exports/export1
        umount $DEV7


        systemctl enable rpcbind.socket
        systemctl restart rpcbind.service
        ssh $RemoteNode "systemctl enable rpcbind.socket"
    ssh $RemoteNode "systemctl restart rpcbind.service"

        pcs resource create nfsshare Filesystem device=$DEV7 directory=/nfsshare fstype=ext4 --group nfsgroup
        pcs resource create nfs-daemon nfsserver nfs_shared_infodir=/nfsshare/nfsinfo nfs_no_notify=true --group nfsgroup
        pcs resource create nfs_exportfs-root exportfs clientspec="*"   options=rw,sync,no_root_squash directory=/nfsshare/exports fsid=0 --group nfsgroup
    pcs resource create nfs_exportfs exportfs clientspec="*" options=rw,sync,no_root_squash directory=/nfsshare/exports/export1 fsid=1 --group nfsgroup
    pcs resource create vip_nfs IPaddr2 ip=$NFS_IP cidr_netmask=24 --group nfsgroup
    pcs resource create nfs-notify nfsnotify source_host=$NFS_IP --group nfsgroup





touch /root/ServiceExist
scp /root//ServiceExist $RemoteNode:/root/

}






function addNFS()
{
   echo "addingNFS"
   if [ -f "/root/ServiceExist" ]
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
   lvcreate -W n -nnfs_lv -l100%VG nfs_vg
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
        root_volume=`vgs --noheadings -o vg_name | grep -v nfs_vg | awk '{print $1}'`
        cp /etc/lvm/lvm.conf /etc/lvm/lvm.withoutVolumelist
                sed "/activation "{"/a volume_list = [ \"$root_volume\" ]" /etc/lvm/lvm.conf > /etc/lvm/lvm.conf_bak
        cp /etc/lvm/lvm.conf_bak /etc/lvm/lvm.conf
        root_volume2=`ssh $RemoteNode "vgs --noheadings -o vg_name | grep -v nfs_vg " | awk '{print $1}'`
        sed "/activation "{"/a volume_list = [ \"$root_volume2\" ]" /etc/lvm/lvm.withoutVolumelist > /etc/lvm/lvm.conf_bak2
        scp /etc/lvm/lvm.conf_bak2 $RemoteNode:/etc/lvm/lvm.conf

#       sed -i -e 's/NFSV4LEASETIME=""/NFSV4LEASETIME="15"/g' /etc/sysconfig/nfs
#       scp /etc/sysconfig/nfs $RemoteNode:/etc/sysconfig/
#       systemctl restart nfs
#       ssh $RemoteNode "systemctl restart nfs"
        sleep 5

        #dracut -H -f /boot/initramfs-$(uname -r).img $(uname -r)

        #ssh $RemoteNode 'dracut -H -f /boot/initramfs-$(uname -r).img $(uname -r)'
        systemctl enable rpcbind.socket
        systemctl restart rpcbind.service
        ssh $RemoteNode "systemctl enable rpcbind.socket"
    ssh $RemoteNode "systemctl restart rpcbind.service"
        pcs resource create nfs_vg_resource  LVM volgrpname=nfs_vg exclusive=true --group nfsgroup
        pcs resource create nfsshare Filesystem device=/dev/nfs_vg/nfs_lv directory=/nfsshare fstype=ext4 --group nfsgroup
        pcs resource create nfs-daemon nfsserver nfs_shared_infodir=/nfsshare/nfsinfo nfs_no_notify=true --group nfsgroup
        pcs resource create nfs_exportfs-root exportfs clientspec="*"   options=rw,sync,no_root_squash directory=/nfsshare/exports fsid=0 --group nfsgroup
    pcs resource create nfs_exportfs exportfs clientspec="*" options=rw,sync,no_root_squash directory=/nfsshare/exports/export1 fsid=1 --group nfsgroup
    pcs resource create vip_nfs IPaddr2 ip=$NFS_IP cidr_netmask=24 --group nfsgroup
    pcs resource create nfs-notify nfsnotify source_host=$NFS_IP --group nfsgroup





touch /root/ServiceExist
scp /root//ServiceExist $RemoteNode:/root/

}


function removeNFS()
{
 echo "removing NFS group"
pcs resource delete nfsgroup


vgchange -cn  nfs_vg
lvremove nfs_vg/nfs_lv
vgremove nfs_vg
pvremove $DEV1 $DEV2

grep -v  "^volume_list" /etc/lvm/lvm.conf > /etc/lvm/lvm.conf_bak
mv /etc/lvm/lvm.conf_bak /etc/lvm/lvm.conf
scp /etc/lvm/lvm.conf $RemoteNode:/etc/lvm/

        #dracut -H -f /boot/initramfs-$(uname -r).img $(uname -r)

        #ssh $RemoteNode 'dracut -H -f /boot/initramfs-$(uname -r).img $(uname -r)'

rm -rf /root/ServiceExist
ssh $RemoteNode "rm -rf  /root/ServiceExist"

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






