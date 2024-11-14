<#PSScriptInfo

.VERSION 1.0

.GUID f2e0a20b-6d3c-4ef3-a3a5-c8391b5c0f0a

.AUTHOR Anthony Yates

.COMPANYNAME Airdesk Services

.COPYRIGHT 2024 Anthony Yates

.TAGS Active Directory

.LICENSEURI https://github.com/Air-Git/ad-remediation/blob/main/LICENSE

.PROJECTURI https://github.com/Air-Git/ad-remediation/tree/main

.ICONURI

.EXTERNALMODULEDEPENDENCIES Active Directory, Microsoft Graph PowerShell SDK, Exchange Online

.REQUIREDSCRIPTS None

.EXTERNALSCRIPTDEPENDENCIES None

.RELEASENOTES

.PRIVATEDATA

#>

<#

.DESCRIPTION
A script to report on all user accounts in AD and discover which ones are inactive.
Because most environments now are hybrid, this requires finding the matching account in Entra ID. We also check Exchange Online for shared mailboxes.
You should check you have access to Entra ID via the Microsoft Graph PowerShell SDK, and to Exchange Online, before proceeding.
The script produces an Excel report, which you can filter to show inactive user accounts.
The name of the output report is hard-coded in the script. Edit it before running.
The script is resource intensive because it needs to read all AD user accounts, all Entra ID user accounts and all mailboxes to match them up.

#>

$date = Get-Date
$fileDate = Get-Date -Format ddMMyy
# AD
$ADUsers = Get-ADUser -Filter * -Properties AccountExpirationDate, CanonicalName, Created, Description, DisplayName, LastLogonDate, LastLogonTimestamp, Modified, PwdLastSet | Sort-Object CanonicalName
# Entra ID
Connect-MgGraph -Scopes "Directory.Read.All"
$AADUsers = Get-MgUser -All -Property UserPrincipalName, SignInActivity -Filter "UserType eq 'Member'" -Sort UserPrincipalName -ConsistencyLevel Eventual -CountVariable counter
# Exchange Online
Connect-ExchangeOnline
$mailboxes = Get-ExoMailbox -ResultSize Unlimited | Sort-Object UserPrincipalName

# Go through each ADuser
$ADUsers | ForEach-Object {
    $UPN = $_.UserPrincipalName
    if ($_.AccountExpirationDate) {
        $accountExpirationDate = Get-Date $_.AccountExpirationDate -Format dd/M/yyyy
    }
    else {
        $accountExpirationDate = 'Never'
    }
    $pwdLastSet = ([datetime]::FromFileTime($_.PwdLastSet))
    $lastLogonTimestamp = ([datetime]::FromFileTime($_.LastLogonTimestamp))
    $onlineAccount = $AADUsers | Where-Object { $_.UserPrincipalName -eq $UPN }
    $lastSignin = $onlineAccount.SignInActivity.LastSignInDateTime
    $mailbox = $mailboxes | Where-Object { $_.UserPrincipalName -eq $UPN }
    if ($mailbox) { $hasMailbox = $true }
    else { $hasMailbox = $false }
    $mailboxType = 'None'
    if ($mailbox) { $mailboxType = $($mailbox.RecipientTypeDetails) }

    # the last signin is often null
    try {
        $lastSignInDate = Get-Date $lastSignin -Format dd/MM/yyyy
    }
    catch [System.Management.Automation.ParameterBindingException] {
        $lastSignInDate = $null
    }
    try {
        $lastSignInGap = (New-TimeSpan -Start $lastSignin -End $date).Days
    }
    catch [System.Management.Automation.ParameterBindingException] {
        $lastSignInGap = $null
    }
    [pscustomobject]@{
        'sAMAccountName'          = $_.sAMAccountName
        'GUID'                    = $_.ObjectGUID
        'Created'                 = Get-Date -Date $_.Created -Format dd/MM/yyyy
        'Last Modified'           = Get-Date -Date $_.Modified -Format dd/MM/yyyy
        'Display Name'            = $_.DisplayName
        'Enabled'                 = $_.Enabled
        'Mailbox'                 = $hasMailbox
        'Mailbox Type'            = $mailboxType
        'Pwd Last Set'            = Get-Date $pwdLastSet -Format dd/MM/yyyy
        'Pwd Gap'                 = (New-TimeSpan -Start $pwdLastSet -End $date).Days
        'Last Logon Timestamp'    = Get-Date $lastLogonTimestamp -Format dd/MM/yyyy
        'Last Logon Gap'          = (New-TimeSpan -Start $lastLogonTimestamp -End $date).Days
        'Account Expiration Date' = $accountExpirationDate
        'Last Signin Activity'    = $lastSignInDate
        'Last Signin Gap'         = $lastSignInGap
        'Description'             = $_.Description
        'Type'                    = $type
        'OU'                      = $_.CanonicalName | Split-Path -Parent
    }

} | Export-Csv "C:\Temp\UserLastActive_$fileDate.csv" -NoTypeInformation
