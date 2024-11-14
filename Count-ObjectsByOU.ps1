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
A script to find empty OUs that can be removed.
An OU may have no objects in it directly, but may still have objects in a child OU.
The name of the output report is hard-coded in the script. Edit it before running.

#>

$fileDate = Get-Date -Format ddMMyy
$domain = (Get-ADRootDSE).DefaultNamingContext
$Ous = Get-ADOrganizationalUnit -Filter * -SearchBase $domain -SearchScope Subtree -Properties CanonicalName, Created, Description, LinkedGroupPolicyObjects, Modified | Sort-Object CanonicalName
$objects = Get-ADObject -Filter * -SearchBase $domain -SearchScope Subtree
$objClass = @('Contact', 'Computer', 'Group', 'OrganizationalUnit', 'User')
$Ous.ForEach({
        $Dn = $_.DistinguishedName
        $objectsInOu = $objects | Where-Object { $_.DistinguishedName -match "$Dn\Z" }
        $countObj = $objectsInOu | Where-Object { $_.ObjectClass -ne 'OrganizationalUnit' } | Measure-Object | Select-Object -ExpandProperty Count
        $countUser = $objectsinOu | Where-Object { $_.ObjectClass -eq 'User' } | Measure-Object | Select-Object -ExpandProperty Count
        $countComputer = $objectsinOu | Where-Object { $_.ObjectClass -eq 'Computer' } | Measure-Object | Select-Object -ExpandProperty Count
        $countGroup = $objectsinOu | Where-Object { $_.ObjectClass -eq 'Group' } | Measure-Object | Select-Object -ExpandProperty Count
        $countContact = $objectsinOu | Where-Object { $_.ObjectClass -eq 'Contact' } | Measure-Object | Select-Object -ExpandProperty Count
        $countOther = $objectsinOu | Where-Object { $_.ObjectClass -notin $objClass } | Measure-Object | Select-Object -ExpandProperty Count
        $countOu = ($objectsinOu | Where-Object { $_.ObjectClass -eq 'OrganizationalUnit' } | Measure-Object | Select-Object -ExpandProperty Count) - 1 # subtract 1 because the parent OU is included in the objects
        [pscustomobject]@{
            'Name'           = Split-Path $_.CanonicalName -Leaf
            'Canonical Name' = $_.CanonicalName
            'Dn'             = $Dn
            'Created'        = (Get-Date $_.Created -Format dd/MM/yyyy)
            'Total'          = $countObj
            'Users'          = $countUser
            'Computers'      = $countComputer
            'Groups'         = $countGroup
            'Contacts'       = $countContact
            'Other'          = $countOther
            'GPOs'           = $_.LinkedGroupPolicyObjects | Measure-Object | Select-Object -ExpandProperty Count
            'OUs'            = $CountOu
        }
    }) | Export-Csv "C:\Temp\CountObjectsByOU_$fileDate.csv" -NoTypeInformation
