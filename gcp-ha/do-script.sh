#!/bin/bash

# Set variables
BIGIP_IP="$TF_VAR_bigip_ip"
URL="https://${TF_VAR_bigip_ip}/mgmt/shared/declarative-onboarding"
echo $URL
AUTH="$TF_VAR_username:$TF_VAR_password"
echo $AUTH
JSON_FILE="$TF_VAR_json_file"
echo $JSON_FILE
PREFIX="$TF_VAR_prefix"
echo $PREFIX

start_time=$(date +%s)  # Get the start time
echo "Sending Declaration"
echo $URL
echo $JSON_FILE
# Send initial request with basic authentication
HTTP_CODE=$(curl -ks --output ${PREFIX}-temp.json --write-out '%{http_code}' -u "$AUTH" --header 'Content-Type: application/json' --data @"$JSON_FILE" --request POST $URL)

if [[ ${HTTP_CODE} -ne 202 ]]; then
  echo "ERROR - ${HTTP_CODE}"
  echo "Deployment Failed"
  cat "${PREFIX}-temp.json"
  exit 1
else
  id=$(cat "${PREFIX}-temp.json" | jq -r '.id')
  echo "HTTP_CODE - ${HTTP_CODE}"
  echo "Deployment for ${PREFIX} has been accepted."
  echo "30 seconds sleep"
  sleep 3
  echo "Poll F5 BIGIP every 5 seconds to get the status of the DO jobID. The ID is $id"
  
  # Initialize the status
  status="RUNNING"
  # Initialize the loop counter
  count=1
  do_status='https://'${BIGIP_IP}'/mgmt/shared/declarative-onboarding/task/'$id
  echo "Getting into a Loop to check DO status"
  # Loop until the status is different than "RUNNING" or a timeout occurs
  while [ "$status" == "RUNNING" ] && [ $count -lt 15 ]; do
    echo "Sending Request #"$count;
    # Send the curl GET request to check the status of the policy creation
    response=$(curl -ks --output ${PREFIX}-status.json -u "$AUTH" $do_status)
    
    status=$(jq -r '.result.status' ${PREFIX}-status.json) # Extract the "status" and "id" from the JSON response using jq
    code=$(jq -r '.result.code' ${PREFIX}-status.json) # Extract the "status" and "id" from the JSON response using jq

    echo "Current status -  $status" # Print the current status
    #echo "Retry ($count)"
    let "count++"   # Increment the loop counter
    echo "Sleep for 10 sec"
    if [ "$status" == "RUNNING" ]; then
      sleep 10    # Sleep for a few seconds before checking again
    fi
  done
  
  # When the loop exits, the status is "COMPLETED" or a timeout occurred
  if [ "$status" != "OK" ]; then
    echo "An Error occured or the proccess timeout after 15 retries."
    echo $response | jq .
    # You can add additional error handling here if needed
  else
    echo "DO Completed successfully"
    end_time=$(date +%s) # Get the end time
    elapsed_time=$((end_time - start_time)) # Calculate the elapsed time
    echo "Time elapsed: $elapsed_time seconds" # Print the elapsed time
  fi
fi