#!/bin/bash
: '
.SYNOPSIS
    This bash script leverages rclone to backup a linux source folder or filesystem to azure blob storage
.DESCRIPTION
    This bash script leverages rclone to backup a linux source folder or filesystem to azure blob storage.
    Its mainly for personal use and a great solution for backing up NAS or other home storage solutions.
.PARAMETER name
    The name that we will assign to the rclone configuration.
.PARAMETER credential_file
    Path for the azure Cli generated credentials file.
.PARAMETER storageaccountname
    The Azure Storage Account Name.
.PARAMETER resourcegroupname
    The resource Group Name where the Azure Storage Account resides.
.PARAMETER subscriptionid
    The Azure subscription ID.
.PARAMETER accesstier
    The desired storage account accesstier for the backed up files.
.PARAMETER accesstier
    The desired storage account accesstier for the backed up files.
.PARAMETER sourcepath
    The filesystem path in which the files to be backed up reside.
.PARAMETER container
    The Azure Storage account container name.
.EXAMPLE
    ./linuxFSAzureBackup.sh  -n "azureBackup" -k "/home/pi/azurecredentials.json" -s "storageaccountxxxx" -r "resourcegroupxxxx" -i "xxxxx-xxx-xxxxx-xxxx-xxxxxxxxxx" -a "Archive" -p "/mnt" -c "backup"
.INPUTS
    Please check parameters
.OUTPUTS
    Outputs the file names of the files being copied to azure storage
.NOTES
    This script is offered as is. If you find any issue please open a github issue and I will try to fix it as soon as possible.
.FUNCTIONALITY
    This script is a backup script written in bash and it aims to be a secure cloud backup solution for linux home devices.
'

# Parameters structure from "Rafael Muynarsk" -> https://unix.stackexchange.com/q/31414
helpFunction() {
    echo ""
    echo "Usage: $0 -n name -k credential_file -s storageaccountname -r resourcegroupname -i subscriptionid -a accesstier -p sourcepath -c container"
    echo -e "\t-n The name that we will assign to the rclone configuration"
    echo -e "\t-k Path for the azure Cli generated credentials file"
    echo -e "\t-s The Azure Storage Account Name"
    echo -e "\t-r The resource Group Name where the Azure Storage Account resides"
    echo -e "\t-i The Azure subscription id"
    echo -e "\t-a The desired storage account accesstier for the backed up files"
    echo -e "\t-p The path where the items to be backed up reside"
    echo -e "\t-c The Azure Storage account container name"
    exit 1 # Exit script after printing help
}

while getopts "n:k:s:r:i:a:p:c:" opt; do
    case "$opt" in
    n) name="$OPTARG" ;;
    k) credential_file="$OPTARG" ;;
    s) storageaccountname="$OPTARG" ;;
    r) resourcegroupname="$OPTARG" ;;
    i) subscriptionid="$OPTARG" ;;
    a) accesstier="$OPTARG" ;;
    p) sourcepath="$OPTARG" ;;
    c) container="$OPTARG" ;;
    ?) helpFunction ;; # Print helpFunction in case parameter is non-existent
    esac
done

# Print helpFunction in case parameters are empty
if [ -z "$name" ] || [ -z "$credential_file" ] || [ -z "$storageaccountname" ] || [ -z "$resourcegroupname" ] || [ -z "$subscriptionid" ] || [ -z "$accesstier" ] || [ -z "$sourcepath" ] || [ -z "$container" ]; then
    echo "Some or all of the parameters are empty"
    echo "$container"
    helpFunction
fi

# Functions
getPublicIp() {
    curl checkip.amazonaws.com
}
getAzureToken() {
    client_id=$1
    client_secret=$2
    tenant=$3
    scope="https%3A%2F%2Fmanagement.core.windows.net%2F.default"
    headers="Content-Type:application/x-www-form-urlencoded"
    data1="client_id=${client_id}&scope=${scope}&client_secret=${client_secret}&grant_type=client_credentials"
    data2="https://login.microsoftonline.com/${tenant}/oauth2/v2.0/token"
    curl -X POST -H $headers -d $data1 $data2
}

