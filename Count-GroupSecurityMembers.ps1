<#PSScriptInfo

.VERSION 1.0

.GUID a4cf37fe-181f-4200-837c-25df3bb47262

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
A script to report on the number of security group members in AD and discover which groups may be obsolete.
The script produces an Excel report, which you can filter to show empty groups, or groups where all members are disabled.
The name of the output report is hard-coded in the script. Edit it before running.

#>

$fileDate = Get-Date -Format ddMMyy
# Use GroupCategory -eq "Security" for security groups
# Exclude the Builtin and default domain groups if required, with Where-Object, or filter out later
$groups = Get-ADGroup -Filter 'GroupCategory -eq "Security"' -Properties CanonicalName, Created, Description, DisplayName, IsCriticalSystemObject, Mail, ManagedBy, Members, Modified | Sort-Object CanonicalName
# Exclude very large groups for this analysis
$groups | Where-Object { $_.Members.count -lt 2000 -and $_.Name -ne 'Domain Users' -and $_.Name -ne 'Domain Computers' } | ForEach-Object {
    try {
        $groupMembersCount = Get-ADGroupMember -Identity $_.ObjectGUID | Measure-Object | Select-Object -ExpandProperty Count  # this is done to check the numbers from Get-ADGroup vs Get-ADGroupMember
    }
    catch { $groupMembersCount = "Count error $Error[0].Exception.GetType().FullName" }
    $members = $_.Members | ForEach-Object {
        try { Get-ADObject -Identity $_ }
        catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] { "Object not found for $_" }
        catch { $Error[0].Exception.GetType().FullName }
    }
    if ($_.ManagedBy) {
        $managedBy = (Get-ADObject -Identity $_.ManagedBy -Properties UserPrincipalName).UserPrincipalName
    }
    else { $managedBy = $null }
    [pscustomobject]@{
        'Name'                   = $_.Name
        'sAMAccountName'         = $_.SamAccountName
        'GUID'                   = $_.ObjectGuid
        'Display Name'           = $_.DisplayName
        'Description'            = $_.Description
        'Canonical Name'         = $_.CanonicalName | Split-Path -Parent
        'Created'                = (Get-Date $_.Created -Format dd/MM/yyyy)
        'Modified'               = (Get-Date $_.Modified -Format dd/MM/yyyy)
        'Managed By'             = $managedBy
        'Mail'                   = $_.Mail
        'Critical System Object' = $_.IsCriticalSystemObject
        'Members'                = $_.Members | Measure-Object | Select-Object -ExpandProperty Count # this one is the members of Get-ADGroup
        'Group Members'          = $groupMembersCount
        'Users'                  = ($members | Where-Object { $_.objectClass -eq 'User' }) | Measure-Object | Select-Object -ExpandProperty Count
        'Disabled Users'         = ($members | Where-Object { $_.objectClass -eq 'User' }) | Get-ADUser | Where-Object { $_.Enabled -eq $false } | Measure-Object | Select-Object -ExpandProperty Count
        'Computers'              = ($members | Where-Object { $_.objectClass -eq 'Computer' }) | Measure-Object | Select-Object -ExpandProperty Count
        'Disabled Computers'     = ($members | Where-Object { $_.objectClass -eq 'Computer' }) | Get-ADComputer | Where-Object { $_.Enabled -eq $false } | Measure-Object | Select-Object -ExpandProperty Count
        'Contacts'               = ($members | Where-Object { $_.objectClass -eq 'Contact' }) | Measure-Object | Select-Object -ExpandProperty Count
        'Groups'                 = ($members | Where-Object { $_.objectClass -eq 'Group' }) | Measure-Object | Select-Object -ExpandProperty Count
        'Other'                  = ($members | Where-Object { $_.objectClass -ne 'User' -and $_.objectClass -ne 'Contact' -and $_.objectClass -ne 'Group' -and $_.objectClass -ne 'Computer' }) | Measure-Object | Select-Object -ExpandProperty Count
    }
} | Export-Csv "C:\Temp\GroupsSecurityMembers_$fileDate.csv" -NoTypeInformation
