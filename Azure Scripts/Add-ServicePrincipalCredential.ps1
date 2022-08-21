<#
.SYNOPSIS
    Script that generates service principal credentials
.DESCRIPTION
    This script automates the creation of a service principal credential. There are 2 options, self-signed
    certificate or password
.PARAMETER certName
    The certificate name.
.PARAMETER certFilePath
    The local filesystem path where the certificate file will be placed.
.PARAMETER appId
    The application Id for the sevice principal
.PARAMETER KeyLength
    The certificate private key length
.PARAMETER KeyAlgorithm
    The certificate key algorithm
.PARAMETER certSubject
    The the unique identifier for the certificate name
.PARAMETER CertStoreLocation
    The certificate store where you wish to store the certificate. It is Cert:\CurrentUser\My by default
.PARAMETER certPassword
    The certificate password. It will be used to access the exported pfx
.PARAMETER ExportPubCertificate
    Exports the public certificate to a file
.PARAMETER ExportPrivateKey
    Exports the private certificate to a file
.PARAMETER startDate
    The start date for the credential
.PARAMETER endDate
     The end date for the credential
.EXAMPLE
    C:\PS>.\Add-ServicePrincipalCredential.ps1 -password -appId xxxxxx-xxxx-xxxx-xxx-xxxxxxxx
    Creates an autogenerated password credential with startdate (get-date) and end date (get-date + 1year)
.EXAMPLE
    C:\PS>.\Add-ServicePrincipalCredential.ps1 -password -appId xxxxxx-xxxx-xxxx-xxx-xxxxxxxx -startDate 05/13/2022 -endDate 05/14/2022
    Creates an autogenerated password credential specifying the start and end date (hours are also accepted example: 07/17/2017 09:00:00)
.EXAMPLE
    C:\PS>.\Add-ServicePrincipalCredential.ps1 -certName xxxxx -certFilePath x:\xxxx -appId xxxxxxxxxx -startDate 05/16/2022 -endDate 05/17/2022
    Create certificate specifying the start and end date (hours are also accepted example: 07/17/2017 09:00:00)
.OUTPUTS
    Password, certificate files
.NOTES
    Version:        1.0
    Author:         Mr-Scripting
    Creation Date:  13/05/2022
    Purpose/Change: Initial script development
.FUNCTIONALITY
    This script is aimed for generating service principal credentials
#>

[CmdletBinding(DefaultParameterSetName = 'Cert')]
param (
    [Parameter(Mandatory, ParameterSetName = 'Cert')][string]$certName,
    [Parameter(Mandatory, ParameterSetName = 'Cert')][string]$certFilePath,
    [Parameter(Mandatory)][string]$appId,
    [Parameter(ParameterSetName = 'Cert')][string]$KeyLength = 4096,
    [Parameter(ParameterSetName = 'Cert')][string]$KeyAlgorithm = "RSA",
    [Parameter(ParameterSetName = 'Cert', HelpMessage = "Example: CN=certificatename")][string]$certSubject = "CN=" + $certName,
    [Parameter(ParameterSetName = 'Cert')][string]$CertStoreLocation = "Cert:\CurrentUser\My",
    [Parameter(ParameterSetName = 'Cert')][securestring]$certPassword,
    [Parameter(ParameterSetName = 'Cert')][switch]$ExportPubCertificate,
    [Parameter(ParameterSetName = 'Cert')][switch]$ExportPrivateKey,
    [Parameter(ParameterSetName = 'Password')][switch]$password,
    [Parameter(HelpMessage = "Enter the start date of the logs, Ex: 07/17/2017 or 07/17/2017 09:00:00")][string]$startDate = (Get-Date),
    [Parameter(HelpMessage = "Enter the start date of the logs, Ex: 07/17/2017 or 07/17/2017 09:00:00")][string]$endDate = (Get-Date).AddYears(1)
)

### * Functions
function ExportCertificate
{
    param (
        [Parameter(Mandatory)][object]$Certificate,
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$CertName,
        [Parameter()][securestring]$Password,
        [Parameter(Mandatory)][string]$certType
    )
    # * Exports certificate to pfx format
    if ($certType -eq "pfx")
    {
        $Certificate | Export-PfxCertificate -FilePath $Path"\"$CertName".pfx" -Password $Password
    }
    # Exports certificate to cer format
    if ($certType -eq "cer")
    {
        $Certificate | Export-Certificate -FilePath $Path"\"$CertName".cer"
    }
}
### End Functions

