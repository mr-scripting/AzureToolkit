<#
.SYNOPSIS
    Script that creates resource groups and adds tags to them
.DESCRIPTION
    This script automates the creation of resource groups in Azure
.PARAMETER resourceGroups
    The array list containing the resource group names
.PARAMETER location
    The string variable for the location of the resource groups
.PARAMETER tags
    An hashtable containing the tags for the resource groups
.PARAMETER append
    Switch parameter specifying the addition of new tags to the existing ones
.EXAMPLE
    C:\PS>$tags = @{"Company"="MetaCortex"; "Manager"="Mr. Rhineheart","Developer"="Thomas A. "Tom" Anderson"}
    C:\PS> $resourcegroups = @("Accounting","Research","Sales")
    C:\PS> .\Add-ResourceGroups.ps1 -resourceGroups $resourcegroups -location westeurope -tags $tags
.OUTPUTS
    Resource group creation or update status
.NOTES
    Version:        1.0
    Author:         Mr-Scripting
    Creation Date:  06/06/2022
    Purpose/Change: Initial script development
.FUNCTIONALITY
    This script is aimed for easy creation and maintenance of resource groups and tags
#>

[CmdletBinding()]
param (
    [Parameter(Position = 1, Mandatory = $true)][array]$resourceGroups,
    [Parameter(Position = 3, Mandatory = $true)][hashtable]$tags,
    [Parameter(Position = 4)][switch]$append
)
DynamicParam
{
    #create a new ParameterAttribute Object
    $location = New-Object System.Management.Automation.ParameterAttribute
    $location.Position = 2
    $location.Mandatory = $true
    $location.HelpMessage = "Please enter the resource group location"

    #create an attributecollection object for the attribute we just created.
    $locationAttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]

    # Get the allowed locations
    $vf = Get-AzLocation | Select-Object -ExpandProperty DisplayName

    #add our custom attribute
    $ValidateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($vf)
    $locationAttributeCollection.Add($ValidateSetAttribute)
    $locationAttributeCollection.Add($location)

    #add our paramater specifying the attribute collection
    $locationNameParam = New-Object System.Management.Automation.RuntimeDefinedParameter('location', [string], $locationAttributeCollection)

    #expose the name of our parameter
    $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
    $paramDictionary.Add('location', $locationNameParam)
    return $paramDictionary
}
begin {}
process
{
    foreach ($rg in $resourceGroups)
    {
        $rgExists = Get-AzResourceGroup -Name $rg -ErrorAction SilentlyContinue
        if (!$rgExists)
        {
            New-AzResourceGroup -Name $rg -Location $location -Tag $tags
        }
        else
        {
            if (!$append)
            {
                Set-AzResourceGroup -Name $rg -Tag $tags
            }
            else
            {
                $newTags = (Get-AzResourceGroup -Name $rg).Tags
                $newTags += $tags
                Set-AzResourceGroup -Name $rg -Tag $newTags
            }
        }
    }
}
end {}
