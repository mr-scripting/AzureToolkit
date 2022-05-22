

function check-variablegroup
{
    [CmdletBinding()]
    param (
        # Azure Devops Organization
        [Parameter(Mandatory)]
        [string]
        $organization,
        # The Azure Devops Project
        [Parameter(Mandatory)]
        [string]
        $project,
        # Azure Devops Variable Group Name
        [Parameter(Mandatory)]
        [string]
        $vargroupName,
        # Azure Devops Personal Access Token
        [Parameter(Mandatory)]
        [string]
        $personalAccessToken
    )

    begin
    {
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(('{0}:{1}' -f '', $personalAccessToken)))
        $vstsUri = 'https://dev.azure.com/' + $organizationName + '/' + $projectName
        $uri = $vstsUri + "/_apis/distributedtask/variablegroups?api-version=7.1-preview.2"
    }

    process
    {
        $groups = Invoke-RestMethod -Uri $ri -Method Get -Headers @{Authorization = ('Basic {0}' -f $base64AuthInfo) }

        end {

        }
    }
}

function update-variablegroup
{
    [CmdletBinding()]
    param (
        # Azure Devops Organization
        [Parameter(Mandatory)]
        [string]
        $organization,
        # The Azure Devops Project
        [Parameter(Mandatory)]
        [string]
        $project,
        # Azure Devops Variable Group Name
        [Parameter(Mandatory)]
        [string]
        $vargroupName
    )

    begin
    {
        $url = "https://dev.azure.com/" + $organization + "/" + $project + "/_apis/distributedtask/variablegroups?api-version=7.1-preview.2"
    }

    process
    {
        end {

        }
    }
}