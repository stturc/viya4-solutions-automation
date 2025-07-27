#!/bin/bash

set -euo pipefail

managed_rg="$1"
subscription_id="$2"
pollInterval="$3"
maxDurationInSeconds="$4"

maxDurationInSecondsCheck=240
start_datetime=$(date +%s)
while true
do
    if [ "$(date +%s)" -gt "$(($start_datetime + ${maxDurationInSecondsCheck}))" ]
    then
        echo "ERROR - It takes too much time to get the list of associated deployments. Aborting..." 
        echo "⏰ Timeout reached"
        echo "status=TIMEOUT" >> "$GITHUB_OUTPUT"
        exit 1
    fi

    echo "[$(date)] Checking for deployment scripts in resource group: $managed_rg"
    if ! az deployment-scripts list -g ${managed_rg} --subscription ${subscription_id} > /dev/null
    then
        echo "Sleep $pollInterval seconds"
        sleep $pollInterval
    else
        break
    fi
done

DEPLOYMENT_SCRIPTS_JSON=$(az deployment-scripts list -g ${managed_rg} --subscription ${subscription_id})
DEPLOYMENT_SCRIPTS_JSON_LENGTH=$(echo "$DEPLOYMENT_SCRIPTS_JSON" | jq -r "length")

for ix_tmp in $(seq 1 $DEPLOYMENT_SCRIPTS_JSON_LENGTH)     
do
    ix=$((ix_tmp-1))
    DEPLOYMENT_SCRIPT_JSON=$(echo "$DEPLOYMENT_SCRIPTS_JSON" | jq -r ".[$ix]")
    DEPLOYMENT_SCRIPT_NAME=$(echo "$DEPLOYMENT_SCRIPT_JSON" | jq -r ".name")

    echo 
    echo "********************************************"
    echo "Monitoring status of deployment script $DEPLOYMENT_SCRIPT_NAME"
    echo "********************************************"

    rm -f oldlog.txt
    touch oldlog.txt
    
    start_datetime=$(date +%s)
    while true
    do
        if [ "$(date +%s)" -gt "$(($start_datetime + ${maxDurationInSeconds}))" ]
        then
            echo "ERROR - It takes too much time to complete the managed app execution. Aborting..." 
            echo "⏰ Timeout reached"
            echo "status=TIMEOUT" >> "$GITHUB_OUTPUT"
            exit 1
        fi
        
        #We need to get the updated version of the JSON
        DEPLOYMENT_SCRIPTS_JSON=$(az deployment-scripts list -g ${managed_rg} --subscription ${subscription_id})
        DEPLOYMENT_SCRIPT_JSON=$(echo "$DEPLOYMENT_SCRIPTS_JSON" | jq -r ".[$ix]")
        DEPLOYMENT_SCRIPT_PROVISIONINGSTATE=$(echo "$DEPLOYMENT_SCRIPT_JSON" | jq -r ".provisioningState")
        DEPLOYMENT_SCRIPT_NAME=$(echo "$DEPLOYMENT_SCRIPT_JSON" | jq -r ".name")
        DEPLOYMENT_SCRIPT_STATUS_ERROR=$(echo "$DEPLOYMENT_SCRIPT_JSON" | jq -r ".status.error")
        DEPLOYMENT_SCRIPT_STATUS_ENDTIME=$(echo "$DEPLOYMENT_SCRIPT_JSON" | jq -r ".status.endTime")
        
        if [ "$DEPLOYMENT_SCRIPT_PROVISIONINGSTATE" == "Failed" ]
        then
            echo "ERROR - An error occured with the deployment $DEPLOYMENT_SCRIPT_NAME. Aborting..."
            echo "❌ Deployment failed"
            echo "status=FAILED" >> "$GITHUB_OUTPUT"
            exit 1
        else
            if [ "$DEPLOYMENT_SCRIPT_STATUS_ENDTIME" == "null" ]
            then
                DEPLOYMENT_SCRIPT_STATUS_STORAGE_ACCOUNT_ID=$(echo "$DEPLOYMENT_SCRIPT_JSON" | jq -r ".status.storageAccountId")
                STORAGE_ACCOUNT_NAME=$(echo $DEPLOYMENT_SCRIPT_STATUS_STORAGE_ACCOUNT_ID | perl -p -e "s/\/subscriptions\/${subscription_id}\/resourceGroups\/${managed_rg}\/providers\/Microsoft.Storage\/storageAccounts\/(.*)/\1/")
                STORAGE_ACCOUNT_KEY=$(az storage account keys list --resource-group $managed_rg --account-name $STORAGE_ACCOUNT_NAME --subscription ${subscription_id} --query "[0].value" -o tsv)
                STORAGE_SHARE_NAME=$(az storage share list --account-name "${STORAGE_ACCOUNT_NAME}" --account-key "${STORAGE_ACCOUNT_KEY}" --subscription ${subscription_id} | jq -r ".[0].name")
                STORAGE_SHARE_PATH="azscriptoutput"
                STORAGE_SHARE_FILE=$(az storage file list --account-name "${STORAGE_ACCOUNT_NAME}" --share-name ${STORAGE_SHARE_NAME} --account-key "${STORAGE_ACCOUNT_KEY}" --subscription ${subscription_id} --path ${STORAGE_SHARE_PATH} | jq -r ".[0].name")
                if [ -z "STORAGE_SHARE_FILE" ] || [ "$STORAGE_SHARE_FILE" == "null" ]
                then
                    echo "WARNING - The file $STORAGE_SHARE_FILE does not exist yet in the share $STORAGE_SHARE_NAME." 
                else
                    az storage file download --path  ${STORAGE_SHARE_PATH}/${STORAGE_SHARE_FILE}  --account-name ${STORAGE_ACCOUNT_NAME} --share-name ${STORAGE_SHARE_NAME} --account-key ${STORAGE_ACCOUNT_KEY} --subscription ${subscription_id} --dest ./${STORAGE_SHARE_FILE} >/dev/null
                    cat ./${STORAGE_SHARE_FILE} > newlog.txt

                    diff --unified=0 oldlog.txt newlog.txt | grep '^+[^+]' | sed 's/^+//' > diff.txt
                    cat diff.txt
                    mv newlog.txt oldlog.txt
                fi
                echo "sleeping $pollInterval seconds"
                sleep $pollInterval  
            elif [ "$(date +%s)" -gt "$(date -d $DEPLOYMENT_SCRIPT_STATUS_ENDTIME +%s)" ]
            then 
                echo "The script execution has completed."
                break
            else
                echo "sleeping $pollInterval seconds"
                sleep $pollInterval
            fi
        fi
    done
done

echo "The managed application has been successfully deployed."
echo "✅ Deployment succeeded"
echo "status=SUCCEEDED" >> "$GITHUB_OUTPUT"