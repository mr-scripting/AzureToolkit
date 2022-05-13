<#
.SYNOPSIS
    Generates a IAM report for a given subscription
.DESCRIPTION
    Generates an Excel report containing the IAM permissions for the resource groups and resources contained in the Azure Subscription
.PARAMETER subscriptionName
    The azure subscription name
.PARAMETER folder
    The folder where you wish to store the report
.PARAMETER format
    Specifies the report format. The options are csv (comma delimited values) or xlsx (Excel format)
.EXAMPLE
    C:\PS>
    .\Export-SubscriptionIAMReport.ps1 -subscriptionName xxxxxxx -folder c:\windows\temp -format csv
.INPUTS
    None
.OUTPUTS
    CSV or XLSX file
.NOTES
    Version:        1.0
    Author:         Mr-Scripting
    Creation Date:  13/05/2022
    Purpose/Change: Initial script development
.FUNCTIONALITY
    This script is aimed for azure permission governance
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)][string]$subscriptionName,
    [Parameter(Mandatory)][ValidateScript({
            if (-Not ($_ | Test-Path) )
            {
                throw "folder does not exist"
            }
            return $true
        })]
    [string]$folder,
    [Parameter(Mandatory)][string][ValidateSet("csv", "xlsx")]$format = "csv"
)

# Functions
function checkConnection
{
    $test = Get-AzContext -ErrorAction SilentlyContinue
    if ($test.Subscription)
    {
        $connected = $true
    }
    if (!$connected.Subscription)
    {
        $connected = $false
    }
    return $connected, $test.Subscription.Id
}

# Connects to azure subscription
$connected = $(checkConnection)[0]
$subscriptionID = $(checkConnection)[1]
if (!$connected)
{ Write-Host "Connecting to Azure..."
    Connect-AzAccount -UseDeviceAuthentication -SubscriptionName $subscriptionName | Out-Null
    Set-AzContext -SubscriptionName $subscriptionName | Out-Null
    $subscriptionID = $(checkConnection)[1]
    Write-Host "Connection established! "
}

# Gets the IAM permissions from resources
Write-Host "Getting IAM permissions for each resource..."
$scope = "/subscriptions/" + $subscriptionID
$roleAssignments = Get-AzRoleAssignment -Scope $scope
Write-Host "Done!"

# Export the report to chosen format
if ($roleAssignments)
{
    switch ($format)
    {
        csv
        {
            Write-Host "Creating CSV..."
            $outputFile = $folder + "\Azure-IAM-Report.csv"
            $roleAssignments | Export-Csv -Path $outputFile -NoTypeInformation
            Write-Host "CSV file created on" $outputfile
            break
        }
        xlsx
        {
            # Check requirements
            $module = Get-InstalledModule -ErrorAction SilentlyContinue
            if (!$module)
            {
                Write-Host "Installing module requirements..."
                Install-Module ImportExcel -Scope CurrentUser -Force
                Write-Host "Done!"
            }
            Write-Host "Creating XLSX..."
            $outputFile = $folder + "\Azure-IAM-Report.xlsx"
            $roleAssignments | Export-Excel -Path $outputFile
            Write-Host "XLSX file created on" $outputfile
            break
        }
        Default {}
    }
}