#!/bin/bash

# All variables are saved as Environment Variables 


###
###  Fetch the current trusted devices with the use of F5 Rest API. This will be used in Stage1 & 3
###

echo "Retrieving the existing list of devices on 'trust_group'"
api_url="https://${primary_bigip}/mgmt/tm/cm/device-group/~Common~device_trust_group/devices"
http_status=$(curl -sk -u "admin":"$f5_password" -o "trust_group_devices.json" -w "%{http_code}" "$api_url")

# Check if the HTTP status code is 200
if [ "$http_status" -ne 200 ]; then
    echo "Failed to fetch API response from $api_url. HTTP Status: $http_status"
    exit 1
fi

# Extract the "names" from the API response
trust_group_devices=$(jq -r '.items[].name' "trust_group_devices.json")


###                                                     ###
###   -----------------------------------------------   ###
###   Stage 1 - Adding new devices to the TRUST Group   ###
###   -----------------------------------------------   ###
###                                                     ###


device_names="$bigip_03_name $bigip_04_name"      ## This list includes only the newly added devices


# Compare the names on the trust_group with the names we want to add. 
echo "Verify devices in the device_names list are already on the trust_group-device list. If not add them"
for device in $device_names; do
  if echo "$trust_group_devices" | grep -q "$device"; then
    echo "Device '$device' found in the API response."
  else
    echo "Device '$device' NOT found in the API response."

    #####  Add device to the trust-device list #######
    echo "Adding Device '$device' to the trust-group."
    api_url="https://$primary_bigip/mgmt/tm/cm/add-to-trust"
    http_status=$(curl -sk -u "admin":"$f5_password" --header 'Content-Type: application/json' --data '{"command":"run","name":"Root","caDevice":true,"device":"'$device'","deviceName":"'$device'","username":"admin","password":"'$f5_password'"}' -w "%{http_code}" -o "add-to-trust.json" "$api_url" )
    # Check if the HTTP status code is 200
    if [ "$http_status" -ne 200 ]; then
      echo "Failed to add '$device' to trust-group. HTTP Status: $http_status"
      echo "For more details open the file 'add-to-trust.json'"
      exit 1
    fi
    echo "Added '$device' Device Successfully to the trust-group."
    echo "Sleep for 5 seconds"
    sleep 5
  fi
done


###                                                                         ###
###   -------------------------------------------------------------------   ###
###   Stage 2 - Modifying the FailoverGroup to match the required devices   ###
###   -------------------------------------------------------------------   ###
###                                                                         ###


failover_group='{"devices": ["'$bigip_01_name'","'$bigip_02_name'","'$bigip_03_name'","'$bigip_04_name'"]}'



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
###   Stage 3 - Remove old devices from the TRUST Group (scaledown)   ###
###   -------------------------------------------------------------   ###
###                                                                   ###

device_names="$bigip_01_name $bigip_02_name $bigip_03_name $bigip_04_name"   ## This list includes the initial BIGIP-HA names (BIGIP01 and BIGIP02) along with the newly added devices


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

