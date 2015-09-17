#!/bin/bash
#
# lib/cinder_backends/bdd
# Configure the BlockDeviceDriver backend

# Enable with:
#
#   CINDER_ENABLED_BACKENDS+=,bdd:<volume-type-name>

# Dependencies:
#
# - ``functions`` file
# - ``cinder`` configurations

# DATA_DIR
# CINDER_BLOCK_DEVICES
# CINDER_BDD_BACKING_FILE_NAME
# CINDER_BDD_DEVICES_COUNT
# CINDER_BDD_DEVICES_SIZE
# CINDER_CONF

# configure_cinder_backend_bdd - Configure Cinder for BlockDeviceDriver backends
# cleanup_cinder_backend_bdd - Clean created files, devices, etc

# Save trace setting
BDD_XTRACE=$(set +o | grep xtrace)
set +o xtrace

CINDER_BDD_BACKING_FILE_NAME=${BDD_BACKING_FILE_NAME:-bdd-backing-file}
CINDER_BDD_DEVICES=${CINDER_BDD_DEVICES:-default}
CINDER_BDD_DEVICES_COUNT=${CINDER_BDD_DEVICES_COUNT:-4}
CINDER_BDD_DEVICES_SIZE=${CINDER_BDD_DEVICES_SIZE:-4100M}

function _init_cinder_bdd_device {
    local backing_file=$DATA_DIR/$CINDER_BDD_BACKING_FILE_NAME-$1
    [[ -f $backing_file ]] || truncate -s $CINDER_BDD_DEVICES_SIZE $backing_file
    echo `sudo losetup -f --show $backing_file`
}

function _init_cinder_bdd_devices {
    local idx=0
    CINDER_BDD_DEVICES=""
    while [ $idx -lt $CINDER_BDD_DEVICES_COUNT ]; do
        local dev_name=`_init_cinder_bdd_device $idx`
        CINDER_BDD_DEVICES=$CINDER_BDD_DEVICES$dev_name,
        let idx=idx+1
    done
    CINDER_BDD_DEVICES=${CINDER_BDD_DEVICES%?}
}

function _cleanup_cinder_bdd_device {
    local idx=$1
    local backing_file=$DATA_DIR/$CINDER_BDD_BACKING_FILE_NAME-$idx
    if [[ -n "$backing_file" ]] && [[ -e "$backing_file" ]]; then
        local vg_dev=$(sudo losetup -j $backing_file | awk -F':' '/'$CINDER_BDD_BACKING_FILE_NAME-$idx'/ { print $1}')
        sudo losetup -d $vg_dev
        rm -f $backing_file
    fi
}

# cleanup_cinder_backend_bdd - Clean created files, devices, etc
function cleanup_cinder_backend_bdd {
    local idx=0
    while [ $idx -lt $CINDER_BDD_DEVICES_COUNT ]; do
        _cleanup_cinder_bdd_device $idx
        let idx=idx+1
    done
}

# configure_cinder_backend_bdd - Set config files, create data dirs, etc
function configure_cinder_backend_bdd {
    local be_name=$1

    if [ "$CINDER_BDD_DEVICES" = "default" ]; then
        _init_cinder_bdd_devices
    fi

    iniset $CINDER_CONF $be_name volume_backend_name $be_name
    iniset $CINDER_CONF $be_name volume_driver "cinder.volume.drivers.block_device.BlockDeviceDriver"
    iniset $CINDER_CONF $be_name available_devices $CINDER_BDD_DEVICES
}

# Restore xtrace
$BDD_XTRACE

# Local variables:
# mode: shell-script
# End:
