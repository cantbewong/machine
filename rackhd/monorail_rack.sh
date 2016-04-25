#!/bin/bash
# monorail_rack
# script to deploy a development test enviorment.


##################
# INCLUDE CONFIG #
##################
SCRIPT_DIR=$(cd $(dirname $0) && pwd)
set -o allexport
source $SCRIPT_DIR/../config/monorail_rack.cfg
set +o allexport

############
# GET OPTS #
############

function usage {
  printf "\nusage: monorail_rack [-h]\n"
  printf "\t-h display usage\n\n"
  printf "\t customize deployment variables by editing:\n"
  printf "\t\t example/config/monorail_rack.cfg\n\n"
  exit
}


while getopts ":h" opt; do
  case $opt in
    h)
      usage
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
  esac
done


##########################
# DEPLOY MONORAIL SERVER #
##########################

# TODO: handle if we want to download static files and/or BMCs
#       For now assumed no downloading of dependicies...

echo "I'll set up monorail server now..."
vagrant up dev

######################
# DEPLOY PXE CLIENTS #
######################

if [ $PXE_COUNT ]
  then
    for (( i=1; i <= $PXE_COUNT; i++ ))
      do
        vmName="pxe-$i"
        if [[ ! -e $vmName.vdi ]]; then # check to see if PXE vm already exists
            echo "deploying pxe: $i"
            VBoxManage createvm --name $vmName --register;
            VBoxManage createhd --filename $vmName --size 8192;
            VBoxManage storagectl $vmName --name "SATA Controller" --add sata --controller IntelAHCI
            VBoxManage storageattach $vmName --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium $vmName.vdi
            VBoxManage modifyvm $vmName --ostype Ubuntu --boot1 net --memory 1024 --cpus 2;
            VBoxManage modifyvm $vmName --nic1 intnet --intnet1 closednet --nicpromisc1 allow-all;
            VBoxManage modifyvm $vmName --nictype1 82540EM --macaddress1 auto;
	          VBoxManage modifyvm $vmName --nic2 NAT;
            VBoxManage modifyvm $vmName --nictype2 82540EM --macaddress2 auto;
	          VBoxManage modifyvm $vmName --natpf2 "guestssh,tcp,,2$i2$i,,22";
	          VBoxManage modifyvm $vmName --ioapic off;
	          VBoxManage modifyvm $vmName --rtcuseutc on;
        fi
      done
fi

echo "starting the services"
echo "The RackHD documentation will be available shortly at http://localhost:9090/docs"
vagrant ssh dev -c "sudo nf start"