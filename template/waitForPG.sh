#!/bin/bash

# Copyright © 2024, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

function echolog {
  echo $(date +"[%Y-%m-%d %H:%M:%S]") "$*" | tee -a $LOGFILE
}

LOGFILE="${AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY}/waitForPG_$(date +"%Y%m%d%H%M%S").log"
echolog "STARTING waitForPG script ..."


echolog PG_RG=$PG_RG
echolog PG_Name=$PG_Name
echolog SUBSCRIPTION_ID=$SUBSCRIPTION_ID

pollInterval=10
maxDurationInSeconds=2400

start_datetime=$(date +%s)
while true
do
    if [ "$(date +%s)" -gt "$(($start_datetime + ${maxDurationInSeconds}))" ]
    then
        echolog "ERROR - It takes too much time to see the PG server $PG_Name either created or updated. Aborting..."
        exit 1
    fi

    TMP=$(hostname)
    echolog "$TMP"
    JSON=$(az account show)
    echolog "$JSON"

    echolog az postgres flexible-server show --resource-group $PG_RG --name $PG_Name --subscription $SUBSCRIPTION_ID
    az postgres flexible-server show --resource-group $PG_RG --name $PG_Name --subscription $SUBSCRIPTION_ID
    PG_JSON=$(az postgres flexible-server show --resource-group $PG_RG --name $PG_Name  --subscription $SUBSCRIPTION_ID)
    echolog "$PG_JSON"

    if az postgres flexible-server show --resource-group $PG_RG --name $PG_Name --subscription $SUBSCRIPTION_ID  > /dev/null 2>&1
    then 
        echolog "PG server $PG_Name exists. Checking if it's running..."
        PG_JSON=$(az postgres flexible-server show --resource-group $PG_RG --name $PG_Name  --subscription $SUBSCRIPTION_ID | jq -r ".")
        PG_STATE=$(echo "$PG_JSON" | jq -r ".state")
        if [ "$PG_STATE" == "Ready" ]
        then   
            echolog "PG server $PG_Name is ready. Exit loop..."
            break
        fi
    else 
        echolog "PG server $PG_Name does not exist (yet). Sleeping..."
        sleep $pollInterval
    fi
done