try
{
    # * Login to Azure
    # ? Any way to automate this login?
    Connect-AzAccount -UseDeviceAuthentication

    # Convert strings to date
    if (!$PSBoundParameters.ContainsKey('startDate'))
    {
        $startDate = Get-Date $startDate
    }
    if (!$PSBoundParameters.ContainsKey('endDate'))
    {
        $endDate = Get-Date $endDate
    }

    # If option is certificate
    if ($PSBoundParameters.ContainsKey('certName'))
    {
        # * Generate the public certificate
        $certificate = ""
        Write-Host "Creating self-signed certificate" $certName "..." -ForegroundColor Yellow
        $certificate = New-SelfSignedCertificate -KeyFriendlyName $certName -KeyAlgorithm $KeyAlgorithm -KeyLength $KeyLength -CertStoreLocation $CertStoreLocation -Subject $certSubject -NotBefore $startDate -NotAfter $endDate
        Write-Host "Certificate "-ForegroundColor Green -NoNewline; Write-Host $certName -ForegroundColor Yellow -NoNewline; Write-Host " created successfully and added to certstore!" -ForegroundColor Green

        # * Export the public certificate to file
        Write-Host "Exporting the certificate..." -ForegroundColor Yellow
        ExportCertificate -Certificate $certificate -Path $certFilePath -CertName $certName -certType "cer" | Out-Null
        $certFullPath = $certFilePath + "\" + $certName + ".cer"
        Write-Host " The certificate was successfully exported!" -ForegroundColor Green

        # * Export certificate with private key
        if ($ExportPrivateKey -and !$PSBoundParameters.ContainsKey('certPassword'))
        {
            $securePassword = Read-Host "Please type the certificate password" -AsSecureString
            Write-Host "Exporting the certificate..." -ForegroundColor Yellow
            ExportCertificate -Certificate $certificate -Path $certFilePath -CertName $certName -Password $securePassword -certType "pfx" | Out-Null
            $certPrivPath = $certFilePath + "\" + $certName + ".pfx"
            Write-Host " The certificate was successfully exported!" -ForegroundColor Green
            Write-Host "You can find the certificate here" $certPrivPath
        }

        if ($ExportPrivateKey -and $PSBoundParameters.ContainsKey('certPassword'))
        {
            Write-Host "Exporting the certificate..." -ForegroundColor Yellow
            ExportCertificate -Certificate $certificate -Path $certFilePath -CertName $certName -Password $certPassword -certType "pfx" | Out-Null
            $certPrivPath = $certFilePath + "\" + $certName + ".pfx"
            Write-Host " The certificate was successfully exported!" -ForegroundColor Green
            Write-Host "You can find the certificate here" $certPrivPath
        }

        # * Upload public certificate
        $cer = ""
        $binCert = ""
        $credValue = ""
        $cer = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certFullPath);
        #$cer.Import($certFullPath)
        $binCert = $cer.GetRawCertData()
        $credValue = [System.Convert]::ToBase64String($binCert)

        # * Add certificate credential
        Write-Host "Creating the certificate credential for application" $appId"..." -ForegroundColor Yellow
        New-AzADAppCredential -ApplicationId $appId -CertValue $credValue -StartDate $cer.GetEffectiveDateString() -EndDate $cer.NotAfter
        Write-Host "Done!" -ForegroundColor Green

        # If the option to export public certificate is not checked then delete the certificate in the end
        if (!$ExportPubCertificate)
        {
            Write-Host "Cleaning up..."
            Remove-Item -Path $certFullPath -Force
            Write-Host "Done!"
        }
        else
        {
            Write-Host "Your certificate is located at" $certFullPath
        }
    }

    # Generates password credential for service principal
    if ($PSBoundParameters.ContainsKey('password'))
    {
        $credentials = New-Object -TypeName "Microsoft.Azure.PowerShell.Cmdlets.Resources.MSGraph.Models.ApiV10.MicrosoftGraphPasswordCredential"
        $credentials.StartDateTime = $startDate
        $credentials.EndDateTime = $endDate

        # * Add password credential
        Write-Host "Creating the application password for" $appId"..." -ForegroundColor Yellow
        # ? Option to output the password to screen or save to keyvault
        New-AzADAppCredential -ApplicationId $appId -StartDate $startDate -EndDate $endDate
        Write-Host "Done!" -ForegroundColor Green
    }
}
catch
{
    Write-Host "An error occurred:"
    Write-Host $_
}