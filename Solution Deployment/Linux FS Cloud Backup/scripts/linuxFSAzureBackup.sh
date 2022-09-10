#!/bin/bash
: '
.SYNOPSIS
    This bash script leverages rclone to backup a linux source folder or filesystem to azure blob storage
.DESCRIPTION
    This bash script leverages rclone to backup a linux source folder or filesystem to azure blob storage.
    Its mainly for personal use and a great solution for backing up NAS or other home storage solutions.
.PARAMETER Path
    Specifies a path to one or more locations.
.PARAMETER LiteralPath
    Specifies a path to one or more locations. Unlike Path, the value of LiteralPath is used exactly as it
    is typed. No characters are interpreted as wildcards. If the path includes escape characters, enclose
    it in single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any
    characters as escape sequences.
.PARAMETER InputObject
    Specifies the object to be processed.  You can also pipe the objects to this command.
.EXAMPLE
    ./linuxFSAzureBackup.sh  -n "azureBackup" -k "/home/pi/azurecredentials.json" -s "storageaccountxxxx" -r "resourcegroupxxxx" -i "xxxxx-xxx-xxxxx-xxxx-xxxxxxxxxx" -a "Archive" -p "/mnt" -c "backup"
.INPUTS
    Inputs to this cmdlet (if any)
.OUTPUTS
    Output from this cmdlet (if any)
.NOTES
    General notes
.COMPONENT
    The component this cmdlet belongs to
.ROLE
    The role this cmdlet belongs to
.FUNCTIONALITY
    The functionality that best describes this cmdlet
'

# Parameters structure from "Rafael Muynarsk" -> https://unix.stackexchange.com/q/31414
helpFunction() {
    echo ""
    echo "Usage: $0 -n name -k credential_file -s storageaccountname -r resourcegroupname -i subscriptionid -a accesstier -p sourcepath -c container"
    echo -e "\t-n Description of what is name"
    echo -e "\t-k Path for the azure Cli generated credentials file"
    echo -e "\t-s The Azure Storage Account Name"
    echo -e "\t-r The resource Group Name where the Azure Storage resides"
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
## Check requirements
checkRcloneInstall=$(apt-cache policy rclone)
rcloneInstalled=$(echo "$checkRcloneInstall" | grep "Installed: (none)")

if [ ! -z "$rcloneInstalled" ]; then
    echo 'rclone is not installed. Please install it before executing this script!' >&2
    exit
else
    echo 'rclone is installed. Proceeding script execution.'
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
if [ ! -z "$config" ]; then
    rclone_config
    rclone_backup
else
    rclone_backup
fi

## Removes the previously added network exception for our public ip
echo "Removing network exception for ip $publicIp ..."
removeNetworkException "$azureToken" "$subscriptionid" "$resourcegroupname" "$storageaccountname" "$publicIp"
echo "Done!"
