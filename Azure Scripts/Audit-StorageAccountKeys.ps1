<#
.SYNOPSIS
    Audits Azure Storage Account Keys
.DESCRIPTION
    Audits Azure Storage Account Keys. If the storage account has a key older than x days
    it will be outputed as the result of the script.
.PARAMETER subscriptionName
    The azure subscription name where the storage accounts reside
.PARAMETER olderthandays
    The creation date should be less then the amount of days provided in order to not appear in the report
.EXAMPLE
    C:\PS>
    .\Audit-StorageAccountKeys.ps1 -subscriptionName xxxxxxx -olderthandays 365
.INPUTS
    None
.OUTPUTS
    In case of non-compliance
    storage account name
    key 1 status
    key 2 status
.NOTES
    Version:        1.0
    Author:         Mr-Scripting
    Creation Date:  26/05/2022
    Purpose/Change: Initial script development
.FUNCTIONALITY
    This script is aimed for auditing storage account keys age
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)][string]$subscriptionName,
    [Parameter()][int]$olderthandays = 365
)
# Check if requirements are in place
$modules = @("Az.Accounts", "Az.Storage")

# Initialize variables
$keys = @()
$outdatedKeys = @()
$currentDate = Get-Date

Write-Host "Checking if necessary modules are installed..."
foreach ($mod in $modules)
{
    $check = Get-InstalledModule -Name $mod -ErrorAction SilentlyContinue
    if (!$check)
    {
        Write-Warning "Please install the powershell module $mod and try again."
        exit
    }
}
Write-Host "All requirements in place!"

# Connects to Azure using device authentication
Write-Host "Connecting to subscription..."
Connect-AzAccount -UseDeviceAuthentication -SubscriptionName $subscriptionName | Out-Null
Write-Host "Done!"

# Lists all the storage accounts in the subscription
# ? Maybe I should include an option to check a single storage account
Write-Host "Getting storage accounts in the subscription..."
$storageAccounts = Get-AzStorageAccount -ErrorAction SilentlyContinue
Write-Host "Done!"

# Iterates through the storage accounts object and stores the creation time property in a new array for later use
Write-Host "Getting keys from storage accounts"
foreach ($storage in $storageAccounts)
{
    $key = Get-AzStorageAccountKey -ResourceGroupName $storage.ResourceGroupName -Name $storage.StorageAccountName -ErrorAction SilentlyContinue
    if ($key)
    {
        $keys += [pscustomobject] @{
            StorageAccountName = $storage.StorageAccountName
            key1Creation       = $key[0].CreationTime
            key2Creation       = $key[1].CreationTime
        }
    }
    Write-Host "Processed storage account" $storage.StorageAccountName
}

# Here we are checking if the creation date is older than the provided number of days or in case we don't have creation
# date then mention to that will be made and the user will have to check manually in the portal
Write-Host "Checking the keys age..."
foreach ($key in $keys)
{
    $key1 = if ($null -ne $key.key1Creation)
    {
        if ($(New-TimeSpan –Start $key.key1Creation –End $currentDate).days -ge $olderthandays)
        {
            "Older than " + $olderthandays + " - " + $key.key1Creation
        }
        else
        {
            "ok"
        }

    }
    else
    {
        "It was not possible to get the key creation date. Please check!"
    }
    $key2 = if ($null -ne $key.key2Creation)
    {
        if ($(New-TimeSpan –Start $key.key2Creation –End $currentDate).days -ge $olderthandays -and $null -ne $key.key2Creation)
        {
            "Older than " + $olderthandays + " - " + $key.key2Creation
        }
        else
        {
            "ok"
        }
    }
    else
    {
        "It was not possible to get the key creation date. Please check!"
    }

    if ($key1 -ne "ok" -or $key2 -ne "ok")
    {
        $outdatedKeys += [pscustomobject] @{
            StorageAccountName = $key.StorageAccountName
            Key1Status         = $key1
            key2Status         = $key2
        }
    }
}
Write-Host "Finished processing all the keys"

Write-Host "Here's the report:"
$outdatedKeys