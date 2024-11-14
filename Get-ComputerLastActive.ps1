<#PSScriptInfo

.VERSION 1.0

.GUID c45667a6-6995-4ecc-9cf5-4fa93b195d38

.AUTHOR Anthony Yates

.COMPANYNAME Airdesk Services

.COPYRIGHT 2024 Anthony Yates

.TAGS Active Directory

.LICENSEURI https://github.com/Air-Git/ad-remediation/blob/main/LICENSE

.PROJECTURI https://github.com/Air-Git/ad-remediation/tree/main

.ICONURI

.EXTERNALMODULEDEPENDENCIES Active Directory

.REQUIREDSCRIPTS None

.EXTERNALSCRIPTDEPENDENCIES None

.RELEASENOTES

.PRIVATEDATA

#>

<#

.DESCRIPTION
A script to report on all computer accounts in AD and discover which ones are inactive.
The script produces an Excel report, which you can filter to show inactive user accounts.
The name of the output report is hard-coded in the script. Edit it before running.

#>

$date = Get-Date
$fileDate = Get-Date -Format ddMMyy
$computers = Get-ADComputer -Filter * -Properties CanonicalName, Created, Description, DisplayName, LastLogonDate, LastLogonTimestamp, Modified, OperatingSystem, PwdLastSet | Sort-Object CanonicalName
# Do each one
$computers | 
ForEach-Object {
    $pwdLastSet = ([datetime]::FromFileTime($_.PwdLastSet))
    $lastLogonTimestamp = ([datetime]::FromFileTime($_.LastLogonTimestamp))
    $OU = try { $_.CanonicalName | Split-Path -Parent } catch [System.Management.Automation.ParameterBindingValidationException] {}
    [pscustomobject]@{
        'sAMAccountName'       = $_.sAMAccountName
        'GUID'                 = $_.ObjectGUID
        'Created'              = Get-Date -Date $_.Created -Format dd/MM/yyyy
        'Last Modified'        = Get-Date -Date $_.Modified -Format dd/MM/yyyy
        'Display Name'         = $_.DisplayName
        'Enabled'              = $_.Enabled
        'Pwd Last Set'         = Get-Date $pwdLastSet -Format dd/MM/yyy
        'Pwd Gap'              = (New-TimeSpan -Start $pwdLastSet -End $date).Days
        'Last Logon Timestamp' = Get-Date $lastLogonTimestamp -Format dd/MM/yyyy
        'Last Logon Gap'       = (New-TimeSpan -Start $lastLogonTimestamp -End $date).Days
        'Description'          = $_.Description
        'Operating System'     = $_.OperatingSystem
        'OU'                   = $OU
    }
} | Export-Csv "C:\Temp\ComputerLastActive_$fileDate.csv" -NoTypeInformation
