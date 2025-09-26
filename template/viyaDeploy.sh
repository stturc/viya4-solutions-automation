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
  echolog "---"
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

function kustomization_insert {
    local kustomization_file_path=$1
    local section=$2
    local item=$3
    local insert_mode=${4:-append}
    local sorted_flg=${5:-N}
    
    echolog "[kustomization_insert] Adding entry in $section for $kustomization_file_path (sorted_flg=$sorted_flg - insert_mode=$insert_mode)"
    
    if [ "$sorted_flg" == "N" ]
    then
      yq_sort="map({key:.,value:1}) | from_entries | keys_unsorted"
    else
      yq_sort="unique"
    fi

    case "$insert_mode" in
      "append")
        yq -y -i ".+ {\"$section\"}  | .$section |= (.+ $item | $yq_sort )" $kustomization_file_path
      ;;
      "prepend")
        yq -y -i ".+ {\"$section\"}  | .$section |= ($item + .| $yq_sort )" $kustomization_file_path
      ;;
    esac;
}

function valid_ip() {
  # Check for a valid IP address
  # Inputs: $1 - IP
  local ip=$1
  local stat=1

  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    OIFS=$IFS
    IFS='.'
    ip=($ip)
    IFS=$OIFS
    [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 &&
      ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
    stat=$?
  fi
  return $stat
}

function wait_for_fn_with_ip_result() {
  # Wait for a function to produce a valid IP address result
  # Inputs: $1 - function to run and wait
  #         $2 - the variable to check
  # Caution will run forever
  ipfunction=$1
  ipvar=$2
  echolog "Function with IP result check [$ipfunction] starting ..."
  $ipfunction
  valid_ip "${!ipvar}"
  while [ $? -ne 0 ]; do
    echolog "Function [$ipfunction] ERROR. Will retry in ${RETRY_BACKOFF}s..."
    sleep $RETRY_BACKOFF
    $ipfunction
    valid_ip "${!ipvar}"
  done
  echolog "Function [$ipfunction] SUCCESS..."
  echolog
}

#####################################################################
# Env
#####################################################################

# Logfile
LOGFILE="${AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY}/viyaDeploy_$(date +"%Y%m%d%H%M%S").log"
echolog "STARTING Viya solution deployment script ..."
echolog

# Constants
RETRY_BACKOFF=30
EXT_CLIENT_ID=ext.api.cli

#LDAP and KEYCLOAK variables
UUID=$(cat /proc/sys/kernel/random/uuid)
LDAP_ADMIN_PASSWORD=$(openssl rand -base64 32)
KEYCLOAK_ADMIN_PASSWORD=$(openssl rand -base64 32)
SASBOOT_ADMIN_PASSWORD=$(openssl rand -hex 16)
KEYCLOAK_STORE_PASSWORD=$(openssl rand -hex 16)
SASBOOT_PASS_ENCODED=$(echo -n $SASBOOT_ADMIN_PASSWORD | /bin/base64)
V4_CFG_OPENLDAP_CERT_DURATION=8760h

# Ingress Variables
INGRESS_POD_CIDR='10.244.0.0/16'
INGRESS_SERVICE_CIDR='10.0.0.0/16'

echolog "ENVIRONMENT:"
echolog

# Environment
echolog "   SUBSCRIPTION_ID=${SUBSCRIPTION_ID}"
echolog "   VIYA_ADMIN_PASSWORD is ${#VIYA_ADMIN_PASSWORD} characters long"
echolog "   LOCATION=${LOCATION}"
echolog "   RG=${RG}"
echolog "   AKS=${AKS}"
echolog "   K8S_VERSION=${K8S_VERSION}"
echolog "   V4_CFG_V4D_VERSION=${V4_CFG_V4D_VERSION}"
echolog "   V4_CFG_NAMESPACE=${V4_CFG_NAMESPACE}"
echolog "   V4_CFG_LOADBALANCER_SOURCE_RANGES=${V4_CFG_LOADBALANCER_SOURCE_RANGES}"

# echolog "   V4_CFG_RWX_FILESTORE_ENDPOINT=${V4_CFG_RWX_FILESTORE_ENDPOINT}"
echolog "   V4_CFG_RWX_FILESTORE_PATH=${V4_CFG_RWX_FILESTORE_PATH}"
echolog "   V4_CFG_INGRESS_DNS_PREFIX=${V4_CFG_INGRESS_DNS_PREFIX}"
echolog "   V4_CFG_INGRESS_FQDN=${V4_CFG_INGRESS_FQDN}"
echolog "   NFS_VM_ADMIN_USER=${NFS_VM_ADMIN_USER}"
# echolog "   NFS_VM_IP=${NFS_VM_IP}"
echolog "   STORAGE_ACCOUNT=${STORAGE_ACCOUNT}"
echolog "   STORAGE_ACCOUNT_CONTAINER=${STORAGE_ACCOUNT_CONTAINER}"
# echolog "   JUMP_VM_IP=${JUMP_VM_IP}"
echolog "   STEP_INSTALL_SUPERSET_FLAG=${STEP_INSTALL_SUPERSET_FLAG}"
echolog "   STEP_UPDATE_SPEC_CIRRUS_FLAG=${STEP_UPDATE_SPEC_CIRRUS_FLAG}"
echolog "   STEP_UPDATE_SPEC_CAS_FLAG=${STEP_UPDATE_SPEC_CAS_FLAG}"
echolog "   STEP_WAIT_FOR_CIRRUS_FLAG=${STEP_WAIT_FOR_CIRRUS_FLAG}"
echolog "   STEP_ADD_USERS=${STEP_ADD_USERS}"
echolog "   STEP_DISABLE_CAS_FLAG=${STEP_DISABLE_CAS_FLAG}"
echolog "   STEP_DISABLE_NONESSENTIAL_APPS_RUN_TIME_FLAG=${STEP_DISABLE_NONESSENTIAL_APPS_RUN_TIME_FLAG}"
echolog "   EXTPG_CONFIG_B64=${EXTPG_CONFIG_B64}"
echolog "   IS_UPDATE=${IS_UPDATE}"

# see here for more vars: https://github.com/sassoftware/viya4-deployment/blob/main/docs/CONFIG-VARS.md

#The ideal situation would be to deploy logging and monitoring, but we're facing an issue with logging component that says
# "Flag --short has been deprecated, and will be removed in the future. The --short output will become the default.",
# "base64: unrecognized option: decode", 
export STEP_CONFIGURE_LOGGING=N #Y: enables / N: disables
export STEP_CONFIGURE_MONITORING=Y #Y: enables / N: disables

export STEP_DEPLOY_PGADMIN_FLAG=Y
export USE_IP_ALLOWLIST=True

echolog "   STEP_CONFIGURE_LOGGING=${STEP_CONFIGURE_LOGGING}"
echolog "   STEP_CONFIGURE_MONITORING=${STEP_CONFIGURE_MONITORING}"

echolog "   STEP_DISABLE_NONESSENTIAL_APPS_DEPLOYMENT_TIME=${STEP_DISABLE_NONESSENTIAL_APPS_DEPLOYMENT_TIME}"
echolog "   STEP_DEPLOY_PGADMIN_FLAG=${STEP_DEPLOY_PGADMIN_FLAG}"
echolog "   "
echolog "   "




#####################################################################
# Functions
#####################################################################

# az login
function azLoginIdentity {
  az login --identity >>$LOGFILE 2>&1
}

# set subscription
function setAzureSubscription {
  az account set --subscription ${SUBSCRIPTION_ID} >>$LOGFILE 2>&1
}

# Install kubectl
function downloadKubectl {
  wget https://dl.k8s.io/release/v${K8S_VERSION}/bin/linux/amd64/kubectl -O /usr/local/bin/kubectl >>$LOGFILE 2>&1
}

# Get kubeconfig
function getKubeconfig {
  az aks get-credentials -g ${RG} -n ${AKS} -f $HOME/.kube/config >>$LOGFILE 2>&1
}

# Get storage account key
function getStorageAccountKey {
  STORAGE_ACCOUNT_KEY=$(az storage account keys list -g "${RG}" -n "${STORAGE_ACCOUNT}" --query "[0].value" -o tsv)
}

function retrieveNFSServerInfo {
  export NFS_VM_IP=$(az vm list-ip-addresses -g ${RG} -n ${AKS/-aks/-nfs-vm} | jq -r ".[0].virtualMachine.network.privateIpAddresses[0]")
  export V4_CFG_RWX_FILESTORE_ENDPOINT="$NFS_VM_IP"
  echolog "   NFS_VM_IP=${NFS_VM_IP}"
  echolog "   V4_CFG_RWX_FILESTORE_ENDPOINT=${V4_CFG_RWX_FILESTORE_ENDPOINT}"
}

function retrieveJumpServerInfo {
  export JUMP_VM_IP=$(az vm list-ip-addresses -g ${RG} -n ${AKS/-aks/-jump-vm} | jq -r ".[0].virtualMachine.network.privateIpAddresses[0]")
  echolog "   JUMP_VM_IP=${JUMP_VM_IP}"
}

# Download NFS VM private key
function downloadNfsVmPrivateKey {
  az storage blob download \
    --account-name "${STORAGE_ACCOUNT}" \
    --account-key "${STORAGE_ACCOUNT_KEY}" \
    --container-name "${STORAGE_ACCOUNT_CONTAINER}" \
    --name id_rsa \
    --file "${HOME}/key"
}

# Delete NFS VM private key
function deleteNfsVmPrivateKey {
  az storage blob delete \
    --account-name "${STORAGE_ACCOUNT}" \
    --account-key "${STORAGE_ACCOUNT_KEY}" \
    --container-name "${STORAGE_ACCOUNT_CONTAINER}" \
    --delete-snapshots include \
    --name id_rsa
}

# Install kustomize
function downloadKustomize {
  wget https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.0.3/kustomize_v5.0.3_linux_amd64.tar.gz \
    -O /tmp/kustomize.tgz >>$LOGFILE 2>&1
}

# Install helm
function downloadHelm {
  wget https://get.helm.sh/helm-v3.9.0-linux-amd64.tar.gz -O /tmp/helm.tgz >>$LOGFILE 2>&1
}

# Install GNU tar
function downloadTar {
  apk -U add tar >>$LOGFILE 2>&1
}

# Install yq
function downloadYq {
  python -m pip install --upgrade yq >>$LOGFILE 2>&1
}

# Clone viya4-deployment repo
function cloneViya4Deployment {
  cd $HOME
  rm -rf viya4-deployment
  git clone https://github.com/sassoftware/viya4-deployment.git >>$LOGFILE 2>&1
}

# Checkout viya4-deployment supplied version
function checkoutViya4Deployment {
  cd $HOME/viya4-deployment
  git checkout $V4_CFG_V4D_VERSION >>$LOGFILE 2>&1
}

# Install python packages
export PATH=/root/.local/bin:$PATH
function v4dInstallPackages {
  cd $HOME/viya4-deployment
  pip3 install --user -r requirements.txt >>$LOGFILE 2>&1
}

# Install ansible packages
function v4dInstallCollections {
  cd $HOME/viya4-deployment
  ansible-galaxy collection install -r requirements.yaml -f >>$LOGFILE 2>&1
}

# Install baseline
function v4dInstallBaseline {
  cd $HOME/viya4-deployment
  ansible-playbook \
    -e BASE_DIR=$HOME/deployments \
    -e CONFIG=$HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/ansible-vars.yaml \
    -e KUBECONFIG=$HOME/.kube/config \
    playbooks/playbook.yaml --tags "baseline,install" >>$LOGFILE 2>&1
}


function v4dInstallLoggingMonitoring  {
  ANSIBLE_TAGS_ARRAY=()
    
  if [ "$STEP_CONFIGURE_LOGGING" == "Y" ]
  then
    ANSIBLE_TAGS_ARRAY+=("cluster-logging")
  fi

  if [ "$STEP_CONFIGURE_MONITORING" == "Y" ]
  then
    ANSIBLE_TAGS_ARRAY+=("cluster-monitoring")
    ANSIBLE_TAGS_ARRAY+=("viya-monitoring")
  fi

  #check if array is not empty
  if [ ${#ANSIBLE_TAGS_ARRAY[@]} -ne 0 ]
  then 
    ANSIBLE_TAGS_ARRAY+=("install")
 
    printf -v joined '%s,' "${ANSIBLE_TAGS_ARRAY[@]}"
    ANSIBLE_TAGS="${joined%,}"

    echolog "ANSIBLE_TAGS=$ANSIBLE_TAGS"

    cd $HOME/viya4-deployment
    ansible-playbook \
      -e BASE_DIR=$HOME/deployments \
      -e CONFIG=$HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/ansible-vars.yaml \
      -e KUBECONFIG=$HOME/.kube/config \
      playbooks/playbook.yaml --tags "$ANSIBLE_TAGS" >>$LOGFILE 2>&1
  else
    echolog "Nothing to do here."
  fi
}

# Add helm NGINX repo
function addNginxRepo {
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >>$LOGFILE 2>&1
}

# Add helm Bitnami repo
function addBitnamiRepo {
  helm repo add bitnami https://charts.bitnami.com/bitnami >>$LOGFILE 2>&1
}

# Add helm Superset repo
function addSupersetRepo {
  if [ "$STEP_INSTALL_SUPERSET_FLAG" == "Y" ]
  then
    echolog "Add Superset Repo"
    helm repo add superset https://apache.github.io/superset >>$LOGFILE 2>&1
  fi
}


# Helm repo update
function updateHelmRepo {
  helm repo update >>$LOGFILE 2>&1
}

# Set ingress DNS label
function setIngressDns {
   # Pendo Internal patch to allow ingress injection of Pendo snippet
   # The snippet below removes some characters based on link https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/configmap/#annotation-value-word-blocklist
  sed -i 's|,{,},\\||g' $HOME/viya4-deployment/roles/baseline/defaults/main.yml
}

# Get Viya manifests
function unzipViya4Manifests {
  cd $HOME
  rm -rf viya4-manifests && mkdir -p viya4-manifests
  unzip /mnt/azscripts/azscriptinput/viyaManifests.zip -d $HOME/viya4-manifests >>$LOGFILE 2>&1
}

# Create Viya namespace
function createViyaNamespace {
  kubectl get ns ${V4_CFG_NAMESPACE} || kubectl create ns ${V4_CFG_NAMESPACE} >>$LOGFILE 2>&1
}




# Apply Viya manifests
function applyViya4Manifests {
  echolog "Function [applyViya4Manifests] starting ..."
  cd $HOME/viya4-manifests




  echolog "[applyViya4Manifests] replacing variables ..."
  
  find . -type f -exec sed -i "s|{{LOCATION}}|${LOCATION}|g" {} \;
  find . -type f -exec sed -i "s|{{RG}}|${RG}|g" {} \;
  find . -type f -exec sed -i "s|{{AKS}}|${AKS}|g" {} \;
  find . -type f -exec sed -i "s|{{K8S_VERSION}}|${K8S_VERSION}|g" {} \;
  find . -type f -exec sed -i "s|{{V4_CFG_NAMESPACE}}|${V4_CFG_NAMESPACE}|g" {} \;
  find . -type f -exec sed -i "s|{{V4_CFG_RWX_FILESTORE_ENDPOINT}}|${V4_CFG_RWX_FILESTORE_ENDPOINT}|g" {} \;
  find . -type f -exec sed -i "s|{{V4_CFG_RWX_FILESTORE_PATH}}|${V4_CFG_RWX_FILESTORE_PATH}|g" {} \;
  find . -type f -exec sed -i "s|{{V4_CFG_INGRESS_FQDN}}|${V4_CFG_INGRESS_FQDN}|g" {} \;
  find . -type f -exec sed -i "s|{{V4_CFG_LOADBALANCER_SOURCE_RANGES}}|${V4_CFG_LOADBALANCER_SOURCE_RANGES}|g" {} \;
  # find . -type f -exec sed -i "s|{{V4_CFG_INGRESS_DNS_PREFIX}}|${V4_CFG_INGRESS_DNS_PREFIX}|g" {} \;
  find . -type f -exec sed -i "s|{{UUID}}|${UUID}|g" {} \;
  find . -type f -exec sed -i "s|{{LDAP_ADMIN_PASSWORD}}|${LDAP_ADMIN_PASSWORD}|g" {} \;
  find . -type f -exec sed -i "s|{{V4_CFG_OPENLDAP_CERT_DURATION}}|${V4_CFG_OPENLDAP_CERT_DURATION}|g" {} \;
  find . -type f -exec sed -i "s|{{VIYA_ADMIN_PASSWORD}}|${VIYA_ADMIN_PASSWORD}|g" {} \;
  find . -type f -exec sed -i "s|{{NFS_VM_IP}}|${NFS_VM_IP}|g" {} \;
  find . -type f -exec sed -i "s|{{SASBOOT_ADMIN_PASSWORD}}|${SASBOOT_ADMIN_PASSWORD}|g" {} \;
  find . -type f -exec sed -i "s|{{SASBOOT_PASS_ENCODED}}|${SASBOOT_PASS_ENCODED}|g" {} \;

  if [[ "${USE_IP_ALLOWLIST}" == "False" ]]; then
    V4_CFG_CM_ISSUER_NAME=sas-viya-letsencrypt-issuer
  else
    V4_CFG_CM_ISSUER_NAME=sas-viya-issuer
  fi
  find . -type f -exec sed -i "s|{{V4_CFG_CM_ISSUER_NAME}}|${V4_CFG_CM_ISSUER_NAME}|g" {} \;

  echolog "[applyViya4Manifests] copying site-config to deployment folder ..."
  cp -r site-config $HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}

  if [ -n "$TLS_CERT_B64" ]
  then
    echolog "[applyViya4Manifests] TLS_CERT_B64 is not empty, so we will delete whatever is in site-config/tls/..."
    rm -rf $HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/site-config/tls/*
  fi

  if [ -f $HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/site-config/tls/ingress-annotation-transformer.yaml ]; then
    echolog "[applyViya4Manifests] ingress-annotation-transformer.yaml found under site-config/tls so lets make sure DaC doesn't touch it ..."
    yq -y 'del(.[] | select(.name == "TLS - Certificate Generation - cert-manager"))' $HOME/viya4-deployment/roles/vdm/tasks/tls.yaml
    echolog "[applyViya4Manifests] ingress-annotation-transformer.yaml OK"
  fi

  if [ -f $HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/site-config/cas/cas-enable-external-services.yaml ]; then
    echolog "[applyViya4Manifests] cas-enable-external-services.yaml found under site-config/cas, so lets apply loadBalancerSourceRanges to it ..."

    IFS=, read -ra RANGES <<<"$V4_CFG_LOADBALANCER_SOURCE_RANGES"
    echo "        loadBalancerSourceRanges:" >cas_lb

    for R in "${RANGES[@]}"; do
      if [[ "${R}" =~ .*"/".* ]]; then
        echo "        - ${R}" >>cas_lb
      else
        echo "        - ${R}/32" >>cas_lb
      fi
    done

    sed -i -e '/{{V4_CFG_CAS_LOAD_BALANCER_SOURCE_RANGES}}/{r cas_lb' -e 'd}' $HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/site-config/cas/cas-enable-external-services.yaml
    echolog "[applyViya4Manifests] cas-enable-external-services.yaml OK"
  fi

  echolog "[applyViya4Manifests] copying cluster manifests to deployment folder ..."
  cp -r cluster $HOME/deployments/${AKS}

  echolog "[applyViya4Manifests] applying cluster manifests ..."
  cd $HOME/deployments/${AKS}/cluster

  for f in *.yaml; do
    # don't deploy the Let's Encrypt issuer if we are using allowlist
    if [[ "${USE_IP_ALLOWLIST}" == "True" && "${f}" == "letsEncryptIssuer.yaml" ]]; then
      echolog "[applyViya4Manifests][$f] skipping, because USE_IP_ALLOWLIST=${USE_IP_ALLOWLIST} ..."
      continue
    fi

    echolog "[applyViya4Manifests][$f] applying ..."
    kubectl apply -f $f >>$LOGFILE 2>&1
    while [ $? -ne 0 ]; do
      echolog "[applyViya4Manifests][$f] ERROR. Will retry ..."
      sleep $RETRY_BACKOFF
      kubectl apply -f $f >>$LOGFILE 2>&1
    done
    echolog "[applyViya4Manifests][$f] SUCCESS."

  done
}

function listCirrusDeployments {
  echolog "[listCirrusDeployments] List SAS Risk Cirrus deployments"
  # list all cirrus-* subfolders under sas-bases/examples  except sas-risk-cirrus-builder and sas-risk-cirrus-rcc
  regex='sas-risk-cirrus-(?!builder|rcc)'
  sas_bases_examples_dir=~/deployments/$AKS/$V4_CFG_NAMESPACE/sas-bases/examples
  IFS=$'\n' readarray -t CIRRUS_SOLUTIONS <<< $(find "$sas_bases_examples_dir" -type d -maxdepth 1 | perl -lne 'print if /'"$regex"'/' | sed "s|$sas_bases_examples_dir/||")
  
  # we need to add sas-risk-cirrus-core in case cirrus subfolders have been found
  if [[ ${#CIRRUS_SOLUTIONS[@]} -gt 0 ]]
  then
    CIRRUS_SOLUTIONS=("sas-risk-cirrus-core" "${CIRRUS_SOLUTIONS[@]}")
  fi
  echolog "CIRRUS_SOLUTIONS=${CIRRUS_SOLUTIONS[@]}"
}


# Install Viya
function v4dInstallViya {
  echolog "Function [v4dInstallViya] starting ..."
  cd $HOME/viya4-deployment
  sed -i '216,255d' /root/viya4-deployment/roles/vdm/tasks/main.yaml

  ansible-playbook \
     -e BASE_DIR=$HOME/deployments \
     -e CONFIG=$HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/ansible-vars.yaml \
     -e KUBECONFIG=$HOME/.kube/config \
     playbooks/playbook.yaml --tags "viya,install" >>$LOGFILE 2>&1
  cd ~/deployments/$AKS/$V4_CFG_NAMESPACE

  echolog "[v4dInstallViya] Enable CDS postgres"
  if grep -q "internal-cds-postgres" ${KUSTOMIZATION_YAML_PATH}
  then
    echolog "[v4dInstallViya] CDS resources already present in kustomization.yaml. Taking no action"
  else
    echolog "[v4dInstallViya] CDS resources NOT already present in kustomization.yaml. Adding required entries"
    #Note that the items must be declared in reverse order, since we are prepending each one
    kustomization_insert "kustomization.yaml" "resources" "[\"sas-bases/overlays/crunchydata/postgres-operator\"]" "prepend"
    kustomization_insert "kustomization.yaml" "resources" "[\"sas-bases/overlays/postgres/cds-postgres\"]" "prepend"

    #Note that the items must be declared in reverse order, since we are prepending each one
    kustomization_insert "kustomization.yaml" "components" "[\"sas-bases/components/crunchydata/internal-platform-postgres\"]" "prepend"
    kustomization_insert "kustomization.yaml" "components" "[\"sas-bases/components/crunchydata/internal-cds-postgres\"]" "prepend"
  fi

  listCirrusDeployments

  #Define variables for transformers files
  SAS_RISK_CIRRUS_WORKFLOW_DEFAULT_SERVICE_ACCOUNT=viya_admin

  echolog "[v4dInstallViya] Applying configuration for SAS Risk Cirrus solutions"
  for cirrus_solution in ${CIRRUS_SOLUTIONS[@]}
  do
    echolog "for $cirrus_solution"
    for modifier in "transformers" "generators"
    do
      transformer_file="$HOME/viya4-manifests/cirrus/${cirrus_solution}-config-${modifier}-${V4_CFG_CADENCE_VERSION}.yaml"
      if [ -f "${transformer_file}" ];
      then 
        echolog "[v4dInstallViya] Using specific cadence $modifier file: $transformer_file"
      else
        transformer_file="$HOME/viya4-manifests/cirrus/${cirrus_solution}-config-${modifier}-${V4_CFG_CADENCE_YEAR}.xx.yaml"
        if [ -f "${transformer_file}" ];
        then 
          echolog "[v4dInstallViya] Using year-specific $modifier file: $transformer_file"
        else
          transformer_file="$HOME/viya4-manifests/cirrus/${cirrus_solution}-config-${modifier}-default.yaml"
          if [ -f "${transformer_file}" ];
          then 
            echolog "[v4dInstallViya] Using default $modifier file: $transformer_file"
          else
            echolog "No $modifier file was found. Skipping $modifier configuration for $cirrus_solution ..."
            transformer_file=""
          fi
        fi
      fi

      if [ -n "$transformer_file" ]
      then
        mkdir -p $HOME/deployments/$AKS/$V4_CFG_NAMESPACE/site-config/$cirrus_solution/resources/
        target_file="$HOME/deployments/$AKS/$V4_CFG_NAMESPACE/site-config/$cirrus_solution/resources/${cirrus_solution}-config-${modifier}.yaml"
        cp "$transformer_file" "$target_file"

        perl -pi -e "s|<<SAS_RISK_CIRRUS_WORKFLOW_DEFAULT_SERVICE_ACCOUNT>>|${SAS_RISK_CIRRUS_WORKFLOW_DEFAULT_SERVICE_ACCOUNT}|" $target_file
        perl -pi -e "s|<<SAS_RISK_CIRRUS_SOLUTION_BUILDER_REPO_USER>>|${SAS_RISK_CIRRUS_SOLUTION_BUILDER_REPO_USER:-Unknown}|" $target_file
        perl -pi -e "s|<<SAS_RISK_CIRRUS_REPO_USER>>|${SAS_RISK_CIRRUS_REPO_USER:-Unknown}|" $target_file
        perl -pi -e "s|<<SAS_RISK_CIRRUS_REPO_FQDN>>|${SAS_RISK_CIRRUS_REPO_FQDN:-Unknown}|" $target_file
        perl -pi -e "s|<<SAS_RISK_CIRRUS_REPO_HOST>>|${SAS_RISK_CIRRUS_REPO_HOST:-Unknown}|" $target_file

        kustomization_insert "kustomization.yaml" "$modifier" "[\"site-config/$cirrus_solution/resources/${cirrus_solution}-config-${modifier}.yaml\"]" "append"
        echolog "[v4dInstallViya] Kustomization for $cirrus_solution (modifier=$modifier) is applied."
      fi
    done
  done

  
  echolog "[v4dInstallViya] Create Viya manifest"
  kustomize build -o site.yaml >>$LOGFILE 2>&1

  echolog "[v4dInstallViya] Apply Viya manifest"
  kubectl apply --selector="sas.com/admin=cluster-api" --server-side --force-conflicts -f site.yaml >>$LOGFILE 2>&1
  kubectl wait --for condition=established --timeout=60s -l "sas.com/admin=cluster-api" crd >>$LOGFILE 2>&1
  kubectl apply --selector="sas.com/admin=cluster-wide" -f site.yaml >>$LOGFILE 2>&1
  sleep 5
  kubectl apply --selector="sas.com/admin=cluster-local" -f site.yaml >>$LOGFILE 2>&1
  sleep 5
  kubectl apply --selector="sas.com/admin=namespace" -f site.yaml >>$LOGFILE 2>&1
}

function disableCAS() {
  # This step will disable CAS
  # To restart it: 
  #   Manually scale sas-cas-operator deployment up to 1
  #   Manually clean SAS_RISK_CIRRUS_DEPLOYER_SKIP_SPECIFIC_INSTALL_STEPS configmap var
  #   Manually restart Cirrus pod

  if [ "$STEP_DISABLE_CAS_FLAG" == "Y" ]
  then
    echolog "[disableCAS] Get CAS deployment configuration"
    kubectl get casdeployment default -n ${V4_CFG_NAMESPACE} -o json > casdeployment.json
    kubectl get casdeployment default -n $V4_CFG_NAMESPACE -o jsonpath='{.metadata.annotations.kubectl\.kubernetes\.io/last-applied-configuration}' > casdeployment_lastAppliedConfiguration.json

    # Shutdown CAS server in last-applied config
    tmp=$(mktemp)
    jq '
      .spec.shutdown = true
    ' casdeployment_lastAppliedConfiguration.json > "$tmp" && mv "$tmp" casdeployment_lastAppliedConfiguration.json

    # Change CAS deployment nodeAffinity in last-applied config
    tmp=$(mktemp)
    jq '
      def additionalMatchExpression: {
        "key": "workload.sas.com/class",
        "operator": "In",
        "values": [
          "cas"
        ]
      };
      .spec.controllerTemplate.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[].matchExpressions += [additionalMatchExpression]
    ' casdeployment_lastAppliedConfiguration.json > "$tmp" && mv "$tmp" casdeployment_lastAppliedConfiguration.json



    # Shutdown CAS server in current config
    tmp=$(mktemp)
    jq '
      .spec.shutdown = true
    ' casdeployment.json > "$tmp" && mv "$tmp" casdeployment.json

    # Change CAS deployment nodeAffinity in current config
    tmp=$(mktemp)
    jq '
      def additionalMatchExpression: {
        "key": "workload.sas.com/class",
        "operator": "In",
        "values": [
          "cas"
        ]
      };
      .spec.controllerTemplate.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms[].matchExpressions += [additionalMatchExpression]
    ' casdeployment.json > "$tmp" && mv "$tmp" casdeployment.json

    # Replace last-applied-config in current config
    tmp=$(mktemp)
    jq --arg input "$(jq -c . casdeployment_lastAppliedConfiguration.json)" '.metadata.annotations["kubectl.kubernetes.io/last-applied-configuration"] = $input' "casdeployment.json" > "$tmp" && mv "$tmp" "casdeployment.json"

    echolog "[disableCAS] Patching CAS deployment (Setting shutdown as true and updating nodeAffinity)"
    kubectl patch casdeployment default -n ${V4_CFG_NAMESPACE} --type=merge --patch-file=casdeployment.json

    echolog "[disableCAS] The procedure to restart CAS is as follows:"
    echolog "Manually start CAS server default controller by setting shutdown: false in CASDeployment Custom Resource"

    echolog "[disableCAS] Get current CAS nodepool max node count"
    casNodepoolMaxCount=$(az aks nodepool show --resource-group $RG --cluster-name $AKS --name cas | jq -r ".maxCount")
    echolog "[disableCAS] Update CAS nodepool min node count=0 max node count=$casNodepoolMaxCount"
    az aks nodepool update --resource-group $RG --cluster-name $AKS --name cas --update-cluster-autoscaler --min-count 0 --max-count $casNodepoolMaxCount

  fi
}


# Create namespace
function createSupersetNamespace {
  if [ "$STEP_INSTALL_SUPERSET_FLAG" == "Y" ]
  then
    echolog "[createSupersetNamespace] Create superset namespace"
    kubectl create ns superset >>$LOGFILE 2>&1
  fi
}


# Deploy superset
function deploySuperset {
  if [ "$STEP_INSTALL_SUPERSET_FLAG" == "Y" ]
  then
    SUPERSET_NAMESPACE=superset

    echolog "[deploySuperset] Deploy superset"
    sleep 60

    SUPERSET_DOMAIN="${V4_CFG_INGRESS_FQDN}"  
    SUPERSET_DOMAIN=$(echo "$SUPERSET_DOMAIN" | tr '[:upper:]' '[:lower:]')

    mkdir -p $HOME/deployments/${AKS}/superset

    mkdir -p $HOME/deployments/${AKS}/superset/configOverrides/
    cat <<EOF >$HOME/deployments/${AKS}/superset/configOverrides/extra_overrides.yaml
EXTRA_CATEGORICAL_COLOR_SCHEMES = [
{
    "id": 'SASColorPalette',
    "description": '',
    "label": 'SAS',
    "isDefault": True,
    "colors":
      ['#0378CD', '#369BE9', '#6CBBFC', '#A2D8FF', '#D7F1FF',
      '#0063B3', '#004C90', '#04304b', '#002543']
}]

# # Add Public API - see https://superset.apache.org/docs/frequently-asked-questions#does-superset-offer-a-public-api
# FAB_API_SWAGGER_UI = True

# Set public role like Alpha role - see https://superset.apache.org/docs/security/#public
PUBLIC_ROLE_LIKE = "Alpha"

# Configuration behind Nginx load balancer - see https://superset.apache.org/docs/installation/configuring-superset/#configuration-behind-a-load-balancer
ENABLE_PROXY_FIX = True

# Feature flags - see https://superset.apache.org/docs/installation/configuring-superset/#feature-flags
FEATURE_FLAGS = {"DRILL_TO_DETAIL": True}

EOF

    cat <<EOF >$HOME/deployments/${AKS}/superset/configOverrides/secret.yaml
SECRET_KEY = '9yW+YLpZlA6l3X6uJ6ErqeE/vjBXseTID5q5F0B7nATAUUhfXKtyNz4Y'
EOF

    cat <<EOF >$HOME/deployments/${AKS}/superset/ingress.yaml
ingress:
  enabled: true
  ingressClassName: nginx
  annotations: 
    nginx.ingress.kubernetes.io/affinity: cookie
    nginx.ingress.kubernetes.io/affinity-mode: persistent
    nginx.ingress.kubernetes.io/app-root: /superset/welcome
    nginx.ingress.kubernetes.io/backend-protocol: HTTP
    nginx.ingress.kubernetes.io/force-ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: 2048m
    nginx.ingress.kubernetes.io/proxy-read-timeout: '1000'
    nginx.ingress.kubernetes.io/redirect-to-https: 'true'
    #nginx.ingress.kubernetes.io/rewrite-target: /$1/$2
    nginx.ingress.kubernetes.io/session-cookie-name: sas-ingress-nginx
    nginx.ingress.kubernetes.io/session-cookie-path: /superset/
    nginx.ingress.kubernetes.io/session-cookie-samesite: Lax
    nginx.ingress.kubernetes.io/ssl-passthrough: 'true'
    nginx.ingress.kubernetes.io/use-regex: 'true'
  tls: 
    - hosts:
        - $SUPERSET_DOMAIN
      secretName: sas-ingress-certificate
  hosts:
    - $SUPERSET_DOMAIN
  paths:
  - path: /superset/
    pathType: Prefix
  - path: /dataset/
    pathType: Prefix
  - path: /roles/
    pathType: Prefix
  - path: /chart/
    pathType: Prefix
  - path: /users/
    pathType: Prefix
  - path: /logout/
    pathType: Prefix
  - path: /login/
    pathType: Prefix
  - path: /api/
    pathType: Prefix
  - path: /static/
    pathType: Prefix
  - path: /dashboard/
    pathType: Prefix
  - path: /csvtodatabaseview/
    pathType: Prefix
  - path: /columnartodatabaseview/
    pathType: Prefix
  - path: /exceltodatabaseview/
    pathType: Prefix
  - path: /tableschemaview/
    pathType: Prefix
  - path: /tabstateview/
    pathType: Prefix
  - path: /explore/
    pathType: Prefix
  - path: /logmodelview/
    pathType: Prefix
  - path: /rowlevelsecurity/
    pathType: Prefix
EOF

    getPGCredentials

    cat <<EOF >$HOME/deployments/${AKS}/superset/extraConfigs.yaml
extraConfigs:
  import_datasources.yaml: |
    databases:
    - allow_file_upload: true
      allow_ctas: true
      allow_cvas: true
      database_name: postgres-cds
      extra: "{\r\n    \"metadata_params\": {},\r\n    \"engine_params\": {},\r\n    \"\
        metadata_cache_timeout\": {},\r\n    \"schemas_allowed_for_file_upload\": []\r\n\
        }"
      sqlalchemy_uri: postgresql+psycopg2://${CDS_POSTGRES_USER}:${CDS_POSTGRES_PASS}@${CDS_POSTGRES_INTERNAL_FQDN}:${CDS_POSTGRES_PORT}/${CDS_POSTGRES_DBNAME}
      tables: []
EOF

    cat <<EOF >$HOME/deployments/${AKS}/superset/bootstrapScript.yaml
bootstrapScript: |
  #!/bin/bash
  # Install system-level dependencies
  apt-get update && apt-get install -y \
    python3-dev \
    default-libmysqlclient-dev \
    build-essential \
    pkg-config

  # Install required Python packages
  pip install \
    authlib \
    psycopg2-binary \
    mysqlclient \

  # Create bootstrap file if it doesn't exist
  if [ ! -f ~/bootstrap ]; then
    echo "Running Superset with uid {{ .Values.runAsUser }}" > ~/bootstrap
  fi
EOF



    SUPERSET_HELM_VERSION=0.14.0 #Installs superset 4.1.1
    # SUPERSET_HELM_VERSION=0.10.7 #Installs superset 2.1.0

      helm upgrade --cleanup-on-fail --install superset superset/superset --version $SUPERSET_HELM_VERSION \
        --namespace ${SUPERSET_NAMESPACE} \
        --create-namespace \
        --set-file configOverrides.extra_overrides=$HOME/deployments/${AKS}/superset/configOverrides/extra_overrides.yaml \
        --set-file configOverrides.secret=$HOME/deployments/${AKS}/superset/configOverrides/secret.yaml \
        -f ${HOME}/deployments/${AKS}/superset/extraConfigs.yaml \
        -f ${HOME}/deployments/${AKS}/superset/ingress.yaml \
        -f ${HOME}/deployments/${AKS}/superset/bootstrapScript.yaml \
        --set supersetNode.connections.db_host=${CDS_POSTGRES_INTERNAL_FQDN} \
        --set supersetNode.connections.db_port="${CDS_POSTGRES_PORT}" \
        --set supersetNode.connections.db_user=${CDS_POSTGRES_USER} \
        --set supersetNode.connections.db_pass=${CDS_POSTGRES_PASS} \
        --set supersetNode.connections.db_name=${CDS_POSTGRES_DBNAME} \
        --set redis.enabled=true \
        --set postgresql.enabled=false 


    echolog "[deploySuperset] Wait for Superset pod to be ready"
    while [[ $(kubectl get pods -n ${SUPERSET_NAMESPACE} --selector="app=superset" -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]
    do 
      echolog "[deploySuperset] Waiting 5 seconds for superset pod" && sleep 5
    done

    echolog "[deploySuperset] Superset pod is ready."
    sleep 10

    SUPERSET_POD=$(kubectl -n ${SUPERSET_NAMESPACE} get pods --selector="app=superset" -o json | jq -r ".items[0].metadata.name")


    echolog "[deploySuperset] Install dashboards"
    cd ${HOME}/viya4-manifests/dashboards

    for cirrus_solution in ${CIRRUS_SOLUTIONS[@]}
    do
      case $cirrus_solution in
        sas-risk-cirrus-alm)
          ;;
        sas-risk-cirrus-mrm)
          echolog "[deploySuperset] Install dashboard for SAS Viya solution: SAS Model Risk Management"
          yq -y -i ".database_name = \"postgres-cds-mrm\"" mrm/databases/PostgreSQL_cds.yaml
          yq -y -i ".sqlalchemy_uri = \"postgresql+psycopg2://${CDS_POSTGRES_USER}:${CDS_POSTGRES_PASS}@${CDS_POSTGRES_INTERNAL_FQDN}:${CDS_POSTGRES_PORT}/${CDS_POSTGRES_DBNAME}\"" mrm/databases/PostgreSQL_cds.yaml

          zip -r dashboard_mrm.zip mrm/*
          kubectl cp dashboard_mrm.zip ${SUPERSET_NAMESPACE}/$SUPERSET_POD:/tmp
          kubectl exec -n ${SUPERSET_NAMESPACE} $SUPERSET_POD -- /bin/bash -c "superset import-dashboards -p /tmp/dashboard_mrm.zip -u admin"
          ;;
      esac
    done
  fi
}

function createPgadminNamespace {
  kubectl get ns pgadmin || kubectl create ns pgadmin >>$LOGFILE 2>&1
}

function getPGCredentials {
  # This will determine the following variables CDS_POSTGRES_USER, CDS_POSTGRES_PASS, CDS_POSTGRES_INTERNAL_FQDN, CDS_POSTGRES_PORT, CDS_POSTGRES_DBNAME
  NAMESPACE=$V4_CFG_NAMESPACE

  if [ -n "$STEP_CONFIGURE_POSTGRES_JSON" ]
  then
    CDS_POSTGRES_USER=$(echo "$STEP_CONFIGURE_POSTGRES_JSON" | jq -r ".\"cds-postgres\".admin")
    CDS_POSTGRES_PASS=$(echo "$STEP_CONFIGURE_POSTGRES_JSON" | jq -r ".\"cds-postgres\".password")
    CDS_POSTGRES_INTERNAL_FQDN=$(echo "$STEP_CONFIGURE_POSTGRES_JSON" | jq -r ".\"cds-postgres\".fqdn")
    CDS_POSTGRES_PORT=$(echo "$STEP_CONFIGURE_POSTGRES_JSON" | jq -r ".\"cds-postgres\".server_port")
    CDS_POSTGRES_DBNAME=$(echo "$STEP_CONFIGURE_POSTGRES_JSON" | jq -r ".\"cds-postgres\".database")
  else
    while ! kubectl get secret  -n $NAMESPACE sas-crunchy-cds-postgres-pguser-dbmsowner
    do 
      echolog "[getPGCredentials] Waiting 10s for sas-crunchy-cds-postgres-pguser-dbmsowner secret."
      sleep 10
    done

    CDS_POSTGRES_CREDS=$(kubectl get secret -n $NAMESPACE sas-crunchy-cds-postgres-pguser-dbmsowner -o json)
    CDS_POSTGRES_USER=$(echo "$CDS_POSTGRES_CREDS" | jq -r ".data.user" | /bin/base64 -d)
    CDS_POSTGRES_PASS=$(echo "$CDS_POSTGRES_CREDS" | jq -r ".data.password" | /bin/base64 -d)

    CDS_POSTGRES_SERVICE="sas-crunchy-cds-postgres-primary"
    CDS_POSTGRES_INTERNAL_FQDN="${CDS_POSTGRES_SERVICE}.${NAMESPACE}.svc.cluster.local"
    CDS_POSTGRES_PORT="5432"
    CDS_POSTGRES_DBNAME="SharedServices"
  fi
}

function deployPgadmin {
  mkdir -p $HOME/deployments/pgadmin

  getPGCredentials
  
  PGADMIN_PASS_B64=$(echo -n "admin" | /bin/base64)

  cat <<EOF >$HOME/deployments/pgadmin/pgadmin.yaml
---
apiVersion: v1
kind: Secret
type: Opaque
metadata:
 name: pgadmin
data:
 pgadmin-password: $PGADMIN_PASS_B64
---
apiVersion: v1
kind: ConfigMap
metadata:
 name: pgadmin-config
data:
 servers.json: |
   {
       "Servers": {
         "1": {
           "Name": "PostgreSQL DB",
           "Group": "Servers",
           "Port": $CDS_POSTGRES_PORT,
           "Username": "$CDS_POSTGRES_USER",
           "Host": "$CDS_POSTGRES_INTERNAL_FQDN",
           "SSLMode": "prefer",
           "MaintenanceDB": "postgres"
         }
       }
   }
---
apiVersion: v1
kind: Service
metadata:
 name: pgadmin-service
spec:
 ports:
 - protocol: TCP
   port: 80
   targetPort: http
 selector:
   app: pgadmin
 type: NodePort
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
 name: pgadmin
spec:
 serviceName: pgadmin-service
 podManagementPolicy: Parallel
 replicas: 1
 updateStrategy:
   type: RollingUpdate
 selector:
   matchLabels:
     app: pgadmin
 template:
   metadata:
     labels:
       app: pgadmin
   spec:
     terminationGracePeriodSeconds: 10
     containers:
       - name: pgadmin
         image: dpage/pgadmin4:9.1
         securityContext:
          runAsUser: 0
          runAsGroup: 0
         imagePullPolicy: Always
         env:
         - name: PGADMIN_DEFAULT_EMAIL
           value: admin@sas.com
         - name: PGADMIN_DEFAULT_PASSWORD
           valueFrom:
             secretKeyRef:
               name: pgadmin
               key: pgadmin-password
         ports:
         - name: http
           containerPort: 80
           protocol: TCP
         volumeMounts:
         - name: pgadmin-config
           mountPath: /pgadmin4/servers.json
           subPath: servers.json
           readOnly: false
         - name: pgadmin-data
           mountPath: /var/lib/pgadmin
           readOnly: false
     volumes:
     - name: pgadmin-config
       configMap:
         name: pgadmin-config
 volumeClaimTemplates:
 - metadata:
     name: pgadmin-data
   spec:
     accessModes: [ "ReadWriteOnce" ]
     resources:
       requests:
         storage: 3Gi
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: pgadmin
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/ssl-redirect: "false" 
    nginx.ingress.kubernetes.io/configuration-snippet: |
      proxy_set_header X-Script-Name /pgadmin;
spec:

  rules:
    - host: ${V4_CFG_INGRESS_FQDN}
      http:
        paths:
          - path: /pgadmin
            pathType: ImplementationSpecific
            backend:
              service:
                name: pgadmin-service
                port:
                  number: 80
EOF
  kubectl apply -n pgadmin -f $HOME/deployments/pgadmin/pgadmin.yaml >>$LOGFILE 2>&1
}

# Zip deployed assets
function zipDeployAssets {
  cd $HOME
  rm -f deployments.zip
  zip -r deployments.zip deployments >>$LOGFILE 2>&1
}

# Upload assets
function uploadDeployAssets {
  az storage blob upload \
    --account-name "${STORAGE_ACCOUNT}" \
    --account-key "${STORAGE_ACCOUNT_KEY}" \
    --container-name "${STORAGE_ACCOUNT_CONTAINER}" \
    --file "${HOME}/deployments.zip" \
    --overwrite
}

# Upload outputs
function uploadOutputs {
  az storage blob upload \
    --account-name "${STORAGE_ACCOUNT}" \
    --account-key "${STORAGE_ACCOUNT_KEY}" \
    --container-name "${STORAGE_ACCOUNT_CONTAINER}" \
    --file "${AZ_SCRIPTS_OUTPUT_PATH}"
}

# Upload CA certificate
function uploadCaCertificate {
  az storage blob upload \
    --account-name "${STORAGE_ACCOUNT}" \
    --account-key "${STORAGE_ACCOUNT_KEY}" \
    --container-name "${STORAGE_ACCOUNT_CONTAINER}" \
    --file "${HOME}/ca-certificate/${V4_CFG_INGRESS_FQDN}-ca.pem" \
    --overwrite
}

# Upload logfile
function uploadLogfile {
  echolog "[uploadLogfile] NOTE: uploaded log file will end here."
  az storage blob upload \
    --account-name "${STORAGE_ACCOUNT}" \
    --account-key "${STORAGE_ACCOUNT_KEY}" \
    --container-name "${STORAGE_ACCOUNT_CONTAINER}" \
    --file "${LOGFILE}"
}

# Add Viya Administrator to the identities service
function addViyaAdmin {
  echolog "[addViyaAdmin] NOTE: adding Viya administrator to identities service"
  kubectl exec -it sas-consul-server-0 -n ${V4_CFG_NAMESPACE} -- bash -c "export CONSUL_HTTP_ADDR=https://sas-consul-server:8500 && /opt/sas/viya/home/bin/sas-bootstrap-config --token-file /opt/sas/viya/config/etc/SASSecurityCertificateFramework/tokens/consul/default/client.token --verbose kv write --key config/identities/sas.identities/administrator --value viya_admin"

  echolog "[addViyaAdmin] NOTE: restarting identities services for changes to take effect"
  kubectl delete pod -l app=sas-identities -n ${V4_CFG_NAMESPACE} >>$LOGFILE 2>&1

  # sleep 10

  echolog "[addViyaAdmin] NOTE: waiting for identities service to come up"
  kubectl wait --for=condition=ready pod -l app=sas-identities -n ${V4_CFG_NAMESPACE} --timeout=1h >>$LOGFILE 2>&1

}

function fixViyaAdmin {
  echolog "[fixViyaAdmin] NOTE:  waiting for the identities service to come up"
  kubectl wait --for=condition=ready pod -l app=sas-identities -n ${V4_CFG_NAMESPACE} --timeout=2h >>$LOGFILE 2>&1

  echolog "[fixViyaAdmin] NOTE:  waiting for the consul service to come up"
  kubectl wait --for=condition=ready pod -l app=sas-consul-server -n ${V4_CFG_NAMESPACE} --timeout=2h >>$LOGFILE 2>&1

  # Call function that adds Viya administrator to identities service
  addViyaAdmin

  CHECK=$(kubectl logs -l app=sas-identities -n ${V4_CFG_NAMESPACE} --tail -1 | grep '"level":"error"' | grep viya_admin)
  while [ -n "$CHECK" ]; do
    echolog "[fixViyaAdmin] NOTE: Viya administrator was not added successfully. Will try again...."
    addViyaAdmin

    CHECK=$(kubectl logs -l app=sas-identities -n ${V4_CFG_NAMESPACE} --tail -1 | grep '"level":"error"' | grep viya_admin)
    if [[ -n "$CHECK" ]]; then
      echolog "[fixViyaAdmin] NOTE: Viya administrator was not added successfully. Will make another attempt..."
    else
      echolog "[fixViyaAdmin]i NOTE: Viya administrator was added. Exiting loop..."
    fi
  done
}

function checkExternalPostgres {
  #extPgServerName=${RG/-rg/-extpg-ids}
  # Stephen

  if [ "${IS_UPDATE}" == "True" ]; then
    # Detect if external postgres is part of deployment
    echolog "[checkExternalPostgres] Check existence of external PostgreSQL server"
    
    extPG_IDS_name=${RG/-mrg/-extpg-ids}
    extPG_CDS_name=${RG/-mrg/-extpg-cds}

    if [[ $(az postgres flexible-server list --resource-group $RG --query "[?name=='$extPG_IDS_name'] | length(@)") > 0 ]] && [[ $(az postgres flexible-server list --resource-group $RG --query "[?name=='$extPG_CDS_name'] | length(@)") > 0 ]]; then
      echolog "[checkExternalPostgres] External postgres instances exist"

      CDS_POSTGRES_SECRET_NAME=$(kubectl -n ${V4_CFG_NAMESPACE} get secrets -o json | jq '.items | sort_by(.metadata.creationTimestamp) | reverse | .[].metadata.name | select(test("cds-postgres-platform-postgres-user"; "i"))' --raw-output | head -n 1)
      CDS_ADMIN_USER=$(kubectl -n ${V4_CFG_NAMESPACE} get secret ${CDS_POSTGRES_SECRET_NAME} -o jsonpath='{.data.username}' | /bin/base64 -d)
      CDS_ADMIN_PASSWORD=$(kubectl -n ${V4_CFG_NAMESPACE} get secret ${CDS_POSTGRES_SECRET_NAME} -o jsonpath='{.data.password}' | /bin/base64 -d)
      CDS_EXTPG_JSON=$(az postgres flexible-server show -g ${RG} -n ${extPG_CDS_name} -o json)
      CDS_EXTPG_FQDN=$(echo "$CDS_EXTPG_JSON" | jq -r ".fullyQualifiedDomainName")
      CDS_EXTPG_PORT=$(az postgres flexible-server parameter show -n port -g ${RG} -s ${extPG_CDS_name} | jq -r ".value")

      IDS_POSTGRES_SECRET_NAME=$(kubectl -n ${V4_CFG_NAMESPACE} get secrets -o json | jq '.items | sort_by(.metadata.creationTimestamp) | reverse | .[].metadata.name | select(test("default-platform-postgres-user"; "i"))' --raw-output | head -n 1)
      IDS_ADMIN_USER=$(kubectl -n ${V4_CFG_NAMESPACE} get secret ${IDS_POSTGRES_SECRET_NAME} -o jsonpath='{.data.username}' | /bin/base64 -d)
      IDS_ADMIN_PASSWORD=$(kubectl -n ${V4_CFG_NAMESPACE} get secret ${IDS_POSTGRES_SECRET_NAME} -o jsonpath='{.data.password}' | /bin/base64 -d)
      IDS_EXTPG_JSON=$(az postgres flexible-server show -g ${RG} -n ${extPG_IDS_name} -o json)
      IDS_EXTPG_FQDN=$(echo "$IDS_EXTPG_JSON" | jq -r ".fullyQualifiedDomainName")
      IDS_EXTPG_PORT=$(az postgres flexible-server parameter show -n port -g ${RG} -s ${extPG_IDS_name} | jq -r ".value")

      STEP_CONFIGURE_POSTGRES_JSON=$(jq -n '{}')
      STEP_CONFIGURE_POSTGRES_JSON=$(echo "$STEP_CONFIGURE_POSTGRES_JSON" | jq '. + 
        { "'"cds-postgres"'": {
          "internal": false, 
          "admin": "'"$CDS_ADMIN_USER"'", 
          "password": "'"$CDS_ADMIN_PASSWORD"'", 
          "fqdn": "'"$CDS_EXTPG_FQDN"'", 
          "ssl_enforcement_enabled": true, 
          "server_port": "'"$CDS_EXTPG_PORT"'", 
          "database": "'"SharedServices"'"
        }}')
      STEP_CONFIGURE_POSTGRES_JSON=$(echo "$STEP_CONFIGURE_POSTGRES_JSON" | jq '. + 
        { "'"default"'": {
          "internal": false, 
          "admin": "'"$IDS_ADMIN_USER"'", 
          "password": "'"$IDS_ADMIN_PASSWORD"'", 
          "fqdn": "'"$IDS_EXTPG_FQDN"'", 
          "ssl_enforcement_enabled": true, 
          "server_port": "'"$IDS_EXTPG_PORT"'", 
          "database": "'"SharedServices"'"
        }}')
    else
      echolog "[checkExternalPostgres] External PostgreSQL server not detected. Proceeding with internal database..."
      export STEP_CONFIGURE_POSTGRES_JSON=""
    fi
  else
    # Detect if external postgres is part of deployment
    echolog "[checkExternalPostgres] Check existence of external PostgreSQL server"
    STEP_CONFIGURE_POSTGRES_JSON=$(jq -n '{}')

    extPgConfig=$(echo "$EXTPG_CONFIG_B64" | /bin/base64 -d )
    echolog "[checkExternalPostgres] extPgConfig: $extPgConfig"
    extPgServers=$(echo "$extPgConfig" | jq -r '.')
    echolog "[checkExternalPostgres] extPgServers: $extPgServers"
    extPgServersLength=$(echo "$extPgServers" | jq -r 'length')
    echolog "[checkExternalPostgres] extPgServersLength: $extPgServersLength"
    if [ "$extPgServersLength" -ne 0 ]
    then
        for ix_tmp in $(seq 1 $extPgServersLength)
        do
            ix=$((ix_tmp-1))
            extPgServer=$(echo "$extPgServers" | jq -r ".[$ix]")
            extPgServerName=$(echo "$extPgServer" | jq -r ".ServerName")
            extPgServerAdminLogin=$(echo "$extPgServer" | jq -r ".AdministratorLogin")
            extPgServerAdminPassword=$(echo "$extPgServer" | jq -r ".AdministratorLoginPassword")
            extPgServerRole=$(echo "$extPgServer" | jq -r ".Role")
            extPgServerDatabases=$(echo "$extPgServer" | jq -r ".Databases")
            echolog "[checkExternalPostgres] Check external Postgres server existence: $extPgServerName"
            if az postgres flexible-server show -g ${RG} -n ${extPgServerName} > /dev/null 2>&1
            then  
                echolog "[checkExternalPostgres] External PostgreSQL server detected ($extPgServerName)"
                EXTPG_JSON=$(az postgres flexible-server show -g ${RG} -n ${extPgServerName} -o json)
                EXTPG_FQDN=$(echo "$EXTPG_JSON" | jq -r ".fullyQualifiedDomainName")
                EXTPG_PORT=$(az postgres flexible-server parameter show -n port -g ${RG} -s ${extPgServerName} | jq -r ".value")

                extPgServerDatabasesLength=$(echo "$extPgServerDatabases" | jq -r 'length')
                if [ "$extPgServerDatabasesLength" -ne 0 ]
                then
                    for jx_tmp in $(seq 1 $extPgServerDatabasesLength)
                    do
                        jx=$((jx_tmp-1))
                        extPgServerDatabase=$(echo "$extPgServerDatabases" | jq -r ".[$jx]")
                        extPgServerDatabaseName=$(echo "$extPgServerDatabase" | jq -r ".name")
                        extPgServerDatabaseDefault=$(echo "$extPgServerDatabase" | jq -r ".default")
                        echolog "[checkExternalPostgres] Creating database $extPgServerDatabaseName..."
                        az postgres flexible-server db create -g ${RG} -s ${extPgServerName} --database-name $extPgServerDatabaseName

                        if [ "$extPgServerDatabaseDefault" == "Y" ]
                        then
                          echolog "[checkExternalPostgres] Configuring database $extPgServerDatabaseName..."
                          STEP_CONFIGURE_POSTGRES_JSON=$(echo "$STEP_CONFIGURE_POSTGRES_JSON" | jq '. + 
                            { "'"$extPgServerRole"'": {
                              "internal": false, 
                              "admin": "'"$extPgServerAdminLogin"'", 
                              "password": "'"$extPgServerAdminPassword"'", 
                              "fqdn": "'"$EXTPG_FQDN"'", 
                              "ssl_enforcement_enabled": true, 
                              "server_port": "'"$EXTPG_PORT"'", 
                              "database": "'"$extPgServerDatabaseName"'"
                            }}')
                        else  
                          echolog "[checkExternalPostgres] Skipping Configuration for database $extPgServerDatabaseName..."
                        fi
                    done
                fi
            fi
        done
    else
      echolog "[checkExternalPostgres] External PostgreSQL server not detected. Proceeding with internal database..."
      export STEP_CONFIGURE_POSTGRES_JSON=""
    fi
  fi
}


function loadCirrusData {
  if [ "$STEP_WAIT_FOR_CIRRUS_FLAG" == "Y" ]
  then
    echolog "[loadCirrusData] NOTE: Starting to load Cirrus data"

    for cirrus_solution in ${CIRRUS_SOLUTIONS[@]}
    do
      case $cirrus_solution in
        sas-risk-cirrus-mrm)

          FILE_NAME="Load_Live_Data.sas"

          echolog "[loadCirrusData] Get bearer token"
          sas_logon_pod=$(kubectl get pods -n ${V4_CFG_NAMESPACE} -l app=sas-logon-app | grep sas-logon-app | awk '{print $1}')
          
          export BEARER_TOKEN=$(kubectl -n ${V4_CFG_NAMESPACE} exec ${sas_logon_pod} -c sas-logon-app -- \
            curl -sk -X POST "https://sas-logon-app.${V4_CFG_NAMESPACE}.svc.cluster.local/SASLogon/oauth/token" \
              -u "sas.cli:" \
              -H "Content-Type: application/x-www-form-urlencoded" \
              -d "grant_type=password&username=viya_admin&password=${VIYA_ADMIN_PASSWORD}" | awk -F: '{print $2}'|awk -F\" '{print $2}')
          
          echo "BEARER_TOKEN: $BEARER_TOKEN"

          echolog "[loadCirrusData] Get content of file $FILE_NAME"      
          FILE_ID=$(kubectl -n ${V4_CFG_NAMESPACE} exec ${sas_logon_pod} -c sas-logon-app -- curl -k -s -L -X GET "https://sas-files.${V4_CFG_NAMESPACE}.svc.cluster.local/files/files?limit=100" --header 'Accept: application/json, application/vnd.sas.api+json' --header "Authorization: Bearer $BEARER_TOKEN" | jq -r ".items[] | select (.name == \"$FILE_NAME\").id")
          echolog "[loadCirrusData] File ID is $FILE_ID"

          echolog "[loadCirrusData] Get file content"
          SAS_FILE_CONTENT=$(kubectl -n ${V4_CFG_NAMESPACE} exec ${sas_logon_pod} -c sas-logon-app -- curl -k -s --request GET \
            --url https://sas-files.${V4_CFG_NAMESPACE}.svc.cluster.local/files/files/${FILE_ID}/content \
            --header 'Accept: application/json, application/vnd.sas.file+json, application/vnd.sas.file+json;version=1, application/vnd.sas.file+json;version=2, application/vnd.sas.file+json;version=3, application/vnd.sas.file+json;version=4, application/vnd.sas.error+json' \
            --header "Authorization: Bearer $BEARER_TOKEN")
          echolog "[loadCirrusData] File content is $(tr -d '\n' <<< "$SAS_FILE_CONTENT")"
          ESCAPED_CODE=$(jq -Rs . <<< "$SAS_FILE_CONTENT")

          echolog "[loadCirrusData] Create job definition to run SAS file"
          JOB_DEF_ID=$(kubectl -n ${V4_CFG_NAMESPACE} exec ${sas_logon_pod} -c sas-logon-app -- \
            curl -sk -X POST "https://sas-job-definitions.${V4_CFG_NAMESPACE}.svc.cluster.local/jobDefinitions/definitions" \
              -H "Authorization: Bearer $BEARER_TOKEN" \
              -H "Content-Type: application/vnd.sas.job.definition+json" \
              -d "{
                \"name\": \"Job Definition $FILE_NAME $(date +%s)\",
                \"description\": \"Compute job that runs the $FILE_NAME SAS file via _program argument\",
                \"type\": \"Compute\",
                \"codeType\": \"SAS\",
                \"createdBy\": \"viya_admin\",
                \"code\": $ESCAPED_CODE
              }" | jq -r '.id')
          echolog "[loadCirrusData] Job Definition ID is $JOB_DEF_ID"

          echolog "[loadCirrusData] Create job execution to run SAS file"
          JOB_EXEC_ID=$(kubectl -n ${V4_CFG_NAMESPACE} exec ${sas_logon_pod} -c sas-logon-app -- \
            curl -sk -X POST "https://sas-job-execution.${V4_CFG_NAMESPACE}.svc.cluster.local/jobExecution/jobs" \
              -H "Authorization: Bearer $BEARER_TOKEN" \
              -H "Content-Type: application/vnd.sas.job.execution.job.request+json" \
              -d "{
                \"name\": \"Job execution $FILE_NAME $(date +%s)\",
                \"jobDefinitionUri\": \"/jobDefinitions/definitions/$JOB_DEF_ID\",
                \"arguments\": {
                  \"_contextName\": \"SAS Job Execution compute context\"
                }                
              }" | jq -r '.id')
          echolog "[loadCirrusData] Job Execution ID is $JOB_EXEC_ID"


          TIMEOUT=7200  # in seconds
          INTERVAL=5  # retry interval in seconds
          START_TIME=$(date +%s)

          while true; do
            STATUS=$(kubectl -n ${V4_CFG_NAMESPACE} exec ${sas_logon_pod} -c sas-logon-app -- \
                              curl -sk -X GET "https://sas-job-execution.${V4_CFG_NAMESPACE}.svc.cluster.local/jobExecution/jobs/$JOB_EXEC_ID" \
                                -H "Authorization: Bearer $BEARER_TOKEN" | jq -r '.state')
            echolog "[loadCirrusData] Job status: $STATUS"
          
            if [[ "$STATUS" == "completed" ]]; then
              echolog "[loadCirrusData] Job completed successfully. Proceeding to retrieve log content..."
              break
            elif [[ "$STATUS" == "failed" ]] || [[ "$STATUS" == "null" ]]; then
              echolog "[loadCirrusData] Job failed. Aborting..."
              exit 1
            fi
          
            CURRENT_TIME=$(date +%s)
            ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
            
            if [ $ELAPSED_TIME -ge $TIMEOUT ]; then
              echolog "[loadCirrusData] Timeout reached: $TIMEOUT seconds. Exiting..."
              exit 1
            fi
          
            echolog "[loadCirrusData] Retrying in $INTERVAL seconds..."
            sleep $INTERVAL
          done

          echolog "[loadCirrusData] Job completed successfully. Retrieving log content"
          LOG_LOCATION_ID=$(kubectl -n ${V4_CFG_NAMESPACE} exec ${sas_logon_pod} -c sas-logon-app -- \
                        curl -sk -X GET "https://sas-job-execution.${V4_CFG_NAMESPACE}.svc.cluster.local/jobExecution/jobs/$JOB_EXEC_ID" \
                          -H "Authorization: Bearer $BEARER_TOKEN" | jq -r '.logLocation')

          echolog "[loadCirrusData] Log location ID is $LOG_LOCATION_ID"

          SAS_LOG_CONTENT=$(kubectl -n ${V4_CFG_NAMESPACE} exec ${sas_logon_pod} -c sas-logon-app -- \
            curl -k -s --request GET \
              --url https://sas-files.${V4_CFG_NAMESPACE}.svc.cluster.local${LOG_LOCATION_ID}/content \
              --header 'Accept: application/json, application/vnd.sas.file+json, application/vnd.sas.file+json;version=1, application/vnd.sas.file+json;version=2, application/vnd.sas.file+json;version=3, application/vnd.sas.file+json;version=4, application/vnd.sas.error+json' \
              --header "Authorization: Bearer $BEARER_TOKEN" | jq -r ".items[].line")

          echolog "[loadCirrusData] Log content is:"
          echolog "$SAS_LOG_CONTENT"

        ;;
      esac
    done

    echolog "[loadCirrusData] NOTE: make sure container has no longer access to environment"
    #We remove the CONTAINER_IP from the ingress-nginx-controller service
    kubectl patch service ingress-nginx-controller -n ingress-nginx --type='merge' -p \
      "$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o json | \
      jq --arg CONTAINER_IP "$CONTAINER_IP/32" '.spec.loadBalancerSourceRanges |= map(select(. != $CONTAINER_IP))')"
  fi
}



# HomeDir creation 
function homeDir {
  USERS=$(cat $HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/site-config/sas-openldap/openldap-modify-users.yaml | grep uid: | awk '{print "         mkdir -p /mnt/viya-share/homes/" $2}')
  ACTION=(create set-permissions)

  for i in ${!ACTION[@]}; do
    echolog "[homeDir] NOTE: replacing variables in YAML file for ACTION: ${ACTION[$i]}"
    cp $HOME/viya4-manifests/homedirs/action-template.yaml /tmp/${ACTION[$i]}-homedir.yaml
    sed -i "s|{{ACTION}}|${ACTION[$i]}|g" /tmp/${ACTION[$i]}-homedir.yaml

    if [ ${ACTION[$i]} == "create" ]; then
      awk -v my_var="$USERS" '/COMMAND/{print;print my_var;next}1' /tmp/${ACTION[$i]}-homedir.yaml >/tmp/${ACTION[$i]}-homedir-command.yaml
      sed -i "/{{COMMAND}}/d" /tmp/${ACTION[$i]}-homedir-command.yaml
    elif [ ${ACTION[$i]} == "set-permissions" ]; then
      cp /tmp/${ACTION[$i]}-homedir.yaml /tmp/${ACTION[$i]}-homedir-command.yaml
      ########active generated UIDs and GIDs 21/12/2022 #######################
      kubectl wait --for=condition=ready pod -l app=sas-logon-app -n ${V4_CFG_NAMESPACE} --timeout=1h >>$LOGFILE 2>&1
      echolog "[homeDir] NOTE: retrieve TOKEN"
      local sas_logon_app_pod_name=$(kubectl -n ${V4_CFG_NAMESPACE} get po -l app=sas-logon-app -o jsonpath='{.items[0].metadata.name}')
      TOKEN=$(kubectl -n ${V4_CFG_NAMESPACE} exec ${sas_logon_app_pod_name} -c sas-logon-app -- \
        curl -k -s -L -X POST "https://sas-logon-app.${V4_CFG_NAMESPACE}.svc.cluster.local/SASLogon/oauth/token" -H 'Accept: application/json' -H 'Content-Type: application/x-www-form-urlencoded' -H 'Authorization: Basic c2FzLmNsaTo=' -d 'grant_type=password' -d "username=viya_admin" -d "password=${VIYA_ADMIN_PASSWORD}" | sed "s/{.*\"access_token\":\"\([^\"]*\).*}/\1/g")
      echolog "[homeDir] NOTE: TOKEN retrieved: ${TOKEN}"
      echolog "[homeDir] NOTE: retrieve UID and GID for user viya_admin"
      kubectl -n ${V4_CFG_NAMESPACE} exec ${sas_logon_app_pod_name} -c sas-logon-app -- \
        curl -k -s -L https://sas-identities.${V4_CFG_NAMESPACE}.svc.cluster.local/identities/users/viya_admin/identifier -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/json" >/tmp/uidgid.json
      uid=$(jq -r '.uid' /tmp/uidgid.json)
      gid=$(jq -r '.gid' /tmp/uidgid.json)
      echolog "[homeDir] NOTE: retrieved UID for viya_admin is ${uid}"
      echolog "[homeDir] NOTE: retrieved GID for viya_admin is ${gid}"
      ######################################################################
      sed -i "s|{{COMMAND}}|chown -R ${uid}:${gid} /mnt/viya-share/homes/viya_admin|g" /tmp/${ACTION[$i]}-homedir-command.yaml
    fi
    echolog "[homeDir] NOTE: executing kubernetes job ${ACTION[$i]}"
    kubectl apply -f /tmp/${ACTION[$i]}-homedir-command.yaml
    sleep 10
    kubectl wait --for=condition=complete --timeout=10m job/${ACTION[$i]}-homedir -n $V4_CFG_NAMESPACE
  done
}


function updateSpecCirrusDeployments {
  if [ "$STEP_UPDATE_SPEC_CIRRUS_FLAG" == "Y" ]
  then
    echolog "[updateSpecCirrusDeployments] Update spec of Cirrus deployments"
    for cirrus_solution in ${CIRRUS_SOLUTIONS[@]}
    do
      case $cirrus_solution in
        sas-risk-cirrus-alm)
          deployment=sas-risk-cirrus-krm
          cat <<EOF > new_spec.yaml   
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              preference:
                matchExpressions:
                  - key: workload.sas.com/class
                    operator: In
                    values:
                      - compute
            - weight: 100
              preference:
                matchExpressions:
                  - key: workload.sas.com/class
                    operator: NotIn
                    values:
                      - stateless
                      - cas
                      - stateful
      tolerations:
        - key: workload.sas.com/class
          operator: Equal
          value: compute
          effect: NoSchedule
EOF
        
          kubectl patch deployment "$deployment" -n "$V4_CFG_NAMESPACE" --type='merge' --patch "$(cat new_spec.yaml)"    
          ;;
      esac  
    done
  fi
}

function waitForCirrusDeployments {
  if [ "$STEP_WAIT_FOR_CIRRUS_FLAG" == "Y" ]
  then
    TIMEOUT=7200  # in seconds
    INTERVAL=60  # retry interval in seconds
    START_TIME=$(date +%s)

    CIRRUS_SOLUTIONS_TO_WAIT_FOR=("sas-risk-cirrus-rcc" "${CIRRUS_SOLUTIONS[@]}")

    while true; do
      echolog "[waitForCirrusDeployments] Checking if all SAS Risk Cirrus deployments and jobs are ready..."
      all_ready=true

      echolog "[waitForCirrusDeployments] Waiting for the SAS Risk Cirrus Builder deployment to be ready..."
      if ! kubectl -n ${V4_CFG_NAMESPACE} wait --for=condition=Ready --timeout=5m pod -l app=sas-risk-cirrus-builder; then
        echolog "[waitForCirrusDeployments] SAS Risk Cirrus Builder still not ready after 5 minutes..."
        all_ready=false
      else
        echolog "[waitForCirrusDeployments] SAS Risk Cirrus Builder is ready. Proceeding..."

        for cirrus_solution in ${CIRRUS_SOLUTIONS_TO_WAIT_FOR[@]}
        do
          case $cirrus_solution in
            sas-risk-cirrus-rcc|sas-risk-cirrus-alm|sas-risk-cirrus-mrm)
              IFS=$'\n' read -r -d '' -a cirrus_job_names < <(
                kubectl get jobs -n "${V4_CFG_NAMESPACE}" -o json |
                jq -r --arg solution "$cirrus_solution" '
                  .items[]
                  | select(.metadata.annotations["sas.com/component-name"] == $solution)
                  | .metadata.name
                ' | sed 's/[][]//g' | tr -d '\r' && printf '\0'
              )

              if [ ${#cirrus_job_names[@]} -eq 0 ]; then
                echolog "[waitForCirrusDeployments] No jobs found for component $cirrus_solution"
                all_ready=false
              else
                for cirrus_job_name in "${cirrus_job_names[@]}"; do
                  echolog "[waitForCirrusDeployments] Waiting for $cirrus_solution (job: $cirrus_job_name) to complete"
                  if ! kubectl wait -n "${V4_CFG_NAMESPACE}" --for=condition=complete --timeout=5m job/${cirrus_job_name}; 
                  then 
                    echolog "[waitForCirrusDeployments] Job $cirrus_job_name still not completed after 5 minutes..."
                    all_ready=false
                    break 2 #this will break 2 loops
                  fi  
                done
              fi
            ;;
          esac
        done
      fi
      
      # Exit loop if everything is ready
      if [ "$all_ready" == true ]; then
        echolog "[waitForCirrusDeployments] All Cirrus deployments and jobs are ready. Proceeding..."
        return 0
      fi

      CURRENT_TIME=$(date +%s)
      ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
      
      if [ $ELAPSED_TIME -ge $TIMEOUT ]; then
        echolog "[waitForCirrusDeployments] Timeout reached: $TIMEOUT seconds. Exiting..."
        exit 1
      fi
    
      echolog "[waitForCirrusDeployments] Retrying in $INTERVAL seconds..."
      sleep $INTERVAL
    done
  fi
}

function addUsers {
  if [ "$STEP_ADD_USERS"!="N" ]
  then
    LDAP_POD=$(kubectl -n $V4_CFG_NAMESPACE get pods --selector="app=openldap" -o json | jq -r ".items[0].metadata.name")
    echolog "[addUsers] LDAP_POD=$LDAP_POD"

    GROUP_NM="SAS_Demo_Users"
    USER_ID_PREFIX="SAS_Demo_User"
    USER_NM_PREFIX="SAS Demo User "
    USER_LOOP_RANGE="1 $STEP_ADD_USERS"

    cat <<EOSCRIPT > addUsers.sh   
#!/bin/bash
for USER_IDX in \$(seq $USER_LOOP_RANGE)
do
  USER_ID="${USER_ID_PREFIX}\$USER_IDX"
  USER_NM="${USER_NM_PREFIX}\$USER_IDX"
  USER_PASS="\$USER_ID"
cat <<EOF >newuser.ldif 
dn: uid=\${USER_ID},ou=people,dc=example,dc=com
objectClass: inetOrgPerson
cn: \${USER_NM}
uid: \${USER_ID}
givenName: \${USER_NM}
sn: \${USER_ID}
userPassword: \${USER_PASS}
EOF
  ldapadd -c -x -w $LDAP_ADMIN_PASSWORD -D "cn=admin,dc=example,dc=com" -f newuser.ldif
done


cat <<EOF >newgroup.ldif 
dn: cn=${GROUP_NM},ou=groups,dc=example,dc=com
objectClass: groupOfUniqueNames
objectClass: extensibleObject
gidNumber: 4000
distinguishedName: cn=${GROUP_NM},ou=groups,dc=example,dc=com
cn: ${GROUP_NM}
EOF

for USER_IDX in \$(seq $USER_LOOP_RANGE)
do
  USER_ID="${USER_ID_PREFIX}\$USER_IDX"

cat <<EOF >> newgroup.ldif 
uniqueMember: uid=\${USER_ID},ou=people,dc=example,dc=com
EOF
done
  ldapadd -c -x -w $LDAP_ADMIN_PASSWORD -D "cn=admin,dc=example,dc=com" -f newgroup.ldif
EOSCRIPT

    chmod +x addUsers.sh
    kubectl cp addUsers.sh -n $V4_CFG_NAMESPACE $V4_CFG_NAMESPACE/$LDAP_POD:/tmp/addUsers.sh
    kubectl exec -i $LDAP_POD -n $V4_CFG_NAMESPACE -- /bin/bash /tmp/addUsers.sh

    function viya_add_membership {
      local namespace="$1"
      local parentGroup="$2"
      local memberType="$3"
      local child="$4"
      local sasadm_user="${5:-sasadm}"
      local sasadm_pwd="${6:-Go4thsas}"
      local sas_logon_pod_name="$7"
      local token="$8"

      if [ -n "$sas_logon_pod_name" ]
      then
        echolog "[viya_add_membership] Using provided sas-logon pod $sas_logon_pod_name"
      else
        pod_prefix=sas-logon-app
        sas_logon_pod_name=$(kubectl -n $namespace get pods --selector="app=$pod_prefix" -o json | jq -r ".items[0].metadata.name")
        echolog "[viya_add_membership] Determined sas-logon pod is $sas_logon_pod_name"
      fi 

      if [ -n "$token" ]
      then
        echolog "[viya_add_membership] Using provided token"
      else
        echolog "[viya_add_membership] Get token"
        token=$(kubectl -n ${namespace} exec $sas_logon_pod_name -c sas-logon-app -- curl -k -s -L -X POST "https://sas-logon-app.${namespace}.svc.cluster.local/SASLogon/oauth/token" -H 'Accept: application/json' -H 'Content-Type: application/x-www-form-urlencoded' -H 'Authorization: Basic c2FzLmNsaTo=' -d 'grant_type=password' -d "username=$sasadm_user" -d "password=${sasadm_pwd}" | jq -r '.access_token')

        echolog "[viya_add_membership] token=$token"
      fi

      echolog "[viya_add_membership] Adding $child to $parentGroup ($memberType relation)..."
      kubectl -n ${namespace} exec $sas_logon_pod_name -c sas-logon-app -- \
          curl -k -s -L -X PUT -H "Authorization: Bearer ${token}" -H "Content-Type: application/json" -H "Accept: application/json" https://sas-identities.${namespace}.svc.cluster.local/identities/groups/$parentGroup/$memberType/$child
      echolog "[viya_add_membership] Added $child to $parentGroup ($memberType relation)"
    }

    echolog "[addUsers] Reload identities by deleting the sas-identities pod"
    # IDENTITIES_POD=$(kubectl -n $V4_CFG_NAMESPACE get pods --selector="app=sas-identities" -o json | jq -r ".items[0].metadata.name")
    kubectl -n ${V4_CFG_NAMESPACE} rollout restart deployment sas-identities

    # Check deployment rollout status every 10 seconds (max 10 minutes) until complete.
    ATTEMPTS=0
    MAX_ATTEMPTS=60
    ROLLOUT_STATUS_CMD="kubectl rollout status deployment/sas-identities  -n ${V4_CFG_NAMESPACE}"
    until $ROLLOUT_STATUS_CMD || [ $MAX_ATTEMPTS -eq 60 ]; do
      $ROLLOUT_STATUS_CMD
      ATTEMPTS=$((attempts + 1))
      sleep 10
    done

    sleep 10

    #Create the list of custom groups the users should be part of depending on the cirrus solutions present in the deployment
    echolog "[addUsers] Create list of custom groups"
    custom_groups=""

    for cirrus_solution in ${CIRRUS_SOLUTIONS[@]}
    do
      case $cirrus_solution in
        sas-risk-cirrus-mrm)
          custom_groups="MRMUsers"$'\n'"${custom_groups}"
          ;;
        sas-risk-cirrus-alm)
          custom_groups="ALMAdmins"$'\n'"${custom_groups}"
          custom_groups="ALMDataAnalyst"$'\n'"${custom_groups}"
          custom_groups="ALMRiskAnalyst"$'\n'"${custom_groups}"
          custom_groups="KRMUsers"$'\n'"${custom_groups}"
          custom_groups="KRMDbWriters"$'\n'"${custom_groups}"
          ;;
      esac
    done

    sas_logon_pod_name=$(kubectl -n $namespace get pods --selector="app=sas-logon-app" -o json | jq -r ".items[0].metadata.name")
    token=$(kubectl -n ${V4_CFG_NAMESPACE} exec $sas_logon_pod_name -c sas-logon-app -- curl -k -s -L -X POST "https://sas-logon-app.${V4_CFG_NAMESPACE}.svc.cluster.local/SASLogon/oauth/token" -H 'Accept: application/json' -H 'Content-Type: application/x-www-form-urlencoded' -H 'Authorization: Basic c2FzLmNsaTo=' -d 'grant_type=password' -d "username=viya_admin" -d "password=${VIYA_ADMIN_PASSWORD}" | jq -r '.access_token')

    echolog "[addUsers] Add the users to the custom groups"
    for USER_IDX in $(seq $USER_LOOP_RANGE)
    do
      USER_ID="${USER_ID_PREFIX}$USER_IDX"
      for custom_group in $custom_groups
      do
        viya_add_membership $V4_CFG_NAMESPACE "$custom_group" "userMembers" "$USER_ID" "viya_admin" "$VIYA_ADMIN_PASSWORD" "${sas_logon_pod_name}" "${token}"
      done
    done
  fi
}

# Get Viya CA Certificate
function getViyaCaCertificate {
  V4_CA_CERTIFICATE_BASE64=$(kubectl -n ${V4_CFG_NAMESPACE} get secret sas-viya-ca-certificate-secret -o=jsonpath="{.data.ca\.crt}")
}

# Write Viya CA Cert to a file
function genViyaCaCertificateFile {
  rm -rf $HOME/ca-certificate
  mkdir $HOME/ca-certificate
  echo -n "${V4_CA_CERTIFICATE_BASE64}" | /bin/base64 -d >"${HOME}/ca-certificate/${V4_CFG_INGRESS_FQDN}-ca.pem"
}

# Get Viya Cadence Release
function getViyaCadenceRelease {
  V4_CFG_CADENCE_RELEASE=$(kubectl -n ${V4_CFG_NAMESPACE} get cm -o yaml | grep ' SAS_CADENCE_RELEASE' | awk -F: '{print $2}' | xargs)
  echolog "[getViyaCadenceRelease] V4_CFG_CADENCE_RELEASE=${V4_CFG_CADENCE_RELEASE}"
}

# Get ingress IP
function getIngressIp {
  V4_INGRESS_IP=$(kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  echolog "[getIngressIp] V4_INGRESS_IP=${V4_INGRESS_IP}"
}

# Get CAS IP
function getCasIp {
  V4_CAS_IP=$(kubectl -n ${V4_CFG_NAMESPACE} get svc sas-cas-server-default-bin -o jsonpath='{.status.loadBalancer.ingress[0].ip}' | xargs)
  echolog "[getCasIp] V4_CAS_IP=${V4_CAS_IP}"
}

function getAksOutboundIp {
  # TODO: fixme - use az cli to get the public ip id from aks, and then query for its value - will need permissions over the MC_ resource group
  kubectl delete pod curlpod >/dev/null 2>/dev/null
  AKS_OUTBOUND_IP=$(kubectl run --image curlimages/curl:7.85.0 --restart=Never -it curlpod -- https://ifconfig.me 2>/dev/null)
  kubectl delete pod curlpod >/dev/null 2>/dev/null
  echolog "[getAksOutboundIp] AKS_OUTBOUND_IP=${AKS_OUTBOUND_IP}"
}

# get ingress Load Balancer source ranges
function getIngressLoadBalancerSourceRanges {
  # get AKS outbound IP
  wait_for_fn_with_ip_result getAksOutboundIp AKS_OUTBOUND_IP

  V4_CFG_LOADBALANCER_SOURCE_RANGES_INGRESS=$(echo "$V4_CFG_LOADBALANCER_SOURCE_RANGES,$AKS_OUTBOUND_IP,$JUMP_VM_IP,$INGRESS_POD_CIDR,$INGRESS_SERVICE_CIDR" | awk '
{
 n = split($0, r, ",")
 result=""
 for ( i = 1; i <= n; i++) {
  if ( i > 1 ) c=","
  if ( !(r[i] ~ "/") ) r[i]=r[i] "/32"
  result=sprintf("%s%s%c%s%c",result,c,39,r[i],39)
 }
 print result
}')

  echolog "V4_CFG_LOADBALANCER_SOURCE_RANGES_INGRESS=${V4_CFG_LOADBALANCER_SOURCE_RANGES_INGRESS}"
}

# Set AKS API Server Authorized Ranges
function setAksApiServerAuthorizedRanges {
  az aks update -g ${RG} -n ${AKS} --api-server-authorized-ip-ranges "${V4_CFG_LOADBALANCER_SOURCE_RANGES}" >>$LOGFILE 2>&1
}

# Set storage account default action = Deny
function setStorageAccountDenyDefaultAction {
  az storage account update -g ${RG} -n ${STORAGE_ACCOUNT} --default-action Deny
}

# Add allowed ranges to storage account
function addStorageAccountNetworkRules {
  IFS=, read -ra RANGES <<<"$V4_CFG_LOADBALANCER_SOURCE_RANGES"
  for R in "${RANGES[@]}"; do
    if [[ "${R}" =~ .*"/31" || "${R}" =~ .*"/32" ]]; then
      R_IP=$(echo $R | awk -F/ '{ print $1 }')
    else
      R_IP=$R
    fi
    echolog "[addStorageAccountNetworkRules] Allowing IP ${R_IP} to storage account ${STORAGE_ACCOUNT}"
    az storage account network-rule add -g ${RG} -n ${STORAGE_ACCOUNT} --ip-address "${R_IP}"
  done
}

function applyAllowlist {
  # lock down AKS API Server  - this must be the last one because we will lose access to the cluster API from the deployment script container instance
  echolog "[applyAllowlist] Setting AKS API Server Authorized Ranges..."
  wait_for_fn_result setAksApiServerAuthorizedRanges

  echolog "[applyAllowlist] Setting Storage Account Deny default action..."
  wait_for_fn_result setStorageAccountDenyDefaultAction

  echolog "[applyAllowlist] Adding Storage Account Network Rules..."
  wait_for_fn_result addStorageAccountNetworkRules
}

function modify_nfs_mounts {
  echolog "[modify_nfs_mounts] NOTE: modifying mount directories for CAS in nfs add mount transformer"
  sed -i "s|mountPath: /mnt/viya-share/data|mountPath: {{ V4_CFG_RWX_FILESTORE_DATA_PATH }}|g" $HOME/viya4-deployment/roles/vdm/templates/transformers/cas-add-nfs-mount.yaml
  sed -i "s|mountPath: /mnt/viya-share/homes|mountPath: {{ V4_CFG_RWX_FILESTORE_HOMES_PATH }}|g" $HOME/viya4-deployment/roles/vdm/templates/transformers/cas-add-nfs-mount.yaml

  echolog "[modify_nfs_mounts] NOTE: modifying mount directories for COMPUTE in nfs add mount transforer"
  sed -i "s|mountPath: /mnt/viya-share/data|mountPath: {{ V4_CFG_RWX_FILESTORE_DATA_PATH }}|g" $HOME/viya4-deployment/roles/vdm/templates/transformers/compute-server-add-nfs-mount.yaml
  sed -i "s|mountPath: /mnt/viya-share/homes|mountPath: {{ V4_CFG_RWX_FILESTORE_HOMES_PATH }}|g" $HOME/viya4-deployment/roles/vdm/templates/transformers/compute-server-add-nfs-mount.yaml

  echolog "[modify_nfs_mounts] NOTE: modifying launcher service patch"
  sed -i "/name: sas-launcher-job-config/d" $HOME/viya4-deployment/roles/vdm/templates/transformers/launcher-service-add-nfs.yaml
  sed -i '/kind: PodTemplate/a \ \ \labelSelector: "sas.com/template-intent=sas-launcher"' $HOME/viya4-deployment/roles/vdm/templates/transformers/launcher-service-add-nfs.yaml

  echolog "[modify_nfs_mounts] NOTE: modifying compute server nfs patch"
  sed -i "/name: sas-compute-job-config/d" $HOME/viya4-deployment/roles/vdm/templates/transformers/compute-server-add-nfs-mount.yaml
  sed -i '/kind: PodTemplate/a \ \ \labelSelector: "sas.com/template-intent=sas-launcher"' $HOME/viya4-deployment/roles/vdm/templates/transformers/compute-server-add-nfs-mount.yaml
}

# Get access token for client registration
function getAccessToken {
  ACCESS_TOKEN=$(kubectl -n ${V4_CFG_NAMESPACE} get secret sas-consul-client -o jsonpath="{.data.CONSUL_TOKEN}" | /bin/base64 -d)
}

# Request client registration OAuth token
function getExtClientRegistrationToken {
  kubectl wait --for=condition=ready pod -l app=sas-logon-app -n ${V4_CFG_NAMESPACE} --timeout=1h >>$LOGFILE 2>&1
  local sas_logon_pod_name=$(kubectl -n ${V4_CFG_NAMESPACE} get po -l app=sas-logon-app -o jsonpath='{.items[0].metadata.name}')
  EXT_CLIENT_REG_TOKEN=$(kubectl -n ${V4_CFG_NAMESPACE} exec ${sas_logon_pod_name} -c sas-logon-app -- \
    curl -s -k -X POST "https://sas-logon-app.${V4_CFG_NAMESPACE}.svc.cluster.local/SASLogon/oauth/clients/consul?callback=false&serviceId=${EXT_CLIENT_ID}" -H "X-Consul-Token: ${ACCESS_TOKEN}" | jq -r '.access_token')
}

# Register API Client
function registerExtClient {
  EXT_CLIENT_REG_DATA=$(jq --null-input \
    --arg client_id "$EXT_CLIENT_ID" \
    --arg client_secret "$VIYA_ADMIN_PASSWORD" \
    --arg scope "openid" \
    --arg authorized_grant_types "authorization_code" \
    --arg redirect_uri "urn:ietf:wg:oauth:2.0:oob" \
    --argjson access_token_validity 86400 \
    '{
"client_id": $client_id,
"client_secret": $client_secret,
"scope": $scope,
"authorized_grant_types": $authorized_grant_types,
"redirect_uri": $redirect_uri,
"access_token_validity": $access_token_validity
}')

  local sas_logon_pod_name=$(kubectl -n ${V4_CFG_NAMESPACE} get po -l app=sas-logon-app -o jsonpath='{.items[0].metadata.name}')
  echolog "[registerExtClient] sas-logon pod is $sas_logon_pod_name"
  kubectl -n ${V4_CFG_NAMESPACE} exec $sas_logon_pod_name -c sas-logon-app -- \
    curl -s -k -X POST "https://sas-logon-app.${V4_CFG_NAMESPACE}.svc.cluster.local/SASLogon/oauth/clients" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${EXT_CLIENT_REG_TOKEN}" \
    -d "${EXT_CLIENT_REG_DATA}" >>$LOGFILE 2>&1
}


function createAnsibleVars() {
  PG_PW=$(kubectl -n postgres get secret dbmsowner.platform-postgres.credentials.postgresql.acid.zalan.do -o jsonpath='{.data.password}' | /bin/base64 -d)
  PG_FQDN="platform-postgres.postgres.svc.cluster.local"
  
  
  # Create ansible-vars.yaml
  mkdir -p $HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}
  rm -f $HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/ansible-vars.yaml
  cat <<EOF >>$HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/ansible-vars.yaml
## ARM generated infrastructure
PROVIDER: azure
CLUSTER_NAME: ${AKS}
V4_CFG_RWX_FILESTORE_ENDPOINT: ${V4_CFG_RWX_FILESTORE_ENDPOINT}
V4_CFG_RWX_FILESTORE_PATH: ${V4_CFG_RWX_FILESTORE_PATH}

## Cluster
NAMESPACE: ${V4_CFG_NAMESPACE}

## MISC
DEPLOY: true
LOADBALANCER_SOURCE_RANGES: [ ${V4_CFG_LOADBALANCER_SOURCE_RANGES_INGRESS} ]
V4_CFG_SITEDEFAULT: $HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/site-config/sitedefault.yaml

## Storage
V4_CFG_MANAGE_STORAGE: true

## SAS API Access
V4_CFG_ORDER_NUMBER: ${V4_CFG_ORDER_NUMBER}
V4_CFG_CADENCE_NAME: ${V4_CFG_CADENCE_NAME}
V4_CFG_CADENCE_VERSION: "${V4_CFG_CADENCE_VERSION}"
V4_CFG_DEPLOYMENT_ASSETS: ${HOME}/assets.tgz
V4_CFG_LICENSE: ${HOME}/license.jwt
V4_CFG_CERTS: ${HOME}/deployments/${AKS}/${V4_CFG_NAMESPACE}/license/certs.zip

## Ingress
V4_CFG_INGRESS_TYPE: ingress
V4_CFG_INGRESS_FQDN: ${V4_CFG_INGRESS_FQDN}
V4_CFG_TLS_MODE: "full-stack" # [full-stack|front-door|disabled]
V4_CFG_TLS_GENERATOR: cert-manager

## LDAP
V4_CFG_EMBEDDED_LDAP_ENABLE: true

## Consul UI
V4_CFG_CONSUL_ENABLE_LOADBALANCER: false

## SAS/CONNECT
V4_CFG_CONNECT_ENABLE_LOADBALANCER: false

EOF


if [[ "$V4_CFG_INGRESS_FQDN" == *.cloudapp.azure.com* ]]; then
  echolog "[createAnsibleVars] V4_CFG_INGRESS_FQDN contains .cloudapp.azure.com"
  cat <<EOF >>$HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/ansible-vars.yaml
INGRESS_NGINX_CONFIG:
  controller:
    service:
      annotations:
        service.beta.kubernetes.io/azure-dns-label-name: ${V4_CFG_INGRESS_DNS_PREFIX}
EOF
else
  echolog "[createAnsibleVars] V4_CFG_INGRESS_FQDN does not contain .cloudapp.azure.com"
fi


  if [ -n "$STEP_CONFIGURE_POSTGRES_JSON" ]
  then
    yq -y -i ".+ {\"V4_CFG_POSTGRES_SERVERS\"}  | .V4_CFG_POSTGRES_SERVERS |= (.+ $STEP_CONFIGURE_POSTGRES_JSON )" $HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/ansible-vars.yaml
  else
    cat <<EOF >>$HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/ansible-vars.yaml
## Postgres
V4_CFG_POSTGRES_SERVERS:
  default:
    internal: true
EOF
  fi


  if [ "$STEP_CONFIGURE_LOGGING" == "Y" ] || [ "$STEP_CONFIGURE_MONITORING" == "Y" ]
  then
    cat <<EOF >>$HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/ansible-vars.yaml
## Monitoring and Logging
V4M_BASE_DOMAIN: ${V4_CFG_INGRESS_FQDN}
V4M_ROUTING: path-based
EOF
  fi


  if [ -n "$TLS_CERT_B64" ]
  then
    echo "$TLS_CERT_B64" | /bin/base64 -d > $HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/TLS_CERT
    cat <<EOF >>$HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/ansible-vars.yaml
## TLS PATH
V4_CFG_TLS_CERT: $HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/TLS_CERT
EOF
  fi

  if [ -n "$TLS_KEY_B64" ]
  then
    echo "$TLS_KEY_B64" | /bin/base64 -d > $HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/TLS_KEY
    cat <<EOF >>$HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/ansible-vars.yaml
## TLS PATH
V4_CFG_TLS_KEY: $HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/TLS_KEY
EOF
  fi

  if [ -n "$TLS_TRUSTED_CA_CERTS_B64" ]
  then
    echo "$TLS_TRUSTED_CA_CERTS_B64" | /bin/base64 -d > $HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/TLS_TRUSTED_CA_CERTS
    cat <<EOF >>$HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/ansible-vars.yaml
## TLS PATH
V4_CFG_TLS_TRUSTED_CA_CERTS: $HOME/deployments/${AKS}/${V4_CFG_NAMESPACE}/TLS_TRUSTED_CA_CERTS
EOF
  fi
}


function disableNonEssentialAppsRunTime(){
   # This step MUST run before the step disabling CAS, because sas-search requires CAS to start
  if [ "$STEP_DISABLE_NONESSENTIAL_APPS_RUN_TIME_FLAG" == "Y" ]
  then

      DEPLOYMENTS=()
      DEPLOYMENTS+=("openldap")
      DEPLOYMENTS+=("prometheus-pushgateway")
      DEPLOYMENTS+=("sas-annotations")
      DEPLOYMENTS+=("sas-app-registry")
      DEPLOYMENTS+=("sas-arke")
      DEPLOYMENTS+=("sas-audit")
      DEPLOYMENTS+=("sas-authorization")
      DEPLOYMENTS+=("sas-cas-control") #required by, at least, deployment/sas-search
      DEPLOYMENTS+=("sas-cas-operator") #required by, at least, deployment/sas-cas-control
      DEPLOYMENTS+=("sas-catalog-services")
      DEPLOYMENTS+=("sas-collaboration")
      DEPLOYMENTS+=("sas-compute")
      DEPLOYMENTS+=("sas-config-reconciler")
      DEPLOYMENTS+=("sas-configuration")
      DEPLOYMENTS+=("sas-connect")
      DEPLOYMENTS+=("sas-connect-spawner")
      DEPLOYMENTS+=("sas-content")
      DEPLOYMENTS+=("sas-credentials")
      DEPLOYMENTS+=("sas-credentials") #required by, at least, deployment/sas-risk-cirrus-rcc
      DEPLOYMENTS+=("sas-crunchy5-postgres-operator") #required by, at least, deployment/sas-identities
      DEPLOYMENTS+=("sas-data-server-operator")
      DEPLOYMENTS+=("sas-data-sources")
      DEPLOYMENTS+=("sas-deployment-data") #required by, at least, deployment/sas-studio
      DEPLOYMENTS+=("sas-environment-manager-app") 
      DEPLOYMENTS+=("sas-feature-flags") #required by, at least, deployment/sas-environment-manager-app
      DEPLOYMENTS+=("sas-files")
      DEPLOYMENTS+=("sas-file-store") #required by, at least, deployment/sas-cas-control
      DEPLOYMENTS+=("sas-geography")
      DEPLOYMENTS+=("sas-identities")
      DEPLOYMENTS+=("sas-job-execution")
      DEPLOYMENTS+=("sas-job-execution-app")
      DEPLOYMENTS+=("sas-job-flow-scheduling")
      DEPLOYMENTS+=("sas-landing-app")
      DEPLOYMENTS+=("sas-launcher")
      DEPLOYMENTS+=("sas-localization") #required by, at least, deployment/sas-environment-manager-app
      DEPLOYMENTS+=("sas-logon-app")
      DEPLOYMENTS+=("sas-natural-language-generation")
      DEPLOYMENTS+=("sas-opendistro-operator")
      DEPLOYMENTS+=("sas-preferences") #required by, at least, deployment/sas-environment-manager-app
      DEPLOYMENTS+=("sas-prepull")
      DEPLOYMENTS+=("sas-readiness")
      DEPLOYMENTS+=("sas-report-execution")
      DEPLOYMENTS+=("sas-report-services-group")
      DEPLOYMENTS+=("sas-transfer")
      DEPLOYMENTS+=("sas-web-assets")
      DEPLOYMENTS+=("sas-workflow-engine")
      DEPLOYMENTS+=("sas-workflow-history")
      DEPLOYMENTS+=("sas-workflow-manager-app")

      STATEFULSETS=()
      STATEFULSETS+=("sas-consul-server")
      STATEFULSETS+=("sas-rabbitmq-server")     

      echolog "[disableNonEssentialAppsRunTime] NOTE: Get access token for authorization rules creation"
      sas_logon_pod=$(kubectl get pods -n ${V4_CFG_NAMESPACE} -l app=sas-logon-app | grep sas-logon-app | awk '{print $1}')
      AUTH_RULES_ACCESS_TOKEN=$(kubectl -n ${V4_CFG_NAMESPACE} exec ${sas_logon_pod} -c sas-logon-app -- \
        curl -k -s -L -X POST "https://sas-logon-app.${V4_CFG_NAMESPACE}.svc.cluster.local/SASLogon/oauth/token" -H 'Accept: application/json' -H 'Content-Type: application/x-www-form-urlencoded' -H 'Authorization: Basic c2FzLmNsaTo=' -d 'grant_type=password' -d "username=viya_admin" -d "password=${VIYA_ADMIN_PASSWORD}" | jq -r ".access_token")

      for cirrus_solution in ${CIRRUS_SOLUTIONS[@]}
      do
        case $cirrus_solution in
          sas-risk-cirrus-mrm)
            echolog "[disableNonEssentialAppsRunTime] Adding deployments required for MRM solution"
            DEPLOYMENTS+=("sas-risk-cirrus-app")
            DEPLOYMENTS+=("sas-risk-cirrus-objects")
            DEPLOYMENTS+=("sas-risk-cirrus-builder")
            DEPLOYMENTS+=("sas-risk-cirrus-core")
            DEPLOYMENTS+=("sas-risk-data")

            if [[ "$V4_CFG_CADENCE_VERSION" < "2025.02" ]]; then
              echolog "[disableNonEssentialAppsRunTime] V4_CFG_CADENCE_VERSION cadence is prior 2025.02. Keeping cirrus deployments..."
              DEPLOYMENTS+=("sas-risk-cirrus-rcc")
              DEPLOYMENTS+=("sas-risk-cirrus-mrm")  
            fi
          ;;
        esac
      done

      REQUIRED_DEPLOYMENTS_JSON=$(jq -c -n '$ARGS.positional' --args "${DEPLOYMENTS[@]}" | jq -r "unique")
      echolog "[disableNonEssentialAppsRunTime] REQUIRED_DEPLOYMENTS_JSON: $REQUIRED_DEPLOYMENTS_JSON"
      CURRENT_DEPLOYMENTS_JSON=$(kubectl get deployments -n $V4_CFG_NAMESPACE -o json | jq -r "[.items[].metadata.name]")
      NONESSENTIAL_DEPLOYMENTS_JSON=$(jq -n --argjson arr1 "$REQUIRED_DEPLOYMENTS_JSON" --argjson arr2 "$CURRENT_DEPLOYMENTS_JSON" '  ($arr1 | reduce .[] as $item ({}; .[$item] = 1)) as $dict |  $arr2 | map(select($dict[.] == null))')
      echolog "[disableNonEssentialAppsRunTime] NONESSENTIAL_DEPLOYMENTS_JSON: $NONESSENTIAL_DEPLOYMENTS_JSON"

      NB_REPLICAS=0

      NONESSENTIAL_DEPLOYMENTS_JSON_LENGTH=$(echo "$NONESSENTIAL_DEPLOYMENTS_JSON" | jq -r "length")
      for ix_tmp in $(seq 1 $NONESSENTIAL_DEPLOYMENTS_JSON_LENGTH)
      do
        ix=$((ix_tmp-1))
        NONESSENTIAL_DEPLOYMENT=$(echo "$NONESSENTIAL_DEPLOYMENTS_JSON" | jq -r ".[$ix]")

        echolog "[disableNonEssentialAppsRunTime] Get the current deployment configuration of $NONESSENTIAL_DEPLOYMENT"
        kubectl get deployment $NONESSENTIAL_DEPLOYMENT -n $V4_CFG_NAMESPACE -o json > ${NONESSENTIAL_DEPLOYMENT}.json
        kubectl get deployment $NONESSENTIAL_DEPLOYMENT -n $V4_CFG_NAMESPACE -o jsonpath='{.metadata.annotations.kubectl\.kubernetes\.io/last-applied-configuration}' > ${NONESSENTIAL_DEPLOYMENT}_lastAppliedConfiguration.json

        # Modify last-applied-configuration by setting the number of replicas to $NB_REPLICAS
        jq ".spec.replicas=$NB_REPLICAS" ${NONESSENTIAL_DEPLOYMENT}_lastAppliedConfiguration.json > ${NONESSENTIAL_DEPLOYMENT}_lastAppliedConfiguration_Updated.json

        # Modify the deployment configuration by updating the last-applied-configuration
        tmp=$(mktemp)
        jq --arg input "$(jq -c . ${NONESSENTIAL_DEPLOYMENT}_lastAppliedConfiguration_Updated.json)" '.metadata.annotations["kubectl.kubernetes.io/last-applied-configuration"] = $input' "${NONESSENTIAL_DEPLOYMENT}.json" > "$tmp" && mv "$tmp" "${NONESSENTIAL_DEPLOYMENT}.json"
        # Set replicas to $NB_REPLICAS
        tmp=$(mktemp)
        jq ".spec.replicas=$NB_REPLICAS" "${NONESSENTIAL_DEPLOYMENT}.json" > "$tmp" && mv "$tmp" "${NONESSENTIAL_DEPLOYMENT}.json"

        echolog "[disableNonEssentialAppsRunTime] Patching $NONESSENTIAL_DEPLOYMENT deployment"
        kubectl patch deployment $NONESSENTIAL_DEPLOYMENT -n $V4_CFG_NAMESPACE --type=merge --patch-file=${NONESSENTIAL_DEPLOYMENT}.json

        #to hide elements from app switcher
        echolog "[disableNonEssentialAppsRunTime] Create auth rule to prohibit access to ingress corresponding to $NONESSENTIAL_DEPLOYMENT"
        NONESSENTIAL_SVC=$(kubectl get svc -A -o json | jq -r "
          .items[]
          | select(.metadata.annotations[\"sas.com/component-name\"] == \"$NONESSENTIAL_DEPLOYMENT\")
          | .metadata.name")

        echolog "Service associated with $NONESSENTIAL_DEPLOYMENT deployment is $NONESSENTIAL_SVC"

        NONESSENTIAL_INGRESS_PATH=$(kubectl get ingress -n $V4_CFG_NAMESPACE -o json | jq -r \
          --arg svc "$NONESSENTIAL_SVC" '
          .items[]
          | .spec.rules[]
          | .http.paths[]
          | select(.backend.service.name == $svc)
          | .path' | sort -u | sed -E 's/\(.*$//; s#/*$##; s#^$#/#; s#^.*#&/**#')
        
        echolog "[disableNonEssentialAppsRunTime] Inrgess rule path associated with $NONESSENTIAL_SVC service is $NONESSENTIAL_INGRESS_PATH"

        if [[ "$NONESSENTIAL_INGRESS_PATH" == /SAS* ]]; then
          echolog "[disableNonEssentialAppsRunTime] Creating auth rule for $NONESSENTIAL_DEPLOYMENT - Description is Deny access to application (Marketplace deployment)"
          jq -n -c --arg path "$NONESSENTIAL_INGRESS_PATH" '
            {
              "type":"prohibit",
              "objectUri": $path,
              "permissions":["read"],
              "principalType":"everyone",
              "principal":"",
              "condition":null,
              "description":"(Azure Marketplace deployment) Deny access to $NONESSENTIAL_INGRESS_PATH",
              "reason":null,
              "enabled":true,
              "version":1
            }' | kubectl -n ${V4_CFG_NAMESPACE} exec -i ${sas_logon_pod} -c sas-logon-app -- \
                  curl -k -s -L \
                  -X POST \
                  "https://sas-authorization.${V4_CFG_NAMESPACE}.svc.cluster.local/authorization/rules" \
                  -H "Content-Type: application/vnd.sas.authorization.rule+json" \
                  --header "Authorization: Bearer $AUTH_RULES_ACCESS_TOKEN" \
                  -d @-  || echo "TO DO: Check if the rule was created successfully"
        fi
      done

      function triggerAndWaitCronJob() {
        local namespace=$1
        local cronjobname=$2
        local timeout=$3
        local interval=$4

        local jobname=${cronjobname}-$(date +"%Y%m%d%H%M%S")
        local startTime=$(date +%s)

        if kubectl get cj $cronjobname  -n "$namespace"
        then
          kubectl create job "$jobname" --from cronjobs/${cronjobname} -n "$namespace"

          while true; do
            currentTime=$(date +%s)
            elapsedTime=$((currentTime - startTime))
            
            if [ $elapsedTime -ge $timeout ]; then
              echolog "[triggerAndWaitCronJob] Timeout reached: $timeout seconds. Exiting..."
              exit 1
            fi

            echolog "[triggerAndWaitCronJob] Waiting for ${cronjobname} cronjob to complete..."
            if ! kubectl wait -n ${namespace} --for=condition=complete --timeout=10s job/${jobname}; then 
              echolog "[triggerAndWaitCronJob] Retrying in $interval seconds..."
              sleep $interval
            else  
              echolog "[triggerAndWaitCronJob] Job $jobname completed. Proceeding..."
              break
            fi
          done
        else
          echolog "[triggerAndWaitCronJob] ${cronjobname} cron job is not present in the $namespace namespace. Aborting..."
          exit 1
        fi
      }

      echolog "[disableNonEssentialAppsRunTime] Trigger sas-stop-all cron job"
      triggerAndWaitCronJob "$V4_CFG_NAMESPACE" "sas-stop-all" 3600 20

      # Now we will delete all nodes but one.
      if [ "$NONESSENTIAL_DEPLOYMENTS_JSON_LENGTH" -le 0 ]; then
        echolog "[disableNonEssentialAppsRunTime] No deployments to be scaled down. Skipping node draining..."
      else
        MAX_NB_NODES=$(kubectl get nodes -l workload.sas.com/class=compute -o name | wc -l)
        NODES_TO_DRAIN=$((MAX_NB_NODES - 1))
        
        echolog "[disableNonEssentialAppsRunTime] Preparing to drain and delete $NODES_TO_DRAIN node(s)..."

        # Get list of eligible nodes
        NODES=$(kubectl get nodes -l workload.sas.com/class=compute -o name | head -n "$NODES_TO_DRAIN")

        for node in $NODES; do
          echolog "[disableNonEssentialAppsRunTime] Draining node $node"
          kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --grace-period=60 --timeout=300s

          if [ $? -eq 0 ]; then
            echolog "[disableNonEssentialAppsRunTime] Drain completed for $node. Deleting..."
            kubectl delete "$node"
          else
            echolog "[disableNonEssentialAppsRunTime] Drain failed for $node. Skipping deletion."
          fi
        done
      fi

      echolog "[disableNonEssentialAppsRunTime] Trigger sas-start-all cron job"
      triggerAndWaitCronJob "$V4_CFG_NAMESPACE" "sas-start-all" 3600 60
     
  fi
}


#####################################################################
# Script
#####################################################################

echolog "Starting Deployment of Viya solution ..."

if [ "$STEP_CONFIGURE_LOGGING" == "Y" ] || [ "$STEP_CONFIGURE_MONITORING" == "Y" ]
then
  if [ -e /bin/busybox ]; then
    echolog "Running on BusyBox"
    echolog "Adding function to 'hack' base64 --decode on busybox"
    
    # the first blank line is required
    cat <<EOF >> ~/.bashrc

  function base64 {
    if [ "$1" = "--decode" ]; then
      shift
      while read -r input; do
        echo "$input" | /bin/base64 -d "$@"
      done
    else
      /bin/base64 "$@"
    fi
  }
EOF
    echolog "Sourcing .bashrc"
    source ~/.bashrc
  fi
fi

# az login
wait_for_fn_result azLoginIdentity

# Set Azure subscription
wait_for_fn_result setAzureSubscription

# Check the existence of external Postgres
wait_for_fn_result checkExternalPostgres

# Download kubectl
wait_for_fn_result downloadKubectl
chmod u+x /usr/local/bin/kubectl

if [ "${IS_UPDATE}" == "True" ]; then
  apk -U add curl
  CURRENT_OUTBOUND_IP=$(curl ipinfo.io/ip)
  CURRENT_IPS=$(az aks show \
    --resource-group "$RG" \
    --name "$AKS" \
    --query "apiServerAccessProfile.authorizedIpRanges" \
    -o tsv | tr '\n' ',')
  
  echolog "Found current IPs of ${CURRENT_IPS}"
  if [[ -z "$CURRENT_IPS" ]]; then
    MERGED="$CURRENT_OUTBOUND_IP"
  else
    if [[ "${CURRENT_IPS: -1}" == "," ]]; then
      CURRENT_IPS="${CURRENT_IPS%,}"
    fi
    # Check if IP already exists
    if echo "$CURRENT_IPS" | grep -qw "$CURRENT_OUTBOUND_IP"; then
      echolog "IP $CURRENT_OUTBOUND_IP is already authorized. Nothing to do."
      exit 0
    fi
    MERGED="$CURRENT_IPS,$CURRENT_OUTBOUND_IP"
  fi
  echolog "Updating current AKS API server authorized IP ranges to: $MERGED"

  az aks update \
    --resource-group "$RG" \
    --name "$AKS_NAME" \
    --api-server-authorized-ip-ranges "$MERGED" >>$LOGFILE 2>&1

  echolog "Successfully updated AKS API server authorized IP ranges."
fi

# Get managed users Kubeconfig
wait_for_fn_result getKubeconfig

# getStorageAccountKey
wait_for_fn_with_str_result getStorageAccountKey STORAGE_ACCOUNT_KEY

# Download NFS VM Private Key
if [ "${IS_UPDATE}" != "True" ]; then
  wait_for_fn_result downloadNfsVmPrivateKey
fi

if [ "${IS_UPDATE}" == "True" ]; then
  LDAP_CONFIG_MAP_NAME=$(kubectl -n ${V4_CFG_NAMESPACE} get configmaps -o json | jq '.items | sort_by(.metadata.creationTimestamp) | reverse | .[].metadata.name | select(test("openldap-bootstrap-config"; "i"))' --raw-output | head -n 1)
  LDAP_ADMIN_PASSWORD=$(kubectl -n ${V4_CFG_NAMESPACE} get configmap ${LDAP_CONFIG_MAP_NAME} -o jsonpath='{.data.LDAP_ADMIN_PASSWORD}')
fi

# Create Viya namespace
wait_for_fn_result createViyaNamespace

# Download kustomize tool
wait_for_fn_result downloadKustomize
tar -zxvf /tmp/kustomize.tgz -C /usr/local/bin
chmod u+x /usr/local/bin/kustomize

# Download Helm
wait_for_fn_result downloadHelm
cd /tmp
tar -zxvf helm.tgz
mv linux-amd64/helm /usr/local/bin/helm
chmod u+x /usr/local/bin/helm

# Install tar tool
wait_for_fn_result downloadTar

# Install yq tool
wait_for_fn_result downloadYq

# Clone Viya4-deployment (DAC)
wait_for_fn_result cloneViya4Deployment

# Checkout the correct version of DAC
wait_for_fn_result checkoutViya4Deployment

# Temp fix until we discuss with DAC team about settings homedirs
wait_for_fn_result modify_nfs_mounts

# Install packages
wait_for_fn_result v4dInstallPackages

# Install collections
wait_for_fn_result v4dInstallCollections

echolog "---"
if [ -n "${VIYA_ORDER_SAS_URI}" ]
then
  echolog "A Blob storage URI has been provided for SAS Viya Order. Using it for deployment...."
  curl -s -o /mnt/azscripts/order.zip "$VIYA_ORDER_SAS_URI"
  unzip -o /mnt/azscripts/order.zip -d /mnt/azscripts/order/
  # extract cadence from jwt
  cp /mnt/azscripts/order/*.tgz ${HOME}/assets.tgz
  cp /mnt/azscripts/order/*.jwt ${HOME}/license.jwt

  mkdir -p ${HOME}/deployments/${AKS}/${V4_CFG_NAMESPACE}/license
  cp /mnt/azscripts/order/*.zip ${HOME}/deployments/${AKS}/${V4_CFG_NAMESPACE}/license/certs.zip
  

  # extract order number, cadence name and version from jwt
  jwt_b64=$(cat ${HOME}/license.jwt)
  IFS='.' read -r header payload signature <<< "$jwt_b64"
  PADDING=$(( (4 - ${#payload} % 4) % 4 ))
  payload="${payload}$(printf '=%.0s' $(seq 1 $PADDING))"
  jwt_payload=$(echo "$payload" | /bin/base64 -d)
  export V4_CFG_ORDER_NUMBER=$(echo "$jwt_payload" | jq -r '.license_payload.orderNumber')
  export V4_CFG_CADENCE_NAME=$(echo "$jwt_payload" | jq -r '.license_payload.cadence.name')
  export V4_CFG_CADENCE_VERSION=$(echo "$jwt_payload" | jq -r '.license_payload.cadence.version')
  export V4_CFG_CADENCE_YEAR=$(echo "$V4_CFG_CADENCE_VERSION" | cut -d'.' -f1)
  export V4_CFG_CADENCE_MONTH=$(echo "$V4_CFG_CADENCE_VERSION" | sed 's/\./_/')

  echolog "V4_CFG_ORDER_NUMBER=${V4_CFG_ORDER_NUMBER}"
  echolog "V4_CFG_CADENCE_NAME=${V4_CFG_CADENCE_NAME}"
  echolog "V4_CFG_CADENCE_VERSION=${V4_CFG_CADENCE_VERSION}"
  echolog "V4_CFG_CADENCE_YEAR=${V4_CFG_CADENCE_YEAR}"
  echolog "V4_CFG_CADENCE_MONTH=${V4_CFG_CADENCE_MONTH}"
else
  echolog "No Blob storage URL for SAS Viya Order was provided. Aborting..."
  exit 1
fi


wait_for_fn_result retrieveNFSServerInfo
wait_for_fn_result retrieveJumpServerInfo

# get V4_CFG_LOADBALANCER_SOURCE_RANGES_INGRESS
wait_for_fn_result getIngressLoadBalancerSourceRanges

# Set Ingress DNS Label
wait_for_fn_result setIngressDns
# Commented out setIngressDns as changing the defaults in main.yaml didn't work
# now we are adding the annotation azure-dns-label-name to add DNS createAnsibleVars function

# Unzip all the files
wait_for_fn_result unzipViya4Manifests

# We can comment this out since we are using azure flexible server
# wait_for_fn_result installPostgres



wait_for_fn_result createAnsibleVars

# Install Viya baseline
wait_for_fn_result v4dInstallBaseline

# Helm add niginx
wait_for_fn_result addNginxRepo

# Helm add bitnami
wait_for_fn_result addBitnamiRepo

# Helm add superset
wait_for_fn_result addSupersetRepo

# Update helm repos
wait_for_fn_result updateHelmRepo

# Apply all the Viya manifests
applyViya4Manifests
echolog "[applyViya4Manifests] SUCCESS."
echolog

# Zip the assets back up again
# Upload the assets
wait_for_fn_result zipDeployAssets
wait_for_fn_result uploadDeployAssets

# Install Viya ->here<-
wait_for_fn_result v4dInstallViya

wait_for_fn_result v4dInstallLoggingMonitoring

if [ "$STEP_DEPLOY_PGADMIN_FLAG" == "Y" ]
then
  wait_for_fn_result createPgadminNamespace
  wait_for_fn_result deployPgadmin
fi

# Zip the assets back up again
# Upload the assets again (if modified)
wait_for_fn_result zipDeployAssets
wait_for_fn_result uploadDeployAssets


# Deployment of Superset
wait_for_fn_result createSupersetNamespace
wait_for_fn_result deploySuperset

#Fix Viya Admin
wait_for_fn_result fixViyaAdmin

# Register Ext Client
wait_for_fn_with_str_result getAccessToken ACCESS_TOKEN
wait_for_fn_with_str_result getExtClientRegistrationToken EXT_CLIENT_REG_TOKEN
wait_for_fn_result registerExtClient

# Clean up and output for template
# Delete NFS VM Private Key
if [ "${IS_UPDATE}" != "True" ]; then
  wait_for_fn_result deleteNfsVmPrivateKey
fi

# Get Viya Cadence Release, but don't error out if we don't find it.
getViyaCadenceRelease

# Get Viya CA certificate
wait_for_fn_with_str_result getViyaCaCertificate V4_CA_CERTIFICATE_BASE64
wait_for_fn_result genViyaCaCertificateFile

# Get the Ingress IP
wait_for_fn_with_ip_result getIngressIp V4_INGRESS_IP

V4_CAS_IP="0.0.0.0"


# Create home directoy
if [ "${IS_UPDATE}" != "True" ]; then
  wait_for_fn_result homeDir
fi

wait_for_fn_result updateSpecCirrusDeployments
wait_for_fn_result waitForCirrusDeployments

wait_for_fn_result addUsers

# Load Cirrus Data
if [ "${IS_UPDATE}" != "True" ]; then
  wait_for_fn_result loadCirrusData
fi

wait_for_fn_result disableNonEssentialAppsRunTime
wait_for_fn_result disableCAS

# Zip the assets back up again
# Upload the assets (again, if modified), outputs, certs and logswait_for_fn_result zipDeployAssets
wait_for_fn_result uploadDeployAssets
# wait_for_fn_result uploadOutputs
wait_for_fn_result uploadCaCertificate
wait_for_fn_result uploadLogfile

echolog "---"
# lock down AKS API Server and Storage Account if we need to
if [ "${USE_IP_ALLOWLIST}" == "True" ]; then
  if [ "${IS_UPDATE}" != "True" ]; then
    echolog "USE_IP_ALLOWLIST=${USE_IP_ALLOWLIST}, locking down deployment..."
    applyAllowlist
    echolog "Allow list applied..."
  else
    echolog "Get current list of authorized IPs"
    CURRENT_IPS=$(az aks show \
      --resource-group "$RG" \
      --name "$AKS" \
      --query "apiServerAccessProfile.authorizedIPRanges" \
      -o tsv | tr '\t' ',')

    if [[ -z "$CURRENT_IPS" ]]; then
      echolog "No authorized IPs are currently set. Nothing to remove."
    else
      echolog "Current authorized IPs: $CURRENT_IPS"
      if [ -n "$DS_IP" ]; then
        echolog "Removing DS_IP: $DS_IP"
        # Convert to array and filter out REMOVE_IP
        NEW_IPS=$(echo "$CURRENT_IPS" | tr ',' '\n' | grep -vw "$DS_IP" | paste -sd "," -)

        if [[ "$NEW_IPS" == "$CURRENT_IPS" ]]; then
          echolog "IP $DS_IP not found in the current list. Nothing to do."
        fi

        echolog "Updating authorized IP ranges: $NEW_IPS"

        az aks update \
          --resource-group "$RG" \
          --name "$AKS" \
          --api-server-authorized-ip-ranges "$NEW_IPS"
      else
        echolog "DS_IP is empty. Nothing to do."
      fi
    fi
  fi
else
  echolog "USE_IP_ALLOWLIST=${USE_IP_ALLOWLIST}, so we won't lock down deployment."
fi


# Write output
RESULT="{"
RESULT+="\"v4CfgCadence\":\"${V4_CFG_CADENCE}\""
RESULT+=",\"v4IngressIp\":\"${V4_INGRESS_IP}\""
RESULT+=",\"v4CaCertificateBase64\":\"${V4_CA_CERTIFICATE_BASE64}\""
RESULT+=",\"v4CasIp\":\"${V4_CAS_IP}\""
RESULT+="}"
echo "$RESULT" >$AZ_SCRIPTS_OUTPUT_PATH

echolog "---"
echolog "Sleep few seconds"
sleep 10

echolog "Exit successfully"
exit 0