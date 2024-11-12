<#PSScriptInfo

.VERSION 1.0

.GUID 7e119883-e0e2-4de7-8a8e-f470afd3d4a0

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
A script to count the number of objects of different types in each OU.
The aim is to identify OUs that can be removed.
The name of the output report is hard-coded in the script. Edit it before running.
You can add any further details to the script, for example the number of enabled and disabled accounts in each OU.
The reason for using Get-ADUser etc. as well as Get-ADObject is so that we can access distinct properties of each object type more easily.

#>

$fileDate = Get-Date -Format ddMMyy
$OUs = Get-ADOrganizationalUnit -Properties CanonicalName, Created, LinkedGroupPolicyObjects -Filter *
$OUs | Sort-Object CanonicalName | ForEach-Object {
    $objects = Get-ADObject -Filter * -SearchBase $_.DistinguishedName -SearchScope OneLevel
    $users = Get-ADUser -Filter * -SearchBase $_.DistinguishedName -SearchScope OneLevel -Properties Enabled
    $computers = Get-ADComputer -Filter * -SearchBase $_.DistinguishedName -SearchScope OneLevel -Properties Enabled, OperatingSystem
    $groups = Get-ADGroup -Filter * -SearchBase $_.DistinguishedName -SearchScope OneLevel
    [pscustomobject]@{
        'Name'           = Split-Path $_.CanonicalName -Leaf
        'Canonical Name' = $_.CanonicalName
        'Created'        = (Get-Date $_.Created -Format dd/MM/yyyy)
        'Objects'        = $objects | Measure-Object | Select-Object -ExpandProperty Count
        'Users'          = $users  | Measure-Object | Select-Object -ExpandProperty Count
        'Contacts'       = $objects | Where-Object { $_.ObjectClass -eq 'Contact' } | Measure-Object | Select-Object -ExpandProperty Count
        'Computers'      = $computers | Measure-Object | Select-Object -ExpandProperty Count
        'Win10'          = $computers | Where-Object { $_.OperatingSystem -Like "Windows 10*" } | Measure-Object | Select-Object -ExpandProperty Count
        'Server'         = $computers | Where-Object { $_.OperatingSystem -Like "Windows Server*" } | Measure-Object | Select-Object -ExpandProperty Count
        'Groups'         = $groups | Measure-Object | Select-Object -ExpandProperty Count
        'Security'       = $groups | Where-Object { $_.GroupCategory -eq 'Security' } | Measure-Object | Select-Object -ExpandProperty Count
        'Distribution'   = $groups | Where-Object { $_.GroupCategory -eq 'Distribution' } | Measure-Object | Select-Object -ExpandProperty Count
        'GPOs'           = $_.LinkedGroupPolicyObjects | Measure-Object | Select-Object -ExpandProperty Count
        'OUs'            = Get-ADOrganizationalUnit -Filter * -SearchBase $_.DistinguishedName -SearchScope OneLevel | Measure-Object | Select-Object -ExpandProperty Count
    }
} | Export-Csv "C:\Temp\ObjectsByOU_$fileDate.csv" -NoTypeInformation