addNetworkException() {
    token=$1
    subscriptionId=$2
    resourceGroupName=$3
    accountName=$4
    publicIp=$5

    headers1="Content-Type:application/json"
    headers2="Authorization:Bearer ${token}"
    url="https://management.azure.com/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.Storage/storageAccounts/${accountName}?api-version=2021-09-01"
    data="{\"properties\":{\"networkAcls\":{\"defaultAction\":\"deny\",\"ipRules\":[{\"action\":\"allow\",\"value\":\"${publicIp}\"}]}}}"
    curl -X PATCH -H "$headers1" -H "$headers2" -d "$data" "$url"
}

removeNetworkException() {
    token=$1
    subscriptionId=$2
    resourceGroupName=$3
    accountName=$4
    publicIp=$5

    headers1="Content-Type:application/json"
    headers2="Authorization:Bearer ${token}"
    url="https://management.azure.com/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.Storage/storageAccounts/${accountName}?api-version=2021-09-01"
    data="{\"properties\":{\"networkAcls\":{\"defaultAction\":\"deny\",\"ipRules\":[]}}}"
    curl -X PATCH -H "$headers1" -H "$headers2" -d "$data" "$url"
}

rclone_config() {
    echo 'Adding configuration...'
    rclone config create "$name" azureblob account="$storageaccountname" access_tier="$accesstier" service_principal_file="$credential_file"
    echo 'Config entry added!'
}

rclone_backup() {
    echo 'Starting backup...'
    rclone sync "$sourcepath" "$name":"$container" "--azureblob-archive-tier-delete" "-v"
    if [ $? -eq 0 ]; then
        echo 'Backup completed!'
    else
        echo 'Something went wrong!'
        exit 1
    fi
}
# End of Functions

# Start Script
## Check if requirements are in place

APTDir="/etc/apt/sources.list.d"
DNFDir="/etc/dnf"
YUMDir="/etc/yum.repos.d"
ZIPPDir="/etc/zypp"
PACMANDir="/etc/pacman.d"

if [ -d "$APTDir" ]; then
    checkRcloneInstall+=$(apt-cache policy rclone | grep -v "Installed: (none)")
    checkJQInstall+=$(apt-cache policy jq | grep -v "Installed: (none)")
fi

if [ -d "$DNFDir" ]; then
    checkRcloneInstall+=$(dnf list installed | grep ^rclone)
    checkJQInstall+=$(dnf list installed | grep ^jq)
fi

if [ -d "$YUMDir" ]; then
    checkRcloneInstall+=$(yum list installed | grep ^rclone)
    checkJQInstall+=$(yum list installed | grep ^jq)
fi

if [ -d "$ZIPPDir" ]; then
    checkRcloneInstall+=$(zypper search -i rclone)
    checkJQInstall+=$(zypper search -i jq)
fi

if [ -d "$PACMANDir" ]; then
    checkRcloneInstall+=$(pacman -Qi rclone)
    checkJQInstall+=$(pacman -Qi jq)
fi

if [ -z "$checkRcloneInstall" ] && [ -z "$checkJQInstall" ]; then
    echo "$checkRcloneInstall"
    echo "$checkJQInstall"
    echo 'Dependencies not installed. Please install rclone and jq before executing this script!' >&2
    exit
else
    echo 'rclone and jq installed. Proceeding script execution.'
fi

## Gets the public ip address in order to use in the network exeption configuration
echo "Getting the public ip address..."
publicIp=$(getPublicIp)
echo "Done!"

## Retrives credentials from the json credentials file produced by azure cli
echo "Importing credentials file..."
credentials=$(cat "$credential_file")
echo "Done!"

client_id=$(jq -j '.appId' <<<"$credentials")
client_secret=$(jq -j '.password' <<<"$credentials")
tenant=$(jq -j '.tenant' <<<"$credentials")

## Generates authentication azure token for http requests
echo "Generating token for authentication..."
azureToken=$(jq -j '.access_token' <<<"$(getAzureToken "$client_id" "$client_secret" "$tenant")")
echo "Done!"

## Adds a network ip exception in the azure storage
echo "Adding network exception for ip $publicIp ..."
addNetworkException "$azureToken" "$subscriptionid" "$resourcegroupname" "$storageaccountname" "$publicIp"
echo "Done!"

## Checks for empty configuration. If empty configuration then a configuration is created and backup is executed
config=$(rclone config dump)
if [ -z "$config" ]; then
    rclone_config
    rclone_backup
else
    rclone_backup
fi

## Removes the previously added network exception for our public ip
echo "Removing network exception for ip $publicIp ..."
removeNetworkException "$azureToken" "$subscriptionid" "$resourcegroupname" "$storageaccountname" "$publicIp"
echo "Done!"
