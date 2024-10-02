#!/bin/bash

# All variables are saved as Environment Variables 


###
###  Fetch the current trusted devices with the use of F5 Rest API. This will be used in Stage1 & 3
###

api_url="https://${primary_bigip}/mgmt/tm/cm/device-group/~Common~device_trust_group/devices"
http_status=$(curl -sk -u "admin":"$f5_password" -o "trust_group_devices.json" -w "%{http_code}" "$api_url")

# Check if the HTTP status code is 200
if [ "$http_status" -ne 200 ]; then
    echo "Failed to fetch API response from $api_url. HTTP Status: $http_status"
    exit 1
fi

# Extract the "names" from the API response
trust_group_devices=$(jq -r '.items[].name' "trust_group_devices.json")



###                                                                         ###
###   -------------------------------------------------------------------   ###
###   Stage 1 - Modifying the FailoverGroup to initial HA devices           ###
###   -------------------------------------------------------------------   ###
###                                                                         ###


# Depending on the scale_out value we will determine which devices to add to the failover group
failover_group='{"devices": ["'$bigip_01_name'","'$bigip_02_name'"]}'


api_url="https://$primary_bigip/mgmt/tm/cm/device-group/failoverGroup"
http_status=$(curl -sk -u "admin":"$f5_password" --request PATCH  --header 'Content-Type: application/json' --data "$failover_group" -w "%{http_code}" -o "add-to-ha.json" "$api_url" )

# Check if the HTTP status code is 200
if [ "$http_status" -ne 200 ]; then
    echo "Failed to patch FailoverGroup with '$failover_group'. HTTP Status: $http_status"
    echo "For more details open the file 'add-to-ha.json'"
    exit 1
fi


###                                                                   ###
###   -------------------------------------------------------------   ###
###   Stage 2 - Remove old devices from the TRUST Group (scaledown)   ###
###   -------------------------------------------------------------   ###
###                                                                   ###

# Depending on the scale_out value we will determine which devices_names should be added to the list. 
device_names="$bigip_01_name $bigip_02_name"


# In case of a scale_down event we need to remove the names on the trust_group that are not requried. For that we will compare
# the existing names with the 'device_names' list and if a name exists on the trust group but is not on the 'device_names' list we will remove it.. 
echo "Verify that the devices on the trust_group-device list matvches the device_names list. If not remove them"
# Loop through each device name from the JSON
for name in $trust_group_devices; do
    if ! echo "$device_names" | grep -q "$name"; then
        echo "Device '$name' not found in device_names. Removing it from the trust group"
        api_url="https://$primary_bigip/mgmt/tm/cm/remove-from-trust"
        http_status=$(curl -sk -u "admin":"$f5_password" --header 'Content-Type: application/json' --data '{"command":"run","name":"Root","deviceName":"'$name'"}' -w "%{http_code}" -o "remove-from-trust.json" "$api_url" )
        # Check if the HTTP status code is 200
        if [ "$http_status" -ne 200 ]; then
          echo "Failed to remove '$name' from trust-group. HTTP Status: $http_status"
          echo "For more details open the file 'remove-from-trust.json'"
          exit 1
        fi
        echo "Removed '$name' Device Successfully from the trust-group."
        echo "Sleep for 5 seconds"
        sleep 5

    else
        echo "Device '$name' is present in device_names."
    fi
done

sleep 20
echo "Script Completed without any errors."

