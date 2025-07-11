
#!/bin/bash

# Copyright © 2024, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0


#####################################################################
# Helper Functions
#####################################################################

# echo and log
function echolog {
  echo $(date +"[%Y-%m-%d %H:%M:%S]") "$*" | tee -a $LOGFILE
}

function wait_for_fn_result() {
  # Wait for a function to produce a result
  # Inputs: $1 - function to run and wait
  # Caution will run forever
  # Todo - consider a finite number of runs before quitting
  function=$1
  echolog "Function [$function] starting ..."
  $function
  while [ $? -ne 0 ]; do
    echolog "Function [$function] ERROR. Will retry in ${RETRY_BACKOFF}s..."
    sleep $RETRY_BACKOFF
    $function
  done
  echolog "Function [$function] SUCCESS..."
  echolog
}

function wait_for_fn_with_str_result() {
  # Wait for a function to produce a result
  # Inputs: $1 - function to run and wait
  #         $2 - the variable to check
  # Caution will run forever
  function=$1
  var=$2
  echolog "Function with string check [$function] starting ..."
  $function
  while [ "${!var}X" == "X" ]; do
    echolog "Function [$function] ERROR. Will retry in ${RETRY_BACKOFF}s..."
    sleep $RETRY_BACKOFF
    $function
  done
  echolog "Function [$function] SUCCESS..."
  echolog
}

#####################################################################
# Env
#####################################################################

# Constants
RETRY_BACKOFF=30

echolog "ENVIRONMENT:"
echolog

# Environment
# todo: remove some/all this if we want to secure all the values
echolog "SUBSCRIPTION_ID=${SUBSCRIPTION_ID}"
echolog "RG=${RG}"
echolog "STORAGE_ACCOUNT=${STORAGE_ACCOUNT}"
echolog "STORAGE_ACCOUNT_CONTAINER=${STORAGE_ACCOUNT_CONTAINER}"

#####################################################################
# Functions
#####################################################################

# Logfile
LOGFILE="${AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY}/viyaGenerateSshKeypair_$(date +"%Y%m%d%H%M%S").log"
echolog "STARTING Viya SSH keypair generator script ..."
echolog

# az login
function azLoginIdentity {
  az login --identity >>$LOGFILE 2>&1
}

# set subscription
function setAzureSubscription {
  az account set --subscription ${SUBSCRIPTION_ID} >>$LOGFILE 2>&1
}

# generate SSH Keypair
function generateSshKeypair {
  cd $HOME
  rm -f id_rsa*
  ssh-keygen -t rsa -b 4096 -f id_rsa -N ''
}

# Get storage account key
function getStorageAccountKey {
  STORAGE_ACCOUNT_KEY=$(az storage account keys list -g "${RG}" -n "${STORAGE_ACCOUNT}" --query "[0].value" -o tsv)
}

# Upload NFS VM private key
function uploadNfsVmPrivateKey {
  az storage blob upload \
    --account-name "${STORAGE_ACCOUNT}" \
    --account-key "${STORAGE_ACCOUNT_KEY}" \
    --container-name "${STORAGE_ACCOUNT_CONTAINER}" \
    --name id_rsa --overwrite \
    --file "${HOME}/id_rsa"
}

# read public key
function getPublicKey {
  PUBLIC_KEY="$(cat ${HOME}/id_rsa.pub)"
}

#####################################################################
# Script
#####################################################################

echolog "Starting ..."
echolog

# az login
wait_for_fn_result azLoginIdentity

# Set Azure subscription
wait_for_fn_result setAzureSubscription

# Generate SSH Keypair
wait_for_fn_result generateSshKeypair

# getStorageAccountKey
wait_for_fn_with_str_result getStorageAccountKey STORAGE_ACCOUNT_KEY

# Upload NFS VM Private Key
wait_for_fn_result uploadNfsVmPrivateKey

#####################################################################
# Clean up and output for template
#####################################################################

# read public key
wait_for_fn_with_str_result getPublicKey PUBLIC_KEY

# Write output
RESULT="{"
RESULT+="\"publicKey\":\"${PUBLIC_KEY}\""
RESULT+="}"
echo "$RESULT" >$AZ_SCRIPTS_OUTPUT_PATH

# Done
echolog "DONE."
