<#
.SYNOPSIS
This script helps to manually prepare a client for clientSideSCP configuration to hybrid join the device

.DESCRIPTION
This script prepare a client for clientSideSCP configuration by getting data from Azure AD or by parameter and configures
the local registry

.PARAMETER TenantId
If you provide tenantId as parameter the automatic discovery is disabled. The tenant id of your Azure AD tenant can be
found in the Azure portal > Azure Active Directory > Properties > Directory ID

.PARAMETER TenantName
If you provide tenantName parameter the automatic discovery is disabled. Just put in one of your verifed domain names. If
you are running ADFS federated authentication you should use one of your federated domains!

.PARAMETER ForceManagedDomain
This switch parameter is used in the automatic discovery to force the script to use a managed instead of a federated
domain.

.PARAMETER RemoveRegistryKey
With the switch RemoveRegistryKey you can remove the ClientSideSCP registry key from your client

.EXAMPLE
PS > SetupClientSideSCP.ps1

The above example will start an automate discovery of your tenant id and name and create the apropriate registry key and
values

.EXAMPLE
PS > SetupClientSideSCP.ps1 -tenantName contoso.com -tenantId 2dcc96e-488e-4587-9e64-554c6a5e3d34

This call will start a manual creation of the registry key and values. No Azure AD module and connection is required.

.EXAMPLE
PS > SetupClientSideSCP.ps1 -RemoveRegistryKey

This example will wipe the any previous registry key.

.NOTES
Script written by Christian Baumgartner

Version history
v1.0    initial release

#>
#Requires -Version 4.0
#Requires -RunAsAdministrator

[CmdletBinding(DefaultParametersetname="Auto")]
Param (
    [Parameter(
        ParameterSetName='Manual',
        Mandatory=$True
    )]
    [String]
    $TenantId,

    [Parameter(
        ParameterSetName='Manual',
        Mandatory=$True
    )]
    [String]
    $TenantName,

    [Parameter(
        ParameterSetName='Auto'
    )]
    [Switch]
    $ForceManagedDomain,

    [Parameter(
        ParameterSetName='Delete'
    )]
    [Switch]
    $RemoveRegistryKey
)

Function Write-InformationColored {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Object]$MessageData,
        [ConsoleColor]$ForegroundColor = $Host.UI.RawUI.ForegroundColor, # Make sure we use the current colours by default
        [ConsoleColor]$BackgroundColor = $Host.UI.RawUI.BackgroundColor,
        [Switch]$NoNewline
    )

    $msg = [System.Management.Automation.HostInformationMessage]@{
        Message         = $MessageData
        ForegroundColor = $ForegroundColor
        BackgroundColor = $BackgroundColor
        NoNewline       = $NoNewline.IsPresent
    }

    Write-Information $msg
}

$InformationPreference = 'Continue'

[Boolean]$Change = $False
[String]$ClientSideSCPPath =  "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDJ\ADD"

Write-InformationColored -MessageData @"
`n#############################################################
#  _____ _ _         _   _____ _   _     _____ _____ _____  #
# |     | |_|___ ___| |_|   __|_|_| |___|   __|     |  _  | #
# |   --| | | -_|   |  _|__   | | . | -_|__   |   --|   __| #
# |_____|_|_|___|_|_|_| |_____|_|___|___|_____|_____|__|    #
#                                                           #
#                                                           #
#              ___ _                    _     _             #
#  ___ ___ ___|  _|_|___    ___ ___ ___|_|___| |_           #
# |  _| . |   |  _| | . |  |_ -|  _|  _| | . |  _|          #
# |___|___|_|_|_| |_|_  |  |___|___|_| |_|  _|_|            #
#                   |___|                |_|                #
#############################################################`n
"@

Write-Verbose "Using parameter set: $($PSCmdlet.ParameterSetName)"

