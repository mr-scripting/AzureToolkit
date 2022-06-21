<#
.SYNOPSIS
    This script Creates a certificate, uploads it into a service principal and then creates a service connection on devops with the pem file
.DESCRIPTIONs.
    This script Creates a certificate, uploads it into a service principal and then creates a service connection on devops with the pem file
.PARAMETERS
  None.
.INPUTS
  None.
.OUTPUTS
  None.
.NOTES
  Version:        1.0
  Authors:        Mr-Scripting
  Creation Date:  2022-06-21

.EXAMPLE
  .\DevopsServiceConnection.ps1 -CertName "XXXXXX" -OutputDirectory "C:\Windows\temp" -SPAppID "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" -AzSubscriptionName "xxxxxxx" -DevpsConnectionName "xxxxxxx" -DevpsOrganization "https://dev.azure.com/XXXXX" -DevpsProject "XXXXX" -PAT "XXXXXXXXXXX"
#>

[CmdletBinding()]
param (
  [Parameter(Mandatory = $true)][string]$CertName,
  [Parameter(Mandatory = $true)][string]$OutputDirectory,
  [Parameter(Mandatory = $true)][string]$SPAppID,
  [Parameter(Mandatory = $true)][string]$AzSubscriptionName,
  [Parameter(Mandatory = $true)][string]$DevpsConnectionName,
  [Parameter(Mandatory = $true)][string]$DevpsOrganization,
  [Parameter(Mandatory = $true)][string]$DevpsProject,
  [Parameter(Mandatory = $true)][string]$PAT


)

# vars
$subject = "CN=" + $CertName # The certificate canonical name
$certFilePath = $OutputDirectory + "\" + $CertName + ".cer" # File path for the public certificate - The one uploaded into app registration
$pfxFilePath = $OutputDirectory + "\" + $CertName + ".pfx" # File path for pfx certificate to be exported - This is needed because it contains the private key
$pemFilePath = $OutputDirectory + "\" + $CertName + ".pem" # File path to store the converted pem - needed to create the connection

# Azure Login
Connect-AzAccount
Set-AzContext -Subscription $AzSubscriptionName
az login
Write-Output $PAT | az devops login --org $DevpsOrganization

# Subscription ID
$AzsubscriptionId = $(Get-AzSubscription -SubscriptionName $AzSubscriptionName).Id

# Tenant ID
$AztenantId = $(Get-AzSubscription -SubscriptionName $AzSubscriptionName).TenantId

# Certificate Operations

# Install OpenSSL

# Download and install OpenSSL

$checkInstalled = cmd.exe /c "winget list ShiningLight.OpenSSLLight" 2> $null
if ($checkInstalled -match "ShiningLight.OpenSSLLight")
{
  Write-Host "Open SSL Already Installed"
}
else
{
  Write-Host "Installing OpenSSL..."
  winget install -e --id ShiningLight.OpenSSL -h
  Write-Host "OpenSSL installed..."
}

## export public certificate
$certificate = ""
$certificate = New-SelfSignedCertificate -KeyFriendlyName $DevpsConnectionName -KeyAlgorithm RSA -KeyLength 4096 -CertStoreLocation "Cert:\CurrentUser\My" -Subject $subject
Export-Certificate -Cert $certificate -FilePath $certFilePath

## export certificate with private key
$password = Read-Host "Please type pfx password" -AsSecureString
$certificate | Export-PfxCertificate -FilePath $pfxFilePath -Password $password

# Convert pfx to pem
Push-Location "C:\Program Files\OpenSSL-Win64\bin"
Invoke-Expression ".\openssl.exe pkcs12 -in $pfxFilePath -out $pemFilePath -nodes"

# Upload public certificate
$cer = ""
$binCert = ""
$credValue = ""
$cer = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2($certFilePath)
$binCert = $cer.GetRawCertData()
$credValue = [System.Convert]::ToBase64String($binCert)

# Create App Credential
New-AzADAppCredential -ApplicationId $SPAppID -CertValue $credValue -StartDate $([System.DateTime]::Now) -EndDate $cer.NotAfter

# Install Devops
az extension add --name azure-devops

# Create Service Endpoint
az devops service-endpoint azurerm create --azure-rm-subscription-id $AzsubscriptionId --azure-rm-service-principal-id $SPAppID --azure-rm-subscription-name $AzSubscriptionName --azure-rm-service-principal-certificate-path $pemFilePath --name $DevpsConnectionName --azure-rm-tenant-id $AztenantId --organization $DevpsOrganization --project $DevpsProject

Pop-Location
