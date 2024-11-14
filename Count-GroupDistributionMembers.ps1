<#PSScriptInfo

.VERSION 1.0

.GUID d18b9b7a-b68d-4fb3-b5b8-5a08ff9686f1

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
A script to report on the number of distribution group members in AD and discover which groups may be obsolete.
Because most environments now are hybrid, this requires checking Exchange Online for accounts that are shared mailboxes.
You should check you have access to Exchange Online before proceeding.
The script produces an Excel report, which you can filter to show empty groups, or groups where all members are disabled.
The name of the output report is hard-coded in the script. Edit it before running.
The script is resource intensive because it needs to read all AD group members and all mailboxes to match them up.

#>

$fileDate = Get-Date -Format ddMMyy
# Use GroupCategory -eq "Distribution" for distribution groups and GroupCategory -eq "Security" for distribution groups
# Exclude the Builtin and default domain groups if required, with Where-Object, or filter out later
$groups = Get-ADGroup -Filter 'GroupCategory -eq "Distribution"' -Properties CanonicalName, Created, Description, DisplayName, IsCriticalSystemObject, ManagedBy, Members, Modified | Sort-Object CanonicalName
# Exchange Online
Connect-ExchangeOnline
$otherMailboxes = Get-ExoMailbox -Filter "RecipientTypeDetails -ne 'UserMailbox'" -ResultSize Unlimited | Sort-Object UserPrincipalName
# Exclude very large groups for this analysis
$groups | Where-Object { $_.Members.count -lt 2000 -and $_.Name -ne 'Domain Users' -and $_.Name -ne 'Domain Computers' } | ForEach-Object {
    $membersCount = $_.Members | Measure-Object | Select-Object -ExpandProperty Count
    try {
        $groupMembers = Get-ADGroupMember -Identity $_.ObjectGUID
        $groupMembersCount = $groupMembers | Measure-Object | Select-Object -ExpandProperty Count  # this is done to check the numbers from Get-ADGroup vs Get-ADGroupMember
    }
    catch { $groupMembersCount = "Count error $Error[0].Exception.GetType().FullName" }
    $members = $_.Members | ForEach-Object {
        try { Get-ADObject -Identity $_ -Properties UserPrincipalName | Sort-Object UserPrincipalName }
        catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] { "Object not found for $_.Name" }
        catch { $Error[0].Exception.GetType().FullName }
    }
    if ($_.ManagedBy) {
        $managedBy = (Get-ADObject -Identity $_.ManagedBy -Properties UserPrincipalName).UserPrincipalName
    }
    else { $managedBy = $null }
    # check for shared mailboxes
    if ($members) {
        $isOtherMailbox = Compare-Object -ReferenceObject $members -DifferenceObject $OtherMailboxes -Property UserPrincipalName -IncludeEqual -ExcludeDifferent
    }
    else { $isOtherMailbox = $null }
    [pscustomobject]@{
        'Name'            = $_.Name
        'sAMAccountName'  = $_.SamAccountName
        'GUID'            = $_.ObjectGuid
        'Display Name'    = $_.DisplayName
        'Description'     = $_.Description
        'Canonical Name'  = $_.CanonicalName | Split-Path -Parent
        'Created'         = (Get-Date $_.Created -Format dd/MM/yyyy)
        'Modified'        = (Get-Date $_.Modified -Format dd/MM/yyyy)
        'Managed By'      = $managedBy
        'Members'         = $membersCount # this one is the members of Get-ADGroup
        'Group Members'   = $groupMembersCount # this one is the members of Get-ADGroupMembers
        'Users'           = ($members | Where-Object { $_.objectClass -eq 'User' }) | Measure-Object | Select-Object -ExpandProperty Count
        'Disabled Users'  = ($members | Where-Object { $_.objectClass -eq 'User' }) | Get-ADUser | Where-Object { $_.Enabled -eq $false } | Measure-Object | Select-Object -ExpandProperty Count
        'Other Mailboxes' = $isOtherMailbox | Measure-Object | Select-Object -ExpandProperty Count
        'Contacts'        = ($members | Where-Object { $_.objectClass -eq 'Contact' }) | Measure-Object | Select-Object -ExpandProperty Count
        'Groups'          = ($members | Where-Object { $_.objectClass -eq 'Group' }) | Measure-Object | Select-Object -ExpandProperty Count
        'Other'           = ($members | Where-Object { $_.objectClass -ne 'User' -and $_.objectClass -ne 'Contact' -and $_.objectClass -ne 'Group' -and $_.objectClass -ne 'Computer' }) | Measure-Object | Select-Object -ExpandProperty Count
    }
} | Export-Csv "C:\Temp\GroupDistributionMembers_$fileDate.csv" -NoTypeInformation