If ($PSCmdlet.ParameterSetName -ne 'Delete') {

    If ($PSCmdlet.ParameterSetName -eq 'Auto') {

        Write-InformationColored -MessageData "Config mode: Auto" -ForegroundColor Yellow
        Write-InformationColored -MessageData "`nTrying to automatically collect <tenantId> and <tenantName>..." -ForegroundColor Yellow

        Try {

            If ($Null -eq (Get-InstalledModule AzureAD -MinimumVersion 2.0.2.4 -ErrorAction SilentlyContinue)) {
                Throw
            }

            Import-Module AzureAD
        } Catch {

            Write-InformationColored -MessageData "The Module AzureAD is not installed on your system. Install the module with Install-Module AzureAD -MinimumVersion 2.0.2.4 and re-run the script." -ForegroundColor Red
            Exit

        }

        Try {
            #Checking if we are already connected
            $AzureAdTenantDetail = Get-AzureADTenantDetail -ErrorAction SilentlyContinue



        } Catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] {

            Write-InformationColored -MessageData "No connection to Azure AD found. Connecting..." -ForegroundColor Yellow

            Try {

                $AzureAdTenant = Connect-AzureAD -ErrorAction SilentlyContinue
                If ($Null -eq $AzureAdTenant) {

                    Throw

                }
            } Catch {

                Write-InformationColored -MessageData "Authentication failed. See below error for details:" -ForegroundColor Red
                Write-InformationColored -MessageData $_.ToString() -ForegroundColor Red
                Exit

            }


        }

        $AzureAdTenantDetail = Get-AzureADTenantDetail
        $TenantId = $AzureAdTenantDetail.ObjectId
        Write-InformationColored -MessageData "Connected with Tenant $TenantId" -ForegroundColor Yellow

        #I have to use a foreach to get filter verifiedDomains. If you just use the dot-notation with the property and a where-object, federated
        #domains are not returned. Strange behavior ;-)
        $VerifiedDomains = @()
        ForEach ($Domain in $AzureAdTenantDetail.VerifiedDomains) {
            $VerifiedDomains += $Domain
        }

        Write-InformationColored -MessageData "`nEnumrating verified domains..." -ForegroundColor Yellow

        If (-not ($ForceManagedDomain)) {
            Write-InformationColored -MessageData "Filtering for federated domains..." -ForegroundColor Yellow
            $FederatedDomains = $VerifiedDomains | Where-Object {$_.Type -eq "Federated"}
        }

        If (($ForceManagedDomain) -or  ($Null -eq $FederatedDomains)) {
            Write-InformationColored -MessageData "Forced to use managed domain by user or no federated domain found." -ForegroundColor Yellow
            $TenantName = ($VerifiedDomains | Where-Object {($_.Name -like "*.onmicrosoft.com") -and ($_.Name -notlike "*.mail.onmicrosoft.com")}).Name.ToLower()
        } Else {
            Write-InformationColored -MessageData "Randomly picking a federated domain..." -ForegroundColor Yellow -NoNewline
            $TenantName = ($FederatedDomains | Get-Random).Name.ToLower()
            Write-InformationColored -MessageData $TenantName -ForegroundColor Green
        }

    } Else {
        Write-InformationColored -MessageData "Config mode: Manual" -ForegroundColor Yellow
    }

    Write-InformationColored -MessageData "`nTenant domain name used for ClientSideSCP: " -ForegroundColor Yellow -NoNewline
    Write-InformationColored -MessageData $TenantName -ForegroundColor Green

    Write-InformationColored -MessageData "Tenant id used for ClientSideSCP: " -ForegroundColor Yellow -NoNewline
    Write-InformationColored -MessageData $TenantId -ForegroundColor Green



    Write-InformationColored -MessageData "Checking for registry key: " -ForegroundColor Yellow -NoNewline
    Write-InformationColored -MessageData $ClientSideSCPPath -ForegroundColor Green

    If ( -not (Test-Path $ClientSideSCPPath) ) {

        Write-InformationColored -MessageData "Registry key $ClientSideSCPPath does not exist." -ForegroundColor Yellow

        $Input = Read-Host "`nDo you want to create the key and values in your registry (y/n)?"

        If ($Input.ToLower() -eq "y") {

            Write-InformationColored -MessageData "Creating registry key..." -ForegroundColor Yellow
            New-Item -Path $ClientSideSCPPath -Force | Out-Null

            Write-InformationColored -MessageData "Adding property TenantID..." -ForegroundColor Yellow
            New-ItemProperty -Path $ClientSideSCPPath -Name "TenantId" -PropertyType String -Force -Value $TenantId  | Out-Null

            Write-InformationColored -MessageData "Adding property TenantName..." -ForegroundColor Yellow
            New-ItemProperty -Path $ClientSideSCPPath -Name "TenantName" -PropertyType String -Force -Value $TenantName | Out-Null

            $Change = $True

        } Else {

            Write-InformationColored -MessageData "Operation cancled. Ending script" -ForegroundColor Red
            Exit

        }


    } Else {

        Write-InformationColored -MessageData "`nRegistry key already exists. Comparing if properties are different..." -ForegroundColor Yellow

        $RegistryValues = [ordered]@{
            "TenantId" = @{
                "Current" = Get-ItemPropertyValue -Path $ClientSideSCPPath -Name "TenantId"
                "New" = $TenantId
            }
            "TenantName" = @{
                "Current" = Get-ItemPropertyValue -Path $ClientSideSCPPath -Name "TenantName"
                "New" = $TenantName
            }
        }

        Foreach ($Key in $RegistryValues.Keys) {

            If ($RegistryValues.$Key.Current.ToLower() -ne $RegistryValues.$Key.New.ToLower()) {

                Write-InformationColored -MessageData ("<{0}> is different:" -f $Key) -ForegroundColor Yellow
                Write-InformationColored -MessageData ("`tCurrent: {0}`n`tNew:     {1}" -f `
                            $RegistryValues.$Key.Current, $RegistryValues.$Key.New)

                $Input = Read-Host -Prompt "Do you wan't to update this value (y/n)?"

                If ($Input.ToLower() -eq "y") {
                    Write-InformationColored -MessageData "Updating <$key>..." -ForegroundColor Yellow
                    Set-ItemProperty -Path $ClientSideSCPPath -Name $Key -Value $RegistryValues.$Key.New -Force

                    $Change = $True

                } Else {

                    Write-InformationColored -MessageData "Skipping update!`n" -ForegroundColor Red

                }


            } Else {

                Write-InformationColored -MessageData "Value $key is the same. No change needed." -ForegroundColor Green

            }
        }


    }


} Else {

    Write-InformationColored -MessageData "Config mMode: Delete" -ForegroundColor Yellow

    $ParentPath = Split-Path -Path $ClientSideSCPPath -Parent

    If (Test-Path $ParentPath) {

        $Input = Read-Host -Prompt "Are you sure you want to remove registry key (y/n)?"
        If ($Input.ToLower() -eq "y") {

            Write-InformationColored -MessageData "Removing registry key..." -ForegroundColor Yellow

            Try {

                Remove-Item -Path $ParentPath -Recurse -Force
                $Change = $True

            } Catch {

                $_
                Exit

            }
        }
    } Else {

        Write-InformationColored -MessageData "ClientSideSCP reg key not found. Skipping!" -ForegroundColor Red

    }
}

If ($Change) {

    Write-InformationColored -MessageData "`n######### SETTINGS CHANGED - RESTART YOUR COMPUTER ##########" -ForegroundColor Yellow

}
